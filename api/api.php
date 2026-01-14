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
 * - GET /api.php?action=get_products&category=X - Get products
 * - POST /api.php?action=save_purchase_request - Save purchase request
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
    case 'get_problems':
        getProblems($pdo);
        break;
    case 'save_identified_problem':
        saveIdentifiedProblem($pdo);
        break;
    case 'get_products':
        getProducts($pdo);
        break;
    case 'save_purchase_request':
        savePurchaseRequest($pdo);
        break;
    case 'get_seed_varieties':
        getSeedVarieties($pdo);
        break;
    case 'get_sowing_date_id':
        getSowingDateId($pdo);
        break;
    default:
        echo json_encode(['success' => false, 'error' => 'Invalid action']);
}

// ===================== USER FUNCTIONS =====================

function handleLogin($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $user_id = $input['user_id'] ?? '';
    
    if (empty($user_id)) {
        echo json_encode(['success' => false, 'error' => 'User ID is required']);
        return;
    }
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ?");
    $stmt->execute([$user_id]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user) {
        echo json_encode(['success' => true, 'user' => $user]);
    } else {
        echo json_encode(['success' => false, 'error' => 'User not found']);
    }
}

function getUser($pdo) {
    $user_id = $_GET['user_id'] ?? '';
    
    if (empty($user_id)) {
        echo json_encode(['success' => false, 'error' => 'User ID is required']);
        return;
    }
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ?");
    $stmt->execute([$user_id]);
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
    
    // The crops table has 'name' column (Telugu by default)
    // For multi-language support, you may need to add name_en, name_hi columns
    $stmt = $pdo->query("SELECT id, name, image_url FROM crops ORDER BY id");
    $crops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'crops' => $crops]);
}

function getVarieties($pdo) {
    $crop_id = $_GET['crop_id'] ?? '';
    
    if (empty($crop_id)) {
        echo json_encode(['success' => false, 'error' => 'Crop ID is required']);
        return;
    }
    
    $stmt = $pdo->prepare("SELECT id, variety_name, packet_image_url, growth_duration FROM crop_varieties WHERE crop_id = ?");
    $stmt->execute([$crop_id]);
    $varieties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'varieties' => $varieties]);
}

// ===================== USER CROP SELECTIONS =====================

function getUserSelections($pdo) {
    $user_id = $_GET['user_id'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    if (empty($user_id)) {
        echo json_encode(['success' => false, 'error' => 'User ID is required']);
        return;
    }
    
    $stmt = $pdo->prepare("
        SELECT 
            ucs.id as selection_id,
            ucs.field_number as field_name,
            c.name as crop_name,
            c.image_url as crop_image_url,
            cv.variety_name,
            sd.sowing_date
        FROM user_crop_selections ucs
        JOIN crops c ON ucs.crop_id = c.id
        LEFT JOIN crop_varieties cv ON ucs.variety_id = cv.id
        JOIN sowing_dates sd ON ucs.sowing_date_id = sd.id
        WHERE ucs.user_id = ?
        ORDER BY ucs.created_at DESC
    ");
    $stmt->execute([$user_id]);
    $selections = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'selections' => $selections]);
}

function getUsedFieldNames($pdo) {
    $user_id = $_GET['user_id'] ?? '';
    
    if (empty($user_id)) {
        echo json_encode(['success' => false, 'error' => 'User ID is required']);
        return;
    }
    
    $stmt = $pdo->prepare("SELECT field_number FROM user_crop_selections WHERE user_id = ?");
    $stmt->execute([$user_id]);
    $fields = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo json_encode(['success' => true, 'used_fields' => $fields]);
}

function getSowingDateId($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $sowing_date = $input['sowing_date'] ?? '';
    
    if (empty($sowing_date)) {
        echo json_encode(['success' => false, 'error' => 'Sowing date is required']);
        return;
    }
    
    // Check if date exists
    $stmt = $pdo->prepare("SELECT id FROM sowing_dates WHERE sowing_date = ?");
    $stmt->execute([$sowing_date]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        echo json_encode(['success' => true, 'sowing_date_id' => $result['id']]);
    } else {
        // Insert new date
        $stmt = $pdo->prepare("INSERT INTO sowing_dates (sowing_date) VALUES (?)");
        $stmt->execute([$sowing_date]);
        $id = $pdo->lastInsertId();
        echo json_encode(['success' => true, 'sowing_date_id' => $id]);
    }
}

function saveSelection($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $user_id = $input['user_id'] ?? '';
    $crop_id = $input['crop_id'] ?? '';
    $variety_id = $input['variety_id'] ?? null;
    $sowing_date = $input['sowing_date'] ?? '';
    $field_name = $input['field_name'] ?? '';
    
    if (empty($user_id) || empty($crop_id) || empty($sowing_date) || empty($field_name)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Get or create sowing_date_id
        $stmt = $pdo->prepare("SELECT id FROM sowing_dates WHERE sowing_date = ?");
        $stmt->execute([$sowing_date]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            $sowing_date_id = $result['id'];
        } else {
            $stmt = $pdo->prepare("INSERT INTO sowing_dates (sowing_date) VALUES (?)");
            $stmt->execute([$sowing_date]);
            $sowing_date_id = $pdo->lastInsertId();
        }
        
        // Insert selection
        $stmt = $pdo->prepare("
            INSERT INTO user_crop_selections (user_id, crop_id, variety_id, sowing_date_id, field_number)
            VALUES (?, ?, ?, ?, ?)
        ");
        $stmt->execute([$user_id, $crop_id, $variety_id, $sowing_date_id, $field_name]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function updateSelection($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $id = $input['id'] ?? '';
    $crop_id = $input['crop_id'] ?? '';
    $variety_id = $input['variety_id'] ?? null;
    $sowing_date = $input['sowing_date'] ?? '';
    
    if (empty($id) || empty($crop_id) || empty($sowing_date)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Get or create sowing_date_id
        $stmt = $pdo->prepare("SELECT id FROM sowing_dates WHERE sowing_date = ?");
        $stmt->execute([$sowing_date]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            $sowing_date_id = $result['id'];
        } else {
            $stmt = $pdo->prepare("INSERT INTO sowing_dates (sowing_date) VALUES (?)");
            $stmt->execute([$sowing_date]);
            $sowing_date_id = $pdo->lastInsertId();
        }
        
        // Update selection
        $stmt = $pdo->prepare("
            UPDATE user_crop_selections 
            SET crop_id = ?, variety_id = ?, sowing_date_id = ?
            WHERE id = ?
        ");
        $stmt->execute([$crop_id, $variety_id, $sowing_date_id, $id]);
        
        echo json_encode(['success' => true]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function deleteSelection($pdo) {
    $id = $_GET['id'] ?? '';
    
    if (empty($id)) {
        echo json_encode(['success' => false, 'error' => 'Selection ID is required']);
        return;
    }
    
    try {
        $stmt = $pdo->prepare("DELETE FROM user_crop_selections WHERE id = ?");
        $stmt->execute([$id]);
        echo json_encode(['success' => true]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== ADVISORY FUNCTIONS =====================

function getCropStages($pdo) {
    $crop_id = $_GET['crop_id'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    if (empty($crop_id)) {
        echo json_encode(['success' => false, 'error' => 'Crop ID is required']);
        return;
    }
    
    $nameColumn = $lang === 'en' ? 'StageName_en' : 'StageName';
    
    $stmt = $pdo->prepare("
        SELECT StageID as id, $nameColumn as name, Description as description, StageImageURL as image_url
        FROM CropStages 
        WHERE crop_id = ?
        ORDER BY StageID
    ");
    $stmt->execute([$crop_id]);
    $stages = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'stages' => $stages]);
}

function getStageDuration($pdo) {
    $crop_id = $_GET['crop_id'] ?? '';
    $variety_id = $_GET['variety_id'] ?? '';
    
    if (empty($crop_id)) {
        echo json_encode(['success' => false, 'error' => 'Crop ID is required']);
        return;
    }
    
    $sql = "SELECT * FROM crop_stage_durations WHERE crop_id = ?";
    $params = [$crop_id];
    
    if (!empty($variety_id)) {
        $sql .= " AND variety_id = ?";
        $params[] = $variety_id;
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $durations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'durations' => $durations]);
}

function getProblems($pdo) {
    $crop_id = $_GET['crop_id'] ?? '';
    $stage_id = $_GET['stage_id'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    $nameColumn = $lang === 'en' ? 'name_en' : 'name_te';
    
    $sql = "SELECT id, $nameColumn as name, image_url FROM rice_problems WHERE 1=1";
    $params = [];
    
    // Note: rice_problems table may need crop_id column for multi-crop support
    // For now, returning all problems
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $problems = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'problems' => $problems]);
}

function getAdvisories($pdo) {
    $problem_id = $_GET['problem_id'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    if (empty($problem_id)) {
        echo json_encode(['success' => false, 'error' => 'Problem ID is required']);
        return;
    }
    
    $titleColumn = $lang === 'en' ? 'advisory_title_en' : 'advisory_title_te';
    $symptomsColumn = $lang === 'en' ? 'symptoms_en' : 'symptoms_te';
    
    $stmt = $pdo->prepare("
        SELECT id, $titleColumn as title, $symptomsColumn as symptoms
        FROM crop_advisories 
        WHERE problem_id = ?
    ");
    $stmt->execute([$problem_id]);
    $advisory = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($advisory) {
        // Get advisory components/recommendations
        $stmt = $pdo->prepare("
            SELECT * FROM advisory_components WHERE advisory_id = ?
        ");
        $stmt->execute([$advisory['id']]);
        $components = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $advisory['components'] = $components;
    }
    
    echo json_encode(['success' => true, 'advisory' => $advisory]);
}

function saveIdentifiedProblem($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $user_id = $input['user_id'] ?? '';
    $problem_id = $input['problem_id'] ?? '';
    $selection_id = $input['selection_id'] ?? null;
    
    if (empty($user_id) || empty($problem_id)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Note: You may need to create a user_identified_problems table
        // For now, using a generic approach
        $stmt = $pdo->prepare("
            INSERT INTO user_identified_problems (user_id, problem_id, selection_id, identified_at)
            VALUES (?, ?, ?, NOW())
        ");
        $stmt->execute([$user_id, $problem_id, $selection_id]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== PRODUCT FUNCTIONS =====================

function getProducts($pdo) {
    $category = $_GET['category'] ?? '';
    $search = $_GET['search'] ?? '';
    
    $sql = "SELECT * FROM products WHERE 1=1";
    $params = [];
    
    if (!empty($category)) {
        $sql .= " AND category = ?";
        $params[] = $category;
    }
    
    if (!empty($search)) {
        $sql .= " AND (product_name LIKE ? OR product_description LIKE ?)";
        $params[] = "%$search%";
        $params[] = "%$search%";
    }
    
    $sql .= " ORDER BY created_at DESC";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $products = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'products' => $products]);
}

function savePurchaseRequest($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $user_id = $input['user_id'] ?? '';
    $product_id = $input['product_id'] ?? '';
    $quantity = $input['quantity'] ?? 1;
    
    if (empty($user_id) || empty($product_id)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Note: You may need to create a purchase_requests table
        $stmt = $pdo->prepare("
            INSERT INTO purchase_requests (user_id, product_id, quantity, created_at)
            VALUES (?, ?, ?, NOW())
        ");
        $stmt->execute([$user_id, $product_id, $quantity]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== SEED VARIETIES FUNCTIONS =====================

function getSeedVarieties($pdo) {
    $crop_name = $_GET['crop_name'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    $varietyColumn = $lang === 'en' ? 'variety_name_en' : 'variety_name_te';
    $detailsColumn = $lang === 'te' ? 'details_te' : 'details_te'; // Add details_en if needed
    
    $sql = "SELECT id, crop_name, $varietyColumn as variety_name, image_url, $detailsColumn as details, 
            region, sowing_period, testimonial_video_url, price, price_unit, average_yield, growth_duration
            FROM seed_varieties WHERE 1=1";
    $params = [];
    
    if (!empty($crop_name)) {
        $sql .= " AND crop_name = ?";
        $params[] = $crop_name;
    }
    
    $sql .= " ORDER BY id";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $varieties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'varieties' => $varieties]);
}

function getCropNames($pdo) {
    $lang = $_GET['lang'] ?? 'te';
    
    // Get distinct crop names from seed_varieties
    $stmt = $pdo->query("SELECT DISTINCT crop_name FROM seed_varieties ORDER BY crop_name");
    $crops = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    // Also get from crops table for localized names
    $stmt = $pdo->query("SELECT name FROM crops ORDER BY id");
    $cropNames = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'crop_names' => $crops, 'crops' => $cropNames]);
}
?>
