<?php
/**
 * Daily Market Prices Notification Script - Dynamic & Sowing-Specific
 * 
 * This script fetches active crop selections for each district, gets the latest 
 * market prices for those crops in the corresponding district, and sends 
 * personalized alerts to topic subscriptions: district_{district}_crop_{crop}.
 * For general users, it sends a fallback native commodity price to the district topic.
 * 
 * Set up a cron job on your server to run this script every morning at 10 AM:
 * 0 10 * * * php /path/to/api/send_market_prices.php
 */

require_once __DIR__ . '/../config.php';

// Prevent unauthorized execution via public web requests
$secretToken = "cropsync_market_cron_secret_8833"; // Secure secret token
if (php_sapi_name() !== 'cli') {
    $providedToken = $_GET['token'] ?? '';
    if (empty($providedToken) || $providedToken !== $secretToken) {
        http_response_code(403);
        die("Unauthorized access.");
    }
}

$projectId = "cropsync-d3457";

// Helper function to map Crop names to government API commodities
function getCommoditySearchPatterns($cropName) {
    $lower = strtolower(trim($cropName));
    switch ($lower) {
        case 'paddy':
            return ['Paddy(Common)%', 'Paddy(Fine)%', 'Paddy%'];
        case 'cotton':
            return ['Cotton%'];
        case 'sunflower':
            return ['Sunflower%'];
        case 'banana':
            return ['Banana%'];
        case 'turmeric':
            return ['Turmeric%'];
        case 'maize':
            return ['Maize%'];
        case 'chilli':
            return ['%Chilli%', '%Chillies%', 'Chilli%'];
        case 'tomato':
            return ['Tomato%'];
        case 'bitter gourd':
            return ['Bitter Gourd%', 'Bittergourd%'];
        case 'tea':
            return ['Tea%'];
        default:
            return ['%' . $cropName . '%'];
    }
}

// 1. Fetch Unique Districts of Registered Users
try {
    $stmt = $pdo->prepare("SELECT DISTINCT district FROM users WHERE district IS NOT NULL AND district != ''");
    $stmt->execute();
    $districts = $stmt->fetchAll(PDO::FETCH_COLUMN);
} catch (PDOException $e) {
    die("Database query failed: " . $e->getMessage());
}

if (empty($districts)) {
    $districts = ['Hyderabad'];
}

// 2. Loop through each district
foreach ($districts as $district) {
    $district = trim($district);
    $safeDistrict = strtolower(preg_replace('/[^a-zA-Z0-9-_.~%]/', '_', $district));

    // A. Fetch unique crop English names sown in this district
    try {
        $stmtCrops = $pdo->prepare("
            SELECT DISTINCT c.name_en 
            FROM user_crop_selections ucs 
            JOIN users u ON ucs.user_id = u.user_id 
            JOIN crops c ON ucs.crop_id = c.id 
            WHERE LOWER(TRIM(u.district)) = LOWER(TRIM(?))
        ");
        $stmtCrops->execute([$district]);
        $sownCrops = $stmtCrops->fetchAll(PDO::FETCH_COLUMN);
    } catch (PDOException $e) {
        echo "Failed to fetch crops for $district: " . $e->getMessage() . "\n";
        $sownCrops = [];
    }

    $sentCropTopics = [];

    // B. Send personalized price notifications for each sown crop
    foreach ($sownCrops as $cropName) {
        $cropName = trim($cropName);
        $safeCrop = strtolower(preg_replace('/[^a-zA-Z0-9-_.~%]/', '_', $cropName));
        $topic = "district_{$safeDistrict}_crop_{$safeCrop}";

        $patterns = getCommoditySearchPatterns($cropName);
        
        // Query latest price in the district
        $priceRecord = null;
        foreach ($patterns as $pattern) {
            $stmtPrice = $pdo->prepare("
                SELECT commodity, market, modal_price, arrival_date 
                FROM market_prices_history 
                WHERE LOWER(TRIM(district)) = LOWER(TRIM(?)) 
                  AND commodity LIKE ? 
                ORDER BY arrival_date DESC, id DESC LIMIT 1
            ");
            $stmtPrice->execute([$district, $pattern]);
            $priceRecord = $stmtPrice->fetch(PDO::FETCH_ASSOC);
            if ($priceRecord) {
                break;
            }
        }

        // State-wide fallback if not found in the district
        if (!$priceRecord) {
            foreach ($patterns as $pattern) {
                $stmtPrice = $pdo->prepare("
                    SELECT commodity, market, modal_price, arrival_date, district as record_district
                    FROM market_prices_history 
                    WHERE commodity LIKE ? 
                    ORDER BY arrival_date DESC, id DESC LIMIT 1
                ");
                $stmtPrice->execute([$pattern]);
                $priceRecord = $stmtPrice->fetch(PDO::FETCH_ASSOC);
                if ($priceRecord) {
                    break;
                }
            }
        }

        if ($priceRecord) {
            $commodity = $priceRecord['commodity'];
            $market = $priceRecord['market'];
            $price = number_format($priceRecord['modal_price'], 2);
            $date = date('d M Y', strtotime($priceRecord['arrival_date']));
            $loc = isset($priceRecord['record_district']) ? $priceRecord['record_district'] : $district;

            $alertTitle = "📈 Market Price: $cropName";
            $alertBody = "Latest price for $commodity at $market ($loc) is ₹$price/Quintal (as of $date). Click to view details.";
            
            // Image mapping based on crop
            $alertImage = "https://images.unsplash.com/photo-1595974482597-4b8da8879bc5?w=600"; // Default marketplace image
            if (strtolower($cropName) === 'paddy') {
                $alertImage = "https://images.unsplash.com/photo-1536657464919-8925412403c1?w=600";
            } else if (strtolower($cropName) === 'cotton') {
                $alertImage = "https://images.unsplash.com/photo-1594489993991-4529b768a341?w=600";
            } else if (strtolower($cropName) === 'chilli') {
                $alertImage = "https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=600";
            } else if (strtolower($cropName) === 'maize') {
                $alertImage = "https://images.unsplash.com/photo-1551754626-787bde9d5653?w=600";
            }

            sendFcmNotification($projectId, $topic, $alertTitle, $alertBody, $alertImage);
            echo "Sent dynamic alert for $cropName to topic: $topic\n";
            $sentCropTopics[] = $cropName;
        }
    }

    // C. Send a fallback native commodity price to the district topic (district_{district})
    // For farmers who haven't selected a crop, or as a general district update.
    try {
        // Find latest available commodity price in the district
        $stmtNative = $pdo->prepare("
            SELECT commodity, market, modal_price, arrival_date 
            FROM market_prices_history 
            WHERE LOWER(TRIM(district)) = LOWER(TRIM(?))
            ORDER BY arrival_date DESC, modal_price DESC LIMIT 1
        ");
        $stmtNative->execute([$district]);
        $nativePrice = $stmtNative->fetch(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        $nativePrice = null;
    }

    // Default state-wide fallback if no district prices exist
    if (!$nativePrice) {
        try {
            $stmtNative = $pdo->query("
                SELECT commodity, market, modal_price, arrival_date, district as fallback_district
                FROM market_prices_history 
                ORDER BY arrival_date DESC, modal_price DESC LIMIT 1
            ");
            $nativePrice = $stmtNative ? $stmtNative->fetch(PDO::FETCH_ASSOC) : null;
        } catch (PDOException $e) {
            $nativePrice = null;
        }
    }

    if ($nativePrice) {
        $commodity = $nativePrice['commodity'];
        $market = $nativePrice['market'];
        $price = number_format($nativePrice['modal_price'], 2);
        $date = date('d M Y', strtotime($nativePrice['arrival_date']));
        $loc = isset($nativePrice['fallback_district']) ? $nativePrice['fallback_district'] : $district;

        $fallbackTitle = "📊 Daily Market Price Update: $district";
        $fallbackBody = "Today's top commodity in $loc: $commodity at $market is trading at ₹$price/Quintal ($date).";
        $fallbackImage = "https://images.unsplash.com/photo-1542838132-92c53300491e?w=600"; // Premium marketplace/veg stall image

        $districtTopic = "district_{$safeDistrict}_market_general";
        sendFcmNotification($projectId, $districtTopic, $fallbackTitle, $fallbackBody, $fallbackImage);
        echo "Sent fallback native commodity alert to district topic: $districtTopic\n";
    }
}

/**
 * Sends FCM Notification via HTTP v1 API
 */
function sendFcmNotification($projectId, $topic, $title, $body, $imageUrl) {
    $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";
    $accessToken = getOAuth2Token();

    if (!$accessToken) {
        echo "Error: Failed to obtain Google OAuth2 access token.\n";
        return;
    }

    $payload = [
        "message" => [
            "topic" => $topic,
            "notification" => [
                "title" => $title,
                "body" => $body
            ],
            "data" => [
                "screen" => "market",
                "image" => $imageUrl
            ],
            "android" => [
                "notification" => [
                    "image" => $imageUrl,
                    "icon" => "ic_notification"
                ]
            ],
            "apns" => [
                "payload" => [
                    "aps" => [
                        "mutable-content" => 1
                    ]
                ],
                "fcm_options" => [
                    "image" => $imageUrl
                ]
            ]
        ]
    ];

    $headers = [
        "Authorization: Bearer $accessToken",
        "Content-Type: application/json"
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200) {
        echo "Failed to send FCM notification to $topic. Response: $response\n";
    }
}

/**
 * Generate Google OAuth2 access token from service account
 */
function getOAuth2Token() {
    $localPath = __DIR__ . '/firebase-service-account.json';
    
    if (file_exists($localPath)) {
        $keyContent = file_get_contents($localPath);
    } else {
        $keyContent = file_get_contents('https://kiosk.cropsync.in/api/firebase-service-account.json');
    }

    if (!$keyContent) {
        return null;
    }
    
    $json = json_decode($keyContent, true);
    if (!isset($json['private_key']) || !isset($json['client_email'])) {
        return null;
    }
    
    $privateKey = $json['private_key'];
    $clientEmail = $json['client_email'];
    
    $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
    $now = time();
    $claimSet = json_encode([
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'exp' => $now + 3600,
        'iat' => $now
    ]);
    
    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlClaimSet = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($claimSet));
    
    $signature = '';
    openssl_sign($base64UrlHeader . "." . $base64UrlClaimSet, $signature, $privateKey, 'SHA256');
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
    
    $jwt = $base64UrlHeader . "." . $base64UrlClaimSet . "." . $base64UrlSignature;
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt
    ]));
    $response = curl_exec($ch);
    curl_close($ch);
    
    $tokenData = json_decode($response, true);
    return $tokenData['access_token'] ?? null;
}
?>
