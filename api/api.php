<?php
/**
 * CropSync Kiosk API
 * MySQL Backend API for Flutter App
 * 
 * Endpoints:
 * - POST /api.php?action=login - User login
 * - GET /api.php?action=get_user&user_id=XXX - Get user details
 * - GET /api.php?action=get_crops&lang=te - Get all crops
 * - GET /api.php?action=get_varieties&crop_id=X - Get varieties for a crop
 * - GET /api.php?action=get_user_selections&user_id=XXX - Get user's crop selections
 * - POST /api.php?action=save_selection - Save crop selection
 * - PUT /api.php?action=update_selection - Update crop selection
 * - DELETE /api.php?action=delete_selection&id=X - Delete crop selection
 * - GET /api.php?action=get_crop_stages&crop_id=X&lang=te - Get crop stages
 * - GET /api.php?action=get_stage_duration&crop_id=X&variety_id=X - Get stage durations
 * - GET /api.php?action=get_advisories&problem_id=X&lang=te - Get advisories
 * - GET /api.php?action=get_problems&crop_id=X&stage_id=X&lang=te - Get problems
 * - POST /api.php?action=save_identified_problem - Save identified problem
 * - GET /api.php?action=get_products&category=X&lang=te - Get products
 * - GET /api.php?action=get_product_categories&lang=te - Get product categories
 * - POST /api.php?action=create_enquiry - Create product enquiry
 * - GET /api.php?action=get_seed_varieties&crop_name=X&lang=te - Get seed varieties
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Database configuration - Update these with your actual credentials
$host = 'localhost';
$dbname = 'u511597003_kiosk';
$username = 'u511597003_kiosk';
$password = 'YOUR_PASSWORD'; // Update this

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'error' => 'Database connection failed']);
    exit();
}

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'login':
        handleLogin($pdo);
        break;
    case 'get_user':
        getUser($pdo);
        break;
    case 'get_crops':
        getCrops($pdo);
        break;
    case 'get_varieties':
        getVarieties($pdo);
        break;
    case 'get_user_selections':
        getUserSelections($pdo);
        break;
    case 'get_used_fields':
        getUsedFields($pdo);
        break;
    case 'save_selection':
        saveSelection($pdo);
        break;
    case 'update_selection':
        updateSelection($pdo);
        break;
    case 'delete_selection':
        deleteSelection($pdo);
        break;
    case 'get_crop_stages':
        getCropStages($pdo);
        break;
    case 'get_stage_duration':
        getStageDuration($pdo);
        break;
    case 'get_advisories':
        getAdvisories($pdo);
        break;
    case 'get_advisory_components':
        getAdvisoryComponents($pdo);
        break;
    case 'get_problems':
        getProblems($pdo);
        break;
    case 'save_identified_problem':
        saveIdentifiedProblem($pdo);
        break;
    case 'get_products':
        getProducts($pdo);
        break;
    case 'get_product_categories':
        getProductCategories($pdo);
        break;
    case 'create_enquiry':
        createEnquiry($pdo);
        break;
    case 'get_seed_varieties':
        getSeedVarieties($pdo);
        break;
    case 'get_crop_names':
        getCropNames($pdo);
        break;
    default:
        echo json_encode(['success' => false, 'error' => 'Invalid action']);
}

// ===================== AUTH FUNCTIONS =====================

function handleLogin($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $userId = $input['user_id'] ?? '';
    
    if (empty($userId)) {
        echo json_encode(['success' => false, 'message' => 'User ID is required']);
        return;
    }
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user) {
        echo json_encode(['success' => true, 'user' => $user]);
    } else {
        echo json_encode(['success' => false, 'message' => 'User not found']);
    }
}

function getUser($pdo) {
    $userId = $_GET['user_id'] ?? '';
    
    if (empty($userId)) {
        echo json_encode(['success' => false, 'error' => 'User ID is required']);
        return;
    }
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user) {
        echo json_encode(['success' => true, 'user' => $user]);
    } else {
        echo json_encode(['success' => false, 'error' => 'User not found']);
    }
}

// ===================== CROP FUNCTIONS =====================

function getCrops($pdo) {
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = 'name_te';
    if ($lang === 'en') $nameField = 'name_en';
    if ($lang === 'hi') $nameField = 'name_hi';
    
    $stmt = $pdo->query("SELECT id, $nameField as name, name_en, name_te, name_hi, image_url FROM crops ORDER BY name_en");
    $crops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'crops' => $crops]);
}

function getVarieties($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    
    $stmt = $pdo->prepare("SELECT id, variety_name FROM crop_varieties WHERE crop_id = ?");
    $stmt->execute([$cropId]);
    $varieties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'varieties' => $varieties]);
}

// ===================== USER CROP SELECTIONS =====================

function getUserSelections($pdo) {
    $userId = $_GET['user_id'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = 'c.name_te';
    if ($lang === 'en') $nameField = 'c.name_en';
    if ($lang === 'hi') $nameField = 'c.name_hi';
    
    $stmt = $pdo->prepare("
        SELECT ucs.id, ucs.crop_id, ucs.variety_id, ucs.sowing_date, ucs.field_name,
               $nameField as crop_name, c.image_url as crop_image_url,
               cv.variety_name
        FROM user_crop_selections ucs
        LEFT JOIN crops c ON ucs.crop_id = c.id
        LEFT JOIN crop_varieties cv ON ucs.variety_id = cv.id
        WHERE ucs.user_id = ?
        ORDER BY ucs.created_at DESC
    ");
    $stmt->execute([$userId]);
    $selections = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'selections' => $selections]);
}

function getUsedFields($pdo) {
    $userId = $_GET['user_id'] ?? '';
    
    $stmt = $pdo->prepare("SELECT DISTINCT field_name FROM user_crop_selections WHERE user_id = ?");
    $stmt->execute([$userId]);
    $fields = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo json_encode(['success' => true, 'used_fields' => $fields]);
}

function saveSelection($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $stmt = $pdo->prepare("
        INSERT INTO user_crop_selections (user_id, crop_id, variety_id, sowing_date, field_name)
        VALUES (?, ?, ?, ?, ?)
    ");
    
    try {
        $stmt->execute([
            $input['user_id'],
            $input['crop_id'],
            $input['variety_id'] ?? null,
            $input['sowing_date'],
            $input['field_name']
        ]);
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function updateSelection($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $stmt = $pdo->prepare("
        UPDATE user_crop_selections 
        SET crop_id = ?, variety_id = ?, sowing_date = ?
        WHERE id = ?
    ");
    
    try {
        $stmt->execute([
            $input['crop_id'],
            $input['variety_id'] ?? null,
            $input['sowing_date'],
            $input['id']
        ]);
        echo json_encode(['success' => true]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function deleteSelection($pdo) {
    $id = $_GET['id'] ?? 0;
    
    $stmt = $pdo->prepare("DELETE FROM user_crop_selections WHERE id = ?");
    
    try {
        $stmt->execute([$id]);
        echo json_encode(['success' => true]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== ADVISORY FUNCTIONS =====================

function getCropStages($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = 'stage_name_te';
    if ($lang === 'en') $nameField = 'stage_name_en';
    if ($lang === 'hi') $nameField = 'stage_name_hi';
    
    $stmt = $pdo->prepare("
        SELECT id, $nameField as stage_name, stage_name_en, stage_name_te, stage_name_hi, image_url
        FROM crop_stages 
        WHERE crop_id = ?
        ORDER BY id
    ");
    $stmt->execute([$cropId]);
    $stages = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'stages' => $stages]);
}

function getStageDuration($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    $varietyId = $_GET['variety_id'] ?? null;
    
    $sql = "SELECT * FROM crop_stage_durations WHERE crop_id = ?";
    $params = [$cropId];
    
    if ($varietyId) {
        $sql .= " AND variety_id = ?";
        $params[] = $varietyId;
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $durations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'durations' => $durations]);
}

function getProblems($pdo) {
    $cropId = $_GET['crop_id'] ?? null;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = 'problem_name_te';
    $descField = 'description_te';
    if ($lang === 'en') {
        $nameField = 'problem_name_en';
        $descField = 'description_en';
    }
    if ($lang === 'hi') {
        $nameField = 'problem_name_hi';
        $descField = 'description_hi';
    }
    
    $sql = "SELECT id, $nameField as problem_name, $descField as description, image_url, crop_id, stage_id FROM crop_problems WHERE 1=1";
    $params = [];
    
    if ($cropId) {
        $sql .= " AND crop_id = ?";
        $params[] = $cropId;
    }
    if ($stageId) {
        $sql .= " AND stage_id = ?";
        $params[] = $stageId;
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $problems = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'problems' => $problems]);
}

function getAdvisories($pdo) {
    $problemId = $_GET['problem_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    
    $titleField = 'title_te';
    $descField = 'description_te';
    if ($lang === 'en') {
        $titleField = 'title_en';
        $descField = 'description_en';
    }
    if ($lang === 'hi') {
        $titleField = 'title_hi';
        $descField = 'description_hi';
    }
    
    $stmt = $pdo->prepare("
        SELECT id, $titleField as title, $descField as description, image_url, video_url
        FROM crop_advisories 
        WHERE problem_id = ?
    ");
    $stmt->execute([$problemId]);
    $advisory = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($advisory) {
        echo json_encode(['success' => true, 'advisory' => $advisory]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Advisory not found']);
    }
}

function getAdvisoryComponents($pdo) {
    $advisoryId = $_GET['advisory_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = 'component_name_te';
    $altNameField = 'alt_component_name_te';
    $doseField = 'dose_te';
    $methodField = 'application_method_te';
    
    if ($lang === 'en') {
        $nameField = 'component_name_en';
        $altNameField = 'alt_component_name_en';
        $doseField = 'dose_en';
        $methodField = 'application_method_en';
    }
    
    $stmt = $pdo->prepare("
        SELECT id, $nameField as component_name, $altNameField as alt_component_name,
               $doseField as dose, $methodField as application_method,
               component_type, stage_scope, image_url
        FROM advisory_components 
        WHERE advisory_id = ?
    ");
    $stmt->execute([$advisoryId]);
    $components = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'components' => $components]);
}

function saveIdentifiedProblem($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $stmt = $pdo->prepare("
        INSERT INTO farmer_identified_problems (farmer_id, problem_id, selection_id)
        VALUES (?, ?, ?)
    ");
    
    try {
        $stmt->execute([
            $input['user_id'],
            $input['problem_id'],
            $input['selection_id'] ?? null
        ]);
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== PRODUCT FUNCTIONS =====================

function getProducts($pdo) {
    $category = $_GET['category'] ?? null;
    $search = $_GET['search'] ?? null;
    $sort = $_GET['sort'] ?? 'default';
    $lang = $_GET['lang'] ?? 'te';
    
    $sql = "
        SELECT p.product_id, p.product_code, p.category, p.product_name, 
               p.price, p.product_description, p.product_video_url,
               p.image_url_1, p.image_url_2, p.image_url_3,
               a.advertiser_id, a.advertiser_name
        FROM products p
        LEFT JOIN advertisers a ON p.advertiser_id = a.advertiser_id
        WHERE 1=1
    ";
    $params = [];
    
    if ($category && $category !== 'All' && $category !== 'అన్ని') {
        $sql .= " AND p.category = ?";
        $params[] = $category;
    }
    
    if ($search) {
        $sql .= " AND (p.product_name LIKE ? OR p.product_description LIKE ?)";
        $params[] = "%$search%";
        $params[] = "%$search%";
    }
    
    // Sorting
    if ($sort === 'price_asc') {
        $sql .= " ORDER BY p.price ASC";
    } elseif ($sort === 'price_desc') {
        $sql .= " ORDER BY p.price DESC";
    } else {
        $sql .= " ORDER BY p.created_at DESC";
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $products = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'products' => $products]);
}

function getProductCategories($pdo) {
    $lang = $_GET['lang'] ?? 'te';
    
    $stmt = $pdo->query("SELECT DISTINCT category FROM products WHERE category IS NOT NULL");
    $categories = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo json_encode(['success' => true, 'categories' => $categories]);
}

function createEnquiry($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $productId = $input['product_id'] ?? null;
    $farmerId = $input['farmer_id'] ?? null;
    $advertiserId = $input['advertiser_id'] ?? null;
    
    if (!$productId || !$farmerId || !$advertiserId) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    $stmt = $pdo->prepare("
        INSERT INTO enquiries (product_id, farmer_id, advertiser_id, status)
        VALUES (?, ?, ?, 'Interested')
    ");
    
    try {
        $stmt->execute([$productId, $farmerId, $advertiserId]);
        echo json_encode(['success' => true, 'enquiry_id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== SEED VARIETIES FUNCTIONS =====================

function getSeedVarieties($pdo) {
    $cropName = $_GET['crop_name'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    // Determine variety name field based on language
    $varietyNameField = 'variety_name_te';
    $detailsField = 'details_te';
    $varietyNameSecondary = 'variety_name_en';
    
    if ($lang === 'en') {
        $varietyNameField = 'variety_name_en';
        $detailsField = 'details_te'; // Fallback to Telugu if English details not available
        $varietyNameSecondary = 'NULL';
    } elseif ($lang === 'hi') {
        $varietyNameField = 'variety_name_en'; // Fallback to English for Hindi
        $detailsField = 'details_te';
        $varietyNameSecondary = 'variety_name_te';
    }
    
    $sql = "
        SELECT 
            sv.id,
            sv.crop_name,
            sv.$varietyNameField as variety_name,
            sv.variety_name_en as variety_name_secondary,
            sv.image_url,
            sv.$detailsField as details,
            sv.region,
            sv.sowing_period,
            sv.testimonial_video_url,
            sv.price,
            sv.price_unit,
            sv.average_yield,
            sv.growth_duration
        FROM seed_varieties sv
        WHERE 1=1
    ";
    $params = [];
    
    if ($cropName) {
        $sql .= " AND sv.crop_name = ?";
        $params[] = $cropName;
    }
    
    $sql .= " ORDER BY sv.crop_name, sv.variety_name_en";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $varieties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'varieties' => $varieties]);
}

function getCropNames($pdo) {
    $stmt = $pdo->query("SELECT DISTINCT crop_name FROM seed_varieties ORDER BY crop_name");
    $cropNames = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo json_encode(['success' => true, 'crop_names' => $cropNames]);
}
?>
