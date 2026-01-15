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
 * - GET /api.php?action=get_problems&crop_id=X&stage_id=X&lang=te - Get problems for a stage
 * - GET /api.php?action=get_advisory_components&advisory_id=X&lang=te - Get advisory components/remedies
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
    
    // The crops table has 'name' column (Telugu by default)
    $stmt = $pdo->query("SELECT id, name, image_url FROM crops ORDER BY id");
    $crops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'crops' => $crops]);
}

function getVarieties($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    
    $stmt = $pdo->prepare("SELECT id, variety_name, packet_image_url, growth_duration FROM crop_varieties WHERE crop_id = ?");
    $stmt->execute([$cropId]);
    $varieties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'varieties' => $varieties]);
}

// ===================== USER CROP SELECTIONS =====================

function getUserSelections($pdo) {
    $userId = $_GET['user_id'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    $stmt = $pdo->prepare("
        SELECT 
            ucs.id as selection_id,
            ucs.field_number as field_name,
            ucs.crop_id,
            ucs.variety_id,
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
    $stmt->execute([$userId]);
    $selections = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'selections' => $selections]);
}

function getUsedFields($pdo) {
    $userId = $_GET['user_id'] ?? '';
    
    $stmt = $pdo->prepare("SELECT DISTINCT field_number FROM user_crop_selections WHERE user_id = ?");
    $stmt->execute([$userId]);
    $fields = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo json_encode(['success' => true, 'used_fields' => $fields]);
}

function saveSelection($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $userId = $input['user_id'] ?? '';
    $cropId = $input['crop_id'] ?? '';
    $varietyId = $input['variety_id'] ?? null;
    $sowingDate = $input['sowing_date'] ?? '';
    $fieldName = $input['field_name'] ?? '';
    
    if (empty($userId) || empty($cropId) || empty($sowingDate) || empty($fieldName)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Get or create sowing_date_id
        $stmt = $pdo->prepare("SELECT id FROM sowing_dates WHERE sowing_date = ?");
        $stmt->execute([$sowingDate]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            $sowingDateId = $result['id'];
        } else {
            $stmt = $pdo->prepare("INSERT INTO sowing_dates (sowing_date) VALUES (?)");
            $stmt->execute([$sowingDate]);
            $sowingDateId = $pdo->lastInsertId();
        }
        
        // Insert selection
        $stmt = $pdo->prepare("
            INSERT INTO user_crop_selections (user_id, crop_id, variety_id, sowing_date_id, field_number)
            VALUES (?, ?, ?, ?, ?)
        ");
        $stmt->execute([$userId, $cropId, $varietyId, $sowingDateId, $fieldName]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function updateSelection($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $id = $input['id'] ?? '';
    $cropId = $input['crop_id'] ?? '';
    $varietyId = $input['variety_id'] ?? null;
    $sowingDate = $input['sowing_date'] ?? '';
    
    if (empty($id) || empty($cropId) || empty($sowingDate)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Get or create sowing_date_id
        $stmt = $pdo->prepare("SELECT id FROM sowing_dates WHERE sowing_date = ?");
        $stmt->execute([$sowingDate]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            $sowingDateId = $result['id'];
        } else {
            $stmt = $pdo->prepare("INSERT INTO sowing_dates (sowing_date) VALUES (?)");
            $stmt->execute([$sowingDate]);
            $sowingDateId = $pdo->lastInsertId();
        }
        
        // Update selection
        $stmt = $pdo->prepare("
            UPDATE user_crop_selections 
            SET crop_id = ?, variety_id = ?, sowing_date_id = ?
            WHERE id = ?
        ");
        $stmt->execute([$cropId, $varietyId, $sowingDateId, $id]);
        
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

/**
 * Get crop stages for a specific crop
 * Uses the CropStages table with proper column names
 */
function getCropStages($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    
    // CropStages table has: StageID, crop_id, StageName (Telugu), StageName_en (English), Description, StageImageURL
    $nameField = ($lang === 'en') ? 'StageName_en' : 'StageName';
    
    $stmt = $pdo->prepare("
        SELECT 
            StageID as id, 
            $nameField as name, 
            StageName as name_te,
            StageName_en as name_en,
            Description as description, 
            StageImageURL as image_url
        FROM CropStages 
        WHERE crop_id = ?
        ORDER BY StageID
    ");
    $stmt->execute([$cropId]);
    $stages = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'stages' => $stages]);
}

/**
 * Get stage durations for a crop variety
 * Uses crop_stage_durations table
 */
function getStageDuration($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    $varietyId = $_GET['variety_id'] ?? null;
    
    $sql = "
        SELECT 
            csd.id,
            csd.variety_id,
            csd.stage_id,
            csd.StartDayFromSowing as start_day_from_sowing,
            csd.EndDayFromSowing as end_day_from_sowing
        FROM crop_stage_durations csd
        WHERE csd.variety_id IN (SELECT id FROM crop_varieties WHERE crop_id = ?)
    ";
    $params = [$cropId];
    
    if ($varietyId) {
        $sql = "
            SELECT 
                csd.id,
                csd.variety_id,
                csd.stage_id,
                csd.StartDayFromSowing as start_day_from_sowing,
                csd.EndDayFromSowing as end_day_from_sowing
            FROM crop_stage_durations csd
            WHERE csd.variety_id = ?
        ";
        $params = [$varietyId];
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $durations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'durations' => $durations]);
}

/**
 * Get problems/diseases for a specific crop and stage
 * Uses rice_problems table joined with problem_stages junction table
 */
function getProblems($pdo) {
    $cropId = $_GET['crop_id'] ?? null;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    // rice_problems has: id, problem_name_te, problem_name_en, category, crop_id, image_url1, image_url2, image_url3
    $nameField = ($lang === 'en') ? 'problem_name_en' : 'problem_name_te';
    
    if ($stageId) {
        // Get problems for a specific stage using problem_stages junction table
        $sql = "
            SELECT DISTINCT
                rp.id,
                rp.$nameField as name,
                rp.problem_name_te as name_te,
                rp.problem_name_en as name_en,
                rp.category,
                rp.crop_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM rice_problems rp
            INNER JOIN problem_stages ps ON rp.id = ps.problem_id
            WHERE ps.stage_id = ?
        ";
        $params = [$stageId];
        
        if ($cropId) {
            $sql .= " AND rp.crop_id = ?";
            $params[] = $cropId;
        }
        
        $sql .= " ORDER BY rp.category, rp.id";
    } else if ($cropId) {
        // Get all problems for a crop
        $sql = "
            SELECT 
                rp.id,
                rp.$nameField as name,
                rp.problem_name_te as name_te,
                rp.problem_name_en as name_en,
                rp.category,
                rp.crop_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM rice_problems rp
            WHERE rp.crop_id = ?
            ORDER BY rp.category, rp.id
        ";
        $params = [$cropId];
    } else {
        // Get all problems
        $sql = "
            SELECT 
                rp.id,
                rp.$nameField as name,
                rp.problem_name_te as name_te,
                rp.problem_name_en as name_en,
                rp.category,
                rp.crop_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM rice_problems rp
            ORDER BY rp.category, rp.id
        ";
        $params = [];
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $problems = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'problems' => $problems]);
}

/**
 * Get advisory details for a specific problem
 * Uses crop_advisories table
 */
function getAdvisories($pdo) {
    $problemId = $_GET['problem_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    
    // crop_advisories has: id, problem_id, advisory_title_en, advisory_title_te, symptoms_en, symptoms_te
    $titleField = ($lang === 'en') ? 'advisory_title_en' : 'advisory_title_te';
    $symptomsField = ($lang === 'en') ? 'symptoms_en' : 'symptoms_te';
    
    $stmt = $pdo->prepare("
        SELECT 
            id,
            problem_id,
            $titleField as title,
            advisory_title_te as title_te,
            advisory_title_en as title_en,
            $symptomsField as symptoms,
            symptoms_te,
            symptoms_en
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

/**
 * Get advisory components/remedies for a specific advisory
 * Uses advisory_components table
 */
function getAdvisoryComponents($pdo) {
    $advisoryId = $_GET['advisory_id'] ?? 0;
    $stageScope = $_GET['stage_scope'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    // advisory_components has: id, advisory_id, problem_stage_id, component_type, stage_scope,
    // component_name_en, component_name_te, alt_component_name_en, alt_component_name_te,
    // dose_en, dose_te, application_method_en, application_method_te, image_url
    
    $nameField = ($lang === 'en') ? 'component_name_en' : 'component_name_te';
    $altNameField = ($lang === 'en') ? 'alt_component_name_en' : 'alt_component_name_te';
    $doseField = ($lang === 'en') ? 'dose_en' : 'dose_te';
    $methodField = ($lang === 'en') ? 'application_method_en' : 'application_method_te';
    
    $sql = "
        SELECT 
            id,
            advisory_id,
            problem_stage_id,
            component_type,
            stage_scope,
            $nameField as component_name,
            component_name_en,
            component_name_te,
            $altNameField as alt_component_name,
            alt_component_name_en,
            alt_component_name_te,
            $doseField as dose,
            dose_en,
            dose_te,
            $methodField as application_method,
            application_method_en,
            application_method_te,
            image_url
        FROM advisory_components 
        WHERE advisory_id = ?
    ";
    $params = [$advisoryId];
    
    if ($stageScope) {
        $sql .= " AND (stage_scope = ? OR stage_scope = 'All Stages')";
        $params[] = $stageScope;
    }
    
    $sql .= " ORDER BY component_type, id";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $components = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'components' => $components]);
}

/**
 * Save an identified problem for a farmer
 */
function saveIdentifiedProblem($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $userId = $input['user_id'] ?? '';
    $problemId = $input['problem_id'] ?? '';
    $selectionId = $input['selection_id'] ?? null;
    
    if (empty($userId) || empty($problemId)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Create advisory_receipts entry
        $receiptId = 'ADV-' . $problemId . '-' . date('YmdHis') . '-' . uniqid();
        
        $stmt = $pdo->prepare("
            INSERT INTO advisory_receipts (user_id, problem_id, receipt_id, receipt_url, status, created_at)
            VALUES (?, ?, ?, '', 'New', NOW())
        ");
        $stmt->execute([$userId, $problemId, $receiptId]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId(), 'receipt_id' => $receiptId]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== PRODUCT FUNCTIONS =====================

function getProducts($pdo) {
    $category = $_GET['category'] ?? null;
    $search = $_GET['search'] ?? null;
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
    
    if ($category) {
        $sql .= " AND p.category = ?";
        $params[] = $category;
    }
    
    if ($search) {
        $sql .= " AND (p.product_name LIKE ? OR p.product_description LIKE ?)";
        $params[] = "%$search%";
        $params[] = "%$search%";
    }
    
    $sql .= " ORDER BY p.product_id DESC";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $products = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'products' => $products]);
}

function getProductCategories($pdo) {
    $stmt = $pdo->query("SELECT DISTINCT category FROM products WHERE category IS NOT NULL ORDER BY category");
    $categories = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo json_encode(['success' => true, 'categories' => $categories]);
}

function createEnquiry($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $productId = $input['product_id'] ?? '';
    $farmerId = $input['farmer_id'] ?? '';
    $advertiserId = $input['advertiser_id'] ?? '';
    
    if (empty($productId) || empty($farmerId) || empty($advertiserId)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        $stmt = $pdo->prepare("
            INSERT INTO enquiries (product_id, farmer_id, advertiser_id, status, created_at)
            VALUES (?, ?, ?, 'Interested', NOW())
        ");
        $stmt->execute([$productId, $farmerId, $advertiserId]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== SEED VARIETIES FUNCTIONS =====================

function getSeedVarieties($pdo) {
    $cropName = $_GET['crop_name'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    $varietyField = ($lang === 'en') ? 'variety_name_en' : 'variety_name_te';
    $detailsField = 'details_te'; // Add details_en if needed
    
    $sql = "
        SELECT id, crop_name, $varietyField as variety_name, image_url, $detailsField as details, 
               region, sowing_period, testimonial_video_url, price, price_unit, average_yield, growth_duration
        FROM seed_varieties 
        WHERE 1=1
    ";
    $params = [];
    
    if (!empty($cropName)) {
        $sql .= " AND crop_name = ?";
        $params[] = $cropName;
    }
    
    $sql .= " ORDER BY id";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $varieties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'varieties' => $varieties]);
}

function getCropNames($pdo) {
    // Get distinct crop names from seed_varieties
    $stmt = $pdo->query("SELECT DISTINCT crop_name FROM seed_varieties ORDER BY crop_name");
    $crops = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    // Also get from crops table for localized names
    $stmt = $pdo->query("SELECT id, name FROM crops ORDER BY id");
    $cropNames = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'crop_names' => $crops, 'crops' => $cropNames]);
}
?>
