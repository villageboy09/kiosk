<?php
/**
 * CropSync Kiosk API
 * MySQL Backend API for Flutter App
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
require_once 'market_prices_api.php';

// Keep app/API string parameters consistent with utf8mb4.
// This helps avoid MySQL collation conflicts when the database contains mixed legacy collations.
try {
    if (isset($pdo) && $pdo instanceof PDO) {
        $pdo->exec("SET NAMES utf8mb4");
    }
} catch (Throwable $e) {
    // Do not block API execution if the server does not allow changing connection charset.
}

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'apply_migration':
        applyMigration($pdo);
        break;
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
    case 'operator_login':
        operatorLogin($pdo);
        break;
    case 'get_operator_details':
        getOperatorDetails($pdo);
        break;
    case 'get_operator_bookings':
        getOperatorBookings($pdo);
        break;
    case 'update_operator_booking_status':
        updateOperatorBookingStatus($pdo);
        break;
    case 'complete_booking_manual':
        completeBookingManual($pdo);
        break;
    case 'send_otp':
        sendOtp($pdo);
        break;
    case 'verify_otp':
        verifyOtp($pdo);
        break;
    case 'register_user':
        registerUser($pdo);
        break;
    case 'check_user':
        checkUser($pdo);
        break;
    case 'login':
        loginUser($pdo);
        break;
    case 'get_user_profile':
        getUserProfile($pdo);
        break;
    // NEW ENDPOINT FOR TROLLEY PRICING
    case 'calculate_trolley_price':
        calculateTrolleyPrice($pdo);
        break;
    // MARKET PRICES V2 ENDPOINTS
    case 'sync_market_prices':
        syncMarketPrices($pdo);
        break;
    case 'get_state_market_prices':
        getStateMarketPrices($pdo);
        break;
    case 'get_live_state_market_prices':
        getLiveStateMarketPrices($pdo);
        break;
    case 'get_commodity_trends':
        getCommodityTrends($pdo);
        break;
    // RETAILER AND EXTENSION OFFICER ENDPOINTS
    case 'get_retailer_dashboard':
        getRetailerDashboard($pdo);
        break;
    case 'get_retailer_leads':
        getRetailerLeads($pdo);
        break;
    case 'update_lead_status':
        updateLeadStatus($pdo);
        break;
    case 'get_extension_dashboard':
        getExtensionDashboard($pdo);
        break;
    case 'get_active_outbreaks':
        getActiveOutbreaks($pdo);
        break;
    case 'bind_retailer_referral':
        bindRetailerReferral($pdo);
        break;
    default:
        echo json_encode(['success' => false, 'error' => 'Invalid action']);
}

function applyMigration($pdo) {
    try {
        $stmt = $pdo->query("SHOW INDEX FROM users WHERE Key_name = 'idx_users_phone_number'");
        $indexExists = $stmt->fetch();
        if ($indexExists) {
            echo json_encode(['success' => true, 'message' => 'Index already exists']);
        } else {
            $pdo->exec("ALTER TABLE `users` ADD INDEX `idx_users_phone_number` (`phone_number`)");
            echo json_encode(['success' => true, 'message' => 'Index applied successfully']);
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== TRACTOR TROLLEY PRICING CALCULATION =====================

function calculateTrolleyPrice($pdo) {
    $equipmentId = $_GET['equipment_id'] ?? 0;
    $clientCode = $_GET['client_code'] ?? '';
    $distance = isset($_GET['distance']) ? (float)$_GET['distance'] : 0;
    $isMember = isset($_GET['is_member']) && $_GET['is_member'] == '1';

    if (empty($equipmentId) || empty($clientCode)) {
        echo json_encode(['success' => false, 'error' => 'Equipment ID and Client Code are required']);
        return;
    }

    try {
        // Find the specific slab where distance falls between min_km and max_km
        $stmt = $pdo->prepare("
            SELECT price_member, price_non_member 
            FROM client_item_price_slabs 
            WHERE item_id = ? AND client_code = ? 
              AND ? > min_km AND ? <= max_km 
            LIMIT 1
        ");
        $stmt->execute([$equipmentId, $clientCode, $distance, $distance]);
        $slab = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($slab) {
            $price = $isMember ? $slab['price_member'] : $slab['price_non_member'];
            echo json_encode(['success' => true, 'price' => $price, 'slab_found' => true]);
        } else {
            // Fallback to the maximum slab if distance exceeds all defined slabs
            $stmtMax = $pdo->prepare("SELECT price_member, price_non_member, max_km FROM client_item_price_slabs WHERE item_id = ? AND client_code = ? ORDER BY max_km DESC LIMIT 1");
            $stmtMax->execute([$equipmentId, $clientCode]);
            $maxSlab = $stmtMax->fetch(PDO::FETCH_ASSOC);
            
            if ($maxSlab && $distance > $maxSlab['max_km']) {
                $price = $isMember ? $maxSlab['price_member'] : $maxSlab['price_non_member'];
                echo json_encode(['success' => true, 'price' => $price, 'slab_found' => true, 'note' => 'Distance exceeds max slab, applying highest slab rate']);
            } else {
                echo json_encode(['success' => false, 'error' => 'No pricing slab found for this distance']);
            }
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}


// ===================== AUTH FUNCTIONS =====================

// MSG91 configuration
define('MSG91_AUTHKEY', '491154AraRrF6el3UI69a6deb0P1'); // Replace with actual Authkey
define('MSG91_TEMPLATE_ID', '69aede8e203e58f67f082ba2'); // Replace with actual Template ID

function sendOtp($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $phone = $input['phone_number'] ?? '';

    if (empty($phone)) {
        echo json_encode(['success' => false, 'error' => 'Phone number is required']);
        return;
    }

    $authkey = defined('MSG91_AUTHKEY') && !empty(MSG91_AUTHKEY) ? MSG91_AUTHKEY : '491154AraRrF6el3UI69a6deb0P1';
    $template_id = defined('MSG91_TEMPLATE_ID') && !empty(MSG91_TEMPLATE_ID) ? MSG91_TEMPLATE_ID : '69aede8e203e58f67f082ba2';
    
    // Default to Indian country code if not present
    $mobile = preg_match('/^\d{10}$/', $phone) ? '91' . $phone : $phone;

    // Generate 6-digit OTP
    $otp = str_pad(mt_rand(0, 999999), 6, '0', STR_PAD_LEFT);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+10 minutes'));

    try {
        // Insert OTP to database
        $stmt = $pdo->prepare("INSERT INTO otps (phone_number, otp, expires_at) VALUES (?, ?, ?)");
        $stmt->execute([$phone, $otp, $expiresAt]);

        $curl = curl_init();
        
        // We use MSG91 Send SMS (Flow API) to deliver our custom generated OTP
        $postData = json_encode([
            "template_id" => $template_id,
            "short_url" => "0", // 0 or 1 depending on requirement
            "recipients" => [
                [
                    "mobiles" => $mobile,
                    "var1" => $otp
                ]
            ]
        ]);

        curl_setopt_array($curl, [
          CURLOPT_URL => "https://api.msg91.com/api/v5/flow/",
          CURLOPT_RETURNTRANSFER => true,
          CURLOPT_ENCODING => "",
          CURLOPT_MAXREDIRS => 10,
          CURLOPT_TIMEOUT => 30,
          CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
          CURLOPT_CUSTOMREQUEST => "POST",
          CURLOPT_POSTFIELDS => $postData,
          CURLOPT_HTTPHEADER => [
            "Content-Type: application/json",
            "authkey: $authkey"
          ],
        ]);

        $response = curl_exec($curl);
        $err = curl_error($curl);

        curl_close($curl);

        if ($err) {
            echo json_encode(['success' => false, 'error' => "cURL Error #:" . $err]);
        } else {
            $result = json_decode($response, true);
            // Flow API success usually does not have "type": "success". It returns an empty json or success message with a request_id
            if (isset($result['type']) && $result['type'] === 'success' || !empty($result['request_id']) || (isset($result['message']) && stripos($result['message'], 'success') !== false)) {
                echo json_encode(['success' => true, 'message' => 'OTP sent successfully']);
            } else {
                echo json_encode(['success' => false, 'error' => $result['message'] ?? 'Failed to send OTP']);
            }
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => 'Database error: ' . $e->getMessage()]);
    }
}

function verifyOtp($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $phone = $input['phone_number'] ?? '';
    $otp = $input['otp'] ?? '';

    if (empty($phone) || empty($otp)) {
        echo json_encode(['success' => false, 'error' => 'Phone number and OTP are required']);
        return;
    }

    try {
        // Fetch the most recent unused OTP for this phone
        $stmt = $pdo->prepare("SELECT * FROM otps WHERE phone_number = ? AND is_verified = 0 ORDER BY created_at DESC LIMIT 1");
        $stmt->execute([$phone]);
        $record = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$record) {
            echo json_encode(['success' => false, 'error' => 'No pending OTP found. Please send another OTP.']);
            return;
        }

        // Check if expired
        $currentTime = date('Y-m-d H:i:s');
        if ($record['expires_at'] < $currentTime) {
            echo json_encode(['success' => false, 'error' => 'OTP has expired']);
            return;
        }

        // Check if OTP matches
        if ($record['otp'] === $otp) {
            // Mark as verified
            $updateStmt = $pdo->prepare("UPDATE otps SET is_verified = 1 WHERE id = ?");
            $updateStmt->execute([$record['id']]);

            echo json_encode(['success' => true, 'message' => 'OTP verified successfully']);
        } else {
            echo json_encode(['success' => false, 'error' => 'Invalid OTP']);
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => 'Database error: ' . $e->getMessage()]);
    }
}

function registerUser($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $userId = $input['phone_number'] ?? ''; // Using phone_number as user_id per requirement
    $name = $input['name'] ?? '';
    $clientCode = $input['client_code'] ?? 'HYD001';
    
    if (empty($userId) || empty($name)) {
        echo json_encode(['success' => false, 'error' => 'Name and Phone number are required']);
        return;
    }

    try {
        // Check if user already exists
        $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ?");
        $stmt->execute([$userId]);
        $existingUser = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($existingUser) {
            echo json_encode(['success' => false, 'error' => 'User with this phone number already exists']);
            return;
        }

        // Insert new user
        $stmt = $pdo->prepare("INSERT INTO users (user_id, name, phone_number, client_code) VALUES (?, ?, ?, ?)");
        $stmt->execute([$userId, $name, $userId, $clientCode]); // phone_number is same as user_id

        // Fetch user object to return
        $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ?");
        $stmt->execute([$userId]);
        $newUser = $stmt->fetch(PDO::FETCH_ASSOC);

        echo json_encode(['success' => true, 'message' => 'User registered successfully', 'user' => $newUser]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function checkUser($pdo) {
    $userId = $_GET['phone_number'] ?? '';
    $role = $_GET['role'] ?? null;
    if (empty($userId)) {
        echo json_encode(['success' => false, 'error' => 'Phone number is required']);
        return;
    }

    try {
        $res = loginWithRoleChecking($pdo, $userId, $role);
        if ($res['success']) {
            echo json_encode(['success' => true, 'exists' => true, 'user' => $res['user']]);
        } else {
            echo json_encode(['success' => true, 'exists' => false]);
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => 'Database error: ' . $e->getMessage()]);
    }
}


function loginWithRoleChecking($pdo, $userId, $role = null) {
    // Ensure PDO throws exceptions for robustness and clear error reporting
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // If role is explicitly provided, target only the single matching table for maximum performance
    if ($role === 'retailer') {
        $stmtRet = $pdo->prepare("SELECT * FROM retailer_partners WHERE contact_number = ? LIMIT 1");
        $stmtRet->execute([$userId]);
        $retailer = $stmtRet->fetch(PDO::FETCH_ASSOC);
        if ($retailer) {
            return [
                'success' => true,
                'role' => 'retailer',
                'retailer_id' => (int)$retailer['id'],
                'user' => [
                    'user_id' => $userId,
                    'name' => $retailer['owner_name'],
                    'phone_number' => $retailer['contact_number'],
                    'village' => $retailer['village'],
                    'mandal' => $retailer['mandal'],
                    'district' => $retailer['district'],
                    'region' => $retailer['region'],
                    'client_code' => $retailer['client_code'],
                    'membership_type' => 'Retailer'
                ]
            ];
        }
    } elseif ($role === 'officer') {
        $stmtOff = $pdo->prepare("SELECT * FROM extension_officers WHERE contact_number = ? LIMIT 1");
        $stmtOff->execute([$userId]);
        $officer = $stmtOff->fetch(PDO::FETCH_ASSOC);
        if ($officer) {
            return [
                'success' => true,
                'role' => 'officer',
                'officer_id' => (int)$officer['id'],
                'user' => [
                    'user_id' => $userId,
                    'name' => $officer['name'],
                    'phone_number' => $officer['contact_number'],
                    'village' => $officer['coverage_mandal'],
                    'mandal' => $officer['coverage_mandal'],
                    'district' => $officer['coverage_district'],
                    'region' => $officer['coverage_district'],
                    'membership_type' => 'Officer'
                ]
            ];
        }
    } elseif ($role === 'farmer') {
        $stmtFarmer = $pdo->prepare("SELECT * FROM users WHERE user_id = ? OR phone_number = ? LIMIT 1");
        $stmtFarmer->execute([$userId, $userId]);
        $user = $stmtFarmer->fetch(PDO::FETCH_ASSOC);
        if ($user) {
            return [
                'success' => true,
                'role' => 'farmer',
                'user' => $user
            ];
        }
    } else {
        // Fallback to UNION lookup if role is not supplied (for backward compatibility)
        $stmt = $pdo->prepare("
            (SELECT 'retailer' AS role, id FROM retailer_partners WHERE contact_number = ? LIMIT 1)
            UNION ALL
            (SELECT 'officer' AS role, id FROM extension_officers WHERE contact_number = ? LIMIT 1)
            UNION ALL
            (SELECT 'farmer' AS role, user_id AS id FROM users WHERE user_id = ? LIMIT 1)
            UNION ALL
            (SELECT 'farmer' AS role, user_id AS id FROM users WHERE phone_number = ? LIMIT 1)
        ");
        $stmt->execute([$userId, $userId, $userId, $userId]);
        $match = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($match) {
            $matchedRole = $match['role'];
            $matchedId = $match['id'];

            if ($matchedRole === 'retailer') {
                $stmtRet = $pdo->prepare("SELECT * FROM retailer_partners WHERE id = ? LIMIT 1");
                $stmtRet->execute([$matchedId]);
                $retailer = $stmtRet->fetch(PDO::FETCH_ASSOC);
                if ($retailer) {
                    return [
                        'success' => true,
                        'role' => 'retailer',
                        'retailer_id' => (int)$retailer['id'],
                        'user' => [
                            'user_id' => $userId,
                            'name' => $retailer['owner_name'],
                            'phone_number' => $retailer['contact_number'],
                            'village' => $retailer['village'],
                            'mandal' => $retailer['mandal'],
                            'district' => $retailer['district'],
                            'region' => $retailer['region'],
                            'client_code' => $retailer['client_code'],
                            'membership_type' => 'Retailer'
                        ]
                    ];
                }
            } elseif ($matchedRole === 'officer') {
                $stmtOff = $pdo->prepare("SELECT * FROM extension_officers WHERE id = ? LIMIT 1");
                $stmtOff->execute([$matchedId]);
                $officer = $stmtOff->fetch(PDO::FETCH_ASSOC);
                if ($officer) {
                    return [
                        'success' => true,
                        'role' => 'officer',
                        'officer_id' => (int)$officer['id'],
                        'user' => [
                            'user_id' => $userId,
                            'name' => $officer['name'],
                            'phone_number' => $officer['contact_number'],
                            'village' => $officer['coverage_mandal'],
                            'mandal' => $officer['coverage_mandal'],
                            'district' => $officer['coverage_district'],
                            'region' => $officer['coverage_district'],
                            'membership_type' => 'Officer'
                        ]
                    ];
                }
            } elseif ($matchedRole === 'farmer') {
                $stmtFarmer = $pdo->prepare("SELECT * FROM users WHERE user_id = ? LIMIT 1");
                $stmtFarmer->execute([$matchedId]);
                $user = $stmtFarmer->fetch(PDO::FETCH_ASSOC);
                if ($user) {
                    return [
                        'success' => true,
                        'role' => 'farmer',
                        'user' => $user
                    ];
                }
            }
        }
    }

    return [
        'success' => false,
        'message' => 'User not found. Please register first.'
    ];
}

function loginUser($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $userId = $input['user_id'] ?? '';
    $role = $input['role'] ?? null;

    if (empty($userId)) {
        echo json_encode(['success' => false, 'message' => 'User ID is required']);
        return;
    }

    try {
        $res = loginWithRoleChecking($pdo, $userId, $role);
        echo json_encode($res);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
    }
}

function getUserProfile($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $userId = $input['user_id'] ?? '';
    $role = $input['role'] ?? null;

    if (empty($userId)) {
        echo json_encode(['success' => false, 'message' => 'User ID is required']);
        return;
    }

    try {
        $res = loginWithRoleChecking($pdo, $userId, $role);
        if ($res['success']) {
            echo json_encode(['success' => true, 'user' => $res['user']]);
        } else {
            echo json_encode(['success' => false, 'message' => 'User not found']);
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
    }
}

function handleLogin($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $userId = $input['user_id'] ?? '';
    $role = $input['role'] ?? null;
    
    if (empty($userId)) {
        echo json_encode(['success' => false, 'message' => 'User ID is required']);
        return;
    }
    
    try {
        $res = loginWithRoleChecking($pdo, $userId, $role);
        echo json_encode($res);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
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
    $nameField = ($lang === 'en') ? 'name_en' : (($lang === 'hi') ? 'name_hi' : 'name');
    
    $stmt = $pdo->prepare("SELECT id, $nameField as name, image_url FROM crops ORDER BY id");
    $stmt->execute();
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
    
    $cropNameField = ($lang === 'en') ? 'c.name_en' : (($lang === 'hi') ? 'c.name_hi' : 'c.name');
    
    $stmt = $pdo->prepare("
        SELECT 
            ucs.id as selection_id,
            ucs.field_number as field_name,
            ucs.crop_id,
            ucs.variety_id,
            $cropNameField as crop_name,
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
    
    $nameField = ($lang === 'en') ? 'StageName_en' : (($lang === 'hi') ? 'StageName_hi' : 'StageName');
    $descField = ($lang === 'en') ? 'Description_en' : (($lang === 'hi') ? 'Description_hi' : 'Description');
    
    $stmt = $pdo->prepare("
        SELECT 
            StageID as id, 
            $nameField as name, 
            StageName as name_te,
            StageName_en as name_en,
            StageName_hi as name_hi,
            $descField as description, 
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
 */
function getProblems($pdo) {
    $cropId = $_GET['crop_id'] ?? null;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = ($lang === 'en') ? 'problem_name_en' : (($lang === 'hi') ? 'problem_name_hi' : 'problem_name_te');
    
    if ($stageId) {
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
 */
function getAdvisories($pdo) {
    $problemId = $_GET['problem_id'] ?? 0;
    $stageId = $_GET['stage_id'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    $titleField = ($lang === 'en') ? 'advisory_title_en' : (($lang === 'hi') ? 'advisory_title_hi' : 'advisory_title_te');
    $symptomsField = ($lang === 'en') ? 'symptoms_en' : (($lang === 'hi') ? 'symptoms_hi' : 'symptoms_te');
    
    $stmt = $pdo->prepare("
        SELECT 
            id,
            problem_id,
            $titleField as title,
            advisory_title_te as title_te,
            advisory_title_en as title_en,
            advisory_title_hi as title_hi,
            $symptomsField as symptoms,
            symptoms_te,
            symptoms_en,
            symptoms_hi
        FROM crop_advisories 
        WHERE problem_id = ?
    ");
    $stmt->execute([$problemId]);
    $advisory = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($advisory) {
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
 */
function getAdvisoryComponents($pdo) {
    $advisoryId = $_GET['advisory_id'] ?? 0;
    $problemStageId = $_GET['problem_stage_id'] ?? null;
    $stageScope = $_GET['stage_scope'] ?? null;
    $lang = $_GET['lang'] ?? 'te';
    
    $nameField = ($lang === 'en') ? 'component_name_en' : (($lang === 'hi') ? 'component_name_hi' : 'component_name_te');
    $altNameField = ($lang === 'en') ? 'alt_component_name_en' : (($lang === 'hi') ? 'alt_component_name_hi' : 'alt_component_name_te');
    $doseField = ($lang === 'en') ? 'dose_en' : (($lang === 'hi') ? 'dose_hi' : 'dose_te');
    $methodField = ($lang === 'en') ? 'application_method_en' : (($lang === 'hi') ? 'application_method_hi' : 'application_method_te');
    
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
    
    if ($problemStageId) {
        $sql .= " AND (problem_stage_id = ? OR problem_stage_id IS NULL)";
        $params[] = $problemStageId;
    }
    
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
    
    if (empty($userId) || empty($problemId)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }
    
    try {
        $checkStmt = $pdo->prepare("
            SELECT id FROM farmer_identified_problems 
            WHERE user_id = ? AND problem_id = ?
        ");
        $checkStmt->execute([$userId, $problemId]);
        $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($existing) {
            echo json_encode([
                'success' => true, 
                'id' => $existing['id'], 
                'message' => 'Already identified'
            ]);
            return;
        }
        
        $stmt = $pdo->prepare("
            INSERT INTO farmer_identified_problems (problem_id, user_id, created_at)
            VALUES (?, ?, NOW())
        ");
        $stmt->execute([$problemId, $userId]);
        $problemRecordId = $pdo->lastInsertId();
        
        // Lead Assignment Engine logic:
        try {
            $userStmt = $pdo->prepare("SELECT referred_by_retailer_id, mandal, district FROM users WHERE user_id = ? LIMIT 1");
            $userStmt->execute([$userId]);
            $user = $userStmt->fetch(PDO::FETCH_ASSOC);
            
            $retailerId = null;
            if ($user) {
                if (!empty($user['referred_by_retailer_id'])) {
                    $retailerId = $user['referred_by_retailer_id'];
                } else {
                    // Find an active retailer in the same mandal and district, prioritized by subscription tier
                    $retStmt = $pdo->prepare("
                        SELECT id FROM retailer_partners 
                        WHERE mandal = ? AND district = ? AND subscription_status = 'ACTIVE'
                        ORDER BY FIELD(tier, 'PLATINUM', 'GOLD', 'SILVER', 'BRONZE') ASC, RAND()
                        LIMIT 1
                    ");
                    $retStmt->execute([$user['mandal'], $user['district']]);
                    $matchedRetailer = $retStmt->fetch(PDO::FETCH_ASSOC);
                    if ($matchedRetailer) {
                        $retailerId = $matchedRetailer['id'];
                    }
                }
            }
            
            if ($retailerId) {
                $leadStmt = $pdo->prepare("
                    INSERT INTO retailer_leads (farmer_identified_problem_id, retailer_partner_id, lead_status, assigned_at)
                    VALUES (?, ?, 'NEW', NOW())
                ");
                $leadStmt->execute([$problemRecordId, $retailerId]);
            }
        } catch (Throwable $leadEx) {
            // Log/ignore errors with lead engine assignment so the main save flow is not blocked
        }
        
        echo json_encode([
            'success' => true, 
            'id' => $problemRecordId,
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
        
        $nameField = ($lang === 'en') ? 'product_name_en' : (($lang === 'hi') ? 'product_name_hi' : 'product_name');
        $descField = ($lang === 'en') ? 'product_description_en' : (($lang === 'hi') ? 'product_description_hi' : 'product_description');
        
        $sql = "
            SELECT p.product_id, p.product_code, p.category, p.$nameField as product_name, 
                   p.price, p.$descField as product_description, p.product_video_url,
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
        
        if ($userId) {
            $stmtUser = $pdo->prepare("SELECT region FROM users WHERE user_id = ?");
            $stmtUser->execute([$userId]);
            $user = $stmtUser->fetch(PDO::FETCH_ASSOC);
            
            if ($user && !empty($user['region'])) {
                $userRegion = $user['region'];
                
                try {
                    $stmtRegion = $pdo->prepare("SELECT id FROM regions WHERE region_name = ? LIMIT 1"); 
                    $stmtRegion->execute([$userRegion]);
                    $region = $stmtRegion->fetch(PDO::FETCH_ASSOC);
                    
                    if ($region) {
                        $regionId = $region['id'];
                        $sql .= " AND (p.region_id IS NULL OR p.region_id = ?)";
                        $params[] = $regionId;
                    } else {
                        $sql .= " AND p.region_id IS NULL";
                    }
                } catch (PDOException $e) {
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
    
    $varietyField = ($lang === 'en') ? 'variety_name_en' : (($lang === 'hi') ? 'variety_name_hi' : 'variety_name_te');
    $detailsField = ($lang === 'en') ? 'details_en' : (($lang === 'hi') ? 'details_hi' : 'details_te');
    
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
    
    if (!empty($cropName)) {
        $sql .= " AND sv.crop_name = ?";
        $params[] = $cropName;
    }
    
    if (!empty($userId)) {
        $stmtUser = $pdo->prepare("SELECT region FROM users WHERE user_id = ?");
        $stmtUser->execute([$userId]);
        $user = $stmtUser->fetch(PDO::FETCH_ASSOC);
        
        if ($user && !empty($user['region'])) {
            $userRegion = $user['region'];
            
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
    $lang = $_GET['lang'] ?? 'te';
    $nameField = ($lang === 'en') ? 'name_en' : (($lang === 'hi') ? 'name_hi' : 'name');
    
    $stmt = $pdo->query("SELECT DISTINCT crop_name FROM seed_varieties ORDER BY crop_name");
    $crops = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    $stmt = $pdo->query("SELECT id, $nameField as name FROM crops ORDER BY id");
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
            SELECT 
                b.id, b.booking_id, b.equipment_type, b.billing_type, b.crop_type, 
                b.land_size_acres, b.billed_qty, b.unit_type, b.service_date, 
                b.rescheduled_date, b.rate, b.total_cost, b.notes, b.booking_status, 
                b.operator_notes, b.assignment_status, b.created_at, b.updated_at,
                
                o.name AS operator_name,
                o.phone_number AS operator_phone,
                o.profile_image AS operator_image,
                o.rating AS operator_rating,
                o.base_village AS operator_village,
                
                tc.status AS task_status,
                tc.start_reading, tc.end_reading,
                tc.measured_qty, tc.measured_unit,
                tc.applied_rate, tc.final_amount,
                tc.transit_start_time, tc.transit_end_time,
                tc.work_start_time, tc.work_end_time,
                tc.return_time,
                tc.breakdown_start, tc.breakdown_end, tc.breakdown_reason,
                tc.cumulative_pause
                
            FROM chc_bookings b
            LEFT JOIN chc_operators o ON b.assigned_operator_id = o.operator_id
            LEFT JOIN chc_task_completions tc ON b.booking_id = tc.booking_id
            WHERE b.user_id = ?
            ORDER BY b.created_at DESC
        ");
        $stmt->execute([$userId]);
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode(['success' => true, 'bookings' => $bookings]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Fetch CHC Equipments
 * Region-specific filter based on client_code
 */
function getCHCEquipments($pdo) {
    $isMember = isset($_GET['is_member']) && $_GET['is_member'] == '1';
    $clientCode = $_GET['client_code'] ?? null;
    $operatorId = $_GET['operator_id'] ?? null; 
    
    try {
        // Automatically fetch client_code if the flutter app sends operator_id
        if (empty($clientCode) && !empty($operatorId)) {
            $stmtOp = $pdo->prepare("SELECT client_code FROM chc_operators WHERE operator_id = ?");
            $stmtOp->execute([$operatorId]);
            $opData = $stmtOp->fetch(PDO::FETCH_ASSOC);
            if ($opData && !empty($opData['client_code'])) {
                $clientCode = $opData['client_code'];
            }
        }

        if (!empty($clientCode)) {
            // Filter by region availability based on client_code and use custom pricing as fallback
            $stmt = $pdo->prepare("
                SELECT DISTINCT e.id, e.name_en, e.name_te, e.image, e.description,
                       e.unit, e.quantity, e.status,
                       COALESCE(p.price_member, e.price_member) AS price_member, 
                       COALESCE(p.price_non_member, e.price_non_member) AS price_non_member
                FROM chc_equipments e
                JOIN chc_region_availability cra ON e.id = cra.equipment_id
                JOIN regions r ON cra.region_id = r.id
                LEFT JOIN client_item_pricing p ON e.id = p.item_id AND p.client_code = ?
                WHERE r.client_code = ? AND e.status = 'Active'
                ORDER BY e.name_en
            ");
            $stmt->execute([$clientCode, $clientCode]);
        } else {
            // Fallback for generic fetch
            $stmt = $pdo->prepare("
                SELECT e.id, e.name_en, e.name_te, e.image, e.description,
                       e.unit, e.quantity, e.status,
                       e.price_member, e.price_non_member
                FROM chc_equipments e
                WHERE e.status = 'Active'
                ORDER BY e.name_en
            ");
            $stmt->execute();
        }

        $equipments = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Add display_price and fetch slabs for Tractor-Trolley
        foreach ($equipments as &$eq) {
            $eq['display_price'] = $isMember ? ($eq['price_member'] ?? 0) : ($eq['price_non_member'] ?? 0);

            if (stripos($eq['name_en'], 'Tractor-Trolley') !== false && !empty($clientCode)) {
                $stmtSlab = $pdo->prepare("SELECT min_km, max_km, price_member, price_non_member FROM client_item_price_slabs WHERE item_id = ? AND client_code = ? ORDER BY min_km");
                $stmtSlab->execute([$eq['id'], $clientCode]);
                $eq['slabs'] = $stmtSlab->fetchAll(PDO::FETCH_ASSOC);
            }
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
        $stmt = $pdo->prepare("SELECT quantity FROM chc_equipments WHERE name_en = ?");
        $stmt->execute([$equipmentName]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $totalQty = $result ? (int)$result['quantity'] : 0;
        
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
        $stmt = $pdo->prepare("SELECT quantity FROM chc_equipments WHERE name_en = ?");
        $stmt->execute([$equipmentName]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $totalQty = $result ? (int)$result['quantity'] : 0;
        
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

// ===================== OPERATOR FUNCTIONS =====================

function getOperatorDetails($pdo) {
    // Only phone number or ID is needed. Since login uses phone_number, we can use operator_id for refreshing
    $operatorId = $_GET['operator_id'] ?? '';
    if (empty($operatorId)) {
        echo json_encode(['success' => false, 'message' => 'Operator ID required']);
        return;
    }
    
    try {
        $stmt = $pdo->prepare("
            SELECT o.*, 
                   (SELECT COUNT(*) FROM chc_bookings b 
                    WHERE b.assigned_operator_id = o.operator_id 
                      AND (b.booking_status = 'Completed' OR b.assignment_status = 'Completed')
                   ) AS jobs_completed
            FROM chc_operators o 
            WHERE o.operator_id = ?
        ");
        $stmt->execute([$operatorId]);
        $operator = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$operator) {
            echo json_encode(['success' => false, 'message' => 'Operator not found.']);
            return;
        }

        unset($operator['password']);
        echo json_encode(['success' => true, 'operator' => $operator]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
    }
}

function operatorLogin($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);

    $phone = $input['phone_number'] ?? '';
    $password = $input['password'] ?? '';

    if (empty($phone) || empty($password)) {
        echo json_encode([
            'success' => false,
            'message' => 'Phone and password are required'
        ]);
        return;
    }

    try {

        // Fetch all operators with same phone number
        $stmt = $pdo->prepare("
            SELECT o.*,
                   (SELECT COUNT(*) FROM chc_bookings b
                    WHERE b.assigned_operator_id = o.operator_id
                    AND (
                        b.booking_status = 'Completed'
                        OR b.assignment_status = 'Completed'
                    )
                   ) AS jobs_completed
            FROM chc_operators o
            WHERE o.phone_number = ?
        ");

        $stmt->execute([$phone]);

        $operators = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (!$operators || count($operators) === 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Operator not found'
            ]);
            return;
        }

        $matchedOperator = null;

        foreach ($operators as $operator) {

            $passwordMatch = false;

            if (!empty($operator['password'])) {

                if (password_verify($password, $operator['password'])) {
                    $passwordMatch = true;
                }

                elseif ($operator['password'] === $password) {
                    $passwordMatch = true;
                }
            }

            if ($passwordMatch) {
                $matchedOperator = $operator;
                break;
            }
        }

        if (!$matchedOperator) {
            echo json_encode([
                'success' => false,
                'message' => 'Incorrect password'
            ]);
            return;
        }

        unset($matchedOperator['password']);

        echo json_encode([
            'success' => true,
            'operator' => $matchedOperator
        ]);

    } catch (PDOException $e) {

        echo json_encode([
            'success' => false,
            'message' => 'Database error: ' . $e->getMessage()
        ]);
    }
}

function getOperatorBookings($pdo) {
    $operatorId = trim($_GET['operator_id'] ?? '');
    $assignmentStatusesRaw = trim($_GET['assignment_statuses'] ?? '');

    if (empty($operatorId)) {
        echo json_encode(['success' => false, 'error' => 'Operator ID required']);
        return;
    }

    try {
        $sql = "
            SELECT
                b.id, b.booking_id, b.user_id, b.equipment_type, b.billing_type,
                b.crop_type, b.land_size_acres, b.billed_qty, b.unit_type,
                b.service_date, b.rescheduled_date, b.rate, b.total_cost,
                b.notes, b.booking_status, b.operator_notes,
                b.assignment_status, b.created_at, b.updated_at,

                MAX(u.name) AS farmer_name,
                MAX(u.phone_number) AS farmer_phone,
                MAX(u.village) AS farmer_village

            FROM chc_bookings b
            LEFT JOIN users u ON b.user_id = u.user_id OR b.user_id = u.phone_number
            WHERE b.assigned_operator_id = ?
        ";

        $params = [$operatorId];

        if (!empty($assignmentStatusesRaw)) {
            $statuses = array_values(array_filter(array_map('trim', explode(',', $assignmentStatusesRaw))));
            if (!empty($statuses)) {
                $placeholders = implode(',', array_fill(0, count($statuses), '?'));
                $sql .= " AND LOWER(TRIM(COALESCE(b.assignment_status, ''))) IN ($placeholders)";
                foreach ($statuses as $status) {
                    $params[] = strtolower($status);
                }
            }
        }

        $sql .= " GROUP BY b.id ORDER BY b.created_at DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(['success' => true, 'bookings' => $bookings]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Update Operator Booking Status + Handle current_booking_id
 */
function updateOperatorBookingStatus($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);

    $bookingId         = trim($input['booking_id'] ?? '');
    $bookingStatus     = trim($input['booking_status'] ?? '');
    $assignmentStatus  = trim($input['assignment_status'] ?? '');
    $rescheduledDate   = $input['rescheduled_date'] ?? null;
    $operatorIdInput   = trim((string)($input['operator_id'] ?? ''));
    $operatorNotes     = trim($input['operator_notes'] ?? '');
    $cancelReason      = trim($input['cancel_reason'] ?? ($input['reason'] ?? ($operatorNotes ?: 'Cancelled by operator from app')));

    if (empty($bookingId)) {
        echo json_encode(['success' => false, 'error' => 'Booking ID is required']);
        return;
    }

    try {
        $pdo->beginTransaction();

        // 1. Lock and read current booking details before changing anything.
        $stmt = $pdo->prepare(" 
            SELECT assigned_operator_id, booking_status, assignment_status, service_date, operator_notes
            FROM chc_bookings 
            WHERE BINARY booking_id = BINARY ?
            FOR UPDATE
        ");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$booking) {
            throw new Exception("Booking not found");
        }

        $operatorId = !empty($booking['assigned_operator_id']) ? $booking['assigned_operator_id'] : $operatorIdInput;
        $bookingStatusLower = strtolower(trim($bookingStatus));
        $assignmentStatusLower = strtolower(trim($assignmentStatus));

        // IMPORTANT:
        // This endpoint is used by the operator app. Therefore, when the app sends
        // Cancelled, it should mean "operator cancelled this assignment", not
        // "farmer/admin cancelled the whole booking". The booking must remain
        // active and reassignable on the dashboard.
        $isOperatorCancellation = in_array($bookingStatusLower, ['cancelled', 'canceled'], true)
            || in_array($assignmentStatusLower, ['cancelled', 'canceled', 'operator cancelled', 'operator canceled'], true);

        if ($isOperatorCancellation) {
            if (empty($operatorId)) {
                throw new Exception('Cannot cancel operator assignment because no operator is attached to this booking.');
            }

            if (strtolower(trim($booking['booking_status'] ?? '')) === 'completed' || strtolower(trim($booking['assignment_status'] ?? '')) === 'completed') {
                throw new Exception('Cannot cancel an already completed booking.');
            }

            // Avoid duplicate open cancellation logs if the app retries the request.
            $existingLogStmt = $pdo->prepare(" 
                SELECT id
                FROM chc_operator_cancelled_orders
                WHERE BINARY booking_id = BINARY ?
                  AND operator_id = ?
                  AND reassigned_to_operator_id IS NULL
                ORDER BY cancelled_at DESC
                LIMIT 1
            ");
            $existingLogStmt->execute([$bookingId, $operatorId]);
            $existingLog = $existingLogStmt->fetch(PDO::FETCH_ASSOC);

            if (!$existingLog) {
                $logStmt = $pdo->prepare(" 
                    INSERT INTO chc_operator_cancelled_orders
                        (booking_id, operator_id, reason, cancelled_at, created_by)
                    VALUES
                        (?, ?, ?, NOW(), 'operator_app')
                ");
                $logStmt->execute([$bookingId, $operatorId, $cancelReason]);
            }

            // Keep the farmer booking alive, detach only the operator assignment,
            // and save the last operator-cancellation details for dashboard filtering.
            // IMPORTANT: decide status values in PHP, not with SQL LOWER/CASE comparisons.
            // This avoids MySQL "Illegal mix of collations" errors on databases with mixed collations.
            $currentBookingStatusLower = strtolower(trim((string)($booking['booking_status'] ?? '')));
            $safeBookingStatus = in_array($currentBookingStatusLower, ['', 'cancelled', 'canceled'], true)
                ? 'Slot Booked'
                : (string)$booking['booking_status'];
            $safeOperatorNotes = $operatorNotes !== '' ? $operatorNotes : ($booking['operator_notes'] ?? null);

            $updateStmt = $pdo->prepare(" 
                UPDATE chc_bookings
                SET booking_status = ?,
                    assignment_status = ?,
                    assigned_operator_id = NULL,
                    last_cancelled_operator_id = ?,
                    last_operator_cancel_reason = ?,
                    last_operator_cancelled_at = NOW(),
                    operator_notes = ?,
                    updated_at = NOW()
                WHERE BINARY booking_id = BINARY ?
            ");
            $updateStmt->execute([$safeBookingStatus, 'Operator Cancelled', $operatorId, $cancelReason, $safeOperatorNotes, $bookingId]);

            // Free the operator for new work.
            $stmtOp = $pdo->prepare(" 
                UPDATE chc_operators
                SET current_booking_id = NULL,
                    availability = 'Available'
                WHERE operator_id = ?
            ");
            $stmtOp->execute([$operatorId]);

            $pdo->commit();

            $stmtFetch = $pdo->prepare(" 
                SELECT booking_id, booking_status, assignment_status, service_date,
                       rescheduled_date, assigned_operator_id, last_cancelled_operator_id,
                       last_operator_cancel_reason, last_operator_cancelled_at, updated_at
                FROM chc_bookings
                WHERE BINARY booking_id = BINARY ?
            ");
            $stmtFetch->execute([$bookingId]);
            $updatedBooking = $stmtFetch->fetch(PDO::FETCH_ASSOC);

            echo json_encode([
                'success' => true,
                'message' => 'Operator assignment cancelled. Booking is kept active for reassignment.',
                'operator_cancelled' => true,
                'booking' => $updatedBooking
            ]);
            return;
        }

        // 2. Normal non-cancellation status updates.
        $updates = [];
        $params = [];

        if (!empty($bookingStatus)) {
            $updates[] = "booking_status = ?";
            $params[] = $bookingStatus;
        }

        if (!empty($assignmentStatus)) {
            $updates[] = "assignment_status = ?";
            $params[] = $assignmentStatus;
        }

        if ($rescheduledDate !== null) {
            $updates[] = "rescheduled_date = ?";
            $params[] = ($rescheduledDate === '') ? null : $rescheduledDate;
        }

        if ($operatorNotes !== '') {
            $updates[] = "operator_notes = ?";
            $params[] = $operatorNotes;
        }

        $updates[] = "updated_at = NOW()";
        $params[] = $bookingId;

        if (!empty($updates)) {
            $sql = "UPDATE chc_bookings SET " . implode(", ", $updates) . " WHERE BINARY booking_id = BINARY ?";
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
        }

        // 3. Handle operator current_booking_id for non-cancellation updates.
        if ($operatorId) {
            if (strtolower($assignmentStatus) === 'in progress' || strtolower($bookingStatus) === 'in progress') {
                $stmtOp = $pdo->prepare(" 
                    UPDATE chc_operators 
                    SET current_booking_id = ?, 
                        availability = 'Busy'
                    WHERE operator_id = ?
                ");
                $stmtOp->execute([$bookingId, $operatorId]);
            } elseif (in_array(strtolower($assignmentStatus), ['completed'], true) || in_array(strtolower($bookingStatus), ['completed'], true)) {
                $stmtOp = $pdo->prepare(" 
                    UPDATE chc_operators 
                    SET current_booking_id = NULL, 
                        availability = 'Available'
                    WHERE operator_id = ?
                ");
                $stmtOp->execute([$operatorId]);

                $stmtJobs = $pdo->prepare(" 
                    UPDATE chc_operators 
                    SET jobs_completed = jobs_completed + 1 
                    WHERE operator_id = ?
                ");
                $stmtJobs->execute([$operatorId]);
            }
        }

        $pdo->commit();

        $stmtFetch = $pdo->prepare(" 
            SELECT booking_id, booking_status, assignment_status, service_date, 
                   rescheduled_date, assigned_operator_id, updated_at 
            FROM chc_bookings 
            WHERE BINARY booking_id = BINARY ?
        ");
        $stmtFetch->execute([$bookingId]);
        $updatedBooking = $stmtFetch->fetch(PDO::FETCH_ASSOC);

        echo json_encode([
            'success' => true,
            'message' => 'Booking status updated successfully',
            'operator_cancelled' => false,
            'booking' => $updatedBooking
        ]);

    } catch (Exception $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function completeBookingManual($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);

    $operatorId     = $input['operator_id'] ?? '';
    $farmerPhone    = $input['farmer_phone'] ?? '';
    $farmerName     = $input['farmer_name'] ?? '';
    $village        = $input['village'] ?? '';
    $equipment      = $input['equipment_used'] ?? '';
    $equipmentId    = $input['equipment_id'] ?? null;
    $startTime      = $input['start_time'] ?? '';
    $endTime        = $input['end_time'] ?? '';
    $distance       = (float)($input['distance'] ?? 0);
    $serviceDate    = $input['service_date'] ?? '';
    $cropType       = $input['crop_type'] ?? null;
    $landSizeAcres  = (float)($input['land_size_acres'] ?? 0);
    $billedQty      = (float)($input['billed_qty'] ?? 0);
    $unitType       = $input['unit_type'] ?? '';
    $rate           = (float)($input['rate'] ?? 0);
    $notes          = $input['notes'] ?? null;
    $operatorNotes  = $input['operator_notes'] ?? 'Walk-in job logged by operator';
    
    $servicesJson = $input['services'] ?? null;
    $services = $servicesJson ? json_decode($servicesJson, true) : null;
    $totalAmount = 0.0;
    $summaryUnit = $input['unit_type'] ?? 'hour';
    $summaryQty = 0.0;
    
    if ($services && is_array($services) && count($services) > 0) {
        foreach ($services as $svc) {
            $qty = floatval($svc['qty'] ?? 0);
            $svcRate = floatval($svc['rate'] ?? 0);
            $cost = $qty * $svcRate;
            $totalAmount += $cost;
            $summaryQty += $qty;
        }
        $finalAmount = $totalAmount;
    } else {
        $finalAmount = (float)($input['final_amount'] ?? 0);
        $summaryQty = (float)($input['billed_qty'] ?? 0);
    }

    if (empty($operatorId) || empty($farmerPhone) || empty($farmerName) || empty($village) || empty($equipment) || empty($serviceDate)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields']);
        return;
    }

    try {
        $pdo->beginTransaction();

        $stmtOp = $pdo->prepare("SELECT client_code FROM chc_operators WHERE operator_id = ?");
        $stmtOp->execute([$operatorId]);
        $operator = $stmtOp->fetch(PDO::FETCH_ASSOC);
        $clientCode = $operator['client_code'] ?? null;

        $stmtUser = $pdo->prepare("SELECT user_id, card_uid FROM users WHERE user_id = ? OR phone_number = ? LIMIT 1");
        $stmtUser->execute([$farmerPhone, $farmerPhone]);
        $existingUser = $stmtUser->fetch(PDO::FETCH_ASSOC);

        if (!$existingUser) {
            $regionId = null;
            if ($clientCode) {
                $stmtReg = $pdo->prepare("SELECT id FROM regions WHERE client_code = ? LIMIT 1");
                $stmtReg->execute([$clientCode]);
                $regionRow = $stmtReg->fetch(PDO::FETCH_ASSOC);
                $regionId = $regionRow['id'] ?? null;
            }

            $stmtNewUser = $pdo->prepare("
                INSERT INTO users (user_id, name, phone_number, village, client_code, region_id)
                VALUES (?, ?, ?, ?, ?, ?)
            ");
            $stmtNewUser->execute([$farmerPhone, $farmerName, $farmerPhone, $village, $clientCode, $regionId]);
        } else {
            $existingUid = $existingUser['card_uid'] ?? '';
            
            if (empty($existingUid)) {
                $stmtUpdateUser = $pdo->prepare("UPDATE users SET name = ?, village = ?, client_code = ? WHERE user_id = ? OR phone_number = ?");
                $stmtUpdateUser->execute([$farmerName, $village, $clientCode, $farmerPhone, $farmerPhone]);
            } else {
                $stmtUpdateUser = $pdo->prepare("UPDATE users SET name = ?, village = ? WHERE user_id = ? OR phone_number = ?");
                $stmtUpdateUser->execute([$farmerName, $village, $farmerPhone, $farmerPhone]);
            }
        }

        $existingBookingId = $input['booking_id'] ?? null;
        if (!empty($existingBookingId)) {
            $bookingId = $existingBookingId;
            $billingType = $unitType === 'Trip' || $unitType === 'Hour' ? 'Variable' : 'Fixed';
            $stmtBook = $pdo->prepare("
                UPDATE chc_bookings SET 
                    equipment_type = ?, billing_type = ?, crop_type = ?,
                    land_size_acres = ?, billed_qty = ?, unit_type = ?, service_date = ?, rate = ?,
                    total_cost = ?, service_breakdown = ?, notes = ?, booking_status = 'Completed', assignment_status = 'Completed', assigned_operator_id = ?,
                    operator_notes = ?, updated_at = NOW()
                WHERE booking_id = ?
            ");
            $stmtBook->execute([
                $equipment,
                $billingType,
                $cropType,
                $landSizeAcres,
                $summaryQty,
                $summaryUnit,
                $serviceDate,
                ($totalAmount > 0 && $summaryQty > 0) ? ($totalAmount / $summaryQty) : $rate,
                $finalAmount,
                $services ? json_encode($services) : null,
                $notes,
                $operatorId,
                $operatorNotes,
                $bookingId
            ]);
        } else {
            $bookingId = 'WLK-' . strtoupper(substr(md5(uniqid()), 0, 8));
            $billingType = $unitType === 'Trip' || $unitType === 'Hour' ? 'Variable' : 'Fixed';

            $stmtBook = $pdo->prepare("
                INSERT INTO chc_bookings (
                    booking_id, user_id, equipment_type, billing_type, crop_type,
                    land_size_acres, billed_qty, unit_type, service_date, rate,
                    total_cost, service_breakdown, notes, booking_status, assignment_status, assigned_operator_id,
                    operator_notes, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Completed', 'Completed', ?, ?, NOW())
            ");
            $stmtBook->execute([
                $bookingId,
                $farmerPhone,
                $equipment,
                $billingType,
                $cropType,
                $landSizeAcres,
                $summaryQty,
                $summaryUnit,
                $serviceDate,
                ($totalAmount > 0 && $summaryQty > 0) ? ($totalAmount / $summaryQty) : $rate,
                $finalAmount,
                $services ? json_encode($services) : null,
                $notes,
                $operatorId,
                $operatorNotes,
            ]);
        }

        // Update operator status and increment jobs_completed atomically
       // Replace the old operator update with:
$stmtOpUpdate = $pdo->prepare("
    UPDATE chc_operators 
    SET availability = 'Available', 
        current_booking_id = NULL,
        jobs_completed = jobs_completed + 1 
    WHERE operator_id = ?
");
$stmtOpUpdate->execute([$operatorId]);

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'booking_id' => $bookingId,
            'equipment_id' => $equipmentId,
            'distance' => $distance,
            'message' => 'Walk-in job logged successfully'
        ]);
    } catch (PDOException $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// ===================== RETAILER AND EXTENSION OFFICER MODULES =====================

function bindRetailerReferral($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $userId = $input['user_id'] ?? $input['phone_number'] ?? '';
    $referralCode = $input['referral_code'] ?? '';
    
    if (empty($userId) || empty($referralCode)) {
        echo json_encode(['success' => false, 'error' => 'User ID and Referral Code are required']);
        return;
    }
    
    try {
        $stmt = $pdo->prepare("SELECT id FROM retailer_partners WHERE referral_code = ? LIMIT 1");
        $stmt->execute([$referralCode]);
        $retailer = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$retailer) {
            echo json_encode(['success' => false, 'error' => 'Invalid referral code']);
            return;
        }
        
        $updateStmt = $pdo->prepare("UPDATE users SET referred_by_retailer_id = ? WHERE user_id = ? OR phone_number = ?");
        $updateStmt->execute([$retailer['id'], $userId, $userId]);
        
        echo json_encode(['success' => true, 'message' => 'Linked to retailer partner successfully']);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getRetailerDashboard($pdo) {
    $retailerId = $_GET['retailer_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    if (empty($retailerId)) {
        echo json_encode(['success' => false, 'error' => 'Retailer ID is required']);
        return;
    }

    try {
        // Fetch retailer details first
        $stmt = $pdo->prepare("SELECT * FROM retailer_partners WHERE id = ? LIMIT 1");
        $stmt->execute([$retailerId]);
        $retailer = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$retailer) {
            echo json_encode(['success' => false, 'error' => 'Retailer not found']);
            return;
        }

        // 1. Total referred farmers
        $stmtCount = $pdo->prepare("SELECT COUNT(*) as referred_count FROM users WHERE referred_by_retailer_id = ?");
        $stmtCount->execute([$retailerId]);
        $referredCount = $stmtCount->fetch(PDO::FETCH_ASSOC)['referred_count'] ?? 0;

        // 2. Total farmers in coverage area (same mandal/district)
        $stmtArea = $pdo->prepare("
            SELECT COUNT(*) as area_count 
            FROM users 
            WHERE mandal = ? AND district = ?
        ");
        $stmtArea->execute([$retailer['mandal'], $retailer['district']]);
        $areaCount = $stmtArea->fetch(PDO::FETCH_ASSOC)['area_count'] ?? 0;

        $cropNameField = ($lang === 'en') ? 'c.name_en' : (($lang === 'hi') ? 'c.name_hi' : 'c.name');

        // 3. Crops grown this season & acreage (coverage area)
        $stmtCrops = $pdo->prepare("
            SELECT 
                c.id as crop_id, 
                $cropNameField as crop_name, 
                COUNT(ucs.id) as fields_count,
                SUM(COALESCE(ucs.acreage, 1.00)) as total_acreage
            FROM user_crop_selections ucs
            JOIN crops c ON ucs.crop_id = c.id
            JOIN users u ON ucs.user_id = u.user_id
            WHERE u.mandal = ? AND u.district = ?
            GROUP BY c.id, $cropNameField
            ORDER BY total_acreage DESC
        ");
        $stmtCrops->execute([$retailer['mandal'], $retailer['district']]);
        $cropsReferred = $stmtCrops->fetchAll(PDO::FETCH_ASSOC);

        // Fallback 1: Check the entire district (with and without trailing spaces)
        if (empty($cropsReferred)) {
            $stmtCropsDist = $pdo->prepare("
                SELECT 
                    c.id as crop_id, 
                    $cropNameField as crop_name, 
                    COUNT(ucs.id) as fields_count,
                    SUM(COALESCE(ucs.acreage, 1.00)) as total_acreage
                FROM user_crop_selections ucs
                JOIN crops c ON ucs.crop_id = c.id
                JOIN users u ON ucs.user_id = u.user_id
                WHERE TRIM(u.district) = ? OR TRIM(u.district) = ?
                GROUP BY c.id, $cropNameField
                ORDER BY total_acreage DESC
            ");
            $distTrimmed = trim($retailer['district']);
            $stmtCropsDist->execute([$distTrimmed, $distTrimmed . ' ']);
            $cropsReferred = $stmtCropsDist->fetchAll(PDO::FETCH_ASSOC);
        }

        // Fallback 2: Get all crop selections globally
        if (empty($cropsReferred)) {
            $stmtCropsAll = $pdo->prepare("
                SELECT 
                    c.id as crop_id, 
                    $cropNameField as crop_name, 
                    COUNT(ucs.id) as fields_count,
                    SUM(COALESCE(ucs.acreage, 1.00)) as total_acreage
                FROM user_crop_selections ucs
                JOIN crops c ON ucs.crop_id = c.id
                GROUP BY c.id, $cropNameField
                ORDER BY total_acreage DESC
            ");
            $stmtCropsAll->execute();
            $cropsReferred = $stmtCropsAll->fetchAll(PDO::FETCH_ASSOC);
        }

        // 4. Sowing peak timeline (coverage area)
        $stmtSowing = $pdo->prepare("
            SELECT 
                sd.sowing_date, 
                COUNT(ucs.id) as sowing_count
            FROM user_crop_selections ucs
            JOIN sowing_dates sd ON ucs.sowing_date_id = sd.id
            JOIN users u ON ucs.user_id = u.user_id
            WHERE u.mandal = ? AND u.district = ?
            GROUP BY sd.sowing_date
            ORDER BY sd.sowing_date ASC
        ");
        $stmtSowing->execute([$retailer['mandal'], $retailer['district']]);
        $sowingTimeline = $stmtSowing->fetchAll(PDO::FETCH_ASSOC);

        // Fallback 1: Check sowing timeline for the entire district
        if (empty($sowingTimeline)) {
            $stmtSowingDist = $pdo->prepare("
                SELECT 
                    sd.sowing_date, 
                    COUNT(ucs.id) as sowing_count
                FROM user_crop_selections ucs
                JOIN sowing_dates sd ON ucs.sowing_date_id = sd.id
                JOIN users u ON ucs.user_id = u.user_id
                WHERE TRIM(u.district) = ? OR TRIM(u.district) = ?
                GROUP BY sd.sowing_date
                ORDER BY sd.sowing_date ASC
            ");
            $distTrimmed = trim($retailer['district']);
            $stmtSowingDist->execute([$distTrimmed, $distTrimmed . ' ']);
            $sowingTimeline = $stmtSowingDist->fetchAll(PDO::FETCH_ASSOC);
        }

        // Fallback 2: Get all sowing dates globally
        if (empty($sowingTimeline)) {
            $stmtSowingAll = $pdo->prepare("
                SELECT 
                    sd.sowing_date, 
                    COUNT(ucs.id) as sowing_count
                FROM user_crop_selections ucs
                JOIN sowing_dates sd ON ucs.sowing_date_id = sd.id
                GROUP BY sd.sowing_date
                ORDER BY sd.sowing_date ASC
            ");
            $stmtSowingAll->execute();
            $sowingTimeline = $stmtSowingAll->fetchAll(PDO::FETCH_ASSOC);
        }

        echo json_encode([
            'success' => true,
            'retailer' => $retailer,
            'referred_farmers_count' => (int)$referredCount,
            'area_farmers_count' => (int)$areaCount,
            'cultivation_intelligence' => $cropsReferred,
            'sowing_timeline' => $sowingTimeline
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getRetailerLeads($pdo) {
    $retailerId = $_GET['retailer_id'] ?? 0;
    $lang = $_GET['lang'] ?? 'te';
    if (empty($retailerId)) {
        echo json_encode(['success' => false, 'error' => 'Retailer ID is required']);
        return;
    }

    try {
        // Fetch retailer details
        $stmtRet = $pdo->prepare("SELECT * FROM retailer_partners WHERE id = ? LIMIT 1");
        $stmtRet->execute([$retailerId]);
        $retailer = $stmtRet->fetch(PDO::FETCH_ASSOC);
        
        if (!$retailer) {
            echo json_encode(['success' => false, 'error' => 'Retailer not found']);
            return;
        }

        $mandal = $retailer['mandal'];
        $district = $retailer['district'];

        $cropNameField = ($lang === 'en') ? 'c.name_en' : (($lang === 'hi') ? 'c.name_hi' : 'c.name');
        $probNameField = ($lang === 'en') ? 'rp.problem_name_en' : (($lang === 'hi') ? 'rp.problem_name_hi' : 'rp.problem_name_te');

        $sql = "
            SELECT 
                rl.id as lead_id,
                rl.lead_status,
                rl.retailer_notes,
                rl.assigned_at,
                fip.id as problem_report_id,
                u.name as farmer_name,
                u.phone_number as farmer_phone,
                u.village,
                u.mandal,
                $cropNameField as crop_name,
                $probNameField as problem_name,
                fip.created_at as reported_at,
                'LEAD' as source_type,
                rp.id as problem_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM retailer_leads rl
            JOIN farmer_identified_problems fip ON rl.farmer_identified_problem_id = fip.id
            JOIN users u ON fip.user_id = u.user_id
            JOIN rice_problems rp ON fip.problem_id = rp.id
            JOIN crops c ON rp.crop_id = c.id
            WHERE rl.retailer_partner_id = ?

            UNION ALL

            SELECT 
                CONCAT('receipt_', ar.id) as lead_id,
                UPPER(ar.status) as lead_status,
                CONCAT('Receipt: ', ar.receipt_id) as retailer_notes,
                ar.created_at as assigned_at,
                ar.id as problem_report_id,
                u.name as farmer_name,
                u.phone_number as farmer_phone,
                u.village,
                u.mandal,
                $cropNameField as crop_name,
                $probNameField as problem_name,
                ar.created_at as reported_at,
                'RECEIPT' as source_type,
                rp.id as problem_id,
                rp.image_url1,
                rp.image_url2,
                rp.image_url3
            FROM advisory_receipts ar
            JOIN users u ON ar.user_id = u.user_id
            JOIN rice_problems rp ON ar.problem_id = rp.id
            JOIN crops c ON rp.crop_id = c.id
            WHERE u.referred_by_retailer_id = ? 
               OR (u.referred_by_retailer_id IS NULL AND u.mandal = ? AND u.district = ?)
            
            ORDER BY assigned_at DESC
        ";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$retailerId, $retailerId, $mandal, $district]);
        $leads = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(['success' => true, 'leads' => $leads]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function updateLeadStatus($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    $leadId = $input['lead_id'] ?? 0;
    $status = $input['status'] ?? '';
    $notes = $input['notes'] ?? null;

    if (empty($leadId) || empty($status)) {
        echo json_encode(['success' => false, 'error' => 'Lead ID and status are required']);
        return;
    }

    try {
        if (strpos($leadId, 'receipt_') === 0) {
            $realId = (int)str_replace('receipt_', '', $leadId);
            // advisory_receipts status enum: 'New', 'Contacted', 'Resolved'
            $dbStatus = 'New';
            if (strcasecmp($status, 'CONTACTED') === 0 || strcasecmp($status, 'VISITED') === 0) {
                $dbStatus = 'Contacted';
            } else if (strcasecmp($status, 'RESOLVED') === 0 || strcasecmp($status, 'CLOSED') === 0) {
                $dbStatus = 'Resolved';
            }

            $stmt = $pdo->prepare("UPDATE advisory_receipts SET status = ? WHERE id = ?");
            $stmt->execute([$dbStatus, $realId]);
            echo json_encode(['success' => true, 'message' => 'Receipt status updated successfully']);
        } else {
            $validStatuses = ['NEW', 'CONTACTED', 'VISITED', 'RESOLVED', 'CLOSED'];
            if (!in_array($status, $validStatuses)) {
                echo json_encode(['success' => false, 'error' => 'Invalid status value']);
                return;
            }

            $stmt = $pdo->prepare("
                UPDATE retailer_leads 
                SET lead_status = ?, retailer_notes = COALESCE(?, retailer_notes), updated_at = NOW() 
                WHERE id = ?
            ");
            $stmt->execute([$status, $notes, $leadId]);
            echo json_encode(['success' => true, 'message' => 'Lead status updated successfully']);
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getExtensionDashboard($pdo) {
    $officerId = $_GET['officer_id'] ?? 0;
    if (empty($officerId)) {
        echo json_encode(['success' => false, 'error' => 'Extension Officer ID is required']);
        return;
    }

    try {
        // Fetch officer details
        $stmt = $pdo->prepare("SELECT * FROM extension_officers WHERE id = ? LIMIT 1");
        $stmt->execute([$officerId]);
        $officer = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$officer) {
            echo json_encode(['success' => false, 'error' => 'Extension Officer not found']);
            return;
        }

        $mandal = $officer['coverage_mandal'];
        $district = $officer['coverage_district'];

        // 1. Total farmers in coverage area
        $stmtCount = $pdo->prepare("SELECT COUNT(*) as total_farmers FROM users WHERE mandal = ? AND district = ?");
        $stmtCount->execute([$mandal, $district]);
        $totalFarmers = $stmtCount->fetch(PDO::FETCH_ASSOC)['total_farmers'] ?? 0;

        // 2. Total cultivation acreage by crop in mandal
        $stmtCrops = $pdo->prepare("
            SELECT 
                c.id as crop_id, 
                c.name_en as crop_name, 
                COUNT(ucs.id) as fields_count,
                SUM(COALESCE(ucs.acreage, 1.00)) as total_acreage
            FROM user_crop_selections ucs
            JOIN crops c ON ucs.crop_id = c.id
            JOIN users u ON ucs.user_id = u.user_id
            WHERE u.mandal = ? AND u.district = ?
            GROUP BY c.id, c.name_en
            ORDER BY total_acreage DESC
        ");
        $stmtCrops->execute([$mandal, $district]);
        $cropStats = $stmtCrops->fetchAll(PDO::FETCH_ASSOC);

        // 3. Sowing progress details
        $stmtSowing = $pdo->prepare("
            SELECT 
                sd.sowing_date, 
                COUNT(ucs.id) as count
            FROM user_crop_selections ucs
            JOIN sowing_dates sd ON ucs.sowing_date_id = sd.id
            JOIN users u ON ucs.user_id = u.user_id
            WHERE u.mandal = ? AND u.district = ?
            GROUP BY sd.sowing_date
            ORDER BY sd.sowing_date ASC
        ");
        $stmtSowing->execute([$mandal, $district]);
        $sowingProgress = $stmtSowing->fetchAll(PDO::FETCH_ASSOC);

        // 4. Disease reports count (active/recent problems in coverage mandal from BOTH tables)
        $stmtProblems = $pdo->prepare("
            SELECT 
                problem_name,
                crop_name,
                COUNT(*) as cases_count
            FROM (
                SELECT rp.problem_name_en as problem_name, c.name_en as crop_name
                FROM farmer_identified_problems fip
                JOIN users u ON fip.user_id = u.user_id
                JOIN rice_problems rp ON fip.problem_id = rp.id
                JOIN crops c ON rp.crop_id = c.id
                WHERE u.mandal = ? AND u.district = ?
                
                UNION ALL
                
                SELECT rp.problem_name_en as problem_name, c.name_en as crop_name
                FROM advisory_receipts ar
                JOIN users u ON ar.user_id = u.user_id
                JOIN rice_problems rp ON ar.problem_id = rp.id
                JOIN crops c ON rp.crop_id = c.id
                WHERE u.mandal = ? AND u.district = ?
            ) combined
            GROUP BY problem_name, crop_name
            ORDER BY cases_count DESC
        ");
        $stmtProblems->execute([$mandal, $district, $mandal, $district]);
        $diseaseReports = $stmtProblems->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            'success' => true,
            'officer' => $officer,
            'total_farmers' => (int)$totalFarmers,
            'crop_cultivation' => $cropStats,
            'sowing_progress' => $sowingProgress,
            'disease_reports' => $diseaseReports
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getActiveOutbreaks($pdo) {
    $district = $_GET['district'] ?? null;
    $mandal = $_GET['mandal'] ?? null;

    try {
        // Run Early Warning analysis on-the-fly to detect new outbreaks
        // We look for problems where >= 3 farmers reported it in the same mandal/district within the last 15 days
        $analysisQuery = "
            SELECT 
                crop_id,
                problem_id,
                district,
                mandal,
                COUNT(*) as reports_count
            FROM (
                SELECT rp.crop_id, fip.problem_id, u.district, u.mandal
                FROM farmer_identified_problems fip
                JOIN users u ON fip.user_id = u.user_id
                JOIN rice_problems rp ON fip.problem_id = rp.id
                WHERE fip.created_at >= DATE_SUB(NOW(), INTERVAL 15 DAY)
                
                UNION ALL
                
                SELECT rp.crop_id, ar.problem_id, u.district, u.mandal
                FROM advisory_receipts ar
                JOIN users u ON ar.user_id = u.user_id
                JOIN rice_problems rp ON ar.problem_id = rp.id
                WHERE ar.created_at >= DATE_SUB(NOW(), INTERVAL 15 DAY)
            ) combined
            GROUP BY crop_id, problem_id, district, mandal
            HAVING reports_count >= 3
        ";
        $analysisStmt = $pdo->prepare($analysisQuery);
        $analysisStmt->execute();
        $potentialOutbreaks = $analysisStmt->fetchAll(PDO::FETCH_ASSOC);

        // For each potential outbreak, upsert it into outbreak_alerts table
        foreach ($potentialOutbreaks as $outbreak) {
            // Check if active alert already exists
            $checkStmt = $pdo->prepare("
                SELECT id FROM outbreak_alerts 
                WHERE crop_id = ? AND problem_id = ? AND district = ? AND mandal = ? AND outbreak_status != 'RESOLVED'
                LIMIT 1
            ");
            $checkStmt->execute([$outbreak['crop_id'], $outbreak['problem_id'], $outbreak['district'], $outbreak['mandal']]);
            $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);

            if ($existing) {
                // Update count
                $updateStmt = $pdo->prepare("UPDATE outbreak_alerts SET reports_count = ? WHERE id = ?");
                $updateStmt->execute([$outbreak['reports_count'], $existing['id']]);
            } else {
                // Insert new alert
                $insertStmt = $pdo->prepare("
                    INSERT INTO outbreak_alerts (crop_id, problem_id, district, mandal, reports_count, outbreak_status, triggered_at)
                    VALUES (?, ?, ?, ?, ?, 'DETECTED', NOW())
                ");
                $insertStmt->execute([
                    $outbreak['crop_id'],
                    $outbreak['problem_id'],
                    $outbreak['district'],
                    $outbreak['mandal'],
                    $outbreak['reports_count']
                ]);
            }
        }

        // Fetch active outbreaks
        $sql = "
            SELECT 
                oa.id as alert_id,
                c.name_en as crop_name,
                rp.problem_name_en as problem_name,
                oa.district,
                oa.mandal,
                oa.outbreak_status,
                oa.reports_count,
                oa.triggered_at
            FROM outbreak_alerts oa
            JOIN crops c ON oa.crop_id = c.id
            JOIN rice_problems rp ON oa.problem_id = rp.id
            WHERE oa.outbreak_status != 'RESOLVED'
        ";
        
        $params = [];
        if ($district) {
            $sql .= " AND oa.district = ?";
            $params[] = $district;
        }
        if ($mandal) {
            $sql .= " AND oa.mandal = ?";
            $params[] = $mandal;
        }
        $sql .= " ORDER BY oa.reports_count DESC, oa.triggered_at DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $alerts = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(['success' => true, 'outbreaks' => $alerts]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

