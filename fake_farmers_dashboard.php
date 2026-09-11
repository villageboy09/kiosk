<?php
/**
 * CropSync - Fake Farmers Management Hub (Hyderabad Region Exclusive)
 * 
 * Production-grade dashboard to manage fake farmer accounts for testing, demonstrations,
 * and regional activity simulation strictly scoped to the HYDERABAD region.
 * 
 * Features:
 * - Scoped exclusively to Hyderabad region / district / HYD001 client code.
 * - Tab 1: Fake Accounts (is_fake = 1)
 * - Tab 2: All Hyderabad Farmers (with 1-click fake/genuine toggle)
 * - Add Fake Farmer with 1-click 10-digit phone generator & curated realistic avatar presets
 * - Batch Quick Generator (instantly generate 1-10 realistic Hyderabad fake accounts)
 * - Edit farmer details, location, phone, and verification status
 * - Toggle verification and fake status via AJAX
 * - Zero native browser popups (confirm/alert) - 100% custom Alpine.js modal & toast stack
 * - Drag-and-drop avatar upload with progress indicator
 * - Seamless cross-navigation links to News & Reels Studio and Seeds & Shop Catalog
 * 
 * Typography: Google Sans, Noto Sans Telugu & Devanagari
 * Icons: Phosphor Icons
 * Framework: Alpine.js
 */

session_start();

// -------------------------------------------------------------
// 1. Database Connection & Setup
// -------------------------------------------------------------
$configPaths = [
    __DIR__ . '/config.php',
    __DIR__ . '/api/config.php',
    __DIR__ . '/../config.php',
    dirname(__DIR__) . '/config.php',
];

foreach ($configPaths as $cp) {
    if (file_exists($cp)) {
        require_once $cp;
        break;
    }
}

if (!isset($pdo) || !($pdo instanceof PDO)) {
    $servername = isset($servername) ? $servername : "127.0.0.1";
    $username   = isset($username) ? $username : "u893187665_arjun";
    $password   = isset($password) ? $password : "CropSync@2024";
    $dbname     = isset($dbname) ? $dbname : "u893187665_kiosk";

    try {
        $dsn = "mysql:host=$servername;dbname=$dbname;charset=utf8mb4";
        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
        $pdo->exec("SET time_zone = '+05:30'");
    } catch (PDOException $e) {
        $dbError = $e->getMessage();
    }
}

// Ensure schema columns exist (Gated by lockfile for high speed)
$schemaLockFile = __DIR__ . '/.fake_farmers_schema_migrated_v1';
if (isset($pdo) && $pdo instanceof PDO && (!file_exists($schemaLockFile) || isset($_GET['recheck_schema']))) {
    try {
        $pdo->exec("SET NAMES utf8mb4");

        // 1. Add is_fake column to users table if missing
        try {
            $chkFake = $pdo->query("SHOW COLUMNS FROM `users` LIKE 'is_fake'");
            if (!$chkFake || !$chkFake->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_fake` TINYINT(1) NOT NULL DEFAULT 0");
                $pdo->exec("ALTER TABLE `users` ADD INDEX `idx_users_is_fake` (`is_fake`)");
            }
        } catch (Throwable $e) {}

        // 2. Add is_verified column if missing
        try {
            $chkVer = $pdo->query("SHOW COLUMNS FROM `users` LIKE 'is_verified'");
            if (!$chkVer || !$chkVer->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_verified` TINYINT(1) NOT NULL DEFAULT 1");
            }
        } catch (Throwable $e) {}

        // 3. Add is_deleted column if missing
        try {
            $chkDel = $pdo->query("SHOW COLUMNS FROM `users` LIKE 'is_deleted'");
            if (!$chkDel || !$chkDel->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_deleted` TINYINT(1) NOT NULL DEFAULT 0");
            }
        } catch (Throwable $e) {}

        // 4. Add role & membership_type columns if missing
        try {
            $chkRole = $pdo->query("SHOW COLUMNS FROM `users` LIKE 'role'");
            if (!$chkRole || !$chkRole->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `role` VARCHAR(50) NOT NULL DEFAULT 'farmer'");
                $pdo->exec("ALTER TABLE `users` ADD INDEX `idx_users_role` (`role`)");
            }
        } catch (Throwable $e) {}

        try {
            $chkMem = $pdo->query("SHOW COLUMNS FROM `users` LIKE 'membership_type'");
            if (!$chkMem || !$chkMem->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `membership_type` VARCHAR(50) NOT NULL DEFAULT 'Farmer'");
            }
        } catch (Throwable $e) {}

        @file_put_contents($schemaLockFile, date('Y-m-d H:i:s'));
    } catch (Throwable $e) {}
}

// -------------------------------------------------------------
// 2. Helpers & Pools (Hyderabad Specifics)
// -------------------------------------------------------------
$HYD_MANDALS = [
    'Secunderabad', 'Khairatabad', 'Amberpet', 'Charminar',
    'Musheerabad', 'Bahadurpura', 'Asif Nagar', 'Bandlaguda',
    'Golconda', 'Himayatnagar', 'Nampally', 'Shaikpet',
    'Saidabad', 'Ameerpet', 'Serilingampally', 'Malkajgiri',
    'Uppal', 'Rajendranagar', 'Quthbullapur', 'Alwal'
];

$HYD_VILLAGES = [
    'Gachibowli', 'Madhapur', 'Kukatpally', 'Mehdipatnam',
    'Begumpet', 'Ameerpet', 'Jubilee Hills', 'Banjara Hills',
    'Dilsukhnagar', 'Malakpet', 'Chandrayangutta', 'Falaknuma',
    'Tarnaka', 'Miyapur', 'Kondapur', 'Santoshnagar',
    'Bowenpally', 'Balanagar', 'Attapur', 'Hayathnagar'
];

$AVATAR_PRESETS = [
    'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=250&q=80',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=250&q=80',
];

$NAME_POOL = [
    'Malla Reddy', 'Venkat Ramana', 'Laxmaiah Goud', 'Srinivasa Rao',
    'Prabhakar Reddy', 'Balaraju Kuruma', 'Narsimha Chary', 'Chandraiah Yadav',
    'Koteswara Rao', 'Anjaneyulu Nayak', 'Ravinder Reddy', 'Gangadhar Rao',
    'Shobhan Babu', 'Satyanarayana Murthy', 'Mallikarjun Goud', 'Sujatha Devi',
    'Lakshmi Bai', 'Radha Krishna', 'Venkateshwarlu', 'Thirupathi Reddy',
    'Kishore Kumar', 'Ramesh Chandra', 'Sanjeeva Reddy', 'Bhikshapathi'
];

function generateRealisticIndianPhone() {
    $prefixes = ['9848', '9989', '9440', '9866', '9701', '8978', '7799', '9100', '6300', '8008'];
    $prefix = $prefixes[array_rand($prefixes)];
    $suffix = str_pad((string)rand(100000, 999999), 6, '0', STR_PAD_LEFT);
    return $prefix . substr($suffix, 0, 6);
}

function uploadFarmerAvatarFile($fileInputName, $subfolder = 'profile_images') {
    $allowed = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    $targetDir = __DIR__ . '/' . trim($subfolder, '/') . '/';
    if (!is_dir($targetDir)) {
        @mkdir($targetDir, 0777, true);
    }

    if (isset($_FILES[$fileInputName]) && $_FILES[$fileInputName]['error'] === UPLOAD_ERR_OK) {
        $ext = strtolower(pathinfo($_FILES[$fileInputName]['name'], PATHINFO_EXTENSION));
        if (in_array($ext, $allowed)) {
            $fileName = 'farmer_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES[$fileInputName]['tmp_name'], $targetDir . $fileName)) {
                return 'https://kiosk.cropsync.in/' . trim($subfolder, '/') . '/' . $fileName;
            }
        }
    }
    return null;
}

// -------------------------------------------------------------
// 3. AJAX Endpoints
// -------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['ajax_upload'])) {
    header('Content-Type: application/json');
    $url = uploadFarmerAvatarFile('file', 'profile_images');
    if (!empty($url)) {
        echo json_encode(['success' => true, 'url' => $url]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Upload failed or unsupported image format.']);
    }
    exit();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['ajax_action'])) {
    header('Content-Type: application/json');
    $ajaxAction = $_POST['ajax_action'];

    try {
        if ($ajaxAction === 'toggle_fake') {
            $userId = trim($_POST['user_id'] ?? '');
            $newFake = intval($_POST['is_fake'] ?? 0);
            if (!empty($userId)) {
                $stmt = $pdo->prepare("UPDATE users SET is_fake = ? WHERE user_id = ?");
                $stmt->execute([$newFake, $userId]);
                echo json_encode(['success' => true, 'user_id' => $userId, 'is_fake' => $newFake]);
            } else {
                echo json_encode(['success' => false, 'error' => 'Missing user ID.']);
            }
            exit();
        }

        if ($ajaxAction === 'toggle_verified') {
            $userId = trim($_POST['user_id'] ?? '');
            $newVer = intval($_POST['is_verified'] ?? 0);
            if (!empty($userId)) {
                $stmt = $pdo->prepare("UPDATE users SET is_verified = ? WHERE user_id = ?");
                $stmt->execute([$newVer, $userId]);
                echo json_encode(['success' => true, 'user_id' => $userId, 'is_verified' => $newVer]);
            } else {
                echo json_encode(['success' => false, 'error' => 'Missing user ID.']);
            }
            exit();
        }

        if ($ajaxAction === 'delete_farmer') {
            $userId = trim($_POST['user_id'] ?? '');
            if (!empty($userId)) {
                // Soft delete to protect relational bookings/orders, or delete
                $stmt = $pdo->prepare("UPDATE users SET is_deleted = 1 WHERE user_id = ?");
                $stmt->execute([$userId]);
                echo json_encode(['success' => true, 'user_id' => $userId]);
            } else {
                echo json_encode(['success' => false, 'error' => 'Missing user ID.']);
            }
            exit();
        }

        if ($ajaxAction === 'quick_generate') {
            $count = max(1, min(20, intval($_POST['count'] ?? 5)));
            $created = 0;

            for ($i = 0; $i < $count; $i++) {
                $name = $NAME_POOL[array_rand($NAME_POOL)];
                $phone = generateRealisticIndianPhone();
                $mandal = $HYD_MANDALS[array_rand($HYD_MANDALS)];
                $village = $HYD_VILLAGES[array_rand($HYD_VILLAGES)];
                $avatar = $AVATAR_PRESETS[array_rand($AVATAR_PRESETS)];

                // Check uniqueness of phone / user_id
                $chk = $pdo->prepare("SELECT user_id FROM users WHERE user_id = ? OR phone_number = ? LIMIT 1");
                $chk->execute([$phone, $phone]);
                if ($chk->fetch()) {
                    $phone = generateRealisticIndianPhone();
                }

                $stmt = $pdo->prepare("
                    INSERT INTO users (
                        user_id, name, phone_number, region, district, mandal, village,
                        client_code, region_id, role, membership_type, profile_image_url,
                        is_verified, is_fake, is_deleted, created_at
                    ) VALUES (
                        ?, ?, ?, 'Hyderabad', 'Hyderabad', ?, ?,
                        'HYD001', 1, 'farmer', 'Farmer', ?,
                        1, 1, 0, NOW()
                    )
                ");
                $stmt->execute([$phone, $name, $phone, $mandal, $village, $avatar]);
                $created++;
            }

            echo json_encode(['success' => true, 'created_count' => $created]);
            exit();
        }

        if ($ajaxAction === 'bulk_toggle_fake') {
            $userIds = json_decode($_POST['user_ids'] ?? '[]', true);
            $newFake = intval($_POST['is_fake'] ?? 0);
            if (is_array($userIds) && count($userIds) > 0) {
                $placeholders = implode(',', array_fill(0, count($userIds), '?'));
                $params = array_merge([$newFake], $userIds);
                $stmt = $pdo->prepare("UPDATE users SET is_fake = ? WHERE user_id IN ($placeholders)");
                $stmt->execute($params);
                echo json_encode(['success' => true, 'updated_count' => count($userIds)]);
            } else {
                echo json_encode(['success' => false, 'error' => 'No users selected.']);
            }
            exit();
        }

        if ($ajaxAction === 'bulk_toggle_verified') {
            $userIds = json_decode($_POST['user_ids'] ?? '[]', true);
            $newVer = intval($_POST['is_verified'] ?? 0);
            if (is_array($userIds) && count($userIds) > 0) {
                $placeholders = implode(',', array_fill(0, count($userIds), '?'));
                $params = array_merge([$newVer], $userIds);
                $stmt = $pdo->prepare("UPDATE users SET is_verified = ? WHERE user_id IN ($placeholders)");
                $stmt->execute($params);
                echo json_encode(['success' => true, 'updated_count' => count($userIds)]);
            } else {
                echo json_encode(['success' => false, 'error' => 'No users selected.']);
            }
            exit();
        }

        if ($ajaxAction === 'bulk_delete') {
            $userIds = json_decode($_POST['user_ids'] ?? '[]', true);
            if (is_array($userIds) && count($userIds) > 0) {
                $placeholders = implode(',', array_fill(0, count($userIds), '?'));
                $stmt = $pdo->prepare("UPDATE users SET is_deleted = 1 WHERE user_id IN ($placeholders)");
                $stmt->execute($userIds);
                echo json_encode(['success' => true, 'deleted_count' => count($userIds)]);
            } else {
                echo json_encode(['success' => false, 'error' => 'No users selected.']);
            }
            exit();
        }

    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        exit();
    }
}

// -------------------------------------------------------------
// 4. Standard Form POST Actions (Add / Edit)
// -------------------------------------------------------------
$formMessage = null;
$formMessageType = 'info';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($_POST['ajax_action']) && !isset($_GET['ajax_upload'])) {
    $action = $_POST['action'] ?? '';

    if ($action === 'create_farmer') {
        $name = trim($_POST['name'] ?? '');
        $phone = trim($_POST['phone_number'] ?? '');
        $mandal = trim($_POST['mandal'] ?? 'Khairatabad');
        $village = trim($_POST['village'] ?? 'Hyderabad');
        $isVerified = isset($_POST['is_verified']) ? intval($_POST['is_verified']) : 1;
        $profileImageUrl = trim($_POST['profile_image_url'] ?? '');

        // Upload new file if provided
        $uploadedUrl = uploadFarmerAvatarFile('avatar_file', 'profile_images');
        if (!empty($uploadedUrl)) {
            $profileImageUrl = $uploadedUrl;
        }
        if (empty($profileImageUrl)) {
            $profileImageUrl = $AVATAR_PRESETS[array_rand($AVATAR_PRESETS)];
        }

        // Auto-generate phone if left blank
        if (empty($phone)) {
            $phone = generateRealisticIndianPhone();
        }
        $userId = $phone;

        try {
            // Check if phone or user_id exists
            $chk = $pdo->prepare("SELECT user_id FROM users WHERE user_id = ? OR phone_number = ? LIMIT 1");
            $chk->execute([$userId, $phone]);
            if ($chk->fetch()) {
                $formMessage = "A user account with phone/ID {$phone} already exists.";
                $formMessageType = 'danger';
            } else {
                $stmt = $pdo->prepare("
                    INSERT INTO users (
                        user_id, name, phone_number, region, district, mandal, village,
                        client_code, region_id, role, membership_type, profile_image_url,
                        is_verified, is_fake, is_deleted, created_at
                    ) VALUES (
                        ?, ?, ?, 'Hyderabad', 'Hyderabad', ?, ?,
                        'HYD001', 1, 'farmer', 'Farmer', ?,
                        ?, 1, 0, NOW()
                    )
                ");
                $stmt->execute([$userId, $name, $phone, $mandal, $village, $profileImageUrl, $isVerified]);
                $formMessage = "Fake farmer '{$name}' created successfully in Hyderabad region!";
                $formMessageType = 'success';
            }
        } catch (Throwable $e) {
            $formMessage = "Database error: " . $e->getMessage();
            $formMessageType = 'danger';
        }
    }

    if ($action === 'edit_farmer') {
        $userId = trim($_POST['user_id'] ?? '');
        $name = trim($_POST['name'] ?? '');
        $phone = trim($_POST['phone_number'] ?? '');
        $mandal = trim($_POST['mandal'] ?? '');
        $village = trim($_POST['village'] ?? '');
        $isVerified = isset($_POST['is_verified']) ? intval($_POST['is_verified']) : 0;
        $isFake = isset($_POST['is_fake']) ? intval($_POST['is_fake']) : 1;
        $profileImageUrl = trim($_POST['profile_image_url'] ?? '');

        $uploadedUrl = uploadFarmerAvatarFile('avatar_file', 'profile_images');
        if (!empty($uploadedUrl)) {
            $profileImageUrl = $uploadedUrl;
        }

        try {
            $stmt = $pdo->prepare("
                UPDATE users SET
                    name = ?,
                    phone_number = ?,
                    mandal = ?,
                    village = ?,
                    profile_image_url = ?,
                    is_verified = ?,
                    is_fake = ?
                WHERE user_id = ?
            ");
            $stmt->execute([$name, $phone, $mandal, $village, $profileImageUrl, $isVerified, $isFake, $userId]);
            $formMessage = "Farmer profile for '{$name}' updated successfully!";
            $formMessageType = 'success';
        } catch (Throwable $e) {
            $formMessage = "Update failed: " . $e->getMessage();
            $formMessageType = 'danger';
        }
    }
}

// -------------------------------------------------------------
// 5. Querying Hyderabad Farmers Exclusively
// -------------------------------------------------------------
$activeTab = $_GET['tab'] ?? 'fake';
$searchQuery = trim($_GET['q'] ?? '');
$statusFilter = trim($_GET['status'] ?? 'all'); // all, verified, unverified

// Base WHERE condition: Strictly Hyderabad farmers
$hydCondition = "
    (
        LOWER(TRIM(COALESCE(u.region, ''))) = 'hyderabad'
        OR LOWER(TRIM(COALESCE(u.district, ''))) = 'hyderabad'
        OR u.region = 'HYD001'
        OR u.region_id = 1
        OR LOWER(TRIM(COALESCE(r.region_name, ''))) = 'hyderabad'
    )
    AND (u.role = 'farmer' OR u.role IS NULL OR u.role = '' OR u.membership_type = 'Farmer')
    AND (u.is_deleted = 0 OR u.is_deleted IS NULL)
";

// KPI Stats Query
$stats = [
    'total_fake'     => 0,
    'verified_fake'  => 0,
    'unverified_fake'=> 0,
    'total_genuine'  => 0,
    'total_hyd'      => 0
];

try {
    $statSql = "
        SELECT 
            COUNT(CASE WHEN u.is_fake = 1 THEN 1 END) AS total_fake,
            COUNT(CASE WHEN u.is_fake = 1 AND u.is_verified = 1 THEN 1 END) AS verified_fake,
            COUNT(CASE WHEN u.is_fake = 1 AND (u.is_verified = 0 OR u.is_verified IS NULL) THEN 1 END) AS unverified_fake,
            COUNT(CASE WHEN (u.is_fake = 0 OR u.is_fake IS NULL) THEN 1 END) AS total_genuine,
            COUNT(*) AS total_hyd
        FROM users u
        LEFT JOIN regions r ON (u.region_id = r.id OR u.region = r.region_name OR u.client_code = r.client_code)
        WHERE $hydCondition
    ";
    $statsStmt = $pdo->query($statSql);
    if ($sRow = $statsStmt->fetch(PDO::FETCH_ASSOC)) {
        $stats = [
            'total_fake'     => intval($sRow['total_fake']),
            'verified_fake'  => intval($sRow['verified_fake']),
            'unverified_fake'=> intval($sRow['unverified_fake']),
            'total_genuine'  => intval($sRow['total_genuine']),
            'total_hyd'      => intval($sRow['total_hyd'])
        ];
    }
} catch (Throwable $e) {}

// Main Farmers Listing Query
$whereClauses = [$hydCondition];
$queryParams = [];

if ($activeTab === 'fake') {
    $whereClauses[] = "u.is_fake = 1";
}

if (!empty($searchQuery)) {
    $whereClauses[] = "(u.name LIKE ? OR u.phone_number LIKE ? OR u.user_id LIKE ? OR u.mandal LIKE ? OR u.village LIKE ?)";
    $kw = "%$searchQuery%";
    $queryParams = array_merge($queryParams, [$kw, $kw, $kw, $kw, $kw]);
}

if ($statusFilter === 'verified') {
    $whereClauses[] = "u.is_verified = 1";
} elseif ($statusFilter === 'unverified') {
    $whereClauses[] = "(u.is_verified = 0 OR u.is_verified IS NULL)";
}

$whereSql = implode(" AND ", $whereClauses);

$farmers = [];
try {
    $listSql = "
        SELECT 
            u.*,
            COALESCE(r.region_name, u.region, 'Hyderabad') AS resolved_region_name
        FROM users u
        LEFT JOIN regions r ON (u.region_id = r.id OR u.region = r.region_name OR u.client_code = r.client_code)
        WHERE $whereSql
        ORDER BY u.created_at DESC
        LIMIT 250
    ";
    $listStmt = $pdo->prepare($listSql);
    $listStmt->execute($queryParams);
    $farmers = $listStmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    $dbError = $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fake Farmers Hub (Hyderabad) - CropSync Management</title>
    
    <!-- Google Sans & Noto Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Google+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Noto+Sans+Telugu:wght@400;500;600;700&display=swap" rel="stylesheet">
    
    <!-- Phosphor Icons -->
    <script src="https://unpkg.com/@phosphor-icons/web@2.1.1"></script>

    <!-- Alpine.js -->
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>

    <style>
        [x-cloak] { display: none !important; }

        :root {
            --font-family: 'Google Sans', 'Noto Sans Telugu', -apple-system, BlinkMacSystemFont, sans-serif;
            --bg: #f8fafc;
            --surface: #ffffff;
            --surface-subtle: #f1f5f9;
            --surface-hover: #f8fafc;
            --border: #e2e8f0;
            --border-light: #edf2f7;

            --text-primary: #0f172a;
            --text-secondary: #475569;
            --text-muted: #94a3b8;

            --primary: #16a34a;
            --primary-dark: #15803d;
            --primary-light: #f0fdf4;
            --primary-ring: rgba(22, 163, 74, 0.2);

            --accent: #2563eb;
            --accent-light: #eff6ff;

            --amber: #d97706;
            --amber-light: #fef3c7;

            --danger: #dc2626;
            --danger-light: #fef2f2;

            --purple: #7c3aed;
            --purple-light: #f5f3ff;

            --radius-sm: 6px;
            --radius-md: 10px;
            --radius-lg: 14px;
            --radius-pill: 9999px;

            --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.04);
            --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.07), 0 2px 4px -1px rgba(0, 0, 0, 0.04);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.08), 0 4px 6px -2px rgba(0, 0, 0, 0.03);
            --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: var(--font-family);
            background-color: var(--bg);
            color: var(--text-primary);
            -webkit-font-smoothing: antialiased;
            min-height: 100vh;
        }

        /* 1. APP HEADER */
        .app-header {
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            position: sticky;
            top: 0;
            z-index: 50;
            padding: 12px 28px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            box-shadow: var(--shadow-sm);
        }

        .header-brand {
            display: flex;
            align-items: center;
            gap: 12px;
            text-decoration: none;
            color: inherit;
        }

        .brand-icon {
            width: 40px;
            height: 40px;
            background: linear-gradient(135deg, #16a34a, #059669);
            color: white;
            border-radius: var(--radius-md);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.35rem;
            box-shadow: 0 2px 8px rgba(22, 163, 74, 0.3);
        }

        .brand-text h1 {
            font-size: 1.15rem;
            font-weight: 700;
            letter-spacing: -0.01em;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .brand-badge {
            font-size: 0.7rem;
            font-weight: 600;
            padding: 2px 8px;
            border-radius: var(--radius-pill);
            background: var(--amber-light);
            color: var(--amber);
            border: 1px solid rgba(217, 119, 6, 0.3);
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }

        .brand-region-badge {
            font-size: 0.72rem;
            font-weight: 700;
            padding: 3px 9px;
            border-radius: var(--radius-pill);
            background: #e0f2fe;
            color: #0369a1;
            border: 1px solid #bae6fd;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }

        .header-actions {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .btn-header {
            display: inline-flex;
            align-items: center;
            gap: 7px;
            padding: 8px 14px;
            font-size: 0.85rem;
            font-weight: 600;
            border-radius: var(--radius-md);
            text-decoration: none;
            color: var(--text-secondary);
            background: var(--surface-subtle);
            border: 1px solid var(--border);
            transition: all 0.15s ease;
            cursor: pointer;
        }

        .btn-header:hover {
            color: var(--text-primary);
            background: #e2e8f0;
            border-color: #cbd5e1;
        }

        .btn-header-primary {
            background: var(--primary);
            color: white;
            border-color: var(--primary-dark);
            box-shadow: 0 2px 6px rgba(22, 163, 74, 0.25);
        }

        .btn-header-primary:hover {
            background: var(--primary-dark);
            color: white;
        }

        /* 2. KPI / STATS BAR */
        .kpi-section {
            padding: 20px 28px 10px;
        }

        .kpi-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
        }

        .kpi-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius-lg);
            padding: 16px 20px;
            box-shadow: var(--shadow-sm);
            display: flex;
            flex-direction: column;
            gap: 6px;
            position: relative;
            overflow: hidden;
            transition: transform 0.15s ease, box-shadow 0.15s ease;
        }

        .kpi-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }

        .kpi-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: transparent;
        }

        .kpi-card.kpi-amber::before { background: var(--amber); }
        .kpi-card.kpi-green::before { background: var(--primary); }
        .kpi-card.kpi-gray::before { background: #94a3b8; }
        .kpi-card.kpi-blue::before { background: var(--accent); }

        .kpi-title {
            font-size: 0.8rem;
            font-weight: 600;
            color: var(--text-secondary);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .kpi-value {
            font-size: 1.65rem;
            font-weight: 700;
            color: var(--text-primary);
            letter-spacing: -0.02em;
        }

        .kpi-sub {
            font-size: 0.75rem;
            color: var(--text-secondary);
        }

        /* NAVIGATION TABS */
        .nav-tabs-bar {
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            padding: 0 28px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 24px;
        }

        .tabs-group {
            display: flex;
            gap: 20px;
        }

        .tab-link {
            padding: 14px 2px;
            font-size: 0.9rem;
            font-weight: 500;
            color: var(--text-secondary);
            text-decoration: none;
            border-bottom: 2px solid transparent;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            white-space: nowrap;
            transition: all 0.15s ease;
        }

        .tab-link:hover { color: var(--text-primary); }

        .tab-link.active {
            color: var(--primary-dark);
            font-weight: 700;
            border-bottom-color: var(--primary);
        }

        .tab-counter {
            font-size: 0.72rem;
            font-weight: 700;
            background: var(--surface-subtle);
            color: var(--text-secondary);
            padding: 2px 8px;
            border-radius: var(--radius-pill);
            border: 1px solid var(--border);
        }

        .tab-link.active .tab-counter {
            background: var(--primary-light);
            color: var(--primary-dark);
            border-color: rgba(22, 163, 74, 0.2);
        }

        .tab-action-btns {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        /* MAIN CONTENT AREA */
        .content-area {
            padding: 20px 28px 40px;
        }

        /* TOOLBAR */
        .toolbar-panel {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius-lg);
            padding: 14px 18px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 14px;
            box-shadow: var(--shadow-sm);
        }

        .search-box {
            display: flex;
            align-items: center;
            gap: 8px;
            background: var(--surface-subtle);
            border: 1px solid var(--border);
            border-radius: var(--radius-md);
            padding: 6px 12px;
            width: 320px;
            max-width: 100%;
        }

        .search-box input {
            border: none;
            background: transparent;
            outline: none;
            font-family: inherit;
            font-size: 0.85rem;
            width: 100%;
            color: var(--text-primary);
        }

        .filter-controls {
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }

        .btn-filter-pill {
            padding: 6px 12px;
            font-size: 0.8rem;
            font-weight: 600;
            border-radius: var(--radius-pill);
            text-decoration: none;
            background: var(--surface-subtle);
            color: var(--text-secondary);
            border: 1px solid var(--border);
            transition: all 0.15s ease;
        }

        .btn-filter-pill.active,
        .btn-filter-pill:hover {
            background: #e2e8f0;
            color: var(--text-primary);
        }

        .btn-filter-pill.active {
            background: var(--text-primary);
            color: white;
            border-color: var(--text-primary);
        }

        /* BULK ACTIONS BAR */
        .bulk-bar {
            background: #1e293b;
            color: white;
            border-radius: var(--radius-md);
            padding: 10px 16px;
            margin-bottom: 14px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            animation: fadeIn 0.2s ease-in-out;
        }

        .bulk-info {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.85rem;
            font-weight: 600;
        }

        .bulk-actions-group {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .btn-bulk {
            background: rgba(255, 255, 255, 0.12);
            color: white;
            border: 1px solid rgba(255, 255, 255, 0.2);
            padding: 6px 12px;
            font-size: 0.78rem;
            font-weight: 600;
            border-radius: var(--radius-sm);
            cursor: pointer;
            transition: all 0.15s ease;
            display: inline-flex;
            align-items: center;
            gap: 5px;
        }

        .btn-bulk:hover {
            background: rgba(255, 255, 255, 0.22);
        }

        .btn-bulk-danger {
            background: rgba(220, 38, 38, 0.8);
            border-color: #dc2626;
        }

        .btn-bulk-danger:hover {
            background: #dc2626;
        }

        /* DATA TABLE */
        .table-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius-lg);
            box-shadow: var(--shadow-sm);
            overflow: hidden;
        }

        .data-table {
            width: 100%;
            border-collapse: collapse;
            text-align: left;
            font-size: 0.88rem;
        }

        .data-table th {
            background: var(--surface-subtle);
            color: var(--text-secondary);
            font-size: 0.76rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            padding: 12px 16px;
            border-bottom: 1px solid var(--border);
        }

        .data-table td {
            padding: 14px 16px;
            border-bottom: 1px solid var(--border-light);
            vertical-align: middle;
            color: var(--text-primary);
        }

        .data-table tr:last-child td {
            border-bottom: none;
        }

        .data-table tr:hover td {
            background: var(--surface-hover);
        }

        /* AVATAR CELL */
        .farmer-cell {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .farmer-avatar-wrap {
            position: relative;
            flex-shrink: 0;
        }

        .farmer-avatar {
            width: 44px;
            height: 44px;
            border-radius: var(--radius-pill);
            object-fit: cover;
            border: 2px solid white;
            box-shadow: var(--shadow-sm);
            background: #e2e8f0;
        }

        .avatar-verified-badge {
            position: absolute;
            bottom: -2px;
            right: -2px;
            background: #0284c7;
            color: white;
            border-radius: var(--radius-pill);
            width: 16px;
            height: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.65rem;
            border: 2px solid white;
        }

        .farmer-name-line {
            font-weight: 600;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .farmer-phone-line {
            font-size: 0.78rem;
            color: var(--text-muted);
            display: flex;
            align-items: center;
            gap: 4px;
            margin-top: 2px;
        }

        /* LOCATION CELL */
        .location-pill {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            font-size: 0.78rem;
            font-weight: 500;
            background: var(--surface-subtle);
            border: 1px solid var(--border);
            padding: 3px 8px;
            border-radius: var(--radius-pill);
            color: var(--text-secondary);
        }

        .location-sub {
            font-size: 0.74rem;
            color: var(--text-muted);
            margin-top: 3px;
        }

        /* STATUS BADGES */
        .badge-pill {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            padding: 4px 10px;
            border-radius: var(--radius-pill);
            font-size: 0.75rem;
            font-weight: 600;
            cursor: pointer;
            user-select: none;
            transition: all 0.15s ease;
            border: 1px solid transparent;
        }

        .badge-verified {
            background: var(--primary-light);
            color: var(--primary-dark);
            border-color: rgba(22, 163, 74, 0.25);
        }

        .badge-unverified {
            background: var(--surface-subtle);
            color: var(--text-muted);
            border-color: var(--border);
        }

        .badge-fake {
            background: var(--amber-light);
            color: var(--amber);
            border-color: rgba(217, 119, 6, 0.3);
        }

        .badge-genuine {
            background: var(--accent-light);
            color: var(--accent);
            border-color: rgba(37, 99, 235, 0.25);
        }

        .badge-pill:hover {
            filter: brightness(0.95);
            transform: scale(1.02);
        }

        /* ACTION BUTTONS */
        .action-btns {
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .btn-icon {
            width: 32px;
            height: 32px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            background: var(--surface);
            color: var(--text-secondary);
            display: inline-flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all 0.15s ease;
            font-size: 1rem;
        }

        .btn-icon:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
            border-color: #cbd5e1;
        }

        .btn-icon-danger:hover {
            background: var(--danger-light);
            color: var(--danger);
            border-color: rgba(220, 38, 38, 0.3);
        }

        /* EMPTY STATE */
        .empty-state {
            padding: 60px 20px;
            text-align: center;
            color: var(--text-secondary);
        }

        .empty-icon {
            width: 64px;
            height: 64px;
            background: var(--surface-subtle);
            border-radius: var(--radius-pill);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 2rem;
            color: var(--text-muted);
            margin: 0 auto 16px;
        }

        .empty-title {
            font-size: 1.1rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 6px;
        }

        .empty-desc {
            font-size: 0.85rem;
            color: var(--text-muted);
            max-width: 400px;
            margin: 0 auto 20px;
        }

        /* BUTTONS */
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            padding: 9px 16px;
            font-size: 0.85rem;
            font-weight: 600;
            border-radius: var(--radius-md);
            border: 1px solid transparent;
            cursor: pointer;
            transition: all 0.15s ease;
            text-decoration: none;
            font-family: inherit;
        }

        .btn-primary {
            background: var(--primary);
            color: white;
            border-color: var(--primary-dark);
            box-shadow: 0 1px 3px rgba(22, 163, 74, 0.3);
        }

        .btn-primary:hover {
            background: var(--primary-dark);
        }

        .btn-secondary {
            background: var(--surface);
            color: var(--text-secondary);
            border-color: var(--border);
        }

        .btn-secondary:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
            border-color: #cbd5e1;
        }

        .btn-amber {
            background: var(--amber);
            color: white;
            border-color: #b45309;
        }

        .btn-amber:hover {
            background: #b45309;
        }

        .btn-danger {
            background: var(--danger);
            color: white;
            border-color: #b91c1c;
        }

        .btn-danger:hover {
            background: #b91c1c;
        }

        /* MODAL DIALOGS */
        .modal-backdrop {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.6);
            backdrop-filter: blur(4px);
            z-index: 100;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            animation: fadeIn 0.15s ease-out;
        }

        .modal-card {
            background: var(--surface);
            border-radius: var(--radius-lg);
            width: 580px;
            max-width: 100%;
            max-height: 90vh;
            display: flex;
            flex-direction: column;
            box-shadow: var(--shadow-xl);
            border: 1px solid var(--border);
            animation: scaleUp 0.2s cubic-bezier(0.16, 1, 0.3, 1);
        }

        .modal-header {
            padding: 18px 24px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .modal-title {
            font-size: 1.1rem;
            font-weight: 700;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .modal-close {
            width: 32px;
            height: 32px;
            border-radius: var(--radius-md);
            border: none;
            background: transparent;
            color: var(--text-muted);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.25rem;
            cursor: pointer;
            transition: all 0.15s ease;
        }

        .modal-close:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
        }

        .modal-body {
            padding: 22px 24px;
            overflow-y: auto;
            flex: 1;
        }

        .modal-footer {
            padding: 16px 24px;
            border-top: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: flex-end;
            gap: 12px;
            background: var(--surface-subtle);
            border-bottom-left-radius: var(--radius-lg);
            border-bottom-right-radius: var(--radius-lg);
        }

        /* FORM ELEMENTS */
        .form-group {
            margin-bottom: 18px;
        }

        .form-label {
            display: block;
            font-size: 0.82rem;
            font-weight: 600;
            color: var(--text-secondary);
            margin-bottom: 6px;
        }

        .form-control {
            width: 100%;
            padding: 10px 14px;
            font-size: 0.88rem;
            border: 1px solid var(--border);
            border-radius: var(--radius-md);
            background: var(--surface);
            color: var(--text-primary);
            font-family: inherit;
            outline: none;
            transition: border-color 0.15s ease, box-shadow 0.15s ease;
        }

        .form-control:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-ring);
        }

        .input-group-btn {
            display: flex;
            gap: 8px;
        }

        .form-grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 14px;
        }

        /* AVATAR PICKER GRID */
        .avatar-presets-grid {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 10px;
            margin-top: 8px;
        }

        .avatar-preset-item {
            position: relative;
            cursor: pointer;
            border-radius: var(--radius-md);
            overflow: hidden;
            border: 2px solid var(--border);
            transition: all 0.15s ease;
            aspect-ratio: 1;
        }

        .avatar-preset-item img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            display: block;
        }

        .avatar-preset-item:hover {
            border-color: var(--primary);
            transform: scale(1.05);
        }

        .avatar-preset-item.selected {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-ring);
        }

        .avatar-preset-item.selected::after {
            content: '✓';
            position: absolute;
            top: 4px;
            right: 4px;
            background: var(--primary);
            color: white;
            font-size: 0.65rem;
            font-weight: bold;
            width: 16px;
            height: 16px;
            border-radius: var(--radius-pill);
            display: flex;
            align-items: center;
            justify-content: center;
        }

        /* DRAG AND DROP UPLOAD ZONE */
        .upload-dropzone {
            border: 2px dashed var(--border);
            border-radius: var(--radius-md);
            padding: 16px;
            text-align: center;
            background: var(--surface-subtle);
            cursor: pointer;
            transition: all 0.15s ease;
            margin-top: 10px;
        }

        .upload-dropzone.dragover {
            border-color: var(--primary);
            background: var(--primary-light);
        }

        .upload-dropzone p {
            font-size: 0.8rem;
            color: var(--text-muted);
            margin-top: 4px;
        }

        /* PROGRESS BAR */
        .progress-bar-wrap {
            background: #e2e8f0;
            border-radius: var(--radius-pill);
            height: 6px;
            overflow: hidden;
            margin-top: 8px;
        }

        .progress-bar-fill {
            background: var(--primary);
            height: 100%;
            transition: width 0.2s ease;
        }

        /* CUSTOM CONFIRM MODAL (Zero Native Popups) */
        .confirm-modal-backdrop {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.65);
            backdrop-filter: blur(4px);
            z-index: 200;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            animation: fadeIn 0.15s ease-out;
        }

        .confirm-modal-card {
            background: var(--surface);
            border-radius: var(--radius-lg);
            width: 440px;
            max-width: 100%;
            padding: 24px;
            box-shadow: var(--shadow-xl);
            border: 1px solid var(--border);
            text-align: center;
            animation: scaleUp 0.2s cubic-bezier(0.16, 1, 0.3, 1);
        }

        .confirm-icon-bubble {
            width: 54px;
            height: 54px;
            border-radius: var(--radius-pill);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.6rem;
            margin: 0 auto 16px;
        }

        .confirm-icon-bubble.confirm-danger {
            background: var(--danger-light);
            color: var(--danger);
        }

        .confirm-icon-bubble.confirm-amber {
            background: var(--amber-light);
            color: var(--amber);
        }

        .confirm-icon-bubble.confirm-primary {
            background: var(--primary-light);
            color: var(--primary);
        }

        .confirm-card-title {
            font-size: 1.15rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 6px;
        }

        .confirm-card-message {
            font-size: 0.88rem;
            color: var(--text-secondary);
            margin-bottom: 20px;
            line-height: 1.4;
        }

        .confirm-modal-actions {
            display: flex;
            gap: 12px;
        }

        .confirm-modal-actions .btn {
            flex: 1;
        }

        /* FLOATING TOAST STACK */
        .toast-stack-container {
            position: fixed;
            bottom: 24px;
            right: 24px;
            z-index: 300;
            display: flex;
            flex-direction: column;
            gap: 10px;
            pointer-events: none;
            max-width: 380px;
            width: 100%;
        }

        .toast-item {
            background: #1e293b;
            color: white;
            padding: 12px 16px;
            border-radius: var(--radius-md);
            box-shadow: var(--shadow-lg);
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 0.85rem;
            font-weight: 500;
            pointer-events: auto;
            border-left: 4px solid #94a3b8;
            animation: slideInRight 0.25s cubic-bezier(0.16, 1, 0.3, 1);
        }

        .toast-item.toast-success { border-left-color: var(--primary); }
        .toast-item.toast-danger { border-left-color: var(--danger); }
        .toast-item.toast-warning { border-left-color: var(--amber); }
        .toast-item.toast-info { border-left-color: var(--accent); }

        .toast-icon { font-size: 1.15rem; flex-shrink: 0; }
        .toast-content { flex: 1; }
        .toast-close {
            background: none;
            border: none;
            color: #94a3b8;
            cursor: pointer;
            font-size: 1.1rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .toast-close:hover { color: white; }

        .spin {
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            100% { transform: rotate(360deg); }
        }

        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }

        @keyframes scaleUp {
            from { opacity: 0; transform: scale(0.95); }
            to { opacity: 1; transform: scale(1); }
        }

        @keyframes slideInRight {
            from { opacity: 0; transform: translateX(40px); }
            to { opacity: 1; transform: translateX(0); }
        }

        @media (max-width: 768px) {
            .app-header { padding: 10px 16px; }
            .kpi-section, .content-area, .nav-tabs-bar { padding-left: 16px; padding-right: 16px; }
            .toolbar-panel { flex-direction: column; align-items: stretch; }
            .search-box { width: 100%; }
            .header-actions { gap: 6px; }
            .btn-header span { display: none; }
            .nav-tabs-bar { flex-direction: column; align-items: stretch; gap: 10px; padding-bottom: 12px; }
        }
    </style>
</head>
<body x-data="fakeFarmersApp()" x-init="init()">

    <!-- Floating Toast Notifications -->
    <div class="toast-stack-container" aria-live="polite">
        <template x-for="toast in toasts" :key="toast.id">
            <div class="toast-item" :class="'toast-' + toast.type">
                <div class="toast-icon">
                    <i class="ph-bold" :class="toast.type === 'success' ? 'ph-check-circle' : (toast.type === 'danger' ? 'ph-warning-circle' : (toast.type === 'warning' ? 'ph-warning' : 'ph-info'))"></i>
                </div>
                <div class="toast-content" x-text="toast.message"></div>
                <button type="button" class="toast-close" @click="removeToast(toast.id)">&times;</button>
            </div>
        </template>
    </div>

    <!-- Custom Confirmation Modal (Zero Browser Popups) -->
    <div class="confirm-modal-backdrop" x-show="confirmModal.show" x-cloak @keydown.escape.window="closeConfirm()">
        <div class="confirm-modal-card" @click.outside="closeConfirm()">
            <div class="confirm-icon-bubble" :class="'confirm-' + confirmModal.iconColor">
                <i class="ph-bold" :class="confirmModal.icon"></i>
            </div>
            <h4 class="confirm-card-title" x-text="confirmModal.title"></h4>
            <p class="confirm-card-message" x-text="confirmModal.message"></p>
            <div class="confirm-modal-actions">
                <button type="button" class="btn btn-secondary" @click="closeConfirm()" :disabled="confirmModal.loading">Cancel</button>
                <button type="button" class="btn" :class="confirmModal.confirmClass" @click="executeConfirm()" :disabled="confirmModal.loading">
                    <i class="ph-bold ph-spinner-gap spin" x-show="confirmModal.loading"></i>
                    <span x-text="confirmModal.confirmText"></span>
                </button>
            </div>
        </div>
    </div>

    <!-- 1. APP HEADER -->
    <header class="app-header">
        <a href="fake_farmers_dashboard.php" class="header-brand">
            <div class="brand-icon">
                <i class="ph-bold ph-users-three"></i>
            </div>
            <div class="brand-text">
                <h1>
                    Fake Farmers Hub
                    <span class="brand-badge">Simulator</span>
                    <span class="brand-region-badge">
                        <i class="ph-fill ph-map-pin"></i> Hyderabad Only
                    </span>
                </h1>
            </div>
        </a>

        <div class="header-actions">
            <!-- Navigation: News & Reels Studio Link -->
            <a href="dashboard.php" class="btn-header" title="Go to News & Agri Reels Studio">
                <i class="ph-bold ph-film-strip"></i>
                <span>News & Reels Studio</span>
            </a>

            <!-- Navigation: Seeds & Shop Catalog Link -->
            <a href="shop_seeds_dashboard.php" class="btn-header" title="Go to Agri Shop & Seeds Catalog">
                <i class="ph-bold ph-storefront"></i>
                <span>Seeds & Shop Catalog</span>
            </a>

            <!-- Quick Refresh -->
            <a href="javascript:location.reload()" class="btn-header" title="Refresh Data">
                <i class="ph ph-arrows-clockwise"></i>
            </a>
        </div>
    </header>

    <!-- 2. KPI / OVERVIEW BAR -->
    <section class="kpi-section">
        <div class="kpi-grid">
            <div class="kpi-card kpi-amber">
                <div class="kpi-title">
                    <span><i class="ph-bold ph-user-circle-gear text-amber-600"></i> Fake Hyderabad Farmers</span>
                    <i class="ph-bold ph-mask-happy text-amber-500"></i>
                </div>
                <div class="kpi-value"><?= number_format($stats['total_fake']) ?></div>
                <div class="kpi-sub">
                    <span class="font-semibold text-amber-700"><?= $stats['verified_fake'] ?> verified</span> &bull; 
                    <?= $stats['unverified_fake'] ?> unverified
                </div>
            </div>

            <div class="kpi-card kpi-green">
                <div class="kpi-title">
                    <span><i class="ph-bold ph-check-circle text-emerald-600"></i> Verified Fake Accounts</span>
                    <i class="ph-bold ph-seal-check text-emerald-500"></i>
                </div>
                <div class="kpi-value"><?= number_format($stats['verified_fake']) ?></div>
                <div class="kpi-sub">Ready with blue checkmark badge</div>
            </div>

            <div class="kpi-card kpi-gray">
                <div class="kpi-title">
                    <span><i class="ph-bold ph-clock text-slate-500"></i> Unverified Fake Accounts</span>
                    <i class="ph-bold ph-hourglass text-slate-400"></i>
                </div>
                <div class="kpi-value"><?= number_format($stats['unverified_fake']) ?></div>
                <div class="kpi-sub">Pending verification status</div>
            </div>

            <div class="kpi-card kpi-blue">
                <div class="kpi-title">
                    <span><i class="ph-bold ph-users text-blue-600"></i> Genuine Hyderabad Farmers</span>
                    <i class="ph-bold ph-shield-check text-blue-500"></i>
                </div>
                <div class="kpi-value"><?= number_format($stats['total_genuine']) ?></div>
                <div class="kpi-sub">Out of <?= number_format($stats['total_hyd']) ?> total Hyderabad users</div>
            </div>
        </div>
    </section>

    <!-- 3. NAVIGATION TABS & ACTION BUTTONS -->
    <nav class="nav-tabs-bar">
        <div class="tabs-group">
            <a href="?tab=fake<?= !empty($searchQuery) ? '&q=' . urlencode($searchQuery) : '' ?><?= $statusFilter !== 'all' ? '&status=' . $statusFilter : '' ?>" 
               class="tab-link <?= $activeTab === 'fake' ? 'active' : '' ?>">
                <i class="ph-bold ph-mask-happy"></i>
                Fake Accounts
                <span class="tab-counter"><?= $stats['total_fake'] ?></span>
            </a>

            <a href="?tab=all<?= !empty($searchQuery) ? '&q=' . urlencode($searchQuery) : '' ?><?= $statusFilter !== 'all' ? '&status=' . $statusFilter : '' ?>" 
               class="tab-link <?= $activeTab === 'all' ? 'active' : '' ?>">
                <i class="ph-bold ph-users"></i>
                All Hyderabad Farmers
                <span class="tab-counter"><?= $stats['total_hyd'] ?></span>
            </a>
        </div>

        <div class="tab-action-btns">
            <!-- Batch Quick Generator -->
            <button type="button" class="btn btn-secondary" @click="openQuickGenModal()" title="Instantly generate realistic Hyderabad fake profiles">
                <i class="ph-bold ph-sparkle text-amber-500"></i>
                Quick Generate
            </button>

            <!-- Add Single Fake Farmer -->
            <button type="button" class="btn btn-primary" @click="openAddModal()">
                <i class="ph-bold ph-user-plus"></i>
                Add Fake Farmer
            </button>
        </div>
    </nav>

    <!-- 4. CONTENT AREA -->
    <main class="content-area">
        
        <!-- Flash Message -->
        <?php if (!empty($formMessage)): ?>
            <div style="margin-bottom: 16px; padding: 12px 18px; border-radius: var(--radius-md); background: <?= $formMessageType === 'success' ? 'var(--primary-light)' : 'var(--danger-light)' ?>; border: 1px solid <?= $formMessageType === 'success' ? 'var(--primary)' : 'var(--danger)' ?>; color: <?= $formMessageType === 'success' ? 'var(--primary-dark)' : 'var(--danger)' ?>; font-size: 0.88rem; display: flex; align-items: center; justify-content: space-between;">
                <span><strong><?= $formMessageType === 'success' ? 'Success:' : 'Notice:' ?></strong> <?= htmlspecialchars($formMessage) ?></span>
                <a href="fake_farmers_dashboard.php?tab=<?= $activeTab ?>" style="color: inherit; text-decoration: none; font-weight: bold;">&times;</a>
            </div>
        <?php endif; ?>

        <!-- Toolbar (Search & Filters) -->
        <div class="toolbar-panel">
            <form method="GET" class="search-box">
                <input type="hidden" name="tab" value="<?= htmlspecialchars($activeTab) ?>">
                <?php if ($statusFilter !== 'all'): ?>
                    <input type="hidden" name="status" value="<?= htmlspecialchars($statusFilter) ?>">
                <?php endif; ?>
                <i class="ph ph-magnifying-glass text-slate-400"></i>
                <input type="text" name="q" placeholder="Search by name, phone, mandal, village..." value="<?= htmlspecialchars($searchQuery) ?>">
                <?php if (!empty($searchQuery)): ?>
                    <a href="?tab=<?= $activeTab ?><?= $statusFilter !== 'all' ? '&status=' . $statusFilter : '' ?>" style="color: var(--text-muted); text-decoration: none;">&times;</a>
                <?php endif; ?>
            </form>

            <div class="filter-controls">
                <span style="font-size: 0.78rem; font-weight: 600; color: var(--text-muted);">Status:</span>
                <a href="?tab=<?= $activeTab ?><?= !empty($searchQuery) ? '&q=' . urlencode($searchQuery) : '' ?>&status=all" 
                   class="btn-filter-pill <?= $statusFilter === 'all' ? 'active' : '' ?>">All (<?= count($farmers) ?>)</a>
                <a href="?tab=<?= $activeTab ?><?= !empty($searchQuery) ? '&q=' . urlencode($searchQuery) : '' ?>&status=verified" 
                   class="btn-filter-pill <?= $statusFilter === 'verified' ? 'active' : '' ?>">Verified Only</a>
                <a href="?tab=<?= $activeTab ?><?= !empty($searchQuery) ? '&q=' . urlencode($searchQuery) : '' ?>&status=unverified" 
                   class="btn-filter-pill <?= $statusFilter === 'unverified' ? 'active' : '' ?>">Unverified Only</a>
            </div>
        </div>

        <!-- Bulk Selection Floating Bar -->
        <div class="bulk-bar" x-show="selectedIds.length > 0" x-cloak>
            <div class="bulk-info">
                <i class="ph-bold ph-check-square"></i>
                <span x-text="selectedIds.length + ' farmers selected'"></span>
            </div>
            <div class="bulk-actions-group">
                <button type="button" class="btn-bulk" @click="bulkSetFake(1)">
                    <i class="ph-bold ph-mask-happy"></i> Mark as Fake
                </button>
                <button type="button" class="btn-bulk" @click="bulkSetFake(0)">
                    <i class="ph-bold ph-shield-check"></i> Mark as Genuine
                </button>
                <button type="button" class="btn-bulk" @click="bulkSetVerified(1)">
                    <i class="ph-bold ph-seal-check"></i> Verify
                </button>
                <button type="button" class="btn-bulk btn-bulk-danger" @click="bulkDelete()">
                    <i class="ph-bold ph-trash"></i> Delete Selected
                </button>
                <button type="button" class="btn-bulk" @click="selectedIds = []" style="opacity: 0.8;">
                    Deselect
                </button>
            </div>
        </div>

        <!-- Data Table -->
        <div class="table-card">
            <?php if (empty($farmers)): ?>
                <div class="empty-state">
                    <div class="empty-icon">
                        <i class="ph-bold ph-user-slash"></i>
                    </div>
                    <div class="empty-title">No Hyderabad Farmers Found</div>
                    <p class="empty-desc">
                        <?= !empty($searchQuery) ? "No accounts match '" . htmlspecialchars($searchQuery) . "'." : ($activeTab === 'fake' ? "No fake farmer accounts have been created for Hyderabad yet." : "No farmers found in Hyderabad region.") ?>
                    </p>
                    <button type="button" class="btn btn-primary" @click="openQuickGenModal()">
                        <i class="ph-bold ph-sparkle"></i> Quick Generate 5 Fake Accounts
                    </button>
                </div>
            <?php else: ?>
                <table class="data-table">
                    <thead>
                        <tr>
                            <th style="width: 40px; text-align: center;">
                                <input type="checkbox" @change="toggleSelectAll($event)">
                            </th>
                            <th>Farmer Profile</th>
                            <th>Hyderabad Location</th>
                            <th>Verification</th>
                            <th>Fake Simulator Status</th>
                            <th>Created Date</th>
                            <th style="text-align: right;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($farmers as $farmer): ?>
                            <?php
                            $uId = $farmer['user_id'];
                            $uName = !empty($farmer['name']) ? $farmer['name'] : 'Unnamed Farmer';
                            $uPhone = !empty($farmer['phone_number']) ? $farmer['phone_number'] : $uId;
                            $uMandal = !empty($farmer['mandal']) ? $farmer['mandal'] : 'Secunderabad';
                            $uVillage = !empty($farmer['village']) ? $farmer['village'] : 'Hyderabad';
                            $uAvatar = !empty($farmer['profile_image_url']) ? $farmer['profile_image_url'] : 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=150&q=80';
                            $isVerified = !empty($farmer['is_verified']) && intval($farmer['is_verified']) === 1;
                            $isFake = !empty($farmer['is_fake']) && intval($farmer['is_fake']) === 1;
                            $createdAt = !empty($farmer['created_at']) ? date('M d, Y', strtotime($farmer['created_at'])) : 'N/A';
                            ?>
                            <tr id="row-<?= htmlspecialchars($uId) ?>">
                                <td style="text-align: center;">
                                    <input type="checkbox" value="<?= htmlspecialchars($uId) ?>" x-model="selectedIds">
                                </td>
                                <td>
                                    <div class="farmer-cell">
                                        <div class="farmer-avatar-wrap">
                                            <img src="<?= htmlspecialchars($uAvatar) ?>" alt="<?= htmlspecialchars($uName) ?>" class="farmer-avatar" loading="lazy" onerror="this.src='https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=150&q=80'">
                                            <?php if ($isVerified): ?>
                                                <div class="avatar-verified-badge" title="Verified Account">✓</div>
                                            <?php endif; ?>
                                        </div>
                                        <div>
                                            <div class="farmer-name-line">
                                                <span><?= htmlspecialchars($uName) ?></span>
                                            </div>
                                            <div class="farmer-phone-line">
                                                <i class="ph ph-phone"></i> <?= htmlspecialchars($uPhone) ?>
                                                <span style="opacity: 0.5;">&bull; ID: <?= htmlspecialchars($uId) ?></span>
                                            </div>
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <div class="location-pill">
                                        <i class="ph-bold ph-map-pin text-emerald-600"></i>
                                        <span><?= htmlspecialchars($uMandal) ?></span>
                                    </div>
                                    <div class="location-sub">
                                        <?= htmlspecialchars($uVillage) ?>, Hyderabad (HYD001)
                                    </div>
                                </td>
                                <td>
                                    <span class="badge-pill <?= $isVerified ? 'badge-verified' : 'badge-unverified' ?>"
                                          @click="toggleVerified('<?= htmlspecialchars($uId) ?>', <?= $isVerified ? 0 : 1 ?>)"
                                          title="Click to toggle verification status">
                                        <i class="ph-bold <?= $isVerified ? 'ph-seal-check' : 'ph-circle' ?>"></i>
                                        <span><?= $isVerified ? 'Verified' : 'Unverified' ?></span>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge-pill <?= $isFake ? 'badge-fake' : 'badge-genuine' ?>"
                                          @click="toggleFake('<?= htmlspecialchars($uId) ?>', <?= $isFake ? 0 : 1 ?>)"
                                          title="Click to toggle fake / genuine status">
                                        <i class="ph-bold <?= $isFake ? 'ph-mask-happy' : 'ph-shield-check' ?>"></i>
                                        <span><?= $isFake ? 'Fake Account' : 'Genuine' ?></span>
                                    </span>
                                </td>
                                <td>
                                    <span style="font-size: 0.8rem; color: var(--text-secondary);"><?= $createdAt ?></span>
                                </td>
                                <td style="text-align: right;">
                                    <div class="action-btns" style="justify-content: flex-end;">
                                        <!-- Edit -->
                                        <button type="button" class="btn-icon" title="Edit Farmer" 
                                                @click="openEditModal(<?= htmlspecialchars(json_encode([
                                                    'user_id' => $uId,
                                                    'name' => $uName,
                                                    'phone_number' => $uPhone,
                                                    'mandal' => $uMandal,
                                                    'village' => $uVillage,
                                                    'profile_image_url' => $uAvatar,
                                                    'is_verified' => $isVerified ? 1 : 0,
                                                    'is_fake' => $isFake ? 1 : 0
                                                ])) ?>)">
                                            <i class="ph ph-pencil-simple"></i>
                                        </button>

                                        <!-- Delete with Zero Native Popups -->
                                        <button type="button" class="btn-icon btn-icon-danger" title="Delete Farmer"
                                                @click="confirmDelete('<?= htmlspecialchars($uId) ?>', '<?= htmlspecialchars(addslashes($uName)) ?>')">
                                            <i class="ph ph-trash"></i>
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
    </main>

    <!-- 5. ADD FAKE FARMER MODAL -->
    <div class="modal-backdrop" x-show="addModal.show" x-cloak @keydown.escape.window="addModal.show = false">
        <div class="modal-card" @click.outside="addModal.show = false">
            <div class="modal-header">
                <div class="modal-title">
                    <i class="ph-bold ph-user-plus text-emerald-600"></i>
                    Add Fake Hyderabad Farmer
                </div>
                <button type="button" class="modal-close" @click="addModal.show = false">&times;</button>
            </div>

            <form method="POST" action="fake_farmers_dashboard.php?tab=<?= $activeTab ?>" enctype="multipart/form-data">
                <input type="hidden" name="action" value="create_farmer">
                <input type="hidden" name="profile_image_url" x-model="addModal.avatar">

                <div class="modal-body">
                    <!-- Name with Quick Random Suggestion -->
                    <div class="form-group">
                        <label class="form-label">Farmer Full Name *</label>
                        <div class="input-group-btn">
                            <input type="text" name="name" class="form-control" required placeholder="e.g. Malla Reddy" x-model="addModal.name">
                            <button type="button" class="btn btn-secondary" @click="suggestRandomName('add')" title="Pick Random Name">
                                <i class="ph ph-arrows-clockwise"></i> Suggest
                            </button>
                        </div>
                    </div>

                    <!-- Phone Number with Auto-Generate Button -->
                    <div class="form-group">
                        <label class="form-label">Phone Number (10 Digits) *</label>
                        <div class="input-group-btn">
                            <input type="text" name="phone_number" class="form-control" required placeholder="e.g. 9848012345" x-model="addModal.phone" maxlength="15">
                            <button type="button" class="btn btn-secondary" @click="generatePhone('add')" title="Auto-generate 10-digit Indian mobile number">
                                <i class="ph ph-magic-wand"></i> Auto Gen
                            </button>
                        </div>
                        <small style="color: var(--text-muted); font-size: 0.72rem; margin-top: 4px; display: block;">
                            Also serves as the primary User ID in the mobile app.
                        </small>
                    </div>

                    <!-- Location Grid: Hyderabad Mandals & Villages -->
                    <div class="form-grid-2">
                        <div class="form-group">
                            <label class="form-label">Hyderabad Mandal *</label>
                            <select name="mandal" class="form-control" x-model="addModal.mandal">
                                <?php foreach ($HYD_MANDALS as $mandal): ?>
                                    <option value="<?= htmlspecialchars($mandal) ?>"><?= htmlspecialchars($mandal) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Village / Locality</label>
                            <input type="text" name="village" class="form-control" placeholder="e.g. Gachibowli" x-model="addModal.village">
                        </div>
                    </div>

                    <!-- Verification Toggle -->
                    <div class="form-group">
                        <label class="form-label">Verification Status</label>
                        <div style="display: flex; gap: 16px; align-items: center; margin-top: 6px;">
                            <label style="display: flex; align-items: center; gap: 6px; font-size: 0.85rem; cursor: pointer;">
                                <input type="radio" name="is_verified" value="1" x-model="addModal.is_verified">
                                <span style="color: var(--primary-dark); font-weight: 600;"><i class="ph-bold ph-seal-check"></i> Verified (Blue checkmark)</span>
                            </label>
                            <label style="display: flex; align-items: center; gap: 6px; font-size: 0.85rem; cursor: pointer;">
                                <input type="radio" name="is_verified" value="0" x-model="addModal.is_verified">
                                <span style="color: var(--text-secondary);"><i class="ph ph-circle"></i> Unverified</span>
                            </label>
                        </div>
                    </div>

                    <!-- Profile Avatar Selection: Curated Presets OR Custom Upload -->
                    <div class="form-group">
                        <label class="form-label">Select Realistic Profile Avatar</label>
                        
                        <!-- Curated Preset Grid -->
                        <div class="avatar-presets-grid">
                            <template x-for="(imgUrl, idx) in avatarPresets" :key="idx">
                                <div class="avatar-preset-item" 
                                     :class="addModal.avatar === imgUrl ? 'selected' : ''"
                                     @click="addModal.avatar = imgUrl">
                                    <img :src="imgUrl" alt="Avatar Preset" loading="lazy">
                                </div>
                            </template>
                        </div>

                        <!-- Or Upload Custom Picture -->
                        <div class="upload-dropzone" 
                             :class="uploader.dragOver ? 'dragover' : ''"
                             @dragover.prevent="uploader.dragOver = true"
                             @dragleave.prevent="uploader.dragOver = false"
                             @drop.prevent="handleDrop($event, 'add')"
                             @click="$refs.addFileInput.click()">
                            <i class="ph-bold ph-cloud-arrow-up text-emerald-600" style="font-size: 1.5rem;"></i>
                            <div style="font-weight: 600; font-size: 0.82rem; margin-top: 4px;">
                                Click or Drag & Drop custom portrait
                            </div>
                            <p>PNG, JPG, WEBP up to 5MB</p>
                            <input type="file" x-ref="addFileInput" style="display: none;" accept="image/*" @change="handleFileSelect($event, 'add')">
                        </div>

                        <!-- Upload Progress Bar -->
                        <div x-show="uploader.isUploading" x-cloak style="margin-top: 8px;">
                            <div style="display: flex; justify-content: space-between; font-size: 0.75rem; color: var(--text-secondary);">
                                <span x-text="uploader.statusText"></span>
                                <span x-text="uploader.progress + '%'"></span>
                            </div>
                            <div class="progress-bar-wrap">
                                <div class="progress-bar-fill" :style="'width: ' + uploader.progress + '%'"></div>
                            </div>
                        </div>

                        <!-- Preview if custom avatar or selected -->
                        <div x-show="addModal.avatar" style="margin-top: 10px; display: flex; align-items: center; gap: 10px;">
                            <img :src="addModal.avatar" style="width: 40px; height: 40px; border-radius: 9999px; object-fit: cover; border: 2px solid var(--primary);">
                            <span style="font-size: 0.78rem; color: var(--text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" x-text="addModal.avatar"></span>
                        </div>
                    </div>
                </div>

                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" @click="addModal.show = false">Cancel</button>
                    <button type="submit" class="btn btn-primary">
                        <i class="ph-bold ph-check"></i> Create Hyderabad Farmer
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- 6. EDIT FARMER MODAL -->
    <div class="modal-backdrop" x-show="editModal.show" x-cloak @keydown.escape.window="editModal.show = false">
        <div class="modal-card" @click.outside="editModal.show = false">
            <div class="modal-header">
                <div class="modal-title">
                    <i class="ph-bold ph-pencil-simple text-blue-600"></i>
                    Edit Hyderabad Farmer Profile
                </div>
                <button type="button" class="modal-close" @click="editModal.show = false">&times;</button>
            </div>

            <form method="POST" action="fake_farmers_dashboard.php?tab=<?= $activeTab ?>" enctype="multipart/form-data">
                <input type="hidden" name="action" value="edit_farmer">
                <input type="hidden" name="user_id" x-model="editModal.user_id">
                <input type="hidden" name="profile_image_url" x-model="editModal.avatar">

                <div class="modal-body">
                    <div class="form-group">
                        <label class="form-label">Farmer Full Name *</label>
                        <input type="text" name="name" class="form-control" required x-model="editModal.name">
                    </div>

                    <div class="form-group">
                        <label class="form-label">Phone Number *</label>
                        <input type="text" name="phone_number" class="form-control" required x-model="editModal.phone">
                    </div>

                    <div class="form-grid-2">
                        <div class="form-group">
                            <label class="form-label">Hyderabad Mandal *</label>
                            <select name="mandal" class="form-control" x-model="editModal.mandal">
                                <?php foreach ($HYD_MANDALS as $mandal): ?>
                                    <option value="<?= htmlspecialchars($mandal) ?>"><?= htmlspecialchars($mandal) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Village / Locality</label>
                            <input type="text" name="village" class="form-control" x-model="editModal.village">
                        </div>
                    </div>

                    <div class="form-grid-2">
                        <div class="form-group">
                            <label class="form-label">Verification Status</label>
                            <select name="is_verified" class="form-control" x-model="editModal.is_verified">
                                <option value="1">Verified (Blue checkmark)</option>
                                <option value="0">Unverified</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label class="form-label">Simulator Status</label>
                            <select name="is_fake" class="form-control" x-model="editModal.is_fake">
                                <option value="1">Fake Account (Simulator)</option>
                                <option value="0">Genuine Farmer</option>
                            </select>
                        </div>
                    </div>

                    <!-- Avatar Edit -->
                    <div class="form-group">
                        <label class="form-label">Profile Avatar</label>
                        <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 10px;">
                            <img :src="editModal.avatar" style="width: 50px; height: 50px; border-radius: 9999px; object-fit: cover; border: 2px solid var(--border);">
                            <div style="flex: 1;">
                                <input type="text" class="form-control" placeholder="Avatar URL" x-model="editModal.avatar" style="font-size: 0.8rem;">
                            </div>
                        </div>

                        <div class="avatar-presets-grid">
                            <template x-for="(imgUrl, idx) in avatarPresets" :key="idx">
                                <div class="avatar-preset-item" 
                                     :class="editModal.avatar === imgUrl ? 'selected' : ''"
                                     @click="editModal.avatar = imgUrl">
                                    <img :src="imgUrl" alt="Avatar Preset" loading="lazy">
                                </div>
                            </template>
                        </div>
                    </div>
                </div>

                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" @click="editModal.show = false">Cancel</button>
                    <button type="submit" class="btn btn-primary">
                        <i class="ph-bold ph-check"></i> Save Changes
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- 7. QUICK BATCH GENERATOR MODAL -->
    <div class="modal-backdrop" x-show="quickGenModal.show" x-cloak @keydown.escape.window="quickGenModal.show = false">
        <div class="modal-card" style="width: 480px;" @click.outside="quickGenModal.show = false">
            <div class="modal-header">
                <div class="modal-title">
                    <i class="ph-bold ph-sparkle text-amber-500"></i>
                    Quick Generate Hyderabad Fake Accounts
                </div>
                <button type="button" class="modal-close" @click="quickGenModal.show = false">&times;</button>
            </div>

            <div class="modal-body">
                <p style="font-size: 0.88rem; color: var(--text-secondary); margin-bottom: 16px; line-height: 1.5;">
                    Instantly create realistic fake farmer profiles strictly in the <strong>Hyderabad region</strong>. Each generated account receives a unique Telugu name, realistic 10-digit mobile number, verified status, an authentic Indian farmer portrait, and an assigned Hyderabad mandal.
                </p>

                <div class="form-group">
                    <label class="form-label">How many accounts to generate?</label>
                    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px;">
                        <button type="button" class="btn" 
                                :class="quickGenModal.count === 3 ? 'btn-primary' : 'btn-secondary'" 
                                @click="quickGenModal.count = 3">
                            3 Accounts
                        </button>
                        <button type="button" class="btn" 
                                :class="quickGenModal.count === 5 ? 'btn-primary' : 'btn-secondary'" 
                                @click="quickGenModal.count = 5">
                            5 Accounts
                        </button>
                        <button type="button" class="btn" 
                                :class="quickGenModal.count === 10 ? 'btn-primary' : 'btn-secondary'" 
                                @click="quickGenModal.count = 10">
                            10 Accounts
                        </button>
                    </div>
                </div>
            </div>

            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" @click="quickGenModal.show = false" :disabled="quickGenModal.loading">Cancel</button>
                <button type="button" class="btn btn-primary" @click="executeQuickGen()" :disabled="quickGenModal.loading">
                    <i class="ph-bold ph-spinner-gap spin" x-show="quickGenModal.loading"></i>
                    <i class="ph-bold ph-magic-wand" x-show="!quickGenModal.loading"></i>
                    <span x-text="quickGenModal.loading ? 'Generating...' : 'Generate ' + quickGenModal.count + ' Accounts'"></span>
                </button>
            </div>
        </div>
    </div>

    <!-- Alpine.js Application Script -->
    <script>
        function fakeFarmersApp() {
            return {
                toasts: [],
                toastCounter: 0,
                selectedIds: [],

                // Avatar Presets Array
                avatarPresets: <?= json_encode($AVATAR_PRESETS) ?>,
                namePool: <?= json_encode($NAME_POOL) ?>,
                hydMandals: <?= json_encode($HYD_MANDALS) ?>,
                hydVillages: <?= json_encode($HYD_VILLAGES) ?>,

                // Confirmation Modal State (Zero Native Popups)
                confirmModal: {
                    show: false,
                    title: '',
                    message: '',
                    icon: 'ph-warning',
                    iconColor: 'danger',
                    confirmText: 'Confirm',
                    confirmClass: 'btn-danger',
                    loading: false,
                    onConfirm: null
                },

                // Add Modal State
                addModal: {
                    show: false,
                    name: '',
                    phone: '',
                    mandal: 'Secunderabad',
                    village: 'Gachibowli',
                    is_verified: '1',
                    avatar: '<?= $AVATAR_PRESETS[0] ?>'
                },

                // Edit Modal State
                editModal: {
                    show: false,
                    user_id: '',
                    name: '',
                    phone: '',
                    mandal: '',
                    village: '',
                    is_verified: 1,
                    is_fake: 1,
                    avatar: ''
                },

                // Quick Gen Modal State
                quickGenModal: {
                    show: false,
                    count: 5,
                    loading: false
                },

                // Uploader State
                uploader: {
                    isUploading: false,
                    progress: 0,
                    statusText: '',
                    dragOver: false
                },

                init() {
                    // Check if initial toast requested
                },

                showToast(message, type = 'info', duration = 3500) {
                    const id = ++this.toastCounter;
                    this.toasts.push({ id, message, type });
                    setTimeout(() => {
                        this.removeToast(id);
                    }, duration);
                },

                removeToast(id) {
                    this.toasts = this.toasts.filter(t => t.id !== id);
                },

                askConfirm(options) {
                    this.confirmModal = {
                        show: true,
                        title: options.title || 'Are you sure?',
                        message: options.message || 'This action cannot be undone.',
                        icon: options.icon || 'ph-warning-circle',
                        iconColor: options.iconColor || 'danger',
                        confirmText: options.confirmText || 'Confirm',
                        confirmClass: options.confirmClass || 'btn-danger',
                        loading: false,
                        onConfirm: options.onConfirm || null
                    };
                },

                closeConfirm() {
                    if (!this.confirmModal.loading) {
                        this.confirmModal.show = false;
                    }
                },

                async executeConfirm() {
                    if (typeof this.confirmModal.onConfirm === 'function') {
                        this.confirmModal.loading = true;
                        try {
                            await this.confirmModal.onConfirm();
                        } catch (err) {
                            this.showToast('Error: ' + err.message, 'danger');
                        }
                        this.confirmModal.loading = false;
                        this.confirmModal.show = false;
                    } else {
                        this.confirmModal.show = false;
                    }
                },

                // Suggest random Telugu name
                suggestRandomName(target) {
                    const rName = this.namePool[Math.floor(Math.random() * this.namePool.length)];
                    if (target === 'add') this.addModal.name = rName;
                },

                // Generate 10-digit Indian phone number
                generatePhone(target) {
                    const prefixes = ['9848', '9989', '9440', '9866', '9701', '8978', '7799', '9100', '6300', '8008'];
                    const prefix = prefixes[Math.floor(Math.random() * prefixes.length)];
                    const suffix = Math.floor(100000 + Math.random() * 900000);
                    const phone = prefix + suffix;
                    if (target === 'add') this.addModal.phone = phone;
                },

                openAddModal() {
                    this.addModal = {
                        show: true,
                        name: this.namePool[Math.floor(Math.random() * this.namePool.length)],
                        phone: '',
                        mandal: this.hydMandals[Math.floor(Math.random() * this.hydMandals.length)],
                        village: this.hydVillages[Math.floor(Math.random() * this.hydVillages.length)],
                        is_verified: '1',
                        avatar: this.avatarPresets[Math.floor(Math.random() * this.avatarPresets.length)]
                    };
                    this.generatePhone('add');
                },

                openEditModal(data) {
                    this.editModal = {
                        show: true,
                        user_id: data.user_id,
                        name: data.name,
                        phone: data.phone_number,
                        mandal: data.mandal,
                        village: data.village,
                        is_verified: data.is_verified,
                        is_fake: data.is_fake,
                        avatar: data.profile_image_url
                    };
                },

                openQuickGenModal() {
                    this.quickGenModal = {
                        show: true,
                        count: 5,
                        loading: false
                    };
                },

                // Handle File Uploads (Drag & drop or input)
                handleDrop(e, target) {
                    this.uploader.dragOver = false;
                    const files = e.dataTransfer.files;
                    if (files.length > 0) {
                        this.uploadAvatar(files[0], target);
                    }
                },

                handleFileSelect(e, target) {
                    const files = e.target.files;
                    if (files.length > 0) {
                        this.uploadAvatar(files[0], target);
                    }
                },

                uploadAvatar(file, target) {
                    const self = this;
                    self.uploader.isUploading = true;
                    self.uploader.progress = 0;
                    self.uploader.statusText = 'Uploading avatar...';

                    const fd = new FormData();
                    fd.append('file', file);

                    const xhr = new XMLHttpRequest();
                    xhr.open('POST', 'fake_farmers_dashboard.php?ajax_upload=farmers', true);

                    xhr.upload.onprogress = function(e) {
                        if (e.lengthComputable) {
                            self.uploader.progress = Math.round((e.loaded / e.total) * 100);
                        }
                    };

                    xhr.onload = function() {
                        self.uploader.isUploading = false;
                        if (xhr.status >= 200 && xhr.status < 300) {
                            try {
                                const res = JSON.parse(xhr.responseText);
                                if (res.success && res.url) {
                                    if (target === 'add') {
                                        self.addModal.avatar = res.url;
                                    } else {
                                        self.editModal.avatar = res.url;
                                    }
                                    self.showToast('Avatar uploaded successfully!', 'success');
                                } else {
                                    self.showToast(res.error || 'Upload failed', 'danger');
                                }
                            } catch (err) {
                                self.showToast('Invalid server response.', 'danger');
                            }
                        } else {
                            self.showToast('Upload error: HTTP ' + xhr.status, 'danger');
                        }
                    };

                    xhr.onerror = function() {
                        self.uploader.isUploading = false;
                        self.showToast('Network error during upload.', 'danger');
                    };

                    xhr.send(fd);
                },

                // 1-Click Verification Toggle
                async toggleVerified(userId, nextVal) {
                    const fd = new FormData();
                    fd.append('ajax_action', 'toggle_verified');
                    fd.append('user_id', userId);
                    fd.append('is_verified', nextVal);

                    try {
                        const res = await fetch('fake_farmers_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(nextVal === 1 ? 'Farmer verified!' : 'Farmer set to unverified.', 'success');
                            setTimeout(() => location.reload(), 500);
                        } else {
                            this.showToast(json.error || 'Failed to update verification.', 'danger');
                        }
                    } catch (e) {
                        this.showToast('Request failed: ' + e.message, 'danger');
                    }
                },

                // 1-Click Fake Simulator Status Toggle
                async toggleFake(userId, nextVal) {
                    const fd = new FormData();
                    fd.append('ajax_action', 'toggle_fake');
                    fd.append('user_id', userId);
                    fd.append('is_fake', nextVal);

                    try {
                        const res = await fetch('fake_farmers_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(nextVal === 1 ? 'Marked as fake account!' : 'Marked as genuine farmer.', 'success');
                            setTimeout(() => location.reload(), 500);
                        } else {
                            this.showToast(json.error || 'Failed to update status.', 'danger');
                        }
                    } catch (e) {
                        this.showToast('Request failed: ' + e.message, 'danger');
                    }
                },

                // Single Delete with Custom Confirm Modal (Zero Native Popups)
                confirmDelete(userId, farmerName) {
                    this.askConfirm({
                        title: 'Delete Farmer Account?',
                        message: `Are you sure you want to remove '${farmerName}' (${userId}) from the Hyderabad registry?`,
                        icon: 'ph-trash',
                        iconColor: 'danger',
                        confirmText: 'Delete Farmer',
                        confirmClass: 'btn-danger',
                        onConfirm: async () => {
                            const fd = new FormData();
                            fd.append('ajax_action', 'delete_farmer');
                            fd.append('user_id', userId);

                            const res = await fetch('fake_farmers_dashboard.php', { method: 'POST', body: fd });
                            const json = await res.json();
                            if (json.success) {
                                this.showToast('Farmer deleted successfully.', 'success');
                                const row = document.getElementById('row-' + userId);
                                if (row) row.remove();
                            } else {
                                this.showToast(json.error || 'Delete failed', 'danger');
                            }
                        }
                    });
                },

                // Batch Quick Generator Execution
                async executeQuickGen() {
                    this.quickGenModal.loading = true;
                    const fd = new FormData();
                    fd.append('ajax_action', 'quick_generate');
                    fd.append('count', this.quickGenModal.count);

                    try {
                        const res = await fetch('fake_farmers_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        this.quickGenModal.loading = false;
                        if (json.success) {
                            this.quickGenModal.show = false;
                            this.showToast(`Successfully generated ${json.created_count} Hyderabad fake accounts!`, 'success');
                            setTimeout(() => location.reload(), 700);
                        } else {
                            this.showToast(json.error || 'Generation failed.', 'danger');
                        }
                    } catch (e) {
                        this.quickGenModal.loading = false;
                        this.showToast('Request failed: ' + e.message, 'danger');
                    }
                },

                // Selection & Bulk Actions
                toggleSelectAll(e) {
                    if (e.target.checked) {
                        const allBoxes = document.querySelectorAll('.data-table tbody input[type="checkbox"]');
                        this.selectedIds = Array.from(allBoxes).map(b => b.value);
                    } else {
                        this.selectedIds = [];
                    }
                },

                async bulkSetFake(newVal) {
                    if (this.selectedIds.length === 0) return;
                    const fd = new FormData();
                    fd.append('ajax_action', 'bulk_toggle_fake');
                    fd.append('user_ids', JSON.stringify(this.selectedIds));
                    fd.append('is_fake', newVal);

                    try {
                        const res = await fetch('fake_farmers_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(`Updated ${json.updated_count} farmers to ${newVal === 1 ? 'Fake' : 'Genuine'}.`, 'success');
                            setTimeout(() => location.reload(), 600);
                        } else {
                            this.showToast(json.error || 'Bulk update failed.', 'danger');
                        }
                    } catch (e) {
                        this.showToast('Error: ' + e.message, 'danger');
                    }
                },

                async bulkSetVerified(newVal) {
                    if (this.selectedIds.length === 0) return;
                    const fd = new FormData();
                    fd.append('ajax_action', 'bulk_toggle_verified');
                    fd.append('user_ids', JSON.stringify(this.selectedIds));
                    fd.append('is_verified', newVal);

                    try {
                        const res = await fetch('fake_farmers_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(`Updated ${json.updated_count} farmers verification status.`, 'success');
                            setTimeout(() => location.reload(), 600);
                        } else {
                            this.showToast(json.error || 'Bulk update failed.', 'danger');
                        }
                    } catch (e) {
                        this.showToast('Error: ' + e.message, 'danger');
                    }
                },

                bulkDelete() {
                    if (this.selectedIds.length === 0) return;
                    const count = this.selectedIds.length;
                    this.askConfirm({
                        title: `Delete ${count} Farmers?`,
                        message: `Are you sure you want to delete ${count} selected farmer records from Hyderabad?`,
                        icon: 'ph-trash',
                        iconColor: 'danger',
                        confirmText: `Delete ${count} Farmers`,
                        confirmClass: 'btn-danger',
                        onConfirm: async () => {
                            const fd = new FormData();
                            fd.append('ajax_action', 'bulk_delete');
                            fd.append('user_ids', JSON.stringify(this.selectedIds));

                            const res = await fetch('fake_farmers_dashboard.php', { method: 'POST', body: fd });
                            const json = await res.json();
                            if (json.success) {
                                this.showToast(`Deleted ${json.deleted_count} farmers.`, 'success');
                                setTimeout(() => location.reload(), 600);
                            } else {
                                this.showToast(json.error || 'Bulk delete failed.', 'danger');
                            }
                        }
                    });
                }
            };
        }
    </script>
</body>
</html>
