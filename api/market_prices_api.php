<?php
// market_prices_api.php

function syncMarketPrices($pdo) {
    // This function should be called daily via cron job
    $apiKey = "579b464db66ec23bdd000001813d8610f33d417d764c680f21f25387";
    $apiUrl = "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070";
    
    // In a real scenario, you'd iterate through states or fetch all.
    // For this app, we focus on Telangana
    $state = "Telangana";
    $encodedState = urlencode($state);
    
    $url = "$apiUrl?api-key=$apiKey&format=json&filters[state]=$encodedState&limit=2000";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode == 200 && $response) {
        $data = json_decode($response, true);
        $records = $data['records'] ?? [];
        
        if (empty($records)) {
            echo json_encode(['success' => false, 'error' => 'No records fetched from Gov API']);
            return;
        }
        
        $inserted = 0;
        
        // Prepare statement for insertion
        $stmt = $pdo->prepare("
            INSERT IGNORE INTO market_prices_history 
            (state, district, market, commodity, variety, grade, arrival_date, min_price, max_price, modal_price)
            VALUES (?, ?, ?, ?, ?, ?, STR_TO_DATE(?, '%d/%m/%Y'), ?, ?, ?)
        ");
        
        foreach ($records as $r) {
            try {
                $stmt->execute([
                    $r['state'],
                    $r['district'],
                    $r['market'],
                    $r['commodity'],
                    $r['variety'],
                    $r['grade'],
                    $r['arrival_date'],
                    $r['min_price'],
                    $r['max_price'],
                    $r['modal_price']
                ]);
                if ($stmt->rowCount() > 0) {
                    $inserted++;
                }
            } catch (PDOException $e) {
                // Ignore errors for duplicates or invalid data
            }
        }
        
        echo json_encode(['success' => true, 'message' => "Synced $inserted new records."]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Failed to fetch from Gov API']);
    }
}

function getStateMarketPrices($pdo) {
    $state = $_GET['state'] ?? 'Telangana';
    
    // Fetch the latest prices for each commodity in each district for the requested state
    // We get the most recent date available in the database for that state
    $stmtDate = $pdo->prepare("SELECT MAX(arrival_date) as max_date FROM market_prices_history WHERE state = ?");
    $stmtDate->execute([$state]);
    $dateRow = $stmtDate->fetch(PDO::FETCH_ASSOC);
    $latestDate = $dateRow['max_date'];
    
    if (!$latestDate) {
        echo json_encode(['success' => false, 'error' => 'No data found for this state', 'records' => []]);
        return;
    }
    
    $stmt = $pdo->prepare("
        SELECT * FROM market_prices_history 
        WHERE state = ? AND arrival_date = ?
    ");
    $stmt->execute([$state, $latestDate]);
    $records = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'date' => $latestDate, 'records' => $records]);
}

function getCommodityTrends($pdo) {
    $district = $_GET['district'] ?? '';
    $commodity = $_GET['commodity'] ?? '';
    
    if (empty($district) || empty($commodity)) {
        echo json_encode(['success' => false, 'error' => 'District and Commodity required']);
        return;
    }
    
    // Fetch last 30 days of data
    $stmt = $pdo->prepare("
        SELECT arrival_date, AVG(modal_price) as avg_price 
        FROM market_prices_history 
        WHERE district = ? AND commodity = ?
        GROUP BY arrival_date
        ORDER BY arrival_date ASC
        LIMIT 30
    ");
    $stmt->execute([$district, $commodity]);
    $trends = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'trends' => $trends]);
}
?>
