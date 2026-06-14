<?php
/**
 * Daily Weather Alert Notification Script - Dynamic & Region-Specific
 * 
 * This script fetches the unique districts of registered users from the database,
 * queries the weather forecast for each district, and broadcasts alerts to each 
 * district's dedicated FCM topic (e.g. district_hyderabad).
 * 
 * Set up a cron job on your server to run this script every morning:
 * 0 7 * * * php /path/to/api/send_weather_alerts.php
 */

require_once __DIR__ . '/../config.php';

// Prevent unauthorized execution via public web requests
$secretToken = "cropsync_weather_cron_secret_7722"; // Secure secret token
if (php_sapi_name() !== 'cli') {
    $providedToken = $_GET['token'] ?? '';
    if (empty($providedToken) || $providedToken !== $secretToken) {
        http_response_code(403);
        die("Unauthorized access.");
    }
}

// 1. Configure Keys
$apiKey = "YOUR_VISUAL_CROSSING_WEATHER_API_KEY"; // Replace with your Visual Crossing key
$projectId = "cropsync-d3457";

// 2. Fetch Unique Districts from Database
try {
    $stmt = $pdo->prepare("SELECT DISTINCT district FROM users WHERE district IS NOT NULL AND district != ''");
    $stmt->execute();
    $districts = $stmt->fetchAll(PDO::FETCH_COLUMN);
} catch (PDOException $e) {
    die("Database query failed: " . $e->getMessage());
}

if (empty($districts)) {
    // Fallback if no districts registered yet
    $districts = ['Hyderabad'];
}

// 3. Loop through each district and send dynamic updates
foreach ($districts as $district) {
    $district = trim($district);
    $safeTopic = 'district_' . strtolower(preg_replace('/[^a-zA-Z0-9-_.~%]/', '_', $district));
    
    // Query weather for the district name (Visual Crossing accepts location names)
    $locationQuery = urlencode($district . ",Telangana,India");
    $weatherUrl = "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$locationQuery?unitGroup=metric&key=$apiKey&contentType=json";

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $weatherUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $weatherResponse = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200 || !$weatherResponse) {
        echo "Failed to fetch weather for $district. Skipping.\n";
        continue;
    }

    $weatherData = json_decode($weatherResponse, true);
    $today = $weatherData['days'][0];
    $conditions = $today['conditions'];
    $tempMax = $today['tempmax'];
    $precipProb = $today['precipprob'];

    // Evaluate dynamic conditions
    $alertTitle = "";
    $alertBody = "";
    $alertImage = "";

    if ($precipProb > 70) {
        $alertTitle = "🌧️ Weather Alert for $district";
        $alertBody = "High chance of rain ({$precipProb}%). Consider postponing irrigation or harvesting mature crops.";
        $alertImage = "https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=600";
    } else if ($tempMax > 40) {
        $alertTitle = "☀️ Heat Alert for $district";
        $alertBody = "Extreme heat expected. Temperature today will reach {$tempMax}°C. Keep crops well-irrigated.";
        $alertImage = "https://images.unsplash.com/photo-1504370805625-d32c54b16100?w=600";
    } else {
        $alertTitle = "🌤️ Morning Weather in $district";
        $alertBody = "Expect {$conditions} today with a high of {$tempMax}°C. Have a great farming day!";
        $alertImage = "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600"; // Beautiful generic farm field
    }

    // Broadcast specifically to this district's topic!
    sendFcmNotification($projectId, $safeTopic, $alertTitle, $alertBody, $alertImage);
    echo "Notification sent to topic: $safeTopic ($district)\n";
}

/**
 * Sends FCM Notification via HTTP v1 API
 */
function sendFcmNotification($projectId, $topic, $title, $body, $imageUrl) {
    $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";
    $accessToken = getOAuth2Token();

    $payload = [
        "message" => [
            "topic" => $topic,
            "notification" => [
                "title" => $title,
                "body" => $body
            ],
            "data" => [
                "screen" => "weather",
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
    curl_close($ch);
}

/**
 * Generate Google OAuth2 access token from service account
 */
function getOAuth2Token() {
    // Load from local file path or download it securely from the private web folder
    $localPath = __DIR__ . '/firebase-service-account.json';
    
    if (file_exists($localPath)) {
        $keyContent = file_get_contents($localPath);
    } else {
        // Fallback to fetching via URL if local path fails
        $keyContent = file_get_contents('https://kiosk.cropsync.in/api/firebase-service-account.json');
    }

    if (!$keyContent) {
        die("Firebase Service Account JSON file not found.");
    }
    
    $json = json_decode($keyContent, true);
    $privateKey = $json['private_key'];
    $clientEmail = $json['client_email'];
    
    // Header
    $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
    
    // Claim set
    $now = time();
    $claimSet = json_encode([
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'exp' => $now + 3600,
        'iat' => $now
    ]);
    
    // Encode Base64Url
    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlClaimSet = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($claimSet));
    
    // Sign JWT
    $signature = '';
    openssl_sign($base64UrlHeader . "." . $base64UrlClaimSet, $signature, $privateKey, 'SHA256');
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
    
    $jwt = $base64UrlHeader . "." . $base64UrlClaimSet . "." . $base64UrlSignature;
    
    // Request OAuth2 Token
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
    return $tokenData['access_token'];
}
