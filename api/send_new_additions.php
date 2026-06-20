<?php
/**
 * Daily New Additions Alert Script - Agri Shop & Seed Varieties
 * 
 * This script checks for new equipments (Agri Shop products) or new seed varieties
 * added to the database in the last 24 hours and broadcasts notifications to
 * the 'all_farmers' FCM topic.
 * 
 * Set up a cron job on your server to run this script every morning at 10 AM:
 * 0 10 * * * php /path/to/api/send_new_additions.php
 */

require_once __DIR__ . '/../config.php';

// Prevent unauthorized execution via public web requests
$secretToken = "cropsync_additions_cron_secret_9944"; // Secure secret token
if (php_sapi_name() !== 'cli') {
    $providedToken = $_GET['token'] ?? '';
    if (empty($providedToken) || $providedToken !== $secretToken) {
        http_response_code(403);
        die("Unauthorized access.");
    }
}

$projectId = "cropsync-d3457";
$isTest = isset($_GET['test']) && $_GET['test'] == 1;

// 1. Check for New Equipments/Products (Agri Shop)
try {
    if ($isTest) {
        // Test mode: grab the single latest active product
        $stmtProd = $pdo->query("
            SELECT product_name_en as name, image_url_1 as image, price 
            FROM products 
            WHERE is_active = 1
            ORDER BY created_at DESC LIMIT 1
        ");
    } else {
        // Daily cron mode: grab products added in the last 24 hours
        $stmtProd = $pdo->query("
            SELECT product_name_en as name, image_url_1 as image, price 
            FROM products 
            WHERE created_at >= NOW() - INTERVAL 1 DAY AND is_active = 1
        ");
    }
    $newProducts = $stmtProd ? $stmtProd->fetchAll(PDO::FETCH_ASSOC) : [];
} catch (PDOException $e) {
    echo "Error checking products: " . $e->getMessage() . "\n";
    $newProducts = [];
}

// 2. Check for New Seed Varieties
try {
    if ($isTest) {
        // Test mode: grab the single latest seed variety
        $stmtSeed = $pdo->query("
            SELECT variety_name_en as name, image_url as image, crop_name 
            FROM seed_varieties 
            ORDER BY created_at DESC LIMIT 1
        ");
    } else {
        // Daily cron mode: grab seed varieties added in the last 24 hours
        $stmtSeed = $pdo->query("
            SELECT variety_name_en as name, image_url as image, crop_name 
            FROM seed_varieties 
            WHERE created_at >= NOW() - INTERVAL 1 DAY
        ");
    }
    $newSeeds = $stmtSeed ? $stmtSeed->fetchAll(PDO::FETCH_ASSOC) : [];
} catch (PDOException $e) {
    echo "Error checking seed varieties: " . $e->getMessage() . "\n";
    $newSeeds = [];
}

// 3. Broadcast notifications to 'all_farmers' topic
if (!empty($newProducts)) {
    foreach ($newProducts as $product) {
        $name = trim($product['name']);
        $price = number_format($product['price'], 2);
        $image = !empty($product['image']) ? $product['image'] : "https://images.unsplash.com/photo-1589923188900-85dae523342b?w=600"; // Default tools image

        $title = "🚜 New Equipment in Agri Shop!";
        $body = "New addition: $name is now available. Click to check out pricing and availability.";
        
        sendFcmNotification($projectId, "all_farmers", "shop", $title, $body, $image);
        echo "Broadcasted new product notification for: $name\n";
    }
} else {
    echo "No new products added in the last 24 hours.\n";
}

if (!empty($newSeeds)) {
    foreach ($newSeeds as $seed) {
        $name = trim($seed['name']);
        $crop = trim($seed['crop_name']);
        $image = !empty($seed['image']) ? $seed['image'] : "https://images.unsplash.com/photo-1530595467537-0b5996c41f2d?w=600"; // Default seed bag image

        $title = "🌱 New Seed Variety Available!";
        $body = "Check out $name ($crop) under Seed Varieties. Click to view sowing window and yield reviews.";

        sendFcmNotification($projectId, "all_farmers", "seeds", $title, $body, $image);
        echo "Broadcasted new seed variety notification for: $name ($crop)\n";
    }
} else {
    echo "No new seed varieties added in the last 24 hours.\n";
}


/**
 * Sends FCM Notification via HTTP v1 API
 */
function sendFcmNotification($projectId, $topic, $screen, $title, $body, $imageUrl) {
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
                "screen" => $screen,
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
