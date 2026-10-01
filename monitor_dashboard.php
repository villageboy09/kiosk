<?php
/**
 * ============================================================================
 * CropSync Central Operations & Ecosystem Monitor Dashboard
 * File: monitor_dashboard.php
 * 
 * Production-Grade Command Center & Farmers Management Hub
 * MODERN LIGHT THEME (Google Sans / Plus Jakarta Sans)
 * 100% ALPINE.JS CUSTOM DROPDOWNS ACROSS ALL MODULES
 * 
 * Modules:
 * 1. Overview: Executive KPI Pulse, 7-Day Velocity Chart & Live Activity Feed
 * 2. Farmers Hub: Full Farmer Registry & Management (Add, Edit, Delete, Toggle Fake/Genuine,
 *    Toggle Verified, Quick Batch Generator 1-10) with Regional Switcher (Hyderabad vs All)
 * 3. Agri Shop Orders: Product Enquiries & Inline Alpine Status Changer
 * 4. Seed Varieties Orders: Demands, Bookings & Inline Alpine Status Changer
 * 5. Mandi Market Prices: Commodity Lookups, Mandi Query Analytics
 * 6. Krishi Agri News: Reader Engagement, Likes & Comments
 * 7. Agri Reels Hub: Uploaded Video Reels, Metrics, Creators & Watch Analytics
 * ============================================================================
 */

error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

session_start();

// ----------------------------------------------------------------------------
// 1. Resilient Database Connection & Setup
// ----------------------------------------------------------------------------
$configPaths = [
    __DIR__ . '/config.php',
    __DIR__ . '/api/config.php',
    __DIR__ . '/../config.php',
    dirname(__DIR__) . '/config.php',
    'C:/Users/reddy/Downloads/Projects/kiosk/config.php'
];

foreach ($configPaths as $cp) {
    if (file_exists($cp)) {
        require_once $cp;
        break;
    }
}

$dbFatalError = null;

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
    } catch (Throwable $e) {
        $dbFatalError = $e->getMessage();
    }
}

if ($dbFatalError) {
    ?>
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>Database Offline - CropSync Monitor</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-slate-50 text-slate-800 flex items-center justify-center min-h-screen p-4 font-sans">
        <div class="max-w-md w-full bg-white border border-rose-200 rounded-2xl p-6 shadow-xl text-center">
            <div class="w-16 h-16 bg-rose-50 text-rose-500 rounded-full flex items-center justify-center mx-auto mb-4 text-2xl font-bold">!</div>
            <h1 class="text-xl font-bold text-slate-900 mb-2">Database Connection Failed</h1>
            <p class="text-sm text-slate-600 mb-6 leading-relaxed">Could not establish connection to the CropSync database. Check credentials in <code class="text-rose-600 font-mono">config.php</code>.</p>
            <div class="bg-slate-100 p-3 rounded-xl text-left text-xs font-mono text-rose-600 border border-slate-200 break-all mb-6">
                <?= htmlspecialchars($dbFatalError) ?>
            </div>
            <button onclick="location.reload()" class="w-full py-2.5 px-4 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-xl shadow-md transition-all">Retry Connection</button>
        </div>
    </body>
    </html>
    <?php
    exit;
}

try { $pdo->exec("SET NAMES utf8mb4"); } catch (Throwable $e) {}
try { $pdo->exec("SET time_zone = '+05:30'"); } catch (Throwable $e) {}

// Auto-migrate tables safely if not existing
try {
    // 1. farmer_interaction_logs
    $pdo->exec("CREATE TABLE IF NOT EXISTS `farmer_interaction_logs` (
        `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
        `user_id` VARCHAR(50) NULL,
        `phone_number` VARCHAR(20) NULL,
        `user_role` VARCHAR(50) DEFAULT 'farmer',
        `action_type` VARCHAR(50) NOT NULL,
        `item_type` VARCHAR(50) NOT NULL,
        `item_id` VARCHAR(50) NULL,
        `item_name` VARCHAR(255) NULL,
        `crop_name` VARCHAR(100) NULL,
        `metadata` JSON NULL,
        `ip_address` VARCHAR(45) NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_farmer_logs_phone` (`phone_number`),
        INDEX `idx_farmer_logs_action` (`action_type`, `item_type`),
        INDEX `idx_farmer_logs_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

    // 2. news_articles
    $pdo->exec("CREATE TABLE IF NOT EXISTS `news_articles` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `title` VARCHAR(255) NOT NULL,
        `summary` TEXT NOT NULL,
        `content` LONGTEXT NOT NULL,
        `category` VARCHAR(50) NOT NULL DEFAULT 'Govt Schemes',
        `image_url` VARCHAR(500) NULL,
        `author` VARCHAR(100) DEFAULT 'CropSync Desk',
        `source_name` VARCHAR(100) DEFAULT 'Krishi Jagran / Govt Portal',
        `views_count` INT DEFAULT 0,
        `likes_count` INT DEFAULT 0,
        `comments_count` INT DEFAULT 0,
        `is_featured` TINYINT(1) DEFAULT 0,
        `status` ENUM('published', 'draft', 'archived') DEFAULT 'published',
        `published_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_news_cat` (`category`),
        INDEX `idx_news_status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

    // 3. creators
    $pdo->exec("CREATE TABLE IF NOT EXISTS `creators` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `username` VARCHAR(100) NOT NULL UNIQUE,
        `display_name` VARCHAR(150) NOT NULL,
        `profile_image_url` VARCHAR(500) DEFAULT NULL,
        `is_verified` TINYINT(1) DEFAULT 0,
        `phone_number` VARCHAR(20) DEFAULT NULL,
        `bio` TEXT DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_creator_phone` (`phone_number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

    // 4. reels
    $pdo->exec("CREATE TABLE IF NOT EXISTS `reels` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `creator_id` INT NOT NULL,
        `video_url` VARCHAR(500) NOT NULL,
        `caption` TEXT NOT NULL,
        `music_title` VARCHAR(200) DEFAULT 'Original Audio',
        `phone_number` VARCHAR(20) NULL,
        `tags` VARCHAR(255) NULL,
        `views_count` INT DEFAULT 0,
        `likes_count` INT DEFAULT 0,
        `saves_count` INT DEFAULT 0,
        `comments_count` INT DEFAULT 0,
        `is_active` TINYINT(1) DEFAULT 1,
        `status` VARCHAR(50) DEFAULT 'published',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_reel_creator` (`creator_id`),
        INDEX `idx_reel_active` (`is_active`),
        INDEX `idx_reel_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

    // 5. reel_watch_analytics
    $pdo->exec("CREATE TABLE IF NOT EXISTS `reel_watch_analytics` (
        `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
        `reel_id` INT NOT NULL,
        `user_id` VARCHAR(50) NULL,
        `phone_number` VARCHAR(20) NULL,
        `watch_duration_seconds` DECIMAL(8,2) NOT NULL DEFAULT 0.00,
        `completed_loop` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_rwa_reel` (`reel_id`),
        INDEX `idx_rwa_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
} catch (Throwable $e) {}

// Dynamic schema detection on `users` table to guarantee ZERO sql errors
$userCols = [];
try {
    $colStmt = $pdo->query("SHOW COLUMNS FROM `users`");
    while ($col = $colStmt->fetch()) {
        $userCols[] = strtolower($col['Field']);
    }
} catch (Throwable $e) {}

// Safe column additions if permitted
if (!in_array('is_fake', $userCols)) {
    try { $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_fake` TINYINT(1) NOT NULL DEFAULT 0"); $userCols[] = 'is_fake'; } catch (Throwable $e) {}
}
if (!in_array('is_verified', $userCols)) {
    try { $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_verified` TINYINT(1) NOT NULL DEFAULT 1"); $userCols[] = 'is_verified'; } catch (Throwable $e) {}
}
if (!in_array('role', $userCols)) {
    try { $pdo->exec("ALTER TABLE `users` ADD COLUMN `role` VARCHAR(50) NOT NULL DEFAULT 'farmer'"); $userCols[] = 'role'; } catch (Throwable $e) {}
}
if (!in_array('is_deleted', $userCols)) {
    try { $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_deleted` TINYINT(1) NOT NULL DEFAULT 0"); $userCols[] = 'is_deleted'; } catch (Throwable $e) {}
}

$hasIsFake    = in_array('is_fake', $userCols);
$hasIsVer     = in_array('is_verified', $userCols);
$hasIsDel     = in_array('is_deleted', $userCols);
$hasRole      = in_array('role', $userCols);

// ----------------------------------------------------------------------------
// 2. Hyderabad Region Pools & Helpers
// ----------------------------------------------------------------------------
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
];

$NAME_POOL = [
    'Malla Reddy', 'Venkat Ramana', 'Laxmaiah Goud', 'Srinivasa Rao',
    'Prabhakar Reddy', 'Balaraju Kuruma', 'Narsimha Chary', 'Chandraiah Yadav',
    'Koteswara Rao', 'Anjaneyulu Nayak', 'Ravinder Reddy', 'Gangadhar Rao',
    'Shobhan Babu', 'Satyanarayana Murthy', 'Mallikarjun Goud', 'Sujatha Devi',
    'Lakshmi Bai', 'Radha Krishna', 'Venkateshwarlu', 'Thirupathi Reddy',
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

// ----------------------------------------------------------------------------
// 3. Regional Scoping & Parameters
// ----------------------------------------------------------------------------
$selectedRegion = $_GET['region_filter'] ?? 'hyd'; // 'hyd' or 'all'
$hydUserCondition = " (u.client_code = 'HYD001' OR u.region_id = 1 OR u.region LIKE '%Hyd%' OR u.district LIKE '%Hyd%' OR u.mandal LIKE '%Hyd%' OR u.village LIKE '%Hyd%') ";

// If user chose 'hyd', apply strict filter, otherwise 1=1
$scopeUserCondition = ($selectedRegion === 'hyd') ? $hydUserCondition : "1=1";

$activeTab = $_GET['tab'] ?? 'overview';
$validTabs = ['overview', 'farmers', 'shop_orders', 'seed_orders', 'market_prices', 'news_viewers', 'reel_viewers'];
if (!in_array($activeTab, $validTabs)) $activeTab = 'overview';

$range = $_GET['range'] ?? 'all';
$validRanges = ['all', 'today', 'yesterday', '7d', '30d'];
if (!in_array($range, $validRanges)) $range = 'all';

$searchQuery = trim($_GET['q'] ?? '');
$farmerFilter = $_GET['farmer_type'] ?? 'all'; // all, genuine, fake, verified, unverified

// Date filters
$dateFilterUsers = "1=1";
$dateFilterEnquiries = "1=1";
$dateFilterBookings = "1=1";
$dateFilterMarket = "1=1";
$dateFilterReels = "1=1";

if ($range === 'today') {
    $todayStr = date('Y-m-d');
    $dateFilterUsers = "DATE(u.created_at) = '$todayStr'";
    $dateFilterEnquiries = "DATE(e.enquiry_date) = '$todayStr'";
    $dateFilterBookings = "DATE(b.booking_timestamp) = '$todayStr'";
    $dateFilterMarket = "DATE(fil.created_at) = '$todayStr'";
    $dateFilterReels = "DATE(r.created_at) = '$todayStr'";
} elseif ($range === 'yesterday') {
    $yestStr = date('Y-m-d', strtotime('-1 day'));
    $dateFilterUsers = "DATE(u.created_at) = '$yestStr'";
    $dateFilterEnquiries = "DATE(e.enquiry_date) = '$yestStr'";
    $dateFilterBookings = "DATE(b.booking_timestamp) = '$yestStr'";
    $dateFilterMarket = "DATE(fil.created_at) = '$yestStr'";
    $dateFilterReels = "DATE(r.created_at) = '$yestStr'";
} elseif ($range === '7d') {
    $sevenDaysAgo = date('Y-m-d', strtotime('-7 days'));
    $dateFilterUsers = "DATE(u.created_at) >= '$sevenDaysAgo'";
    $dateFilterEnquiries = "DATE(e.enquiry_date) >= '$sevenDaysAgo'";
    $dateFilterBookings = "DATE(b.booking_timestamp) >= '$sevenDaysAgo'";
    $dateFilterMarket = "DATE(fil.created_at) >= '$sevenDaysAgo'";
    $dateFilterReels = "DATE(r.created_at) >= '$sevenDaysAgo'";
} elseif ($range === '30d') {
    $thirtyDaysAgo = date('Y-m-d', strtotime('-30 days'));
    $dateFilterUsers = "DATE(u.created_at) >= '$thirtyDaysAgo'";
    $dateFilterEnquiries = "DATE(e.enquiry_date) >= '$thirtyDaysAgo'";
    $dateFilterBookings = "DATE(b.booking_timestamp) >= '$thirtyDaysAgo'";
    $dateFilterMarket = "DATE(fil.created_at) >= '$thirtyDaysAgo'";
    $dateFilterReels = "DATE(r.created_at) >= '$thirtyDaysAgo'";
}

// ----------------------------------------------------------------------------
// 4. AJAX Endpoints
// ----------------------------------------------------------------------------

// A. Image Upload AJAX
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['ajax_upload'])) {
    header('Content-Type: application/json; charset=utf-8');
    $url = uploadFarmerAvatarFile('file', 'profile_images');
    if (!empty($url)) {
        echo json_encode(['success' => true, 'url' => $url]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Upload failed.']);
    }
    exit;
}

// B. Live Pulse Heartbeat
if (isset($_GET['ajax']) && $_GET['ajax'] === 'live_pulse') {
    header('Content-Type: application/json; charset=utf-8');
    try {
        $today = date('Y-m-d');
        $liveUsersToday = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition AND DATE(u.created_at) = '$today'")->fetchColumn());
        $liveEnquiriesToday = intval($pdo->query("SELECT COUNT(*) FROM enquiries e JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number) WHERE $scopeUserCondition AND DATE(e.enquiry_date) = '$today'")->fetchColumn());
        $liveBookingsToday = intval($pdo->query("SELECT COUNT(*) FROM bookings b LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number) WHERE ($scopeUserCondition OR b.user_region = 'Hyderabad') AND DATE(b.booking_timestamp) = '$today'")->fetchColumn());
        $liveMarketLogsToday = intval($pdo->query("SELECT COUNT(*) FROM farmer_interaction_logs fil LEFT JOIN users u ON (fil.phone_number = u.phone_number OR fil.user_id = u.user_id) WHERE (fil.item_type IN ('market_prices', 'market', 'commodity', 'mandi')) AND DATE(fil.created_at) = '$today'")->fetchColumn());
        $liveNewsViewsTotal = intval($pdo->query("SELECT COALESCE(SUM(views_count), 0) FROM news_articles")->fetchColumn());
        $liveReelsTotal = intval($pdo->query("SELECT COUNT(*) FROM reels")->fetchColumn());

        // Latest activity events
        $pulseSql = "
            (SELECT 'user_reg' as event_type, u.name as title, u.phone_number as subtitle, COALESCE(u.mandal, 'Hyderabad') as tag, u.created_at 
             FROM users u WHERE $scopeUserCondition ORDER BY u.created_at DESC LIMIT 4)
            UNION ALL
            (SELECT 'shop_order' as event_type, CONCAT('Shop Order #', e.enquiry_id) as title, COALESCE(u.name, e.farmer_id) as subtitle, e.status as tag, e.enquiry_date as created_at 
             FROM enquiries e JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number) WHERE $scopeUserCondition ORDER BY e.enquiry_date DESC LIMIT 4)
            UNION ALL
            (SELECT 'seed_booking' as event_type, CONCAT('Seed Order #', b.booking_id) as title, CONCAT(b.quantity_kg, ' kg') as subtitle, b.booking_status as tag, b.booking_timestamp as created_at 
             FROM bookings b LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number) WHERE ($scopeUserCondition OR b.user_region = 'Hyderabad') ORDER BY b.booking_timestamp DESC LIMIT 4)
            UNION ALL
            (SELECT 'market_query' as event_type, COALESCE(fil.item_name, 'Mandi Price Lookup') as title, COALESCE(fil.phone_number, 'Farmer') as subtitle, COALESCE(fil.crop_name, 'Mandi') as tag, fil.created_at 
             FROM farmer_interaction_logs fil LEFT JOIN users u ON (fil.phone_number = u.phone_number OR fil.user_id = u.user_id) WHERE fil.item_type IN ('market_prices', 'market', 'commodity', 'mandi') ORDER BY fil.created_at DESC LIMIT 4)
            ORDER BY created_at DESC LIMIT 8
        ";
        $pulseEvents = $pdo->query($pulseSql)->fetchAll();

        echo json_encode([
            'success' => true,
            'timestamp' => date('H:i:s'),
            'metrics' => [
                'users_today' => $liveUsersToday,
                'shop_orders_today' => $liveEnquiriesToday,
                'seed_orders_today' => $liveBookingsToday,
                'market_queries_today' => $liveMarketLogsToday,
                'news_views_total' => $liveNewsViewsTotal,
                'reels_total' => $liveReelsTotal,
            ],
            'events' => $pulseEvents
        ]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit;
}

// C. Farmer AJAX Operations
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['ajax_action'])) {
    header('Content-Type: application/json; charset=utf-8');
    $ajaxAction = $_POST['ajax_action'];

    try {
        if ($ajaxAction === 'toggle_fake') {
            $userId = trim($_POST['user_id'] ?? '');
            $newFake = intval($_POST['is_fake'] ?? 0);
            if (!empty($userId)) {
                $stmt = $pdo->prepare("UPDATE users SET is_fake = ? WHERE user_id = ?");
                $stmt->execute([$newFake, $userId]);
                echo json_encode(['success' => true, 'user_id' => $userId, 'is_fake' => $newFake, 'message' => 'Status updated']);
            }
            exit;
        }

        if ($ajaxAction === 'toggle_verified') {
            $userId = trim($_POST['user_id'] ?? '');
            $newVer = intval($_POST['is_verified'] ?? 0);
            if (!empty($userId)) {
                $stmt = $pdo->prepare("UPDATE users SET is_verified = ? WHERE user_id = ?");
                $stmt->execute([$newVer, $userId]);
                echo json_encode(['success' => true, 'user_id' => $userId, 'is_verified' => $newVer, 'message' => 'Verification toggled']);
            }
            exit;
        }

        if ($ajaxAction === 'delete_farmer') {
            $userId = trim($_POST['user_id'] ?? '');
            if (!empty($userId)) {
                if ($hasIsDel) {
                    $stmt = $pdo->prepare("UPDATE users SET is_deleted = 1 WHERE user_id = ?");
                    $stmt->execute([$userId]);
                } else {
                    $stmt = $pdo->prepare("DELETE FROM users WHERE user_id = ?");
                    $stmt->execute([$userId]);
                }
                echo json_encode(['success' => true, 'user_id' => $userId, 'message' => "Farmer removed"]);
            }
            exit;
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

                $chk = $pdo->prepare("SELECT user_id FROM users WHERE user_id = ? OR phone_number = ? LIMIT 1");
                $chk->execute([$phone, $phone]);
                if ($chk->fetch()) {
                    $phone = generateRealisticIndianPhone();
                }

                $stmt = $pdo->prepare("
                    INSERT INTO users (
                        user_id, name, phone_number, region, district, mandal, village,
                        client_code, region_id, role, profile_image_url,
                        is_verified, is_fake, is_deleted, created_at
                    ) VALUES (
                        ?, ?, ?, 'Hyderabad', 'Hyderabad', ?, ?,
                        'HYD001', 1, 'farmer', ?,
                        1, 1, 0, NOW()
                    )
                ");
                $stmt->execute([$phone, $name, $phone, $mandal, $village, $avatar]);
                $created++;
            }

            echo json_encode(['success' => true, 'created_count' => $created, 'message' => "Generated $created Hyderabad farmer accounts!"]);
            exit;
        }
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        exit;
    }
}

// D. Status Changers (Shop & Seed) via AJAX
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    header('Content-Type: application/json; charset=utf-8');
    $action = $_POST['action'];

    if ($action === 'update_enquiry_status') {
        $enquiryId = intval($_POST['enquiry_id'] ?? 0);
        $newStatus = trim($_POST['status'] ?? '');
        $allowed = ['Interested', 'Contacted', 'Purchased'];
        if ($enquiryId > 0 && in_array($newStatus, $allowed)) {
            try {
                $stmt = $pdo->prepare("UPDATE enquiries SET status = ?, updated_at = NOW() WHERE enquiry_id = ?");
                $stmt->execute([$newStatus, $enquiryId]);
                echo json_encode(['success' => true, 'message' => "Order #$enquiryId updated to $newStatus"]);
            } catch (Throwable $e) {
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            exit;
        }
    }

    if ($action === 'update_booking_status') {
        $bookingId = trim($_POST['booking_id'] ?? '');
        $newStatus = trim($_POST['status'] ?? '');
        $allowed = ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'];
        if (!empty($bookingId) && in_array($newStatus, $allowed)) {
            try {
                $stmt = $pdo->prepare("UPDATE bookings SET booking_status = ? WHERE booking_id = ?");
                $stmt->execute([$newStatus, $bookingId]);
                echo json_encode(['success' => true, 'message' => "Seed Order $bookingId updated to $newStatus"]);
            } catch (Throwable $e) {
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            exit;
        }
    }
}

// E. Standard Form POST (Add / Edit Farmer)
$formFeedback = null;
$formFeedbackType = 'info';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($_POST['ajax_action']) && !isset($_GET['ajax_upload']) && !isset($_POST['action'])) {
    $postAction = $_POST['form_action'] ?? '';

    if ($postAction === 'create_farmer') {
        $name = trim($_POST['name'] ?? '');
        $phone = trim($_POST['phone_number'] ?? '');
        $mandal = trim($_POST['mandal'] ?? 'Khairatabad');
        $village = trim($_POST['village'] ?? 'Hyderabad');
        $isVerified = isset($_POST['is_verified']) ? intval($_POST['is_verified']) : 1;
        $isFake = isset($_POST['is_fake']) ? intval($_POST['is_fake']) : 1;
        $profileImageUrl = trim($_POST['profile_image_url'] ?? '');

        $uploaded = uploadFarmerAvatarFile('avatar_file', 'profile_images');
        if (!empty($uploaded)) $profileImageUrl = $uploaded;
        if (empty($profileImageUrl)) $profileImageUrl = $AVATAR_PRESETS[array_rand($AVATAR_PRESETS)];
        if (empty($phone)) $phone = generateRealisticIndianPhone();
        $userId = $phone;

        try {
            $chk = $pdo->prepare("SELECT user_id FROM users WHERE user_id = ? OR phone_number = ? LIMIT 1");
            $chk->execute([$userId, $phone]);
            if ($chk->fetch()) {
                $formFeedback = "Phone number $phone already exists.";
                $formFeedbackType = 'danger';
            } else {
                $stmt = $pdo->prepare("
                    INSERT INTO users (
                        user_id, name, phone_number, region, district, mandal, village,
                        client_code, region_id, role, profile_image_url,
                        is_verified, is_fake, is_deleted, created_at
                    ) VALUES (
                        ?, ?, ?, 'Hyderabad', 'Hyderabad', ?, ?,
                        'HYD001', 1, 'farmer', ?,
                        ?, ?, 0, NOW()
                    )
                ");
                $stmt->execute([$userId, $name, $phone, $mandal, $village, $profileImageUrl, $isVerified, $isFake]);
                $formFeedback = "Farmer '{$name}' created successfully!";
                $formFeedbackType = 'success';
            }
        } catch (Throwable $e) {
            $formFeedback = "Error: " . $e->getMessage();
            $formFeedbackType = 'danger';
        }
    }

    if ($postAction === 'edit_farmer') {
        $userId = trim($_POST['user_id'] ?? '');
        $name = trim($_POST['name'] ?? '');
        $phone = trim($_POST['phone_number'] ?? '');
        $mandal = trim($_POST['mandal'] ?? 'Khairatabad');
        $village = trim($_POST['village'] ?? 'Hyderabad');
        $isVerified = isset($_POST['is_verified']) ? intval($_POST['is_verified']) : 0;
        $isFake = isset($_POST['is_fake']) ? intval($_POST['is_fake']) : 1;
        $profileImageUrl = trim($_POST['profile_image_url'] ?? '');

        $uploaded = uploadFarmerAvatarFile('avatar_file', 'profile_images');
        if (!empty($uploaded)) $profileImageUrl = $uploaded;

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
            $formFeedback = "Farmer '{$name}' updated successfully!";
            $formFeedbackType = 'success';
        } catch (Throwable $e) {
            $formFeedback = "Error updating: " . $e->getMessage();
            $formFeedbackType = 'danger';
        }
    }
}

// ----------------------------------------------------------------------------
// 5. Aggregated KPIs
// ----------------------------------------------------------------------------
$kpis = [
    'users_total' => 0,
    'users_today' => 0,
    'users_genuine' => 0,
    'users_fake' => 0,
    'users_verified' => 0,
    'users_unverified' => 0,

    'shop_orders_total' => 0,
    'shop_orders_purchased' => 0,
    'shop_orders_value_est' => 0,

    'seed_bookings_total' => 0,
    'seed_bookings_delivered' => 0,
    'seed_bookings_total_kg' => 0,
    'seed_bookings_value' => 0,

    'market_lookups_total' => 0,
    'market_unique_farmers' => 0,
    'market_top_commodity' => 'Chilli Red',

    'news_articles_total' => 0,
    'news_views_total' => 0,
    'news_likes_total' => 0,

    'reels_total' => 0,
    'reels_views_total' => 0,
    'reels_likes_total' => 0,
];

try {
    $todayDate = date('Y-m-d');
    $delClause = $hasIsDel ? " AND (u.is_deleted = 0 OR u.is_deleted IS NULL)" : "";

    // 1. Farmers
    $kpis['users_total'] = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition $delClause")->fetchColumn());
    $kpis['users_today'] = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition $delClause AND DATE(u.created_at) = '$todayDate'")->fetchColumn());
    
    if ($hasIsFake) {
        $kpis['users_genuine'] = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition $delClause AND (u.is_fake = 0 OR u.is_fake IS NULL)")->fetchColumn());
        $kpis['users_fake'] = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition $delClause AND u.is_fake = 1")->fetchColumn());
    } else {
        $kpis['users_genuine'] = $kpis['users_total'];
    }

    if ($hasIsVer) {
        $kpis['users_verified'] = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition $delClause AND u.is_verified = 1")->fetchColumn());
        $kpis['users_unverified'] = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition $delClause AND (u.is_verified = 0 OR u.is_verified IS NULL)")->fetchColumn());
    }

    // 2. Shop Orders
    $kpis['shop_orders_total'] = intval($pdo->query("SELECT COUNT(*) FROM enquiries e JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number) WHERE $scopeUserCondition")->fetchColumn());
    $kpis['shop_orders_purchased'] = intval($pdo->query("SELECT COUNT(*) FROM enquiries e JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number) WHERE $scopeUserCondition AND e.status = 'Purchased'")->fetchColumn());
    $valStmt = $pdo->query("SELECT COALESCE(SUM(p.price), 0) FROM enquiries e JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number) JOIN products p ON e.product_id = p.product_id WHERE $scopeUserCondition AND e.status = 'Purchased'");
    $kpis['shop_orders_value_est'] = floatval($valStmt->fetchColumn());

    // 3. Seed Demands
    $kpis['seed_bookings_total'] = intval($pdo->query("SELECT COUNT(*) FROM bookings b LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number) WHERE ($scopeUserCondition OR b.user_region = 'Hyderabad')")->fetchColumn());
    $kpis['seed_bookings_delivered'] = intval($pdo->query("SELECT COUNT(*) FROM bookings b LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number) WHERE ($scopeUserCondition OR b.user_region = 'Hyderabad') AND b.booking_status = 'delivered'")->fetchColumn());
    $seedVolStmt = $pdo->query("SELECT COALESCE(SUM(quantity_kg), 0), COALESCE(SUM(total_price), 0) FROM bookings b LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number) WHERE ($scopeUserCondition OR b.user_region = 'Hyderabad') AND b.booking_status != 'cancelled'")->fetch(PDO::FETCH_NUM);
    $kpis['seed_bookings_total_kg'] = floatval($seedVolStmt[0] ?? 0);
    $kpis['seed_bookings_value'] = floatval($seedVolStmt[1] ?? 0);

    // 4. Mandi Queries
    $kpis['market_lookups_total'] = intval($pdo->query("SELECT COUNT(*) FROM farmer_interaction_logs fil LEFT JOIN users u ON (fil.phone_number = u.phone_number OR fil.user_id = u.user_id) WHERE fil.item_type IN ('market_prices', 'market', 'commodity', 'mandi')")->fetchColumn());
    $kpis['market_unique_farmers'] = intval($pdo->query("SELECT COUNT(DISTINCT fil.phone_number) FROM farmer_interaction_logs fil WHERE fil.item_type IN ('market_prices', 'market', 'commodity', 'mandi') AND fil.phone_number IS NOT NULL AND fil.phone_number != ''")->fetchColumn());
    $topComm = $pdo->query("SELECT crop_name, COUNT(*) as cnt FROM farmer_interaction_logs WHERE item_type IN ('market_prices', 'market', 'commodity', 'mandi') AND crop_name IS NOT NULL AND crop_name != '' GROUP BY crop_name ORDER BY cnt DESC LIMIT 1")->fetch();
    if ($topComm && !empty($topComm['crop_name'])) {
        $kpis['market_top_commodity'] = $topComm['crop_name'];
    }

    // 5. News
    $kpis['news_articles_total'] = intval($pdo->query("SELECT COUNT(*) FROM news_articles")->fetchColumn());
    $kpis['news_views_total'] = intval($pdo->query("SELECT COALESCE(SUM(views_count), 0) FROM news_articles")->fetchColumn());
    $kpis['news_likes_total'] = intval($pdo->query("SELECT COALESCE(SUM(likes_count), 0) FROM news_articles")->fetchColumn());

    // 6. Reels (FETCHING REAL REELS DATA)
    $kpis['reels_total'] = intval($pdo->query("SELECT COUNT(*) FROM reels")->fetchColumn());
    $kpis['reels_views_total'] = intval($pdo->query("SELECT COALESCE(SUM(views_count), 0) FROM reels")->fetchColumn());
    $kpis['reels_likes_total'] = intval($pdo->query("SELECT COALESCE(SUM(likes_count), 0) FROM reels")->fetchColumn());

} catch (Throwable $e) {}

// ----------------------------------------------------------------------------
// 6. Data Queries (Farmers, Orders, Seeds, Mandi, News, Reels)
// ----------------------------------------------------------------------------
$farmersList = [];
$shopOrdersList = [];
$seedOrdersList = [];
$marketInteractionsList = [];
$newsArticlesList = [];
$reelsList = [];

// A. Farmers Tab
if ($activeTab === 'farmers' || $activeTab === 'overview') {
    $delWhere = $hasIsDel ? " AND (u.is_deleted = 0 OR u.is_deleted IS NULL)" : "";
    $fSql = "SELECT u.* FROM users u WHERE $scopeUserCondition $delWhere AND $dateFilterUsers";
    $fParams = [];

    if ($hasIsFake) {
        if ($farmerFilter === 'genuine') {
            $fSql .= " AND (u.is_fake = 0 OR u.is_fake IS NULL)";
        } elseif ($farmerFilter === 'fake') {
            $fSql .= " AND u.is_fake = 1";
        }
    }
    if ($hasIsVer) {
        if ($farmerFilter === 'verified') {
            $fSql .= " AND u.is_verified = 1";
        } elseif ($farmerFilter === 'unverified') {
            $fSql .= " AND (u.is_verified = 0 OR u.is_verified IS NULL)";
        }
    }

    if (!empty($searchQuery)) {
        $fSql .= " AND (u.name LIKE ? OR u.phone_number LIKE ? OR u.user_id LIKE ?)";
        $like = "%$searchQuery%";
        $fParams = [$like, $like, $like];
    }

    $fSql .= " ORDER BY u.created_at DESC LIMIT 150";
    try {
        $fStmt = $pdo->prepare($fSql);
        $fStmt->execute($fParams);
        $farmersList = $fStmt->fetchAll();
    } catch (Throwable $e) {
        $farmersList = [];
    }
}

// B. Agri Shop Orders Tab
if ($activeTab === 'shop_orders' || $activeTab === 'overview') {
    $eStatus = $_GET['order_status'] ?? '';
    $eSql = "SELECT e.*, p.product_name, p.product_name_en, p.price, p.category, p.image_url_1, 
                    a.advertiser_name, u.name as farmer_name, u.phone_number as farmer_phone,
                    COALESCE(u.mandal, 'Hyderabad') as farmer_mandal
             FROM enquiries e
             JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number)
             LEFT JOIN products p ON e.product_id = p.product_id
             LEFT JOIN advertisers a ON e.advertiser_id = a.advertiser_id
             WHERE $scopeUserCondition AND $dateFilterEnquiries";
    $eParams = [];
    if (!empty($eStatus)) {
        $eSql .= " AND e.status = ?";
        $eParams[] = $eStatus;
    }
    if (!empty($searchQuery)) {
        $eSql .= " AND (p.product_name LIKE ? OR p.product_name_en LIKE ? OR u.name LIKE ?)";
        $like = "%$searchQuery%";
        $eParams = array_merge($eParams, [$like, $like, $like]);
    }
    $eSql .= " ORDER BY e.enquiry_id DESC LIMIT 100";
    try {
        $eStmt = $pdo->prepare($eSql);
        $eStmt->execute($eParams);
        $shopOrdersList = $eStmt->fetchAll();
    } catch (Throwable $e) {
        $shopOrdersList = [];
    }
}

// C. Seed Varieties Orders Tab
if ($activeTab === 'seed_orders' || $activeTab === 'overview') {
    $bStatus = $_GET['booking_status'] ?? '';
    $bSql = "SELECT b.*, sv.variety_name_en, sv.variety_name_te, sv.crop_name, sv.image_url as seed_image,
                    u.name as farmer_name, u.phone_number as farmer_phone, vl.packet_size,
                    COALESCE(u.mandal, 'Hyderabad') as farmer_mandal
             FROM bookings b
             LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number)
             LEFT JOIN seed_varieties sv ON b.seed_variety_id = sv.id
             LEFT JOIN vendor_listings vl ON b.listing_id = vl.id
             WHERE ($scopeUserCondition OR b.user_region = 'Hyderabad') AND $dateFilterBookings";
    $bParams = [];
    if (!empty($bStatus)) {
        $bSql .= " AND b.booking_status = ?";
        $bParams[] = $bStatus;
    }
    if (!empty($searchQuery)) {
        $bSql .= " AND (b.booking_id LIKE ? OR sv.variety_name_en LIKE ? OR u.name LIKE ?)";
        $like = "%$searchQuery%";
        $bParams = array_merge($bParams, [$like, $like, $like]);
    }
    $bSql .= " ORDER BY b.booking_timestamp DESC LIMIT 100";
    try {
        $bStmt = $pdo->prepare($bSql);
        $bStmt->execute($bParams);
        $seedOrdersList = $bStmt->fetchAll();
    } catch (Throwable $e) {
        $seedOrdersList = [];
    }
}

// D. Mandi Market Prices Tab
if ($activeTab === 'market_prices' || $activeTab === 'overview') {
    $mSql = "SELECT fil.*, u.name as farmer_name, COALESCE(u.mandal, 'Hyderabad') as user_mandal
             FROM farmer_interaction_logs fil
             LEFT JOIN users u ON (fil.phone_number = u.phone_number OR fil.user_id = u.user_id)
             WHERE fil.item_type IN ('market_prices', 'market', 'commodity', 'mandi') AND $dateFilterMarket";
    $mParams = [];
    if (!empty($searchQuery)) {
        $mSql .= " AND (fil.item_name LIKE ? OR fil.crop_name LIKE ? OR fil.phone_number LIKE ?)";
        $like = "%$searchQuery%";
        $mParams = [$like, $like, $like];
    }
    $mSql .= " ORDER BY fil.created_at DESC LIMIT 100";
    try {
        $mStmt = $pdo->prepare($mSql);
        $mStmt->execute($mParams);
        $marketInteractionsList = $mStmt->fetchAll();
    } catch (Throwable $e) {
        $marketInteractionsList = [];
    }
}

// E. Agri News Tab
if ($activeTab === 'news_viewers' || $activeTab === 'overview') {
    $nSql = "SELECT na.* FROM news_articles na WHERE 1=1";
    $nParams = [];
    if (!empty($searchQuery)) {
        $nSql .= " AND (na.title LIKE ? OR na.category LIKE ? OR na.author LIKE ?)";
        $like = "%$searchQuery%";
        $nParams = [$like, $like, $like];
    }
    $nSql .= " ORDER BY na.views_count DESC, na.id DESC LIMIT 100";
    try {
        $nStmt = $pdo->prepare($nSql);
        $nStmt->execute($nParams);
        $newsArticlesList = $nStmt->fetchAll();
    } catch (Throwable $e) {
        $newsArticlesList = [];
    }
}

// F. Agri Reels Hub (DIRECT FETCH FROM REELS TABLE)
if ($activeTab === 'reel_viewers' || $activeTab === 'overview') {
    $rSql = "SELECT r.*, c.display_name AS creator_name, c.username AS creator_username, c.profile_image_url AS creator_avatar
             FROM reels r
             LEFT JOIN creators c ON r.creator_id = c.id
             WHERE 1=1 AND $dateFilterReels";
    $rParams = [];
    if (!empty($searchQuery)) {
        $rSql .= " AND (r.caption LIKE ? OR r.tags LIKE ? OR r.music_title LIKE ? OR c.display_name LIKE ?)";
        $like = "%$searchQuery%";
        $rParams = [$like, $like, $like, $like];
    }
    $rSql .= " ORDER BY r.id DESC LIMIT 100";
    try {
        $rStmt = $pdo->prepare($rSql);
        $rStmt->execute($rParams);
        $reelsList = $rStmt->fetchAll();
    } catch (Throwable $e) {
        $reelsList = [];
    }
}

// ----------------------------------------------------------------------------
// 7. 7-Day Velocity Data
// ----------------------------------------------------------------------------
$chartDays = [];
$chartUsersData = [];
$chartShopData = [];
$chartSeedData = [];
$chartMarketData = [];
$chartReelData = [];

for ($i = 6; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i days"));
    $chartDays[] = date('D, M j', strtotime($d));

    $uCount = 0; $eCount = 0; $bCount = 0; $mCount = 0; $rCount = 0;
    try {
        $uCount = intval($pdo->query("SELECT COUNT(*) FROM users u WHERE $scopeUserCondition AND DATE(u.created_at) = '$d'")->fetchColumn());
        $eCount = intval($pdo->query("SELECT COUNT(*) FROM enquiries e JOIN users u ON (e.farmer_id = u.user_id OR e.farmer_id = u.phone_number) WHERE $scopeUserCondition AND DATE(e.enquiry_date) = '$d'")->fetchColumn());
        $bCount = intval($pdo->query("SELECT COUNT(*) FROM bookings b LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number) WHERE ($scopeUserCondition OR b.user_region = 'Hyderabad') AND DATE(b.booking_timestamp) = '$d'")->fetchColumn());
        $mCount = intval($pdo->query("SELECT COUNT(*) FROM farmer_interaction_logs fil WHERE fil.item_type IN ('market_prices', 'market', 'commodity', 'mandi') AND DATE(fil.created_at) = '$d'")->fetchColumn());
        $rCount = intval($pdo->query("SELECT COUNT(*) FROM reels r WHERE DATE(r.created_at) = '$d'")->fetchColumn());
    } catch (Throwable $e) {}

    $chartUsersData[] = $uCount;
    $chartShopData[] = $eCount;
    $chartSeedData[] = $bCount;
    $chartMarketData[] = $mCount;
    $chartReelData[] = $rCount;
}

function formatInr($num) {
    return '₹' . number_format($num, 2);
}

function timeAgoFormatted($datetime) {
    if (empty($datetime)) return 'N/A';
    $time = strtotime($datetime);
    if (!$time) return 'N/A';
    $diff = time() - $time;
    if ($diff < 60) return $diff . 's ago';
    if ($diff < 3600) return floor($diff / 60) . 'm ago';
    if ($diff < 86400) return floor($diff / 3600) . 'h ago';
    if ($diff < 604800) return floor($diff / 86400) . 'd ago';
    return date('M j, Y', $time);
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CropSync Operations Command & Farmers Hub</title>

    <!-- Google Fonts: Plus Jakarta Sans & JetBrains Mono -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">

    <!-- Phosphor Icons -->
    <script src="https://unpkg.com/@phosphor-icons/web"></script>

    <!-- Tailwind CSS (Light Mode Architecture) -->
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['"Plus Jakarta Sans"', 'sans-serif'],
                        mono: ['"JetBrains Mono"', 'monospace'],
                    },
                    colors: {
                        brand: {
                            50: '#ecfdf5',
                            100: '#d1fae5',
                            500: '#10b981',
                            600: '#059669',
                            700: '#047857',
                        }
                    }
                }
            }
        }
    </script>

    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

    <!-- Alpine.js -->
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.13.5/dist/cdn.min.js"></script>

    <style>
        [x-cloak] { display: none !important; }
        body { background-color: #f8fafc; color: #1e293b; }
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: #f1f5f9; }
        ::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
        .light-card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.05), 0 1px 2px -1px rgba(0, 0, 0, 0.05);
        }
        .pulse-dot {
            box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
            animation: pulse-ring 2s infinite;
        }
        @keyframes pulse-ring {
            0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
            70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
            100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
        }
    </style>
</head>
<body class="bg-slate-50 text-slate-800 min-h-screen font-sans antialiased"
      x-data="monitorApp()" 
      x-init="initDashboard()">

    <!-- TOP HEADER (LIGHT THEME) -->
    <header class="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-sm">
        <div class="max-w-[1780px] mx-auto px-4 sm:px-6 h-16 flex items-center justify-between gap-4">
            
            <!-- Brand & Region Identifier -->
            <div class="flex items-center gap-4">
                <a href="monitor_dashboard.php" class="flex items-center gap-3 group">
                    <div class="w-10 h-10 rounded-xl bg-emerald-600 flex items-center justify-center text-white shadow-md shadow-emerald-500/20 group-hover:scale-105 transition-transform">
                        <i class="ph-bold ph-chart-line-up text-xl"></i>
                    </div>
                    <div>
                        <div class="flex items-center gap-2">
                            <span class="font-bold text-base tracking-tight text-slate-900">CropSync</span>
                            <span class="text-[10px] uppercase font-bold tracking-widest px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700 border border-emerald-200">Central Monitor</span>
                        </div>
                        <div class="flex items-center gap-2 mt-0.5">
                            <span class="w-2 h-2 rounded-full bg-emerald-500 pulse-dot inline-block"></span>
                            <span class="text-xs font-semibold text-slate-600"><?= $selectedRegion === 'hyd' ? 'Hyderabad Region (HYD001)' : 'All Agricultural Regions' ?></span>
                        </div>
                    </div>
                </a>
            </div>

            <!-- Global Alpine.js Dropdowns Bar -->
            <div class="flex items-center gap-3">
                
                <!-- 1. Alpine Dropdown: Region Filter -->
                <div class="relative" x-data="{ open: false }" @click.outside="open = false">
                    <button type="button" @click="open = !open" class="px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 border border-slate-300 text-xs font-semibold text-slate-700 flex items-center gap-2 transition-colors">
                        <i class="ph-bold ph-map-pin text-emerald-600"></i>
                        <span><?= $selectedRegion === 'hyd' ? 'Hyderabad Only' : 'All Regions' ?></span>
                        <i class="ph ph-caret-down text-slate-400 text-xs transition-transform" :class="{ 'rotate-180': open }"></i>
                    </button>
                    <div x-cloak x-show="open" x-transition class="absolute right-0 mt-1.5 w-48 bg-white border border-slate-200 rounded-xl shadow-lg py-1.5 z-50 text-xs">
                        <a href="monitor_dashboard.php?tab=<?= $activeTab ?>&range=<?= $range ?>&region_filter=hyd" class="flex items-center justify-between px-3 py-2 hover:bg-emerald-50 text-slate-700 font-medium">
                            <span class="flex items-center gap-2">
                                <i class="ph-bold ph-check text-emerald-600" style="visibility: <?= $selectedRegion === 'hyd' ? 'visible' : 'hidden' ?>;"></i>
                                Hyderabad (HYD001)
                            </span>
                            <span class="px-1.5 py-0.5 rounded bg-emerald-100 text-emerald-800 text-[10px] font-mono">Scoped</span>
                        </a>
                        <a href="monitor_dashboard.php?tab=<?= $activeTab ?>&range=<?= $range ?>&region_filter=all" class="flex items-center justify-between px-3 py-2 hover:bg-emerald-50 text-slate-700 font-medium border-t border-slate-100">
                            <span class="flex items-center gap-2">
                                <i class="ph-bold ph-check text-emerald-600" style="visibility: <?= $selectedRegion === 'all' ? 'visible' : 'hidden' ?>;"></i>
                                All Regions
                            </span>
                            <span class="px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 text-[10px] font-mono">Global</span>
                        </a>
                    </div>
                </div>

                <!-- 2. Alpine Dropdown: Time Range -->
                <div class="relative" x-data="{ open: false }" @click.outside="open = false">
                    <button type="button" @click="open = !open" class="px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 border border-slate-300 text-xs font-semibold text-slate-700 flex items-center gap-2 transition-colors">
                        <i class="ph-bold ph-calendar text-slate-500"></i>
                        <span>
                            <?= ['all' => 'All Time', 'today' => 'Today', 'yesterday' => 'Yesterday', '7d' => 'Last 7 Days', '30d' => 'Last 30 Days'][$range] ?? 'All Time' ?>
                        </span>
                        <i class="ph ph-caret-down text-slate-400 text-xs transition-transform" :class="{ 'rotate-180': open }"></i>
                    </button>
                    <div x-cloak x-show="open" x-transition class="absolute right-0 mt-1.5 w-40 bg-white border border-slate-200 rounded-xl shadow-lg py-1.5 z-50 text-xs">
                        <?php foreach (['all' => 'All Time', 'today' => 'Today', 'yesterday' => 'Yesterday', '7d' => 'Last 7 Days', '30d' => 'Last 30 Days'] as $rKey => $rLabel): ?>
                            <a href="monitor_dashboard.php?tab=<?= $activeTab ?>&range=<?= $rKey ?>&region_filter=<?= $selectedRegion ?>" class="flex items-center justify-between px-3 py-2 hover:bg-slate-50 text-slate-700 font-medium <?= $range === $rKey ? 'bg-emerald-50 text-emerald-700 font-bold' : '' ?>">
                                <span><?= $rLabel ?></span>
                                <?php if ($range === $rKey): ?><i class="ph-bold ph-check text-emerald-600"></i><?php endif; ?>
                            </a>
                        <?php endforeach; ?>
                    </div>
                </div>

                <!-- Navigation Cross-Links -->
                <a href="shop_seeds_dashboard.php" class="hidden md:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 border border-slate-300 text-xs font-semibold text-slate-700 transition-colors">
                    <i class="ph-bold ph-storefront text-emerald-600"></i>
                    <span>Catalog Hub</span>
                </a>

                <a href="news_reels_dashboard.php" class="hidden md:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 border border-slate-300 text-xs font-semibold text-slate-700 transition-colors">
                    <i class="ph-bold ph-film-strip text-purple-600"></i>
                    <span>News & Reels</span>
                </a>

                <!-- Manual Live Refresh Button -->
                <button type="button" @click="fetchLivePulse(true)" class="p-2 rounded-xl bg-slate-100 hover:bg-slate-200 border border-slate-300 text-slate-600 transition-colors" title="Force Refresh Telemetry">
                    <i class="ph ph-arrows-clockwise text-base" :class="{ 'animate-spin': isRefreshing }"></i>
                </button>
            </div>
        </div>

        <!-- MODULE NAVIGATION TABS (LIGHT THEME) -->
        <div class="border-t border-slate-200 bg-white overflow-x-auto">
            <div class="max-w-[1780px] mx-auto px-4 sm:px-6 flex items-center gap-1 py-1.5">
                
                <a href="monitor_dashboard.php?tab=overview&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>"
                   class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all <?= $activeTab === 'overview' ? 'bg-emerald-50 text-emerald-700 border border-emerald-300 shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' ?>">
                    <i class="ph-bold ph-gauge text-sm"></i>
                    <span>Executive Pulse</span>
                </a>

                <a href="monitor_dashboard.php?tab=farmers&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>"
                   class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all <?= $activeTab === 'farmers' ? 'bg-emerald-50 text-emerald-700 border border-emerald-300 shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' ?>">
                    <i class="ph-bold ph-users-three text-sm text-amber-600"></i>
                    <span>Farmers Registry</span>
                    <span class="px-1.5 py-0.5 rounded-full bg-slate-200 text-[10px] text-slate-700 font-mono font-bold"><?= $kpis['users_total'] ?></span>
                </a>

                <a href="monitor_dashboard.php?tab=shop_orders&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>"
                   class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all <?= $activeTab === 'shop_orders' ? 'bg-emerald-50 text-emerald-700 border border-emerald-300 shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' ?>">
                    <i class="ph-bold ph-shopping-bag text-sm text-emerald-600"></i>
                    <span>Agri Shop Orders</span>
                    <span class="px-1.5 py-0.5 rounded-full bg-slate-200 text-[10px] text-slate-700 font-mono font-bold"><?= $kpis['shop_orders_total'] ?></span>
                </a>

                <a href="monitor_dashboard.php?tab=seed_orders&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>"
                   class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all <?= $activeTab === 'seed_orders' ? 'bg-emerald-50 text-emerald-700 border border-emerald-300 shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' ?>">
                    <i class="ph-bold ph-plant text-sm text-teal-600"></i>
                    <span>Seed Demands</span>
                    <span class="px-1.5 py-0.5 rounded-full bg-slate-200 text-[10px] text-slate-700 font-mono font-bold"><?= $kpis['seed_bookings_total'] ?></span>
                </a>

                <a href="monitor_dashboard.php?tab=market_prices&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>"
                   class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all <?= $activeTab === 'market_prices' ? 'bg-emerald-50 text-emerald-700 border border-emerald-300 shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' ?>">
                    <i class="ph-bold ph-scales text-sm text-amber-600"></i>
                    <span>Mandi Prices & Search</span>
                    <span class="px-1.5 py-0.5 rounded-full bg-slate-200 text-[10px] text-slate-700 font-mono font-bold"><?= $kpis['market_lookups_total'] ?></span>
                </a>

                <a href="monitor_dashboard.php?tab=news_viewers&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>"
                   class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all <?= $activeTab === 'news_viewers' ? 'bg-emerald-50 text-emerald-700 border border-emerald-300 shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' ?>">
                    <i class="ph-bold ph-newspaper text-sm text-sky-600"></i>
                    <span>Agri News Reads</span>
                    <span class="px-1.5 py-0.5 rounded-full bg-slate-200 text-[10px] text-slate-700 font-mono font-bold"><?= number_format($kpis['news_views_total']) ?></span>
                </a>

                <a href="monitor_dashboard.php?tab=reel_viewers&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>"
                   class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all <?= $activeTab === 'reel_viewers' ? 'bg-emerald-50 text-emerald-700 border border-emerald-300 shadow-sm' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' ?>">
                    <i class="ph-bold ph-play-circle text-sm text-purple-600"></i>
                    <span>Agri Reels Hub</span>
                    <span class="px-1.5 py-0.5 rounded-full bg-slate-200 text-[10px] text-slate-700 font-mono font-bold"><?= number_format($kpis['reels_total']) ?></span>
                </a>
            </div>
        </div>
    </header>

    <!-- NOTIFICATION FEEDBACK BANNER -->
    <?php if (!empty($formFeedback)): ?>
        <div class="max-w-[1780px] mx-auto px-4 sm:px-6 pt-4">
            <div class="p-4 rounded-xl flex items-center justify-between <?= $formFeedbackType === 'success' ? 'bg-emerald-50 border border-emerald-200 text-emerald-800' : 'bg-rose-50 border border-rose-200 text-rose-800' ?>">
                <div class="flex items-center gap-3">
                    <i class="<?= $formFeedbackType === 'success' ? 'ph-bold ph-check-circle text-emerald-600 text-xl' : 'ph-bold ph-warning-circle text-rose-600 text-xl' ?>"></i>
                    <span class="text-sm font-semibold"><?= htmlspecialchars($formFeedback) ?></span>
                </div>
                <button type="button" onclick="this.parentElement.remove()" class="text-slate-400 hover:text-slate-600">&times;</button>
            </div>
        </div>
    <?php endif; ?>

    <!-- MAIN BODY CONTENT -->
    <main class="max-w-[1780px] mx-auto px-4 sm:px-6 py-6 space-y-6">

        <!-- ================================================================== -->
        <!-- TAB 1: EXECUTIVE PULSE & OVERVIEW -->
        <!-- ================================================================== -->
        <?php if ($activeTab === 'overview'): ?>
            
            <!-- SCOPE NOTICE BANNER (LIGHT THEME) -->
            <div class="light-card p-4 rounded-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4 border-l-4 border-l-emerald-600">
                <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-xl bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold text-lg">
                        <i class="ph-bold ph-map-pin"></i>
                    </div>
                    <div>
                        <h2 class="text-sm font-bold text-slate-900 flex items-center gap-2">
                            <span><?= $selectedRegion === 'hyd' ? 'Active Command Node: Hyderabad Region (HYD001)' : 'Global Mode: Reporting Across All Regions' ?></span>
                            <span class="px-2 py-0.5 rounded text-[10px] font-mono font-bold bg-slate-100 text-slate-700"><?= count($farmersList) ?> Farmers Synced</span>
                        </h2>
                        <p class="text-xs text-slate-500">Real-time telemetry of farmer accounts, marketplace enquiries, seed varieties demand, and multimedia content engagement.</p>
                    </div>
                </div>
                <div class="flex items-center gap-2">
                    <a href="monitor_dashboard.php?tab=farmers" class="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs shadow-sm transition-colors flex items-center gap-1.5">
                        <i class="ph-bold ph-user-plus"></i> Manage Farmers
                    </a>
                </div>
            </div>

            <!-- HERO METRIC CARDS (LIGHT THEME) -->
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
                
                <!-- Farmers -->
                <div class="light-card p-4 rounded-2xl relative overflow-hidden">
                    <div class="flex items-center justify-between text-xs text-slate-500 mb-2">
                        <span class="font-medium">Registered Farmers</span>
                        <div class="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center text-base">
                            <i class="ph-bold ph-users-three"></i>
                        </div>
                    </div>
                    <div class="text-2xl font-extrabold text-slate-900 tracking-tight"><?= number_format($kpis['users_total']) ?></div>
                    <div class="mt-2 flex items-center justify-between text-[11px] text-slate-500 border-t border-slate-100 pt-2 font-mono">
                        <span class="text-emerald-600 font-bold">+<?= $kpis['users_today'] ?> today</span>
                        <span><?= $kpis['users_genuine'] ?> real &bull; <?= $kpis['users_fake'] ?> demo</span>
                    </div>
                </div>

                <!-- Shop Orders -->
                <div class="light-card p-4 rounded-2xl relative overflow-hidden">
                    <div class="flex items-center justify-between text-xs text-slate-500 mb-2">
                        <span class="font-medium">Agri Shop Enquiries</span>
                        <div class="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center text-base">
                            <i class="ph-bold ph-shopping-bag"></i>
                        </div>
                    </div>
                    <div class="text-2xl font-extrabold text-slate-900 tracking-tight"><?= number_format($kpis['shop_orders_total']) ?></div>
                    <div class="mt-2 flex items-center justify-between text-[11px] text-slate-500 border-t border-slate-100 pt-2 font-mono">
                        <span class="text-emerald-600 font-bold"><?= $kpis['shop_orders_purchased'] ?> bought</span>
                        <span><?= formatInr($kpis['shop_orders_value_est']) ?></span>
                    </div>
                </div>

                <!-- Seed Demands -->
                <div class="light-card p-4 rounded-2xl relative overflow-hidden">
                    <div class="flex items-center justify-between text-xs text-slate-500 mb-2">
                        <span class="font-medium">Seed Bookings</span>
                        <div class="w-8 h-8 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center text-base">
                            <i class="ph-bold ph-plant"></i>
                        </div>
                    </div>
                    <div class="text-2xl font-extrabold text-slate-900 tracking-tight"><?= number_format($kpis['seed_bookings_total']) ?></div>
                    <div class="mt-2 flex items-center justify-between text-[11px] text-slate-500 border-t border-slate-100 pt-2 font-mono">
                        <span class="text-teal-600 font-bold"><?= number_format($kpis['seed_bookings_total_kg'], 1) ?> kg</span>
                        <span><?= formatInr($kpis['seed_bookings_value']) ?></span>
                    </div>
                </div>

                <!-- Mandi Searches -->
                <div class="light-card p-4 rounded-2xl relative overflow-hidden">
                    <div class="flex items-center justify-between text-xs text-slate-500 mb-2">
                        <span class="font-medium">Mandi Price Searches</span>
                        <div class="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center text-base">
                            <i class="ph-bold ph-scales"></i>
                        </div>
                    </div>
                    <div class="text-2xl font-extrabold text-slate-900 tracking-tight"><?= number_format($kpis['market_lookups_total']) ?></div>
                    <div class="mt-2 flex items-center justify-between text-[11px] text-slate-500 border-t border-slate-100 pt-2 font-mono">
                        <span class="text-amber-600 font-bold truncate max-w-[120px]">Top: <?= htmlspecialchars($kpis['market_top_commodity']) ?></span>
                        <span><?= $kpis['market_unique_farmers'] ?> callers</span>
                    </div>
                </div>

                <!-- News Reads -->
                <div class="light-card p-4 rounded-2xl relative overflow-hidden">
                    <div class="flex items-center justify-between text-xs text-slate-500 mb-2">
                        <span class="font-medium">Krishi News Reads</span>
                        <div class="w-8 h-8 rounded-xl bg-sky-50 text-sky-600 flex items-center justify-center text-base">
                            <i class="ph-bold ph-newspaper"></i>
                        </div>
                    </div>
                    <div class="text-2xl font-extrabold text-slate-900 tracking-tight"><?= number_format($kpis['news_views_total']) ?></div>
                    <div class="mt-2 flex items-center justify-between text-[11px] text-slate-500 border-t border-slate-100 pt-2 font-mono">
                        <span class="text-sky-600 font-bold"><?= $kpis['news_likes_total'] ?> likes</span>
                        <span><?= $kpis['news_articles_total'] ?> articles</span>
                    </div>
                </div>

                <!-- Agri Reels Hub -->
                <div class="light-card p-4 rounded-2xl relative overflow-hidden">
                    <div class="flex items-center justify-between text-xs text-slate-500 mb-2">
                        <span class="font-medium">Agri Reels Published</span>
                        <div class="w-8 h-8 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center text-base">
                            <i class="ph-bold ph-film-strip"></i>
                        </div>
                    </div>
                    <div class="text-2xl font-extrabold text-slate-900 tracking-tight"><?= number_format($kpis['reels_total']) ?></div>
                    <div class="mt-2 flex items-center justify-between text-[11px] text-slate-500 border-t border-slate-100 pt-2 font-mono">
                        <span class="text-purple-600 font-bold"><?= number_format($kpis['reels_views_total']) ?> views</span>
                        <span><?= number_format($kpis['reels_likes_total']) ?> likes</span>
                    </div>
                </div>

            </div>

            <!-- ANALYTICS CHARTS SECTION (LIGHT THEME) -->
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                
                <!-- 7-Day Velocity Chart -->
                <div class="lg:col-span-2 light-card p-5 rounded-2xl">
                    <div class="flex items-center justify-between mb-4">
                        <div>
                            <h3 class="text-sm font-bold text-slate-900">7-Day Ecosystem Activity Velocity</h3>
                            <p class="text-xs text-slate-500">Daily velocity of farmer signups, shop orders, seed demands, mandi queries, and reels.</p>
                        </div>
                        <div class="text-xs font-mono font-medium text-slate-500 bg-slate-100 px-2.5 py-1 rounded-lg">Last 7 Days</div>
                    </div>
                    <div class="h-64 relative">
                        <canvas id="velocityLineChart"></canvas>
                    </div>
                </div>

                <!-- Distribution Doughnut -->
                <div class="light-card p-5 rounded-2xl flex flex-col justify-between">
                    <div>
                        <h3 class="text-sm font-bold text-slate-900 mb-1">Activity Distribution</h3>
                        <p class="text-xs text-slate-500 mb-4">Proportionate breakdown of activity in this scope.</p>
                        <div class="h-56 relative flex items-center justify-center">
                            <canvas id="distributionDoughnutChart"></canvas>
                        </div>
                    </div>
                    <div class="text-[11px] text-slate-500 text-center border-t border-slate-100 pt-3 font-mono">
                        Node: <span class="text-emerald-700 font-bold"><?= $selectedRegion === 'hyd' ? 'Hyderabad Region (HYD001)' : 'Global All Regions' ?></span>
                    </div>
                </div>

            </div>

            <!-- LIVE ACTIVITY FEED -->
            <div class="light-card p-5 rounded-2xl">
                <div class="flex items-center justify-between mb-4">
                    <h3 class="text-sm font-bold text-slate-900 flex items-center gap-2">
                        <span class="w-2.5 h-2.5 rounded-full bg-emerald-500 pulse-dot"></span>
                        <span>Live Telemetry Activity Feed</span>
                    </h3>
                    <span class="text-[11px] font-mono text-slate-400" x-text="'Polled at: ' + lastUpdated"><?= date('H:i:s') ?></span>
                </div>
                
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <template x-for="(evt, idx) in liveEvents" :key="idx">
                        <div class="p-3 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between gap-3 text-xs">
                            <div class="flex items-center gap-3">
                                <div class="w-8 h-8 rounded-lg flex items-center justify-center text-sm font-bold"
                                     :class="{
                                        'bg-amber-100 text-amber-700': evt.event_type === 'user_reg',
                                        'bg-emerald-100 text-emerald-700': evt.event_type === 'shop_order',
                                        'bg-teal-100 text-teal-700': evt.event_type === 'seed_booking',
                                        'bg-purple-100 text-purple-700': evt.event_type === 'market_query'
                                     }">
                                    <i :class="{
                                        'ph-bold ph-user': evt.event_type === 'user_reg',
                                        'ph-bold ph-shopping-bag': evt.event_type === 'shop_order',
                                        'ph-bold ph-plant': evt.event_type === 'seed_booking',
                                        'ph-bold ph-scales': evt.event_type === 'market_query'
                                    }"></i>
                                </div>
                                <div>
                                    <div class="font-bold text-slate-800" x-text="evt.title"></div>
                                    <div class="text-[11px] text-slate-500" x-text="evt.subtitle"></div>
                                </div>
                            </div>
                            <div class="text-right">
                                <span class="px-2 py-0.5 rounded text-[10px] font-mono font-semibold uppercase bg-white text-slate-700 border border-slate-200" x-text="evt.tag"></span>
                                <div class="text-[10px] text-slate-400 mt-0.5" x-text="evt.created_at ? evt.created_at.substring(11, 16) : ''"></div>
                            </div>
                        </div>
                    </template>
                </div>
            </div>

        <?php endif; ?>

        <!-- ================================================================== -->
        <!-- TAB 2: FARMERS REGISTRY & MANAGEMENT HUB -->
        <!-- ================================================================== -->
        <?php if ($activeTab === 'farmers'): ?>
            <div class="space-y-4">
                
                <!-- Farmers Header Bar -->
                <div class="light-card p-5 rounded-2xl flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <div>
                        <h2 class="text-lg font-bold text-slate-900 flex items-center gap-2">
                            <span>Farmers Registry & Account Control</span>
                            <span class="px-2.5 py-0.5 rounded-full text-xs font-mono font-bold bg-emerald-100 text-emerald-800">
                                <?= $selectedRegion === 'hyd' ? 'Hyderabad Only (HYD001)' : 'All Regions' ?>
                            </span>
                        </h2>
                        <p class="text-xs text-slate-500 mt-1">Manage real farmer profiles and demo accounts. Toggle verification and fake status directly via AJAX, or batch generate demo profiles.</p>
                    </div>

                    <div class="flex flex-wrap items-center gap-2.5">
                        <!-- Quick Batch Generator Trigger -->
                        <button type="button" @click="openQuickGenModal = true" class="px-3.5 py-2 rounded-xl bg-amber-500 hover:bg-amber-600 text-white font-semibold text-xs transition-colors flex items-center gap-1.5 shadow-sm">
                            <i class="ph-bold ph-lightning"></i>
                            <span>Quick Generate (1-10)</span>
                        </button>

                        <!-- Add Farmer Modal Trigger -->
                        <button type="button" @click="openAddFarmerModal = true" class="px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs transition-colors flex items-center gap-1.5 shadow-sm">
                            <i class="ph-bold ph-plus"></i>
                            <span>Add New Farmer</span>
                        </button>

                        <!-- Export CSV Button -->
                        <button type="button" onclick="exportTableToCSV('farmersTable', 'farmers_registry.csv')" class="px-3 py-2 rounded-xl bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 font-semibold text-xs transition-colors flex items-center gap-1.5">
                            <i class="ph-bold ph-download-simple"></i>
                            <span>Export CSV</span>
                        </button>
                    </div>
                </div>

                <!-- Filters & Search Toolbar with Alpine.js Dropdowns -->
                <div class="light-card p-4 rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-3">
                    
                    <!-- Alpine.js Filter Dropdown -->
                    <div class="flex items-center gap-2 w-full sm:w-auto">
                        <div class="relative" x-data="{ open: false }" @click.outside="open = false">
                            <button type="button" @click="open = !open" class="px-3 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 border border-slate-300 text-xs font-semibold text-slate-700 flex items-center gap-2">
                                <i class="ph-bold ph-funnel text-slate-500"></i>
                                <span>Filter: <?= ucfirst($farmerFilter) ?></span>
                                <i class="ph ph-caret-down text-slate-400 text-xs transition-transform" :class="{ 'rotate-180': open }"></i>
                            </button>
                            <div x-cloak x-show="open" x-transition class="absolute left-0 mt-1.5 w-48 bg-white border border-slate-200 rounded-xl shadow-lg py-1.5 z-50 text-xs">
                                <?php 
                                $fTypes = [
                                    'all' => 'All Farmers (' . $kpis['users_total'] . ')',
                                    'genuine' => 'Genuine (' . $kpis['users_genuine'] . ')',
                                    'fake' => 'Demo / Fake (' . $kpis['users_fake'] . ')',
                                    'verified' => 'Verified (' . $kpis['users_verified'] . ')',
                                    'unverified' => 'Unverified (' . $kpis['users_unverified'] . ')'
                                ];
                                foreach ($fTypes as $fKey => $fLabel):
                                ?>
                                    <a href="monitor_dashboard.php?tab=farmers&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>&farmer_type=<?= $fKey ?>" class="flex items-center justify-between px-3 py-2 hover:bg-emerald-50 text-slate-700 font-medium <?= $farmerFilter === $fKey ? 'bg-emerald-50 text-emerald-800 font-bold' : '' ?>">
                                        <span><?= $fLabel ?></span>
                                        <?php if ($farmerFilter === $fKey): ?><i class="ph-bold ph-check text-emerald-600"></i><?php endif; ?>
                                    </a>
                                <?php endforeach; ?>
                            </div>
                        </div>

                        <span class="text-xs text-slate-500 font-medium"><?= count($farmersList) ?> records found</span>
                    </div>

                    <!-- Instant Search Bar -->
                    <form method="GET" action="monitor_dashboard.php" class="relative w-full sm:w-80">
                        <input type="hidden" name="tab" value="farmers">
                        <input type="hidden" name="range" value="<?= htmlspecialchars($range) ?>">
                        <input type="hidden" name="region_filter" value="<?= htmlspecialchars($selectedRegion) ?>">
                        <input type="hidden" name="farmer_type" value="<?= htmlspecialchars($farmerFilter) ?>">
                        <i class="ph ph-magnifying-glass absolute left-3 top-2.5 text-slate-400 text-sm"></i>
                        <input type="text" name="q" value="<?= htmlspecialchars($searchQuery) ?>" placeholder="Search name, phone, village..."
                               class="w-full pl-9 pr-8 py-2 rounded-xl bg-slate-50 border border-slate-300 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-emerald-600 focus:bg-white">
                        <?php if (!empty($searchQuery)): ?>
                            <a href="monitor_dashboard.php?tab=farmers&range=<?= $range ?>&region_filter=<?= $selectedRegion ?>&farmer_type=<?= $farmerFilter ?>" class="absolute right-2.5 top-2.5 text-slate-400 hover:text-slate-600 text-xs">&times;</a>
                        <?php endif; ?>
                    </form>
                </div>

                <!-- Farmers Data Table -->
                <div class="light-card rounded-2xl overflow-hidden">
                    <div class="overflow-x-auto">
                        <table id="farmersTable" class="w-full text-left text-xs text-slate-700">
                            <thead class="bg-slate-100 text-slate-600 uppercase font-mono text-[11px] border-b border-slate-200">
                                <tr>
                                    <th class="p-3.5 pl-5">Farmer Profile</th>
                                    <th class="p-3.5">Phone & WhatsApp</th>
                                    <th class="p-3.5">Region & Location</th>
                                    <th class="p-3.5 text-center">Account Flag</th>
                                    <th class="p-3.5 text-center">Verification</th>
                                    <th class="p-3.5">Registered</th>
                                    <th class="p-3.5 pr-5 text-right">Actions</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-100">
                                <?php if (empty($farmersList)): ?>
                                    <tr>
                                        <td colspan="7" class="p-12 text-center text-slate-400">
                                            <i class="ph ph-users-three text-4xl block mb-2 text-slate-300"></i>
                                            No farmers found in this criteria. Try changing the region or search filter.
                                        </td>
                                    </tr>
                                <?php else: foreach ($farmersList as $f): 
                                    $avatar = !empty($f['profile_image_url']) ? $f['profile_image_url'] : 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=150&q=80';
                                    $isFake = intval($f['is_fake'] ?? 0);
                                    $isVerified = intval($f['is_verified'] ?? 1);
                                    $mandal = !empty($f['mandal']) ? $f['mandal'] : 'Secunderabad';
                                    $village = !empty($f['village']) ? $f['village'] : 'Hyderabad';
                                    $uRegion = !empty($f['region']) ? $f['region'] : (!empty($f['client_code']) ? $f['client_code'] : 'Hyderabad');
                                ?>
                                    <tr class="hover:bg-slate-50 transition-colors">
                                        <td class="p-3.5 pl-5">
                                            <div class="flex items-center gap-3">
                                                <img src="<?= htmlspecialchars($avatar) ?>" alt="Avatar" class="w-10 h-10 rounded-full object-cover border border-slate-200 flex-shrink-0" onerror="this.src='https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=150&q=80'">
                                                <div>
                                                    <div class="font-bold text-slate-900 text-sm"><?= htmlspecialchars($f['name']) ?></div>
                                                    <div class="text-[11px] font-mono text-slate-400">UID: <?= htmlspecialchars($f['user_id']) ?></div>
                                                </div>
                                            </div>
                                        </td>
                                        <td class="p-3.5 font-mono">
                                            <div class="text-slate-800 font-semibold"><?= htmlspecialchars($f['phone_number'] ?? 'N/A') ?></div>
                                            <?php if (!empty($f['phone_number'])): ?>
                                                <div class="flex items-center gap-2 mt-1 text-[11px]">
                                                    <a href="tel:<?= htmlspecialchars($f['phone_number']) ?>" class="text-slate-500 hover:text-emerald-700 flex items-center gap-0.5">
                                                        <i class="ph-bold ph-phone"></i> Call
                                                    </a>
                                                    <a href="https://wa.me/91<?= htmlspecialchars(preg_replace('/[^0-9]/', '', $f['phone_number'])) ?>" target="_blank" class="text-slate-500 hover:text-emerald-700 flex items-center gap-0.5">
                                                        <i class="ph-bold ph-whatsapp-logo"></i> Chat
                                                    </a>
                                                </div>
                                            <?php endif; ?>
                                        </td>
                                        <td class="p-3.5">
                                            <div class="font-semibold text-slate-800"><?= htmlspecialchars($mandal) ?></div>
                                            <div class="text-[11px] text-slate-500"><?= htmlspecialchars($village) ?> &bull; <?= htmlspecialchars($uRegion) ?></div>
                                        </td>
                                        <td class="p-3.5 text-center">
                                            <button type="button" @click="toggleFarmerFake('<?= $f['user_id'] ?>', <?= $isFake ?>)" 
                                                    class="px-2.5 py-1 rounded-full text-[11px] font-bold cursor-pointer transition-all <?= $isFake ? 'bg-amber-100 text-amber-800 border border-amber-300 hover:bg-amber-200' : 'bg-blue-100 text-blue-800 border border-blue-300 hover:bg-blue-200' ?>">
                                                <?= $isFake ? 'Demo / Fake' : 'Genuine' ?>
                                            </button>
                                        </td>
                                        <td class="p-3.5 text-center">
                                            <button type="button" @click="toggleFarmerVerified('<?= $f['user_id'] ?>', <?= $isVerified ?>)"
                                                    class="px-2 py-0.5 rounded text-[11px] font-semibold cursor-pointer transition-all <?= $isVerified ? 'bg-emerald-100 text-emerald-800 border border-emerald-300' : 'bg-slate-100 text-slate-500 border border-slate-300' ?>">
                                                <?= $isVerified ? 'Verified' : 'Pending' ?>
                                            </button>
                                        </td>
                                        <td class="p-3.5 text-slate-500 whitespace-nowrap font-mono text-[11px]">
                                            <?= timeAgoFormatted($f['created_at']) ?>
                                        </td>
                                        <td class="p-3.5 pr-5 text-right whitespace-nowrap">
                                            <button type="button" @click='openEditModal(<?= json_encode($f) ?>)' class="p-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 transition-colors" title="Edit Farmer">
                                                <i class="ph-bold ph-pencil-simple text-sm"></i>
                                            </button>
                                            <button type="button" @click="confirmDeleteFarmer('<?= $f['user_id'] ?>', '<?= htmlspecialchars(addslashes($f['name'])) ?>')" class="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-600 border border-rose-200 transition-colors ml-1" title="Delete Farmer">
                                                <i class="ph-bold ph-trash text-sm"></i>
                                            </button>
                                        </td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>
        <?php endif; ?>

        <!-- ================================================================== -->
        <!-- TAB 3: AGRI SHOP ORDERS (WITH ALPINE STATUS CHANGER) -->
        <!-- ================================================================== -->
        <?php if ($activeTab === 'shop_orders'): ?>
            <div class="space-y-4">
                
                <div class="light-card p-4 rounded-2xl flex items-center justify-between">
                    <div>
                        <h2 class="text-sm font-bold text-slate-900">Agri Shop Product Enquiries</h2>
                        <p class="text-xs text-slate-500">Farmers requesting contacts or purchasing products through the app.</p>
                    </div>
                    <button type="button" onclick="exportTableToCSV('shopOrdersTable', 'shop_orders.csv')" class="px-3 py-1.5 rounded-xl bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 font-semibold text-xs flex items-center gap-1.5">
                        <i class="ph-bold ph-download-simple"></i>
                        <span>Export CSV</span>
                    </button>
                </div>

                <div class="light-card rounded-2xl overflow-hidden">
                    <div class="overflow-x-auto">
                        <table id="shopOrdersTable" class="w-full text-left text-xs text-slate-700">
                            <thead class="bg-slate-100 text-slate-600 uppercase font-mono text-[11px] border-b border-slate-200">
                                <tr>
                                    <th class="p-3.5 pl-5">Enquiry #</th>
                                    <th class="p-3.5">Product</th>
                                    <th class="p-3.5">Farmer Contact</th>
                                    <th class="p-3.5">Advertiser</th>
                                    <th class="p-3.5">Ordered At</th>
                                    <th class="p-3.5 pr-5 text-right">Status (Alpine Dropdown)</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-100">
                                <?php if (empty($shopOrdersList)): ?>
                                    <tr>
                                        <td colspan="6" class="p-12 text-center text-slate-400">
                                            No shop orders found in this range.
                                        </td>
                                    </tr>
                                <?php else: foreach ($shopOrdersList as $o): ?>
                                    <tr class="hover:bg-slate-50 transition-colors">
                                        <td class="p-3.5 pl-5 font-mono font-bold text-emerald-700">#<?= $o['enquiry_id'] ?></td>
                                        <td class="p-3.5">
                                            <div class="font-bold text-slate-900"><?= htmlspecialchars($o['product_name_en'] ?? $o['product_name'] ?? 'Product') ?></div>
                                            <div class="text-[11px] font-mono text-emerald-700 font-semibold"><?= formatInr($o['price'] ?? 0) ?></div>
                                        </td>
                                        <td class="p-3.5">
                                            <div class="font-semibold text-slate-800"><?= htmlspecialchars($o['farmer_name'] ?? 'Farmer') ?></div>
                                            <div class="text-[11px] font-mono text-slate-500"><?= htmlspecialchars($o['farmer_phone'] ?? $o['farmer_id']) ?> &bull; <?= htmlspecialchars($o['farmer_mandal']) ?></div>
                                        </td>
                                        <td class="p-3.5 text-slate-600"><?= htmlspecialchars($o['advertiser_name'] ?? 'Advertiser') ?></td>
                                        <td class="p-3.5 font-mono text-[11px] text-slate-500"><?= timeAgoFormatted($o['enquiry_date']) ?></td>
                                        
                                        <!-- Inline Alpine.js Status Dropdown -->
                                        <td class="p-3.5 pr-5 text-right" x-data="{ open: false, curStatus: '<?= $o['status'] ?>' }">
                                            <div class="relative inline-block text-left" @click.outside="open = false">
                                                <button type="button" @click="open = !open" 
                                                        class="px-2.5 py-1 rounded-lg text-xs font-semibold border flex items-center gap-1.5 transition-colors"
                                                        :class="{
                                                            'bg-emerald-50 text-emerald-800 border-emerald-300': curStatus === 'Purchased',
                                                            'bg-blue-50 text-blue-800 border-blue-300': curStatus === 'Contacted',
                                                            'bg-amber-50 text-amber-800 border-amber-300': curStatus === 'Interested'
                                                        }">
                                                    <span x-text="curStatus"></span>
                                                    <i class="ph ph-caret-down text-[10px]"></i>
                                                </button>
                                                <div x-cloak x-show="open" x-transition class="absolute right-0 mt-1 w-32 bg-white border border-slate-200 rounded-xl shadow-lg py-1 z-50 text-xs">
                                                    <?php foreach (['Interested', 'Contacted', 'Purchased'] as $st): ?>
                                                        <button type="button" @click="curStatus = '<?= $st ?>'; open = false; updateShopOrderStatus(<?= $o['enquiry_id'] ?>, '<?= $st ?>')" class="w-full text-left px-3 py-1.5 hover:bg-slate-50 font-medium text-slate-700">
                                                            <?= $st ?>
                                                        </button>
                                                    <?php endforeach; ?>
                                                </div>
                                            </div>
                                        </td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>
        <?php endif; ?>

        <!-- ================================================================== -->
        <!-- TAB 4: SEED VARIETIES ORDERS (WITH ALPINE STATUS CHANGER) -->
        <!-- ================================================================== -->
        <?php if ($activeTab === 'seed_orders'): ?>
            <div class="space-y-4">
                
                <div class="light-card p-4 rounded-2xl flex items-center justify-between">
                    <div>
                        <h2 class="text-sm font-bold text-slate-900">Seed Varieties Bookings & Demand</h2>
                        <p class="text-xs text-slate-500">Seed packet orders placed by farmers across varieties.</p>
                    </div>
                    <button type="button" onclick="exportTableToCSV('seedOrdersTable', 'seed_bookings.csv')" class="px-3 py-1.5 rounded-xl bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 font-semibold text-xs flex items-center gap-1.5">
                        <i class="ph-bold ph-download-simple"></i>
                        <span>Export CSV</span>
                    </button>
                </div>

                <div class="light-card rounded-2xl overflow-hidden">
                    <div class="overflow-x-auto">
                        <table id="seedOrdersTable" class="w-full text-left text-xs text-slate-700">
                            <thead class="bg-slate-100 text-slate-600 uppercase font-mono text-[11px] border-b border-slate-200">
                                <tr>
                                    <th class="p-3.5 pl-5">Booking ID</th>
                                    <th class="p-3.5">Seed Variety</th>
                                    <th class="p-3.5">Farmer</th>
                                    <th class="p-3.5">Quantity & Price</th>
                                    <th class="p-3.5">Ordered At</th>
                                    <th class="p-3.5 pr-5 text-right">Booking Status (Alpine Dropdown)</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-100">
                                <?php if (empty($seedOrdersList)): ?>
                                    <tr>
                                        <td colspan="6" class="p-12 text-center text-slate-400">
                                            No seed bookings found.
                                        </td>
                                    </tr>
                                <?php else: foreach ($seedOrdersList as $b): ?>
                                    <tr class="hover:bg-slate-50 transition-colors">
                                        <td class="p-3.5 pl-5 font-mono font-bold text-teal-700"><?= htmlspecialchars($b['booking_id']) ?></td>
                                        <td class="p-3.5">
                                            <div class="font-bold text-slate-900"><?= htmlspecialchars($b['variety_name_en'] ?? 'Seed Variety') ?></div>
                                            <div class="text-[11px] text-slate-500"><?= htmlspecialchars($b['crop_name'] ?? 'Crop') ?></div>
                                        </td>
                                        <td class="p-3.5">
                                            <div class="font-semibold text-slate-800"><?= htmlspecialchars($b['farmer_name'] ?? 'Farmer') ?></div>
                                            <div class="text-[11px] font-mono text-slate-500"><?= htmlspecialchars($b['farmer_phone'] ?? $b['user_id']) ?></div>
                                        </td>
                                        <td class="p-3.5 font-mono">
                                            <div class="font-bold text-slate-900"><?= formatInr($b['total_price']) ?></div>
                                            <div class="text-[11px] text-teal-700 font-semibold"><?= $b['quantity_kg'] ?> kg (<?= htmlspecialchars($b['packet_size'] ?? '1 kg') ?>)</div>
                                        </td>
                                        <td class="p-3.5 font-mono text-[11px] text-slate-500"><?= timeAgoFormatted($b['booking_timestamp']) ?></td>
                                        
                                        <!-- Inline Alpine.js Booking Status Dropdown -->
                                        <td class="p-3.5 pr-5 text-right" x-data="{ open: false, curStatus: '<?= $b['booking_status'] ?>' }">
                                            <div class="relative inline-block text-left" @click.outside="open = false">
                                                <button type="button" @click="open = !open" 
                                                        class="px-2.5 py-1 rounded-lg text-xs font-semibold border flex items-center gap-1.5 transition-colors uppercase font-mono"
                                                        :class="{
                                                            'bg-emerald-50 text-emerald-800 border-emerald-300': curStatus === 'delivered',
                                                            'bg-sky-50 text-sky-800 border-sky-300': curStatus === 'shipped',
                                                            'bg-blue-50 text-blue-800 border-blue-300': curStatus === 'confirmed',
                                                            'bg-amber-50 text-amber-800 border-amber-300': curStatus === 'pending',
                                                            'bg-rose-50 text-rose-800 border-rose-300': curStatus === 'cancelled'
                                                        }">
                                                    <span x-text="curStatus"></span>
                                                    <i class="ph ph-caret-down text-[10px]"></i>
                                                </button>
                                                <div x-cloak x-show="open" x-transition class="absolute right-0 mt-1 w-32 bg-white border border-slate-200 rounded-xl shadow-lg py-1 z-50 text-xs">
                                                    <?php foreach (['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'] as $st): ?>
                                                        <button type="button" @click="curStatus = '<?= $st ?>'; open = false; updateSeedBookingStatus('<?= $b['booking_id'] ?>', '<?= $st ?>')" class="w-full text-left px-3 py-1.5 hover:bg-slate-50 font-medium text-slate-700 capitalize">
                                                            <?= $st ?>
                                                        </button>
                                                    <?php endforeach; ?>
                                                </div>
                                            </div>
                                        </td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>
        <?php endif; ?>

        <!-- ================================================================== -->
        <!-- TAB 5: MANDI MARKET PRICES SEARCHES -->
        <!-- ================================================================== -->
        <?php if ($activeTab === 'market_prices'): ?>
            <div class="space-y-4">
                
                <div class="light-card p-4 rounded-2xl flex items-center justify-between">
                    <div>
                        <h2 class="text-sm font-bold text-slate-900">Mandi Price Searches & Farmer Queries</h2>
                        <p class="text-xs text-slate-500">Live commodity lookups recorded from mobile app and kiosk terminals.</p>
                    </div>
                    <button type="button" onclick="exportTableToCSV('marketTable', 'mandi_queries.csv')" class="px-3 py-1.5 rounded-xl bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 font-semibold text-xs flex items-center gap-1.5">
                        <i class="ph-bold ph-download-simple"></i>
                        <span>Export CSV</span>
                    </button>
                </div>

                <div class="light-card rounded-2xl overflow-hidden">
                    <div class="overflow-x-auto">
                        <table id="marketTable" class="w-full text-left text-xs text-slate-700">
                            <thead class="bg-slate-100 text-slate-600 uppercase font-mono text-[11px] border-b border-slate-200">
                                <tr>
                                    <th class="p-3.5 pl-5">Commodity</th>
                                    <th class="p-3.5">Action</th>
                                    <th class="p-3.5">Farmer Phone</th>
                                    <th class="p-3.5">Location</th>
                                    <th class="p-3.5 pr-5 text-right">Time</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-100">
                                <?php if (empty($marketInteractionsList)): ?>
                                    <tr>
                                        <td colspan="5" class="p-12 text-center text-slate-400">
                                            No mandi market queries logged yet.
                                        </td>
                                    </tr>
                                <?php else: foreach ($marketInteractionsList as $m): ?>
                                    <tr class="hover:bg-slate-50 transition-colors">
                                        <td class="p-3.5 pl-5 font-bold text-slate-900 flex items-center gap-2">
                                            <i class="ph-bold ph-scales text-amber-600"></i>
                                            <span><?= htmlspecialchars($m['crop_name'] ?? $m['item_name'] ?? 'Mandi Rates') ?></span>
                                        </td>
                                        <td class="p-3.5 font-mono uppercase text-[11px] text-slate-500"><?= htmlspecialchars($m['action_type'] ?? 'lookup') ?></td>
                                        <td class="p-3.5 font-mono"><?= htmlspecialchars($m['phone_number'] ?? 'N/A') ?></td>
                                        <td class="p-3.5 text-slate-600"><?= htmlspecialchars($m['user_mandal'] ?? 'Hyderabad') ?></td>
                                        <td class="p-3.5 pr-5 text-right font-mono text-[11px] text-slate-500"><?= timeAgoFormatted($m['created_at']) ?></td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>
        <?php endif; ?>

        <!-- ================================================================== -->
        <!-- TAB 6: AGRI NEWS READS -->
        <!-- ================================================================== -->
        <?php if ($activeTab === 'news_viewers'): ?>
            <div class="space-y-4">
                
                <div class="light-card p-4 rounded-2xl flex items-center justify-between">
                    <div>
                        <h2 class="text-sm font-bold text-slate-900">Krishi News Reader Analytics</h2>
                        <p class="text-xs text-slate-500">Readership engagement across articles, schemes, and farming advisories.</p>
                    </div>
                    <button type="button" onclick="exportTableToCSV('newsTable', 'news_engagement.csv')" class="px-3 py-1.5 rounded-xl bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 font-semibold text-xs flex items-center gap-1.5">
                        <i class="ph-bold ph-download-simple"></i>
                        <span>Export CSV</span>
                    </button>
                </div>

                <div class="light-card rounded-2xl overflow-hidden">
                    <div class="overflow-x-auto">
                        <table id="newsTable" class="w-full text-left text-xs text-slate-700">
                            <thead class="bg-slate-100 text-slate-600 uppercase font-mono text-[11px] border-b border-slate-200">
                                <tr>
                                    <th class="p-3.5 pl-5">Headline</th>
                                    <th class="p-3.5">Category</th>
                                    <th class="p-3.5">Author</th>
                                    <th class="p-3.5 text-center">Views</th>
                                    <th class="p-3.5 text-center">Likes</th>
                                    <th class="p-3.5 pr-5 text-right">Published</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-100">
                                <?php if (empty($newsArticlesList)): ?>
                                    <tr>
                                        <td colspan="6" class="p-12 text-center text-slate-400">
                                            No news articles found.
                                        </td>
                                    </tr>
                                <?php else: foreach ($newsArticlesList as $n): ?>
                                    <tr class="hover:bg-slate-50 transition-colors">
                                        <td class="p-3.5 pl-5 font-bold text-slate-900 max-w-sm truncate" title="<?= htmlspecialchars($n['title']) ?>"><?= htmlspecialchars($n['title']) ?></td>
                                        <td class="p-3.5">
                                            <span class="px-2 py-0.5 rounded text-[10px] font-mono font-semibold bg-sky-50 text-sky-800 border border-sky-200"><?= htmlspecialchars($n['category']) ?></span>
                                        </td>
                                        <td class="p-3.5 text-slate-600"><?= htmlspecialchars($n['author'] ?? 'Desk') ?></td>
                                        <td class="p-3.5 text-center font-mono font-bold text-sky-700"><?= number_format($n['views_count']) ?></td>
                                        <td class="p-3.5 text-center font-mono font-bold text-emerald-700"><?= number_format($n['likes_count']) ?></td>
                                        <td class="p-3.5 pr-5 text-right font-mono text-[11px] text-slate-500"><?= timeAgoFormatted($n['published_at'] ?? $n['created_at']) ?></td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>
        <?php endif; ?>

        <!-- ================================================================== -->
        <!-- TAB 7: AGRI REELS HUB (PROPERLY FETCHING REELS DATA) -->
        <!-- ================================================================== -->
        <?php if ($activeTab === 'reel_viewers'): ?>
            <div class="space-y-4">
                
                <div class="light-card p-4 rounded-2xl flex items-center justify-between">
                    <div>
                        <h2 class="text-sm font-bold text-slate-900 flex items-center gap-2">
                            <span>Agri Reels Hub</span>
                            <span class="px-2 py-0.5 rounded-full text-xs font-mono font-bold bg-purple-100 text-purple-800"><?= count($reelsList) ?> Reels Fetched</span>
                        </h2>
                        <p class="text-xs text-slate-500">Short video reels published by creators, watch statistics, and viewer engagement.</p>
                    </div>

                    <div class="flex items-center gap-2">
                        <a href="news_reels_dashboard.php?tab=reels" class="px-3.5 py-1.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white font-semibold text-xs flex items-center gap-1.5 shadow-sm">
                            <i class="ph-bold ph-plus"></i>
                            <span>Upload Reel</span>
                        </a>
                        <button type="button" onclick="exportTableToCSV('reelsTable', 'reels_data.csv')" class="px-3 py-1.5 rounded-xl bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 font-semibold text-xs flex items-center gap-1.5">
                            <i class="ph-bold ph-download-simple"></i>
                            <span>Export CSV</span>
                        </button>
                    </div>
                </div>

                <!-- Reels Table & Cards -->
                <div class="light-card rounded-2xl overflow-hidden">
                    <div class="overflow-x-auto">
                        <table id="reelsTable" class="w-full text-left text-xs text-slate-700">
                            <thead class="bg-slate-100 text-slate-600 uppercase font-mono text-[11px] border-b border-slate-200">
                                <tr>
                                    <th class="p-3.5 pl-5">Reel Caption & Video</th>
                                    <th class="p-3.5">Creator Profile</th>
                                    <th class="p-3.5 text-center">Views</th>
                                    <th class="p-3.5 text-center">Likes</th>
                                    <th class="p-3.5 text-center">Saves / Comments</th>
                                    <th class="p-3.5 text-center">Status</th>
                                    <th class="p-3.5 pr-5 text-right">Published</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-100">
                                <?php if (empty($reelsList)): ?>
                                    <tr>
                                        <td colspan="7" class="p-12 text-center text-slate-400">
                                            <i class="ph ph-film-strip text-4xl block mb-2 text-slate-300"></i>
                                            No reels found in the database.
                                        </td>
                                    </tr>
                                <?php else: foreach ($reelsList as $r): 
                                    $creatorAvatar = !empty($r['creator_avatar']) ? $r['creator_avatar'] : 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=150&q=80';
                                ?>
                                    <tr class="hover:bg-slate-50 transition-colors">
                                        <td class="p-3.5 pl-5">
                                            <div class="flex items-center gap-3">
                                                <a href="<?= htmlspecialchars($r['video_url'] ?? '#') ?>" target="_blank" class="w-10 h-10 rounded-xl bg-purple-100 text-purple-700 flex items-center justify-center flex-shrink-0 hover:scale-105 transition-transform" title="Watch Video">
                                                    <i class="ph-fill ph-play text-base"></i>
                                                </a>
                                                <div>
                                                    <div class="font-bold text-slate-900 text-sm max-w-sm truncate" title="<?= htmlspecialchars($r['caption'] ?? '') ?>">
                                                        <?= htmlspecialchars($r['caption'] ?? 'Reel #' . $r['id']) ?>
                                                    </div>
                                                    <div class="text-[11px] text-slate-500 font-mono">
                                                        <?= htmlspecialchars($r['tags'] ?? 'general') ?> &bull; <?= htmlspecialchars($r['music_title'] ?? 'Original Audio') ?>
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                        <td class="p-3.5">
                                            <div class="flex items-center gap-2">
                                                <img src="<?= htmlspecialchars($creatorAvatar) ?>" class="w-7 h-7 rounded-full object-cover border border-slate-200" onerror="this.src='https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=150&q=80'">
                                                <div>
                                                    <div class="font-bold text-slate-800"><?= htmlspecialchars($r['creator_name'] ?? 'Creator') ?></div>
                                                    <div class="text-[10px] text-purple-700 font-mono">@<?= htmlspecialchars($r['creator_username'] ?? 'creator') ?></div>
                                                </div>
                                            </div>
                                        </td>
                                        <td class="p-3.5 text-center font-mono font-bold text-purple-700"><?= number_format($r['views_count'] ?? 0) ?></td>
                                        <td class="p-3.5 text-center font-mono font-bold text-emerald-700"><?= number_format($r['likes_count'] ?? 0) ?></td>
                                        <td class="p-3.5 text-center font-mono text-slate-600 text-[11px]">
                                            <?= number_format($r['saves_count'] ?? 0) ?> saves &bull; <?= number_format($r['comments_count'] ?? 0) ?> comments
                                        </td>
                                        <td class="p-3.5 text-center">
                                            <span class="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase <?= ($r['is_active'] ?? 1) ? 'bg-emerald-100 text-emerald-800 border border-emerald-300' : 'bg-slate-100 text-slate-500' ?>">
                                                <?= ($r['is_active'] ?? 1) ? 'Active' : 'Inactive' ?>
                                            </span>
                                        </td>
                                        <td class="p-3.5 pr-5 text-right font-mono text-[11px] text-slate-500"><?= timeAgoFormatted($r['created_at']) ?></td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

            </div>
        <?php endif; ?>

    </main>

    <!-- ================================================================== -->
    <!-- MODALS: ADD FARMER, EDIT FARMER, QUICK GENERATE -->
    <!-- ================================================================== -->

    <!-- MODAL 1: ADD FARMER -->
    <div x-cloak x-show="openAddFarmerModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
        <div @click.outside="openAddFarmerModal = false" class="bg-white border border-slate-200 rounded-2xl w-full max-w-lg p-6 shadow-2xl relative">
            <div class="flex items-center justify-between pb-3 border-b border-slate-200">
                <h3 class="text-base font-bold text-slate-900 flex items-center gap-2">
                    <i class="ph-bold ph-user-plus text-emerald-600"></i>
                    <span>Register New Farmer</span>
                </h3>
                <button type="button" @click="openAddFarmerModal = false" class="text-slate-400 hover:text-slate-600 text-lg">&times;</button>
            </div>

            <form method="POST" action="monitor_dashboard.php?tab=farmers&region_filter=<?= $selectedRegion ?>" enctype="multipart/form-data" class="mt-4 space-y-3.5 text-left">
                <input type="hidden" name="form_action" value="create_farmer">
                
                <div>
                    <label class="block text-xs font-semibold text-slate-700 mb-1">Farmer Full Name *</label>
                    <input type="text" name="name" required placeholder="e.g. Malla Reddy" class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <div class="flex items-center justify-between mb-1">
                            <label class="text-xs font-semibold text-slate-700">10-Digit Mobile *</label>
                            <button type="button" @click="newFarmerPhone = generateRandomPhone()" class="text-[10px] text-emerald-600 hover:underline font-bold">Auto-Gen</button>
                        </div>
                        <input type="text" name="phone_number" x-model="newFarmerPhone" required class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs font-mono text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                    </div>

                    <div>
                        <label class="block text-xs font-semibold text-slate-700 mb-1">Account Type *</label>
                        <select name="is_fake" class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                            <option value="1">Demo / Fake Profile</option>
                            <option value="0">Genuine Farmer</option>
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="block text-xs font-semibold text-slate-700 mb-1">Mandal *</label>
                        <select name="mandal" class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                            <?php foreach ($HYD_MANDALS as $hm): ?>
                                <option value="<?= htmlspecialchars($hm) ?>"><?= htmlspecialchars($hm) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div>
                        <label class="block text-xs font-semibold text-slate-700 mb-1">Village / Locality *</label>
                        <select name="village" class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                            <?php foreach ($HYD_VILLAGES as $hv): ?>
                                <option value="<?= htmlspecialchars($hv) ?>"><?= htmlspecialchars($hv) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                </div>

                <div>
                    <label class="block text-xs font-semibold text-slate-700 mb-1">Profile Photo (Optional Upload)</label>
                    <input type="file" name="avatar_file" accept="image/*" class="w-full text-xs text-slate-500 file:mr-2 file:py-1 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-slate-100 file:text-slate-700 hover:file:bg-slate-200">
                </div>

                <div class="pt-4 border-t border-slate-200 flex items-center justify-end gap-2">
                    <button type="button" @click="openAddFarmerModal = false" class="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold">Cancel</button>
                    <button type="submit" class="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold shadow-sm">Save Farmer</button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 2: EDIT FARMER -->
    <div x-cloak x-show="openEditFarmerModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
        <div @click.outside="openEditFarmerModal = false" class="bg-white border border-slate-200 rounded-2xl w-full max-w-lg p-6 shadow-2xl relative">
            <div class="flex items-center justify-between pb-3 border-b border-slate-200">
                <h3 class="text-base font-bold text-slate-900 flex items-center gap-2">
                    <i class="ph-bold ph-pencil text-emerald-600"></i>
                    <span>Edit Farmer Profile</span>
                </h3>
                <button type="button" @click="openEditFarmerModal = false" class="text-slate-400 hover:text-slate-600 text-lg">&times;</button>
            </div>

            <form method="POST" action="monitor_dashboard.php?tab=farmers&region_filter=<?= $selectedRegion ?>" enctype="multipart/form-data" class="mt-4 space-y-3.5 text-left">
                <input type="hidden" name="form_action" value="edit_farmer">
                <input type="hidden" name="user_id" :value="editFarmer.user_id">
                
                <div>
                    <label class="block text-xs font-semibold text-slate-700 mb-1">Farmer Full Name *</label>
                    <input type="text" name="name" x-model="editFarmer.name" required class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="block text-xs font-semibold text-slate-700 mb-1">10-Digit Mobile *</label>
                        <input type="text" name="phone_number" x-model="editFarmer.phone_number" required class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs font-mono text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                    </div>

                    <div>
                        <label class="block text-xs font-semibold text-slate-700 mb-1">Account Type *</label>
                        <select name="is_fake" x-model="editFarmer.is_fake" class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                            <option value="1">Demo / Fake Profile</option>
                            <option value="0">Genuine Farmer</option>
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="block text-xs font-semibold text-slate-700 mb-1">Mandal *</label>
                        <input type="text" name="mandal" x-model="editFarmer.mandal" class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                    </div>

                    <div>
                        <label class="block text-xs font-semibold text-slate-700 mb-1">Village / Locality *</label>
                        <input type="text" name="village" x-model="editFarmer.village" class="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-xl text-xs text-slate-900 focus:outline-none focus:border-emerald-600 focus:bg-white">
                    </div>
                </div>

                <div class="pt-4 border-t border-slate-200 flex items-center justify-end gap-2">
                    <button type="button" @click="openEditFarmerModal = false" class="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold">Cancel</button>
                    <button type="submit" class="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold shadow-sm">Save Changes</button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 3: QUICK BATCH GENERATOR -->
    <div x-cloak x-show="openQuickGenModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
        <div @click.outside="openQuickGenModal = false" class="bg-white border border-slate-200 rounded-2xl w-full max-w-md p-6 shadow-2xl relative text-center">
            <div class="w-14 h-14 rounded-2xl bg-amber-50 text-amber-600 flex items-center justify-center mx-auto mb-3 text-2xl font-bold">
                <i class="ph-bold ph-lightning"></i>
            </div>
            <h3 class="text-base font-bold text-slate-900 mb-1">Batch Generate Hyderabad Farmers</h3>
            <p class="text-xs text-slate-500 mb-5 leading-relaxed">Instantly populate realistic demo farmer accounts with genuine Telugu names, 10-digit mobile numbers, authentic portraits, and assigned Hyderabad mandals.</p>

            <div class="mb-5 text-left">
                <label class="block text-xs font-semibold text-slate-700 mb-2">Number of accounts to generate:</label>
                <div class="grid grid-cols-4 gap-2">
                    <?php foreach ([1, 3, 5, 10] as $gCount): ?>
                        <button type="button" @click="genCount = <?= $gCount ?>" :class="{ 'bg-emerald-600 text-white border-emerald-600': genCount === <?= $gCount ?>, 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100': genCount !== <?= $gCount ?> }" class="py-2 rounded-xl text-xs font-bold border transition-colors">
                            <?= $gCount ?> Account<?= $gCount > 1 ? 's' : '' ?>
                        </button>
                    <?php endforeach; ?>
                </div>
            </div>

            <div class="flex items-center gap-3">
                <button type="button" @click="openQuickGenModal = false" class="w-1/2 py-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold">Cancel</button>
                <button type="button" @click="executeQuickGenerate()" :disabled="isGenerating" class="w-1/2 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-xs font-semibold flex items-center justify-center gap-2 shadow-sm">
                    <span x-show="!isGenerating">Generate Now</span>
                    <span x-show="isGenerating">Creating...</span>
                </button>
            </div>
        </div>
    </div>

    <!-- FOOTER -->
    <footer class="border-t border-slate-200 bg-white py-4 mt-8 text-xs text-slate-500">
        <div class="max-w-[1780px] mx-auto px-4 sm:px-6 flex flex-col sm:flex-row items-center justify-between gap-3">
            <div>
                CropSync Operations Command &bull; Region: <span class="text-emerald-700 font-bold"><?= $selectedRegion === 'hyd' ? 'Hyderabad Exclusive' : 'All Regions' ?></span>
            </div>
            <div class="flex items-center gap-4 text-[11px]">
                <a href="shop_seeds_dashboard.php" class="text-slate-600 hover:text-emerald-700 transition-colors">Seeds & Shop Catalog</a>
                <a href="news_reels_dashboard.php" class="text-slate-600 hover:text-purple-700 transition-colors">News & Reels Studio</a>
                <span class="font-mono text-emerald-700 font-semibold">Database: <?= htmlspecialchars($dbname ?? 'u893187665_kiosk') ?> (IST UTC+5:30)</span>
            </div>
        </div>
    </footer>

    <!-- TOAST NOTIFICATION STACK -->
    <div class="fixed bottom-5 right-5 z-50 flex flex-col gap-2 max-w-sm pointer-events-none">
        <template x-for="(toast, tIdx) in toasts" :key="tIdx">
            <div class="pointer-events-auto p-3.5 rounded-xl shadow-xl border text-xs flex items-center gap-3 backdrop-blur-md transition-all duration-300"
                 :class="{
                     'bg-emerald-50 text-emerald-900 border-emerald-300': toast.type === 'success',
                     'bg-rose-50 text-rose-900 border-rose-300': toast.type === 'error',
                     'bg-white text-slate-800 border-slate-300 shadow-md': toast.type === 'info'
                 }">
                <i :class="{
                    'ph-bold ph-check-circle text-emerald-600 text-base': toast.type === 'success',
                    'ph-bold ph-warning-circle text-rose-600 text-base': toast.type === 'error',
                    'ph-bold ph-info text-sky-600 text-base': toast.type === 'info'
                }"></i>
                <span class="flex-1 font-medium" x-text="toast.message"></span>
            </div>
        </template>
    </div>

    <!-- JAVASCRIPT APPLICATION LOGIC -->
    <script>
        function monitorApp() {
            return {
                isRefreshing: false,
                isGenerating: false,
                openAddFarmerModal: false,
                openEditFarmerModal: false,
                openQuickGenModal: false,
                newFarmerPhone: '<?= generateRealisticIndianPhone() ?>',
                genCount: 5,
                editFarmer: {},
                lastUpdated: '<?= date('H:i:s') ?>',
                liveEvents: <?= json_encode($pulseEvents ?? []) ?>,
                toasts: [],

                initDashboard() {
                    setInterval(() => {
                        this.fetchLivePulse(false);
                    }, 15000);

                    <?php if ($activeTab === 'overview'): ?>
                        this.renderCharts();
                    <?php endif; ?>
                },

                showToast(message, type = 'success') {
                    const id = Date.now();
                    this.toasts.push({ id, message, type });
                    setTimeout(() => {
                        this.toasts = this.toasts.filter(t => t.id !== id);
                    }, 4000);
                },

                generateRandomPhone() {
                    const prefixes = ['9848', '9989', '9440', '9866', '9701', '8978', '7799', '9100', '6300', '8008'];
                    const p = prefixes[Math.floor(Math.random() * prefixes.length)];
                    const s = String(Math.floor(100000 + Math.random() * 900000)).padStart(6, '0');
                    return p + s;
                },

                openEditModal(farmer) {
                    this.editFarmer = Object.assign({}, farmer);
                    this.openEditFarmerModal = true;
                },

                async fetchLivePulse(manual = false) {
                    if (manual) this.isRefreshing = true;
                    try {
                        const res = await fetch('monitor_dashboard.php?ajax=live_pulse&region_filter=<?= $selectedRegion ?>');
                        const data = await res.json();
                        if (data.success) {
                            this.liveEvents = data.events;
                            this.lastUpdated = data.timestamp;
                            if (manual) this.showToast('Telemetry refreshed!', 'info');
                        }
                    } catch (e) {
                        console.error('Pulse poll failed', e);
                    } finally {
                        if (manual) this.isRefreshing = false;
                    }
                },

                async toggleFarmerFake(userId, currentFake) {
                    const newFake = currentFake ? 0 : 1;
                    const fd = new FormData();
                    fd.append('ajax_action', 'toggle_fake');
                    fd.append('user_id', userId);
                    fd.append('is_fake', newFake);
                    try {
                        const res = await fetch('monitor_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(`Farmer ${userId} set to ${newFake ? 'Demo/Fake' : 'Genuine'}`);
                            setTimeout(() => location.reload(), 600);
                        } else {
                            this.showToast(json.error || 'Failed', 'error');
                        }
                    } catch (e) {
                        this.showToast('Network error', 'error');
                    }
                },

                async toggleFarmerVerified(userId, currentVer) {
                    const newVer = currentVer ? 0 : 1;
                    const fd = new FormData();
                    fd.append('ajax_action', 'toggle_verified');
                    fd.append('user_id', userId);
                    fd.append('is_verified', newVer);
                    try {
                        const res = await fetch('monitor_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(`Farmer ${userId} verification set to ${newVer ? 'Verified' : 'Pending'}`);
                            setTimeout(() => location.reload(), 600);
                        } else {
                            this.showToast(json.error || 'Failed', 'error');
                        }
                    } catch (e) {
                        this.showToast('Network error', 'error');
                    }
                },

                async confirmDeleteFarmer(userId, farmerName) {
                    if (!confirm(`Are you sure you want to remove '${farmerName}' (${userId})?`)) {
                        return;
                    }
                    const fd = new FormData();
                    fd.append('ajax_action', 'delete_farmer');
                    fd.append('user_id', userId);
                    try {
                        const res = await fetch('monitor_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(`Farmer '${farmerName}' deleted successfully`);
                            setTimeout(() => location.reload(), 600);
                        } else {
                            this.showToast(json.error || 'Failed', 'error');
                        }
                    } catch (e) {
                        this.showToast('Network error', 'error');
                    }
                },

                async executeQuickGenerate() {
                    this.isGenerating = true;
                    const fd = new FormData();
                    fd.append('ajax_action', 'quick_generate');
                    fd.append('count', this.genCount);
                    try {
                        const res = await fetch('monitor_dashboard.php', { method: 'POST', body: fd });
                        const json = await res.json();
                        if (json.success) {
                            this.showToast(`Created ${json.created_count} Hyderabad farmer accounts!`);
                            setTimeout(() => location.reload(), 600);
                        } else {
                            this.showToast(json.error || 'Failed', 'error');
                        }
                    } catch (e) {
                        this.showToast('Network error', 'error');
                    } finally {
                        this.isGenerating = false;
                        this.openQuickGenModal = false;
                    }
                },

                renderCharts() {
                    const ctxVelocity = document.getElementById('velocityLineChart');
                    if (ctxVelocity) {
                        new Chart(ctxVelocity, {
                            type: 'line',
                            data: {
                                labels: <?= json_encode($chartDays) ?>,
                                datasets: [
                                    {
                                        label: 'Farmers',
                                        data: <?= json_encode($chartUsersData) ?>,
                                        borderColor: '#4f46e5',
                                        backgroundColor: 'rgba(79, 70, 229, 0.08)',
                                        tension: 0.35,
                                        borderWidth: 2,
                                        pointRadius: 3
                                    },
                                    {
                                        label: 'Shop Orders',
                                        data: <?= json_encode($chartShopData) ?>,
                                        borderColor: '#059669',
                                        backgroundColor: 'rgba(5, 150, 105, 0.08)',
                                        tension: 0.35,
                                        borderWidth: 2,
                                        pointRadius: 3
                                    },
                                    {
                                        label: 'Seed Demands',
                                        data: <?= json_encode($chartSeedData) ?>,
                                        borderColor: '#0d9488',
                                        backgroundColor: 'rgba(13, 148, 136, 0.08)',
                                        tension: 0.35,
                                        borderWidth: 2,
                                        pointRadius: 3
                                    },
                                    {
                                        label: 'Mandi Queries',
                                        data: <?= json_encode($chartMarketData) ?>,
                                        borderColor: '#d97706',
                                        backgroundColor: 'rgba(217, 119, 6, 0.08)',
                                        tension: 0.35,
                                        borderWidth: 2,
                                        pointRadius: 3
                                    },
                                    {
                                        label: 'Reels Added',
                                        data: <?= json_encode($chartReelData) ?>,
                                        borderColor: '#9333ea',
                                        backgroundColor: 'rgba(147, 51, 234, 0.08)',
                                        tension: 0.35,
                                        borderWidth: 2,
                                        pointRadius: 3
                                    }
                                ]
                            },
                            options: {
                                responsive: true,
                                maintainAspectRatio: false,
                                plugins: {
                                    legend: {
                                        labels: { color: '#475569', font: { family: 'Plus Jakarta Sans', size: 11, weight: 'bold' } }
                                    }
                                },
                                scales: {
                                    x: {
                                        grid: { color: '#f1f5f9' },
                                        ticks: { color: '#64748b', font: { size: 10 } }
                                    },
                                    y: {
                                        beginAtZero: true,
                                        grid: { color: '#f1f5f9' },
                                        ticks: { color: '#64748b', font: { size: 10 } }
                                    }
                                }
                            }
                        });
                    }

                    const ctxDonut = document.getElementById('distributionDoughnutChart');
                    if (ctxDonut) {
                        new Chart(ctxDonut, {
                            type: 'doughnut',
                            data: {
                                labels: ['Farmers', 'Shop Orders', 'Seed Demands', 'Mandi Queries', 'News Reads', 'Reels'],
                                datasets: [{
                                    data: [
                                        <?= max(1, $kpis['users_total']) ?>,
                                        <?= max(1, $kpis['shop_orders_total']) ?>,
                                        <?= max(1, $kpis['seed_bookings_total']) ?>,
                                        <?= max(1, $kpis['market_lookups_total']) ?>,
                                        <?= max(1, $kpis['news_views_total']) ?>,
                                        <?= max(1, $kpis['reels_total']) ?>
                                    ],
                                    backgroundColor: ['#4f46e5', '#059669', '#0d9488', '#d97706', '#0284c7', '#9333ea'],
                                    borderColor: '#ffffff',
                                    borderWidth: 3
                                }]
                            },
                            options: {
                                responsive: true,
                                maintainAspectRatio: false,
                                plugins: {
                                    legend: {
                                        position: 'bottom',
                                        labels: { color: '#475569', font: { family: 'Plus Jakarta Sans', size: 10 }, boxWidth: 12 }
                                    }
                                },
                                cutout: '65%'
                            }
                        });
                    }
                }
            }
        }

        async function updateShopOrderStatus(enquiryId, status) {
            const fd = new FormData();
            fd.append('action', 'update_enquiry_status');
            fd.append('enquiry_id', enquiryId);
            fd.append('status', status);
            try {
                const res = await fetch('monitor_dashboard.php', { method: 'POST', body: fd });
                const json = await res.json();
                if (json.success) {
                    alert(json.message);
                } else {
                    alert('Error: ' + (json.error || 'Failed'));
                }
            } catch (e) {
                alert('Request failed');
            }
        }

        async function updateSeedBookingStatus(bookingId, status) {
            const fd = new FormData();
            fd.append('action', 'update_booking_status');
            fd.append('booking_id', bookingId);
            fd.append('status', status);
            try {
                const res = await fetch('monitor_dashboard.php', { method: 'POST', body: fd });
                const json = await res.json();
                if (json.success) {
                    alert(json.message);
                } else {
                    alert('Error: ' + (json.error || 'Failed'));
                }
            } catch (e) {
                alert('Request failed');
            }
        }

        function exportTableToCSV(tableId, filename = 'export.csv') {
            const table = document.getElementById(tableId);
            if (!table) return;
            let csv = [];
            const rows = table.querySelectorAll('tr');
            for (let i = 0; i < rows.length; i++) {
                const row = [];
                const cols = rows[i].querySelectorAll('td, th');
                for (let j = 0; j < cols.length - 1; j++) {
                    let data = cols[j].innerText.replace(/(\r\n|\n|\r)/gm, ' ').replace(/\s+/g, ' ').trim();
                    data = data.replace(/"/g, '""');
                    row.push('"' + data + '"');
                }
                csv.push(row.join(','));
            }
            const csvFile = new Blob([csv.join('\n')], { type: 'text/csv;charset=utf-8;' });
            const downloadLink = document.createElement('a');
            downloadLink.download = filename;
            downloadLink.href = window.URL.createObjectURL(csvFile);
            downloadLink.style.display = 'none';
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
        }
    </script>
</body>
</html>
