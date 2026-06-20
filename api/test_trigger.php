<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

$projectId = "cropsync-d3457";

echo "<h2>CropSync Notification Test Tool</h2>";
echo "Attempting to send a test notification to topic: <b>all_farmers</b>...<br><br>";

$url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";
$accessToken = getOAuth2Token();

if (!$accessToken) {
    die("<b style='color:red;'>Error:</b> Failed to generate Google OAuth2 token. Check your firebase-service-account.json file.");
}

echo "OAuth2 Token generated successfully!<br>";

$payload = [
    "message" => [
        "topic" => "all_farmers",
        "notification" => [
            "title" => "🎉 CropSync Notification Test",
            "body" => "Congratulations! Your notifications setup is working perfectly. Sent on " . date('Y-m-d H:i:s')
        ],
        "data" => [
            "screen" => "shop",
            "image" => "https://images.unsplash.com/photo-1589923188900-85dae523342b?w=600"
        ],
        "android" => [
            "notification" => [
                "image" => "https://images.unsplash.com/photo-1589923188900-85dae523342b?w=600",
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
                "image" => "https://images.unsplash.com/photo-1589923188900-85dae523342b?w=600"
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

echo "HTTP Code: $httpCode<br>";
echo "FCM API Response: <pre>" . htmlspecialchars($response) . "</pre>";

if ($httpCode === 200) {
    echo "<h3 style='color:green;'>Success! Test notification broadcasted to 'all_farmers'. Check your device!</h3>";
} else {
    echo "<h3 style='color:red;'>Failed to send notification. See response details above.</h3>";
}

function getOAuth2Token() {
    $localPath = __DIR__ . '/firebase-service-account.json';
    if (!file_exists($localPath)) {
        return null;
    }
    
    $keyContent = file_get_contents($localPath);
    $json = json_decode($keyContent, true);
    if (!$json) {
        return null;
    }
    
    $privateKey = str_replace(["\\n", '\n'], "\n", $json['private_key']);
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
