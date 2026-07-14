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
$envPath = __DIR__ . '/../.env';
$apiKey = "7E7P7EAAR6GGWYM3Q44J66HR2"; // Default fallback
if (file_exists($envPath)) {
    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        if (strpos($line, '=') !== false) {
            list($name, $value) = explode('=', $line, 2);
            if (trim($name) === 'WEATHER_API_KEY') {
                $apiKey = trim($value);
                break;
            }
        }
    }
}
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

    // Get time of day context based on IST timezone
    date_default_timezone_set('Asia/Kolkata');
    $hour = (int)date('H');
    
    $timeKey = "time_morning";
    if ($hour >= 12 && $hour < 17) {
        $timeKey = "time_afternoon";
    } else if ($hour >= 17 || $hour < 5) {
        $timeKey = "time_evening";
    }

    $weatherTranslations = [
        'en' => [
            'time_morning' => 'Morning',
            'time_afternoon' => 'Afternoon',
            'time_evening' => 'Evening',
            'weather_in' => '🌤️ {time} Weather in {district}',
            'heat_alert' => '☀️ Heat Alert for {district}',
            'rain_alert' => '🌧️ Weather Alert for {district}',
            'rain_body' => 'High chance of rain ({precip}%). Consider postponing irrigation or harvesting mature crops.',
            'heat_body' => 'Extreme heat expected. Temperature today will reach {temp}°C. Keep crops well-irrigated.',
            'normal_body' => 'Expect {conditions} today with a high of {temp}°C. Have a great farming day!'
        ],
        'hi' => [
            'time_morning' => 'सुबह का',
            'time_afternoon' => 'दोपहर का',
            'time_evening' => 'शाम का',
            'weather_in' => '🌤️ {district} में {time} मौसम',
            'heat_alert' => '☀️ {district} के लिए गर्मी की चेतावनी',
            'rain_alert' => '🌧️ {district} के लिए बारिश की चेतावनी',
            'rain_body' => 'बारिश की उच्च संभावना ({precip}%)। सिंचाई स्थगित करने या पकी फसलों की कटाई पर विचार करें।',
            'heat_body' => 'अत्यधिक गर्मी की संभावना। तापमान आज {temp}°C तक पहुंच जाएगा। फसलों की अच्छी सिंचाई रखें।',
            'normal_body' => 'आज {conditions} की उम्मीद है, अधिकतम तापमान {temp}°C रहेगा। आपका दिन शुभ हो!'
        ],
        'te' => [
            'time_morning' => 'ఉదయం',
            'time_afternoon' => 'మధ్యాహ్నం',
            'time_evening' => 'సాయంత్రం',
            'weather_in' => '🌤️ {district} లో {time} వాతావరణం',
            'heat_alert' => '☀️ {district} తీవ్ర ఎండల హెచ్చరిక',
            'rain_alert' => '🌧️ {district} వర్ష సూచన హెచ్చరిక',
            'rain_body' => 'వర్షం పడే అవకాశం ఎక్కువగా ఉంది ({precip}%). నీటి పారుదల వాయిదా వేయడం లేదా పంట కోయడం మంచిది.',
            'heat_body' => 'ఈరోజు తీవ్రమైన ఎండలు కాసే అవకాశం ఉంది. ఉష్ణోగ్రత {temp}°C కి చేరుకుంటుంది. పంటలకు తగిన నీరు అందించండి.',
            'normal_body' => 'ఈరోజు గరిష్ట ఉష్ణోగ్రత {temp}°C తో {conditions} గా ఉండే అవకాశం ఉంది. మీకు మంచి వ్యవసాయ దినం లభించాలని కోరుకుంటున్నాం!'
        ]
    ];

    // Helper function to translate weather conditions string
    $translateConditions = function($cond, $lang) use ($weatherTranslations) {
        $condLower = strtolower(trim($cond));
        if (isset($weatherTranslations[$lang][$condLower])) {
            return $weatherTranslations[$lang][$condLower];
        }
        $dict = [
            'overcast' => ['hi' => 'बादल छाए रहेंगे', 'te' => 'మేఘావృతం'],
            'partly cloudy' => ['hi' => 'आंशिक बादल छाए रहेंगे', 'te' => 'పాక్షిక మేఘావృతం'],
            'clear' => ['hi' => 'साफ आसमान', 'te' => 'ప్రశాంతమైన వాతావరణం'],
            'sunny' => ['hi' => 'धूप', 'te' => 'ఎండగా'],
            'rain' => ['hi' => 'बारिश', 'te' => 'वर्షం']
        ];
        foreach ($dict as $key => $trans) {
            if (strpos($condLower, $key) !== false && isset($trans[$lang])) {
                return $trans[$lang];
            }
        }
        return $cond;
    };

    // Send notifications to each language
    $languages = ['en', 'hi', 'te'];
    foreach ($languages as $lang) {
        $alertTitle = "";
        $alertBody = "";
        $alertImage = "";

        $translatedTime = $weatherTranslations[$lang][$timeKey];
        $translatedConditions = $translateConditions($conditions, $lang);

        if ($precipProb > 70) {
            $alertTitle = str_replace('{district}', $district, $weatherTranslations[$lang]['rain_alert']);
            $alertBody = str_replace('{precip}', $precipProb, $weatherTranslations[$lang]['rain_body']);
            $alertImage = "https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=600";
        } else if ($tempMax > 40) {
            $alertTitle = str_replace('{district}', $district, $weatherTranslations[$lang]['heat_alert']);
            $alertBody = str_replace('{temp}', $tempMax, $weatherTranslations[$lang]['heat_body']);
            $alertImage = "https://images.unsplash.com/photo-1504370805625-d32c54b16100?w=600";
        } else {
            $alertTitle = str_replace(['{district}', '{time}'], [$district, $translatedTime], $weatherTranslations[$lang]['weather_in']);
            $alertBody = str_replace(['{conditions}', '{temp}'], [$translatedConditions, $tempMax], $weatherTranslations[$lang]['normal_body']);
            $alertImage = "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600";
        }

        // Send to language-specific topic
        $langTopic = $safeTopic . '_' . $lang;
        sendFcmNotification($projectId, $langTopic, $alertTitle, $alertBody, $alertImage);
        echo "Notification sent to topic: $langTopic ($district - $lang)\n";
        
        // Also send to the legacy district general topic (defaults to English content)
        if ($lang === 'en') {
            sendFcmNotification($projectId, $safeTopic, $alertTitle, $alertBody, $alertImage);
            echo "Notification sent to legacy topic: $safeTopic ($district)\n";
        }
    }
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
                    "icon" => "launcher_icon"
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
    $privateKey = str_replace(["\\n", '\n'], "\n", $json['private_key']);
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
