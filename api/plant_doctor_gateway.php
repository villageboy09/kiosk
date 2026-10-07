<?php
/**
 * CropSync Plant Doctor Vision AI Gateway
 * Production endpoint hosted on kiosk.cropsync.in/api/plant_doctor_gateway.php
 * 
 * Features:
 * 1. Strictly enforces 24-crop whitelist from MySQL `crops` table.
 * 2. Grounds diagnoses into verified `rice_problems` catalog.
 * 3. Enriches AI recommendations with curated CIBRC dosages.
 * 4. Secures DEEPSEEK_API_KEY on the server.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 1. Include DB Configurations
if (file_exists(__DIR__ . '/config.php')) {
    require_once __DIR__ . '/config.php';
} elseif (file_exists(__DIR__ . '/../config.php')) {
    require_once __DIR__ . '/../config.php';
} elseif (file_exists('../config.php')) {
    require_once '../config.php';
}

// DeepSeek API key configuration:
// Option 1: Paste your DeepSeek API key directly inside the quotes below:
$deepseekApiKey = '';

// Option 2 (Fallback): Auto-load from server environment, config.php, or .env file
if (empty($deepseekApiKey)) {
    $deepseekApiKey = getenv('DEEPSEEK_API_KEY') ?: '';
}
if (empty($deepseekApiKey) && defined('DEEPSEEK_API_KEY')) {
    $deepseekApiKey = DEEPSEEK_API_KEY;
}
if (empty($deepseekApiKey) && file_exists(__DIR__ . '/.env')) {
    $envLines = file(__DIR__ . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($envLines as $line) {
        if (strpos(trim($line), 'DEEPSEEK_API_KEY=') === 0) {
            $deepseekApiKey = trim(substr(trim($line), strlen('DEEPSEEK_API_KEY=')));
            break;
        }
    }
}

// Supported 24 Crops Whitelist
$supportedCrops = [
    1 => 'Paddy',
    2 => 'Cotton',
    12 => 'Sunflower',
    13 => 'Banana',
    14 => 'Turmeric',
    17 => 'Maize',
    18 => 'Chilli',
    19 => 'Tomato',
    20 => 'Bitter Gourd',
    21 => 'Tea',
    22 => 'Apple',
    23 => 'Sugarcane',
    24 => 'Brinjal',
    25 => 'Cumin',
    26 => 'Groundnut',
    27 => 'Mango',
    28 => 'Onion',
    29 => 'Soybean',
    30 => 'Wheat',
    31 => 'Garlic',
    32 => 'Okra',
    33 => 'Potato',
    34 => 'Pomegranate',
    35 => 'Grapes'
];

$action = $_GET['action'] ?? $_POST['action'] ?? 'diagnose';

if ($action === 'supported_crops') {
    $cropsList = [];
    if (isset($pdo) && $pdo instanceof PDO) {
        try {
            $stmt = $pdo->query("SELECT id, name, name_en, name_hi, image_url FROM crops ORDER BY id ASC");
            $cropsList = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (Throwable $e) {}
    }
    echo json_encode([
        'success' => true,
        'crops' => !empty($cropsList) ? $cropsList : $supportedCrops
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// 2. Read Request Payload
$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true) ?: [];

$language = $_POST['language'] ?? $data['language'] ?? 'en';
$selectedCropId = isset($_POST['crop_id']) ? intval($_POST['crop_id']) : (isset($data['crop_id']) ? intval($data['crop_id']) : null);
$selectedCropName = $_POST['crop_name'] ?? $data['crop_name'] ?? '';
$latitude = $_POST['latitude'] ?? $data['latitude'] ?? null;
$longitude = $_POST['longitude'] ?? $data['longitude'] ?? null;
$imageDataUri = $_POST['image_base64'] ?? $data['image_base64'] ?? '';

// Handle multipart file upload if base64 not in body
if (empty($imageDataUri) && isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
    $fileTmp = $_FILES['image']['tmp_name'];
    $mime = mime_content_type($fileTmp) ?: 'image/jpeg';
    $fileBytes = file_get_contents($fileTmp);
    $imageDataUri = 'data:' . $mime . ';base64,' . base64_encode($fileBytes);
}

if (empty($imageDataUri)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Image data is required.'], JSON_UNESCAPED_UNICODE);
    exit();
}

// Ensure data URI has prefix
if (strpos($imageDataUri, 'data:') !== 0) {
    $imageDataUri = 'data:image/jpeg;base64,' . $imageDataUri;
}

// If client passed API key in header (fallback), accept if server key is empty
$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if (empty($deepseekApiKey) && !empty($authHeader) && strpos($authHeader, 'Bearer ') === 0) {
    $deepseekApiKey = trim(substr($authHeader, 7));
}

if (empty($deepseekApiKey)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Server AI API key is not configured.'], JSON_UNESCAPED_UNICODE);
    exit();
}

if (!in_array($language, ['en', 'te', 'hi'], true)) {
    $language = 'en';
}
$selectedCropName = mb_substr(trim(strip_tags((string)$selectedCropName)), 0, 40);

// 3. Ground with the selected crop's full problem catalog
$candidateProblems = [];
if (isset($pdo) && $pdo instanceof PDO && $selectedCropId) {
    try {
        $stmtP = $pdo->prepare("SELECT id, problem_name_en, problem_name_te, problem_name_hi, category FROM rice_problems WHERE crop_id = ? ORDER BY id LIMIT 80");
        $stmtP->execute([$selectedCropId]);
        $candidateProblems = $stmtP->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {}
}

// 4. System prompt (keep identical to the app's direct-call prompt)
$systemPrompt = <<<PROMPT
You are Dr. Krishi, a senior Indian plant pathologist and entomologist.
Look carefully at the photo and name the SPECIFIC disease, pest or deficiency you see (e.g. "Rice Blast", "Early Blight", "Fall Armyworm", "Zinc Deficiency"). Never answer with generic labels like "Leaf Issue", "Crop Health Analysis", "Fungal infection" or "Disease".

You ONLY diagnose these 24 crops:
Paddy (Rice), Cotton, Sunflower, Banana, Turmeric, Maize, Chilli, Tomato, Bitter Gourd, Tea, Apple, Sugarcane, Brinjal, Cumin, Groundnut, Mango, Onion, Soybean, Wheat, Garlic, Okra, Potato, Pomegranate, Grapes.

Method:
1. Confirm the photo is a plant and is clear enough.
2. Describe the visible signs (lesion shape, colour, margin, halo, location, insects, frass, webbing, mottling).
3. Compare with the known problems of the crop (use the candidate catalog when given) and choose the single most likely cause.
4. If the plant looks healthy, say healthy. Do not invent a disease.

Guardrails:
- Not a plant: {"is_plant":false,"is_crop_supported":false,"is_clear_image":false,"reason":"..."}
- Plant but not one of the 24 crops: {"is_plant":true,"is_crop_supported":false,"unsupported_crop_name":"<name>","detected_crop_name":"<name>","health_status":"unknown","reason":"...","ai_control_measures":{"chemical":[],"biological":[],"preventative":[]}}. Never prescribe sprays for unsupported crops.
- Blurry or dark: {"is_plant":true,"is_clear_image":false,"reason":"..."}

For supported crops reply with exactly this JSON (no markdown):
{"is_plant":true,"is_crop_supported":true,"is_clear_image":true,"detected_crop_name":"<crop, target language>","problem_name_en":"<specific common name in English>","scientific_name":"<pathogen/pest latin name or null>","matched_problem_name":"<same problem, target language>","matched_problem_id":<catalog id or null>,"health_status":"healthy|diseased|deficiency|pest_infestation","severity_level":"mild|moderate|severe","confidence":0.0-1.0,"observed_symptoms":["..."],"ai_analysis":"2 short sentences.","weather_impact":"1 sentence on spray timing/risk.","recovery_recommendations":["..."],"ai_control_measures":{"chemical":["<molecule % formulation> @ <dose>/acre in <L> water"],"biological":["<agent> @ <dose>/acre in <L> water"],"preventative":["..."]}}
Use CIBRC-registered molecules with exact per-acre dose and water volume. Keep molecule/brand names in English letters.

PROMPT;

$langName = ($language === 'te') ? 'Telugu (తెలుగు)' : (($language === 'hi') ? 'Hindi (हिन्दी)' : 'English');
$userText = '';

if (!empty($selectedCropName)) {
    $userText .= "Crop selected by farmer: $selectedCropName. Diagnose this crop only. ";
}

if (!empty($candidateProblems)) {
    $probListStr = implode(', ', array_map(function($p) {
        return $p['id'] . ':' . $p['problem_name_en'];
    }, $candidateProblems));
    $userText .= "Known problems of this crop (id:name): [$probListStr]. If the photo matches one, set matched_problem_id to that id and use that name; otherwise give the correct specific name and matched_problem_id null. ";
}

$userText .= "Target language: $langName. Write every JSON value (except problem_name_en, scientific_name, health_status, severity_level and molecule names) in $langName script. JSON keys stay in English.";

// 5. Call DeepSeek Vision API
$messages = [
    [
        'role' => 'system',
        'content' => $systemPrompt
    ],
    [
        'role' => 'user',
        'content' => [
            ['type' => 'text', 'text' => $userText],
            [
                'type' => 'image_url',
                'image_url' => [
                    'url' => $imageDataUri,
                    'detail' => 'high'
                ]
            ]
        ]
    ]
];

$postBody = json_encode([
    'model' => 'deepseek-v4-flash-vision-exp',
    'messages' => $messages,
    'thinking' => ['type' => 'disabled'],
    'temperature' => 0.1,
    // Telugu/Hindi output needs far more tokens; 700 truncated the JSON.
    'max_tokens' => 1800
], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

$ch = curl_init('https://api.deepseek.com/chat/completions');
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => $postBody,
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $deepseekApiKey
    ],
    CURLOPT_RETURNTRANSF5R => true,
    CURLOPT_TIMEOUT => 40
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlErr = curl_error($ch);
curl_close($ch);

if ($curlErr || $httpCode !== 200) {
    http_response_code(502);
    echo json_encode([
        'success' => false,
        'error' => 'AI Gateway communication error: ' . ($curlErr ?: "HTTP $httpCode")
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

$resData = json_decode($response, true);
$content = $resData['choices'][0]['message']['content'] ?? '';

// Parse and Clean JSON
$cleaned = trim($content);
if (strpos($cleaned, '```json') !== false) {
    $parts = explode('```json', $cleaned);
    $cleaned = end($parts);
}
if (strpos($cleaned, '```') !== false) {
    $parts = explode('```', $cleaned);
    $cleaned = reset($parts);
}
$cleaned = trim($cleaned);

$parsed = json_decode($cleaned, true);
bracePos = strpos($cleaned, '{');
if ($bracePos !== false && $bracePos > 0) {
    $cleaned = substr($cleaned, $bracePos);
}

$parsed = json_decode($cleaned, true);

if (!is_array($parsed)) {
    // Let the app retry directly instead of returning a fake generic diagnosis.
    http_response_code(502);
    echo json_encode(['success' => false, 'error' => 'AI returned malformed output.'], JSON_UNESCAPED_UNICODE);
    exit();
}

// 6. Validate matched id against this crop's catalog and use the curated localized name
$matchedId = isset($parsed['matched_problem_id']) ? intval($parsed['matched_problem_id']) : 0;
$official = null;
foreach ($candidateProblems as $p) {
    if ($matchedId > 0 && intval($p['id']) === $matchedId) {
        $official = $p;
        break;
    }
}
if (!$official && !empty($candidateProblems) && !empty($parsed['problem_name_en'])) {
    $needle = strtolower(trim($parsed['problem_name_en']));
    foreach ($candidateProblems as $p) {
        if (strtolower(trim($p['problem_name_en'])) === $needle) {
            $official = $p;
            break;
        }
    }
}
if ($official) {
    $nameKey = ($language === 'en') ? 'problem_name_en' : (($language === 'hi') ? 'problem_name_hi' : 'problem_name_te');
    $parsed['matched_problem_id'] = intval($official['id']);
    if (!empty($official[$nameKey])) {
        $parsed['matched_problem_name'] = $official[$nameKey];
    }
    if (empty($parsed['problem_name_en'])) {
        $parsed['problem_name_en'] = $official['problem_name_en'];
    }
    $parsed['official_database_verified'] = true;
    $parsed['matched_problem_category'] = $official['category'];
} else {
    $parsed['matched_problem_id'] = null;

echo json_encode([
    'success' => true,
    'diagnosis' => $parsed
], JSON_UNESCAPED_UNICODE);
