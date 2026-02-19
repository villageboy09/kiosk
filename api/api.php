<?php
/**
 * CropSync Kiosk API
 * MySQL Backend API for Flutter App
 * 
 * COMPLETE FLOW:
 * 1. Select Crop → get_crops
 * 2. Get Stages for Crop → get_crop_stages?crop_id=X
 * 3. Select Stage → get_problems?crop_id=X&stage_id=Y (returns problem_stage_id)
 * 4. Select Problem → get_advisories?problem_id=X&stage_id=Y (returns advisory with problem_stage_id)
 * 5. Get Stage-Specific Remedies → get_advisory_components?advisory_id=X&problem_stage_id=Y
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

require_once '../config.php';

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
    case 'create_chc_booking':
        createCHCBooking($pdo);
        break;
    case 'get_chc_bookings':
        getCHCBookings($pdo);
        break;
    case 'get_chc_equipments':
        getCHCEquipments($pdo);
        break;
    case 'check_chc_availability':
        checkCHCAvailability($pdo);
        break;
    case 'get_booked_dates':
        getBookedDates($pdo);
        break;
    case 'create_seed_booking':
        createSeedBooking($pdo);
        break;
    case 'get_announcements':
        getAnnouncements($pdo);
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
 */
function getCropStages($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    
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
 */
function getStageDuration($pdo) {
    $cropId = $_GET['crop_id'] ?? 0;
    $varietyId = $_GET['variety_id'] ?? null;
    
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
    } else {
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
    }
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $durations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'durations' => $durations]);
}

/**
 * Get problems/diseases for a specific crop and stage
 * 
 * CRITICAL: Returns problem_stage_id which is needed for stage-specific advisory components
 * 
 * The problem_stage_id is the ID from the problem_stages junction table that links
 * a specific problem to a specific stage. This ID is used to fetch stage-specific
 * advisory components.
 * 
 * Usage: get_problems?crop_id=1&stage_id=2&lang=en
 * Returns: problems with problem_stage_id for each
 */
function getProblems($pdo) {
    $cropId = $_GET['crop_id'] ?? null;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = ($lang === 'en') ? 'problem_name_en' : 'problem_name_te';
    
    if ($stageId) {
        // Get problems for a specific stage
        // CRITICAL: Include ps.id as problem_stage_id for stage-specific advisory lookup
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
                rp.image_url3,
                ps.id as problem_stage_id,
                ps.stage_id
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
        // Get all problems for a crop (no stage filter)
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
                rp.image_url3,
                NULL as problem_stage_id,
                NULL as stage_id
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
                rp.image_url3,
                NULL as problem_stage_id,
                NULL as stage_id
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
 * Get advisory for a specific problem
 * 
 * NEW: Also accepts stage_id to return the problem_stage_id for stage-specific components
 * 
 * Usage: get_advisories?problem_id=5&stage_id=2&lang=en
 * Returns: advisory with problem_stage_id for the specific stage
 */
function getAdvisories($pdo) {
    $problemId = $_GET['problem_id'] ?? 0;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    $titleField = ($lang === 'en') ? 'advisory_title_en' : 'advisory_title_te';
    $symptomsField = ($lang === 'en') ? 'symptoms_en' : 'symptoms_te';
    
    // Get the advisory for this problem
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
        // If stage_id is provided, get the problem_stage_id
        if ($stageId) {
            $stmt = $pdo->prepare("
                SELECT id as problem_stage_id 
                FROM problem_stages 
                WHERE problem_id = ? AND stage_id = ?
            ");
            $stmt->execute([$problemId, $stageId]);
            $psResult = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($psResult) {
                $advisory['problem_stage_id'] = $psResult['problem_stage_id'];
            } else {
                $advisory['problem_stage_id'] = null;
            }
            $advisory['stage_id'] = $stageId;
        } else {
            $advisory['problem_stage_id'] = null;
            $advisory['stage_id'] = null;
        }
        
        echo json_encode(['success' => true, 'advisory' => $advisory]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Advisory not found']);
    }
}

/**
 * Get advisory components/remedies for a specific advisory
 * 
 * CRITICAL FIX: Now properly filters by problem_stage_id for stage-specific components
 * 
 * The advisory_components table has:
 * - problem_stage_id: Links to problem_stages.id (stage-specific components)
 * - stage_scope: General stage category (Nursery, Vegetative, Reproductive, Ripening, All Stages)
 * 
 * Logic:
 * 1. If problem_stage_id is provided, return components that match it OR have NULL problem_stage_id
 * 2. If stage_scope is provided, also filter by stage_scope OR 'All Stages'
 * 3. Components with NULL problem_stage_id are general and apply to all stages
 * 
 * Usage: get_advisory_components?advisory_id=5&problem_stage_id=13&stage_scope=Nursery&lang=en
 */
function getAdvisoryComponents($pdo) {
    $advisoryId = $_GET['advisory_id'] ?? 0;
    $problemStageId = $_GET['problem_stage_id'] ?? null;
    $stageScope = $_GET['stage_scope'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
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
    
    // Filter by problem_stage_id if provided
    // Include components that match the specific stage OR are general (NULL)
    if ($problemStageId) {
        $sql .= " AND (problem_stage_id = ? OR problem_stage_id IS NULL)";
        $params[] = $problemStageId;
    }
    
    // Filter by stage_scope if provided
    // Include components that match the specific scope OR are 'All Stages'
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
 * Saves to farmer_identified_problems table
 */
function saveIdentifiedProblem($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $userId = $input['user_id'] ?? '';
    $problemId = $input['problem_id'] ?? '';
    
    if (empty($userId) || empty($problemId)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        // Check if already identified to prevent duplicates
        $checkStmt = $pdo->prepare("
            SELECT id FROM farmer_identified_problems 
            WHERE user_id = ? AND problem_id = ?
        ");
        $checkStmt->execute([$userId, $problemId]);
        $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($existing) {
            // Already marked, return success with existing ID
            echo json_encode([
                'success' => true, 
                'id' => $existing['id'], 
                'message' => 'Already identified'
            ]);
            return;
        }
        
        // Insert new record
        $stmt = $pdo->prepare("
            INSERT INTO farmer_identified_problems (problem_id, user_id, created_at)
            VALUES (?, ?, NOW())
        ");
        $stmt->execute([$problemId, $userId]);
        
        echo json_encode([
            'success' => true, 
            'id' => $pdo->lastInsertId(),
            'message' => 'Problem marked as identified'
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== PRODUCT FUNCTIONS =====================

function getProducts($pdo) {
    try {
        $category = $_GET['category'] ?? null;
        $search = $_GET['search'] ?? null;
        $userId = $_GET['user_id'] ?? null;
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
        
        // Filter by User Region
        if ($userId) {
            // Get user's region
            $stmtUser = $pdo->prepare("SELECT region FROM users WHERE user_id = ?");
            $stmtUser->execute([$userId]);
            $user = $stmtUser->fetch(PDO::FETCH_ASSOC);
            
            if ($user && !empty($user['region'])) {
                $userRegion = $user['region'];
                
                // FIND REGION ID
                // Schema confirmed: regions(id, region_name, client_code, created_at)
                // We match users.region (string) against regions.region_name
                try {
                    $stmtRegion = $pdo->prepare("SELECT id FROM regions WHERE region_name = ? LIMIT 1"); 
                    $stmtRegion->execute([$userRegion]);
                    $region = $stmtRegion->fetch(PDO::FETCH_ASSOC);
                    
                    if ($region) {
                        $regionId = $region['id'];
                        // Logic: Show products for this Region ID OR Global products (NULL)
                        $sql .= " AND (p.region_id IS NULL OR p.region_id = ?)";
                        $params[] = $regionId;
                    } else {
                        // Region name from user profile doesn't match any region in DB.
                        // Fallback: Show ONLY Global products.
                        $sql .= " AND p.region_id IS NULL";
                    }
                } catch (PDOException $e) {
                    // Fallback to Global if query fails
                    $sql .= " AND p.region_id IS NULL";
                }
            }
        }
        
        $sql .= " ORDER BY p.product_id DESC";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $products = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode(['success' => true, 'products' => $products]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
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
            INSERT INTO enquiries (product_id, farmer_id, advertiser_id, status, enquiry_date)
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
    $userId = $_GET['user_id'] ?? '';
    $lang = $_GET['lang'] ?? 'te';
    
    $varietyField = ($lang === 'en') ? 'variety_name_en' : 'variety_name_te';
    $detailsField = 'details_te';
    
    // Base SQL
    $sql = "
        SELECT DISTINCT 
            sv.id, 
            sv.crop_name, 
            sv.$varietyField as variety_name, 
            sv.image_url, 
            sv.$detailsField as details, 
            sv.region, 
            sv.sowing_period, 
            sv.testimonial_video_url, 
            vl.base_price as price, 
            vl.packet_size as price_unit, 
            sv.average_yield, 
            sv.growth_duration
        FROM seed_varieties sv
        LEFT JOIN vendor_listings vl ON sv.id = vl.seed_variety_id
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filter by Crop Name
    if (!empty($cropName)) {
        $sql .= " AND sv.crop_name = ?";
        $params[] = $cropName;
    }
    
    // Filter by User Region
    if (!empty($userId)) {
        // Get user's region
        $stmtUser = $pdo->prepare("SELECT region FROM users WHERE user_id = ?");
        $stmtUser->execute([$userId]);
        $user = $stmtUser->fetch(PDO::FETCH_ASSOC);
        
        if ($user && !empty($user['region'])) {
            $userRegion = $user['region'];
            
            // Filter: (All Regions OR Specific Region)
            // Note: vl.is_all_regions = 1 means available everywhere
            // sv.region matches user's region
            // RELAXED LOGIC: If is_all_regions column doesn't exist or is null, checks sv.region
            $sql .= " AND (
                (vl.base_price IS NOT NULL AND vl.is_all_regions = 1) 
                OR 
                (sv.region LIKE ?)
                OR
                (sv.region IS NULL OR sv.region = '')
            )";
            $params[] = "%$userRegion%";
        }
    }
    
    $sql .= " ORDER BY sv.id";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $varieties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'varieties' => $varieties]);
}

function getCropNames($pdo) {
    $stmt = $pdo->query("SELECT DISTINCT crop_name FROM seed_varieties ORDER BY crop_name");
    $crops = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    $stmt = $pdo->query("SELECT id, name FROM crops ORDER BY id");
    $cropNames = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode(['success' => true, 'crop_names' => $crops, 'crops' => $cropNames]);
}

// ===================== CHC BOOKING FUNCTIONS =====================

function createCHCBooking($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $bookingId = $input['booking_id'] ?? '';
    $userId = $input['user_id'] ?? '';
    $equipmentType = $input['equipment_type'] ?? '';
    $billingType = $input['billing_type'] ?? 'Fixed';
    $cropType = $input['crop_type'] ?? null;
    $landSizeAcres = $input['land_size_acres'] ?? 0;
    $billedQty = $input['billed_qty'] ?? null;
    $unitType = $input['unit_type'] ?? 'Acre';
    $serviceDate = $input['service_date'] ?? '';
    $rate = $input['rate'] ?? 0;
    $totalCost = $input['total_cost'] ?? 0;
    $notes = $input['notes'] ?? null;
    $bookingStatus = $input['booking_status'] ?? 'Confirmed';
    
    if (empty($bookingId) || empty($userId) || empty($equipmentType) || empty($serviceDate)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    // Generate operator notes for variable billing
    $operatorNotes = null;
    if ($billingType === 'Variable') {
        $operatorNotes = "Variable Billing: Final bill based on actual $unitType";
        if ($unitType === 'Trip') {
            $operatorNotes .= " (Note: Valid up to 5km only)";
        }
    } else {
        $operatorNotes = "Fixed Rate Booking";
    }
    
    try {
        $stmt = $pdo->prepare("
            INSERT INTO chc_bookings (
                booking_id, user_id, equipment_type, billing_type, crop_type, 
                land_size_acres, billed_qty, unit_type, service_date, rate, 
                total_cost, notes, booking_status, operator_notes, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ");
        $stmt->execute([
            $bookingId, $userId, $equipmentType, $billingType, $cropType,
            $landSizeAcres, $billedQty, $unitType, $serviceDate, $rate,
            $totalCost, $notes, $bookingStatus, $operatorNotes
        ]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId(), 'booking_id' => $bookingId]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getCHCBookings($pdo) {
    $userId = $_GET['user_id'] ?? '';
    
    if (empty($userId)) {
        echo json_encode(['success' => false, 'error' => 'User ID required']);
        return;
    }
    
    try {
        $stmt = $pdo->prepare("
            SELECT id, booking_id, equipment_type, billing_type, crop_type, 
                   land_size_acres, billed_qty, unit_type, service_date, rate, 
                   total_cost, notes, booking_status, operator_notes, created_at
            FROM chc_bookings 
            WHERE user_id = ?
            ORDER BY created_at DESC
        ");
        $stmt->execute([$userId]);
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode(['success' => true, 'bookings' => $bookings]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getCHCEquipments($pdo) {
    $isMember = isset($_GET['is_member']) && $_GET['is_member'] == '1';
    $userId = $_GET['user_id'] ?? null;
    
    try {
        $sql = "
            SELECT ce.id, ce.name_en, ce.name_te, ce.image, ce.description, 
                   ce.price_member, ce.price_non_member, ce.unit, ce.quantity, ce.status
            FROM chc_equipments ce
            WHERE ce.status = 'Active' AND ce.quantity > 0
        ";
        
        $params = [];
        
        if ($userId) {
            // Get user's region
            $stmtUser = $pdo->prepare("SELECT region FROM users WHERE user_id = ?");
            $stmtUser->execute([$userId]);
            $user = $stmtUser->fetch(PDO::FETCH_ASSOC);
            
            if ($user && !empty($user['region'])) {
                // Assuming the table name is 'equipment_regions' based on the schema provided by user (id, region, equipment_id)
                // Using LEFT JOIN to include equipment available for the specific region OR general availability if we want?
                // The prompt implies "display based on user region", so strictly filtering seems appropriate.
                // However, if there are "Global" equipments, we should include them. 
                // Let's assume strict filtering for now based on "display based on user region".
                // But typically some items are for all regions. 
                // Let's use: WHERE id IN (SELECT equipment_id FROM equipment_regions WHERE region = ?)
                
                // WAIT, checking if table name is known. User just gave columns. 
                // I will use `equipment_availability` or similar? No, I'll use `region_equipment_mapping` or similar. 
                // Actually, I'll assume the table is `equipment_regions` as per convention and earlier plan approval.
                
                // Correct table name from user screenshot: chc_region_availability
                // Schema: id, region, equipment_id
                // Schema: id, region, equipment_id
                // Logic: 
                // 1. Equipment is explicitly available in user's region (IN clause)
                // 2. Equipment is NOT in the availability table at all (Global)
                // This covers:
                // - Restrictive: If it's in the table for ANY region, it adheres to those rules.
                // - Global: If it's not in the table, it's open to all.
                $sql .= " AND (
                    ce.id IN (SELECT equipment_id FROM chc_region_availability WHERE region = ?)
                    OR
                    ce.id NOT IN (SELECT DISTINCT equipment_id FROM chc_region_availability)
                )";
                $params[] = $user['region'];
            }
        }
        
        $sql .= " ORDER BY ce.id";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $equipments = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Add display_price based on membership
        foreach ($equipments as &$eq) {
            $eq['display_price'] = $isMember ? $eq['price_member'] : $eq['price_non_member'];
        }
        
        echo json_encode(['success' => true, 'equipments' => $equipments]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function checkCHCAvailability($pdo) {
    $equipmentName = $_GET['equipment_name'] ?? '';
    $serviceDate = $_GET['service_date'] ?? '';
    
    if (empty($equipmentName) || empty($serviceDate)) {
        echo json_encode(['success' => false, 'error' => 'Missing required parameters']);
        return;
    }
    
    try {
        // Get total quantity for equipment
        $stmt = $pdo->prepare("SELECT quantity FROM chc_equipments WHERE name_en = ?");
        $stmt->execute([$equipmentName]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $totalQty = $result ? (int)$result['quantity'] : 0;
        
        // Count existing bookings for this date (excluding cancelled)
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as booked_count 
            FROM chc_bookings 
            WHERE equipment_type = ? AND service_date = ? AND booking_status != 'Cancelled'
        ");
        $stmt->execute([$equipmentName, $serviceDate]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $bookedCount = $result ? (int)$result['booked_count'] : 0;
        
        $available = $totalQty - $bookedCount;
        $canBook = $available > 0;
        
        echo json_encode([
            'success' => true,
            'total_quantity' => $totalQty,
            'booked_count' => $bookedCount,
            'available' => $available,
            'can_book' => $canBook,
            'message' => $canBook ? 'Slot available' : 'క్షమించండి, ఈ తేదీలో స్లాట్లు అన్నీ బుక్ అయిపోయాయి. (Fully Booked)'
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getBookedDates($pdo) {
    $equipmentName = $_GET['equipment_name'] ?? '';
    $month = isset($_GET['month']) ? (int)$_GET['month'] : date('n');
    $year = isset($_GET['year']) ? (int)$_GET['year'] : date('Y');
    
    if (empty($equipmentName)) {
        echo json_encode(['success' => false, 'error' => 'Equipment name required']);
        return;
    }
    
    try {
        // Get total quantity for equipment
        $stmt = $pdo->prepare("SELECT quantity FROM chc_equipments WHERE name_en = ?");
        $stmt->execute([$equipmentName]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $totalQty = $result ? (int)$result['quantity'] : 0;
        
        // Get booking counts per date for this month
        $startDate = sprintf('%04d-%02d-01', $year, $month);
        $endDate = date('Y-m-t', strtotime($startDate));
        
        $stmt = $pdo->prepare("
            SELECT service_date, COUNT(*) as booked_count 
            FROM chc_bookings 
            WHERE equipment_type = ? 
              AND service_date BETWEEN ? AND ?
              AND booking_status != 'Cancelled'
            GROUP BY service_date
        ");
        $stmt->execute([$equipmentName, $startDate, $endDate]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $dates = [];
        foreach ($results as $row) {
            $dates[] = [
                'date' => $row['service_date'],
                'booked_count' => (int)$row['booked_count'],
                'total_quantity' => $totalQty,
                'is_full' => (int)$row['booked_count'] >= $totalQty
            ];
        }
        
        echo json_encode(['success' => true, 'dates' => $dates]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function createSeedBooking($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $bookingId = $input['booking_id'] ?? '';
    $userId = $input['user_id'] ?? '';
    $seedVarietyId = $input['seed_variety_id'] ?? 0;
    $quantityKg = $input['quantity_kg'] ?? 1.0;
    $totalPrice = $input['total_price'] ?? 0;
    
    if (empty($bookingId)) {
        echo json_encode(['success' => false, 'error' => 'Missing booking_id']);
        return;
    }
    if (empty($userId)) {
        echo json_encode(['success' => false, 'error' => 'Missing user_id']);
        return;
    }
    if (empty($seedVarietyId)) {
        echo json_encode(['success' => false, 'error' => 'Missing seed_variety_id']);
        return;
    }
    
    try {
        error_log("Seed Booking: Request received - ID: $bookingId, User: $userId, Variety: $seedVarietyId");
        
        // Find a valid listing_id for this seed variety
        // Prioritize listings that are active and available in all regions or match user's region
        // For simplicity, we'll pick the first active listing for this variety
        // In a real scenario, you might want to pass the specific listing_id from the frontend if multiple vendors exist
        $stmtListing = $pdo->prepare("
            SELECT id FROM vendor_listings 
            WHERE seed_variety_id = ? AND is_active = 1 
            LIMIT 1
        ");
        $stmtListing->execute([$seedVarietyId]);
        $listing = $stmtListing->fetch(PDO::FETCH_ASSOC);
        
        if (!$listing) {
            echo json_encode(['success' => false, 'error' => 'No active vendor listing found for this variety']);
            return;
        }
        
        $listingId = $listing['id'];
        
        // Get user region optionally
        $stmtUser = $pdo->prepare("SELECT region FROM users WHERE user_id = ?");
        $stmtUser->execute([$userId]);
        $user = $stmtUser->fetch(PDO::FETCH_ASSOC);
        $userRegion = $user['region'] ?? null;
        
        $stmt = $pdo->prepare("
            INSERT INTO bookings (
                booking_id, user_id, seed_variety_id, listing_id, user_region, quantity_kg, total_price, booking_status, booking_timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', NOW())
        ");
        $stmt->execute([
            $bookingId, $userId, $seedVarietyId, $listingId, $userRegion, $quantityKg, $totalPrice
        ]);
        
        error_log("Seed Booking: Successfully created ID " . $pdo->lastInsertId());
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId(), 'booking_id' => $bookingId]);
    } catch (PDOException $e) {
        error_log("Seed Booking Error: " . $e->getMessage());
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== ANNOUNCEMENTS FUNCTIONS =====================

function getAnnouncements($pdo) {
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 5;
    
    try {
        $stmt = $pdo->prepare("
            SELECT id, headline, description, media_url, media_type, created_at
            FROM announcements 
            ORDER BY created_at DESC
            LIMIT ?
        ");
        $stmt->execute([$limit]);
        $announcements = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode(['success' => true, 'announcements' => $announcements]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}
?>
