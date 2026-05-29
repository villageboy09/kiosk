<?php
// market_prices_api.php

function fetchMarketPriceRecordsFromGov($state) {
    $state = trim((string)$state);
    if ($state === '') {
        return ['success' => false, 'error' => 'State is required'];
    }

    $apiKey = "579b464db66ec23bdd000001813d8610f33d417d764c680f21f25387";
    $apiUrl = "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070";
    $encodedState = rawurlencode($state);
    $url = "$apiUrl?api-key=$apiKey&format=json&filters[state]=$encodedState&limit=2000";

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode != 200 || !$response) {
        return ['success' => false, 'error' => 'Failed to fetch from Gov API'];
    }

    $data = json_decode($response, true);
    $records = $data['records'] ?? [];

    if (empty($records)) {
        return ['success' => false, 'error' => 'No records fetched from Gov API'];
    }

    return ['success' => true, 'records' => $records];
}

function fetchAndStoreMarketPrices($pdo, $state) {
    $fetched = fetchMarketPriceRecordsFromGov($state);
    if (($fetched['success'] ?? false) !== true) {
        return $fetched;
    }

    $records = $fetched['records'] ?? [];

    if (empty($records)) {
        return ['success' => false, 'error' => 'No records fetched from Gov API'];
    }

    $stmt = $pdo->prepare("
        INSERT IGNORE INTO market_prices_history
        (state, district, market, commodity, variety, grade, arrival_date, min_price, max_price, modal_price)
        VALUES (?, ?, ?, ?, ?, ?, STR_TO_DATE(?, '%d/%m/%Y'), ?, ?, ?)
    ");

    $inserted = 0;
    foreach ($records as $r) {
        try {
            $stmt->execute([
                $r['state'] ?? $state,
                $r['district'] ?? '',
                $r['market'] ?? '',
                $r['commodity'] ?? '',
                $r['variety'] ?? '',
                $r['grade'] ?? '',
                $r['arrival_date'] ?? null,
                $r['min_price'] ?? 0,
                $r['max_price'] ?? 0,
                $r['modal_price'] ?? 0,
            ]);
            if ($stmt->rowCount() > 0) {
                $inserted++;
            }
        } catch (PDOException $e) {
            // Ignore malformed rows and duplicates.
        }
    }

    return ['success' => true, 'message' => "Synced $inserted new records."];
}

function syncMarketPrices($pdo) {
    $statesParam = trim((string)($_GET['states'] ?? ''));

    if ($statesParam !== '') {
        $states = array_values(array_filter(array_map('trim', explode(',', $statesParam))));
        $totalInserted = 0;
        $messages = [];

        foreach ($states as $state) {
            $result = fetchAndStoreMarketPrices($pdo, $state);
            if (($result['success'] ?? false) === true) {
                if (preg_match('/Synced\s+(\d+)\s+new records\./', $result['message'] ?? '', $matches)) {
                    $totalInserted += (int)$matches[1];
                }
                $messages[] = $state;
            }
        }

        echo json_encode([
            'success' => true,
            'message' => 'Synced market prices for: ' . implode(', ', $messages),
            'states' => $messages,
            'inserted' => $totalInserted,
        ]);
        return;
    }

    $state = $_GET['state'] ?? 'Telangana';
    echo json_encode(fetchAndStoreMarketPrices($pdo, $state));
}

function getLiveStateMarketPrices($pdo) {
    $state = trim((string)($_GET['state'] ?? 'Telangana'));
    $result = fetchMarketPriceRecordsFromGov($state);

    if (($result['success'] ?? false) !== true) {
        echo json_encode($result);
        return;
    }

    $records = $result['records'] ?? [];
    $latestDate = '';
    foreach ($records as $record) {
        $dateValue = $record['arrival_date'] ?? '';
        if ($dateValue !== '' && ($latestDate === '' || strcmp($dateValue, $latestDate) > 0)) {
            $latestDate = $dateValue;
        }
    }

    echo json_encode([
        'success' => true,
        'state' => $state,
        'date' => $latestDate,
        'records' => $records,
        'source' => 'live_api',
    ]);
}

function getStateMarketPrices($pdo) {
    $requestedState = trim((string)($_GET['state'] ?? 'Telangana'));
    $state = $requestedState !== '' ? $requestedState : 'Telangana';

    $stmtDate = $pdo->prepare("
        SELECT MAX(arrival_date) as max_date
        FROM market_prices_history
        WHERE LOWER(TRIM(state)) = LOWER(TRIM(?))
    ");
    $stmtDate->execute([$state]);
    $dateRow = $stmtDate->fetch(PDO::FETCH_ASSOC);
    $latestDate = $dateRow['max_date'] ?? null;

    if (!$latestDate) {
        $syncResult = fetchAndStoreMarketPrices($pdo, $state);
        if (($syncResult['success'] ?? false) === true) {
            $stmtDate->execute([$state]);
            $dateRow = $stmtDate->fetch(PDO::FETCH_ASSOC);
            $latestDate = $dateRow['max_date'] ?? null;
        }
    }

    if (!$latestDate) {
        $stmtLatestAny = $pdo->query("
            SELECT state, MAX(arrival_date) AS max_date
            FROM market_prices_history
            GROUP BY state
            ORDER BY max_date DESC
            LIMIT 1
        ");
        $fallback = $stmtLatestAny ? $stmtLatestAny->fetch(PDO::FETCH_ASSOC) : false;
        if ($fallback && !empty($fallback['state']) && !empty($fallback['max_date'])) {
            $state = $fallback['state'];
            $latestDate = $fallback['max_date'];
        }
    }

    if (!$latestDate) {
        echo json_encode(['success' => false, 'error' => 'No market price data available yet', 'records' => []]);
        return;
    }

    $stmt = $pdo->prepare("
        SELECT * FROM market_prices_history
        WHERE LOWER(TRIM(state)) = LOWER(TRIM(?)) AND arrival_date = ?
        ORDER BY district ASC, market ASC, commodity ASC
    ");
    $stmt->execute([$state, $latestDate]);
    $records = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (empty($records)) {
        $stmtLatestAny = $pdo->prepare("
            SELECT * FROM market_prices_history
            WHERE arrival_date = ?
            ORDER BY state ASC, district ASC, market ASC, commodity ASC
        ");
        $stmtLatestAny->execute([$latestDate]);
        $records = $stmtLatestAny->fetchAll(PDO::FETCH_ASSOC);
    }

    echo json_encode(['success' => true, 'date' => $latestDate, 'state' => $state, 'records' => $records]);
}

function getCommodityTrends($pdo) {
    $state = trim((string)($_GET['state'] ?? ''));
    $district = trim((string)($_GET['district'] ?? ''));
    $commodity = trim((string)($_GET['commodity'] ?? ''));

    if (empty($district) || empty($commodity)) {
        echo json_encode(['success' => false, 'error' => 'District and Commodity required']);
        return;
    }

    $sql = "
        SELECT arrival_date, AVG(modal_price) as avg_price
        FROM market_prices_history
        WHERE LOWER(TRIM(district)) = LOWER(TRIM(?))
          AND LOWER(TRIM(commodity)) = LOWER(TRIM(?))
    ";

    $params = [$district, $commodity];
    if ($state !== '') {
        $sql .= " AND LOWER(TRIM(state)) = LOWER(TRIM(?))";
        $params[] = $state;
    }

    $sql .= "
        GROUP BY arrival_date
        ORDER BY arrival_date ASC
        LIMIT 30
    ";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $trends = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['success' => true, 'trends' => $trends]);
}
?>
