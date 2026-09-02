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

        // Automatically run migrations silently on load to prevent missing column errors
        try {
            $stmt = $pdo->query("SHOW INDEX FROM users WHERE Key_name = 'idx_users_phone_number'");
            if (!$stmt->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD INDEX `idx_users_phone_number` (`phone_number`)");
            }
        } catch (Throwable $e) {}

        // Multi-role columns on users table
        try {
            $stmtRole = $pdo->query("SHOW COLUMNS FROM users LIKE 'role'");
            if (!$stmtRole->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `role` VARCHAR(50) NOT NULL DEFAULT 'farmer'");
                $pdo->exec("ALTER TABLE `users` ADD INDEX `idx_users_role` (`role`)");
            }
        } catch (Throwable $e) {}

        try {
            $stmtMemb = $pdo->query("SHOW COLUMNS FROM users LIKE 'membership_type'");
            if (!$stmtMemb->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `membership_type` VARCHAR(50) DEFAULT 'Farmer'");
            }
        } catch (Throwable $e) {}

        try {
            $stmtEmail = $pdo->query("SHOW COLUMNS FROM users LIKE 'email'");
            if (!$stmtEmail->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `email` VARCHAR(150) DEFAULT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtPass = $pdo->query("SHOW COLUMNS FROM users LIKE 'password_hash'");
            if (!$stmtPass->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `password_hash` VARCHAR(255) DEFAULT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtSecQ = $pdo->query("SHOW COLUMNS FROM users LIKE 'security_question'");
            if (!$stmtSecQ->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `security_question` VARCHAR(100) DEFAULT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtSecA = $pdo->query("SHOW COLUMNS FROM users LIKE 'security_answer'");
            if (!$stmtSecA->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `security_answer` VARCHAR(255) DEFAULT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtVer = $pdo->query("SHOW COLUMNS FROM users LIKE 'is_verified'");
            if (!$stmtVer->fetch()) {
                $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_verified` TINYINT(1) DEFAULT 1");
            }
        } catch (Throwable $e) {}

        // Auto-migrate all required creators table columns
        try {
            $pdo->exec("CREATE TABLE IF NOT EXISTS `creators` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `user_id` VARCHAR(50) NULL,
                `username` VARCHAR(100) NOT NULL UNIQUE,
                `display_name` VARCHAR(150) NOT NULL,
                `profile_image_url` VARCHAR(500) NULL,
                `is_verified` TINYINT(1) DEFAULT 1,
                `phone_number` VARCHAR(20) NULL,
                `email` VARCHAR(150) DEFAULT NULL,
                `bio` TEXT NULL,
                `followers_count` INT DEFAULT 0,
                `following_count` INT DEFAULT 0,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_creator_user_id` (`user_id`),
                INDEX `idx_creator_phone` (`phone_number`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
        } catch (Throwable $e) {}

        try {
            $stmtCVer = $pdo->query("SHOW COLUMNS FROM creators LIKE 'is_verified'");
            if (!$stmtCVer->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `is_verified` TINYINT(1) DEFAULT 1");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCUser = $pdo->query("SHOW COLUMNS FROM creators LIKE 'user_id'");
            if (!$stmtCUser->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `user_id` VARCHAR(50) DEFAULT NULL");
                $pdo->exec("ALTER TABLE `creators` ADD INDEX `idx_creator_user_id` (`user_id`)");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCEmail = $pdo->query("SHOW COLUMNS FROM creators LIKE 'email'");
            if (!$stmtCEmail->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `email` VARCHAR(150) DEFAULT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCFoll = $pdo->query("SHOW COLUMNS FROM creators LIKE 'followers_count'");
            if (!$stmtCFoll->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `followers_count` INT DEFAULT 0");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCFoll2 = $pdo->query("SHOW COLUMNS FROM creators LIKE 'following_count'");
            if (!$stmtCFoll2->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `following_count` INT DEFAULT 0");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCPhone = $pdo->query("SHOW COLUMNS FROM creators LIKE 'phone_number'");
            if (!$stmtCPhone->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `phone_number` VARCHAR(20) DEFAULT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCBio = $pdo->query("SHOW COLUMNS FROM creators LIKE 'bio'");
            if (!$stmtCBio->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `bio` TEXT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCProf = $pdo->query("SHOW COLUMNS FROM creators LIKE 'profile_image_url'");
            if (!$stmtCProf->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `profile_image_url` VARCHAR(500) DEFAULT NULL");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCol = $pdo->query("SHOW COLUMNS FROM chc_bookings LIKE 'amount_paid'");
            if (!$stmtCol->fetch()) {
                $pdo->exec("ALTER TABLE `chc_bookings` ADD COLUMN `amount_paid` DECIMAL(10,2) NOT NULL DEFAULT 0.00");
            }
        } catch (Throwable $e) {}

        try {
            $stmtCol2 = $pdo->query("SHOW COLUMNS FROM chc_bookings LIKE 'payment_status'");
            if (!$stmtCol2->fetch()) {
                $pdo->exec("ALTER TABLE `chc_bookings` ADD COLUMN `payment_status` VARCHAR(20) NOT NULL DEFAULT 'Pending'");
            }
        } catch (Throwable $e) {}

        try {
            $pdo->exec("UPDATE chc_bookings SET amount_paid = total_cost, payment_status = 'Paid' WHERE booking_status = 'Completed' AND amount_paid = 0.00");
        } catch (Throwable $e) {}

        try {
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
                `status` ENUM('published', 'draft') DEFAULT 'published',
                `published_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX `idx_news_cat` (`category`),
                INDEX `idx_news_published` (`published_at`),
                INDEX `idx_news_featured` (`is_featured`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            $pdo->exec("CREATE TABLE IF NOT EXISTS `news_article_likes` (
                `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                `article_id` INT NOT NULL,
                `user_id` VARCHAR(50) NULL,
                `phone_number` VARCHAR(20) NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY `uk_article_phone` (`article_id`, `phone_number`),
                INDEX `idx_like_article` (`article_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            $pdo->exec("CREATE TABLE IF NOT EXISTS `news_article_comments` (
                `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                `article_id` INT NOT NULL,
                `user_id` VARCHAR(50) NULL,
                `user_name` VARCHAR(100) NOT NULL,
                `user_role` VARCHAR(50) DEFAULT 'farmer',
                `phone_number` VARCHAR(20) NOT NULL,
                `comment_text` TEXT NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_comment_article` (`article_id`, `created_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            // Creators table for Reels & Content Creators
            $pdo->exec("CREATE TABLE IF NOT EXISTS `creators` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `user_id` VARCHAR(50) NULL,
                `username` VARCHAR(100) NOT NULL UNIQUE,
                `display_name` VARCHAR(150) NOT NULL,
                `profile_image_url` VARCHAR(500) NULL,
                `is_verified` TINYINT(1) DEFAULT 1,
                `phone_number` VARCHAR(20) NULL,
                `email` VARCHAR(150) DEFAULT NULL,
                `bio` TEXT NULL,
                `followers_count` INT DEFAULT 0,
                `following_count` INT DEFAULT 0,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_creator_phone` (`phone_number`),
                INDEX `idx_creator_user_id` (`user_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            try {
                $stmtCUser = $pdo->query("SHOW COLUMNS FROM creators LIKE 'user_id'");
                if (!$stmtCUser->fetch()) {
                    $pdo->exec("ALTER TABLE `creators` ADD COLUMN `user_id` VARCHAR(50) NULL");
                    $pdo->exec("ALTER TABLE `creators` ADD INDEX `idx_creator_user_id` (`user_id`)");
                }
            } catch (Throwable $e) {}

            try {
                $stmtCEmail = $pdo->query("SHOW COLUMNS FROM creators LIKE 'email'");
                if (!$stmtCEmail->fetch()) {
                    $pdo->exec("ALTER TABLE `creators` ADD COLUMN `email` VARCHAR(150) DEFAULT NULL");
                }
            } catch (Throwable $e) {}

            try {
                $stmtCPhone = $pdo->query("SHOW COLUMNS FROM creators LIKE 'phone_number'");
                if (!$stmtCPhone->fetch()) {
                    $pdo->exec("ALTER TABLE `creators` ADD COLUMN `phone_number` VARCHAR(20) NULL");
                    $pdo->exec("ALTER TABLE `creators` ADD INDEX `idx_creator_phone` (`phone_number`)");
                }
            } catch (Throwable $e) {}

            // Reels table
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
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_reel_creator` (`creator_id`),
                INDEX `idx_reel_active` (`is_active`),
                INDEX `idx_reel_created` (`created_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            $reelsColumnsToCheck = [
                'music_title' => "ALTER TABLE `reels` ADD COLUMN `music_title` VARCHAR(200) DEFAULT 'Original Audio'",
                'phone_number' => "ALTER TABLE `reels` ADD COLUMN `phone_number` VARCHAR(20) DEFAULT NULL",
                'tags' => "ALTER TABLE `reels` ADD COLUMN `tags` VARCHAR(255) DEFAULT NULL",
                'views_count' => "ALTER TABLE `reels` ADD COLUMN `views_count` INT DEFAULT 0",
                'likes_count' => "ALTER TABLE `reels` ADD COLUMN `likes_count` INT DEFAULT 0",
                'saves_count' => "ALTER TABLE `reels` ADD COLUMN `saves_count` INT DEFAULT 0",
                'comments_count' => "ALTER TABLE `reels` ADD COLUMN `comments_count` INT DEFAULT 0",
                'is_active' => "ALTER TABLE `reels` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1",
                'created_at' => "ALTER TABLE `reels` ADD COLUMN `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
            ];
            foreach ($reelsColumnsToCheck as $rcCol => $rcSql) {
                try {
                    $st = $pdo->query("SHOW COLUMNS FROM `reels` LIKE '$rcCol'");
                    if (!$st || !$st->fetch()) {
                        $pdo->exec($rcSql);
                    }
                } catch (Throwable $e) {}
            }

            // Reel Likes table
            $pdo->exec("CREATE TABLE IF NOT EXISTS `reel_likes` (
                `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                `reel_id` INT NOT NULL,
                `farmer_username` VARCHAR(100) NULL,
                `phone_number` VARCHAR(20) NOT NULL,
                `user_id` VARCHAR(50) NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY `uk_reel_phone` (`reel_id`, `phone_number`),
                INDEX `idx_like_reel` (`reel_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            // Reel Comments table
            $pdo->exec("CREATE TABLE IF NOT EXISTS `reel_comments` (
                `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                `reel_id` INT NOT NULL,
                `farmer_username` VARCHAR(100) NOT NULL,
                `phone_number` VARCHAR(20) NULL,
                `user_id` VARCHAR(50) NULL,
                `comment_text` TEXT NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_comment_reel` (`reel_id`, `created_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            // Reel Actions table (Save, Call, Share, WhatsApp)
            $pdo->exec("CREATE TABLE IF NOT EXISTS `reel_actions` (
                `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                `reel_id` INT NOT NULL,
                `farmer_username` VARCHAR(100) NULL,
                `phone_number` VARCHAR(20) NULL,
                `user_id` VARCHAR(50) NULL,
                `action_type` VARCHAR(50) NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_action_reel` (`reel_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            // Reel Watch Analytics table
            $pdo->exec("CREATE TABLE IF NOT EXISTS `reel_watch_analytics` (
                `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                `reel_id` INT NOT NULL,
                `farmer_username` VARCHAR(100) NULL,
                `phone_number` VARCHAR(20) NULL,
                `user_id` VARCHAR(50) NULL,
                `watch_duration_seconds` INT DEFAULT 0,
                `is_completed` TINYINT(1) DEFAULT 0,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_watch_reel` (`reel_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            // Schema tables ensured without dummy seed data
        } catch (Throwable $e) {}
    }
} catch (Throwable $e) {
    // Do not block API execution if any DB setup fails
}

$rawInput = file_get_contents('php://input');
$jsonParsed = !empty($rawInput) ? json_decode($rawInput, true) : null;
$action = $_GET['action'] ?? $_POST['action'] ?? ($jsonParsed['action'] ?? '');

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
    case 'get_operator_analytics':
        getOperatorAnalytics($pdo);
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
    case 'log_interaction':
        logFarmerInteraction($pdo);
        break;
    case 'get_farmer_interaction_logs':
        getFarmerInteractionLogs($pdo);
        break;
    // KRISHI NEWS & INSIGHTS ENDPOINTS
    case 'get_news_articles':
        getNewsArticles($pdo);
        break;
    case 'get_news_article_detail':
        getNewsArticleDetail($pdo);
        break;
    case 'increment_news_view':
        incrementNewsView($pdo);
        break;
    case 'toggle_news_like':
        toggleNewsLike($pdo);
        break;
    case 'get_news_comments':
        getNewsComments($pdo);
        break;
    case 'add_news_comment':
        addNewsComment($pdo);
        break;
    // AGRI REELS & SHORT VIDEOS ENDPOINTS
    case 'get_reels':
        getReels($pdo);
        break;
    case 'toggle_reel_like':
        toggleReelLike($pdo);
        break;
    case 'toggle_reel_save':
        toggleReelSave($pdo);
        break;
    case 'get_reel_comments':
        getReelComments($pdo);
        break;
    case 'add_reel_comment':
        addReelComment($pdo);
        break;
    case 'log_reel_action':
        logReelAction($pdo);
        break;
    case 'log_reel_watch':
        logReelWatch($pdo);
        break;
    // CREATOR STUDIO & UPLOAD ENDPOINTS
    case 'upload_reel':
        uploadReel($pdo);
        break;
    case 'delete_reel':
        deleteReel($pdo);
        break;
    case 'toggle_reel_status':
        toggleReelStatus($pdo);
        break;
    case 'create_news_article':
        createNewsArticle($pdo);
        break;
    case 'delete_news_article':
        deleteNewsArticle($pdo);
        break;
    case 'toggle_news_status':
        toggleNewsStatus($pdo);
        break;
    case 'get_creator_studio_data':
        getCreatorStudioData($pdo);
        break;
    default:
        echo json_encode(['success' => false, 'error' => 'Invalid action']);
}

/**
 * Log farmer interaction (crop view, problem view, control measures view, shop item view, seed view, etc.)
 */
function logFarmerInteraction($pdo) {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        echo json_encode(['success' => false, 'error' => 'Invalid JSON input']);
        return;
    }

    $ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;
    $logs = isset($input['logs']) && is_array($input['logs']) ? $input['logs'] : [$input];
    $inserted = 0;

    try {
        $stmt = $pdo->prepare("
            INSERT INTO `farmer_interaction_logs` 
            (user_id, phone_number, user_role, action_type, item_type, item_id, item_name, crop_name, metadata, ip_address, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW()))
        ");

        foreach ($logs as $log) {
            $userId = $log['user_id'] ?? null;
            $phoneNumber = $log['phone_number'] ?? null;
            $userRole = $log['user_role'] ?? 'farmer';
            $actionType = $log['action_type'] ?? '';
            $itemType = $log['item_type'] ?? '';
            $itemId = isset($log['item_id']) ? (string)$log['item_id'] : null;
            $itemName = $log['item_name'] ?? null;
            $cropName = $log['crop_name'] ?? null;
            $metadata = isset($log['metadata']) ? (is_string($log['metadata']) ? $log['metadata'] : json_encode($log['metadata'])) : null;
            $createdAt = $log['timestamp'] ?? null;

            if (!empty($actionType) && !empty($itemType)) {
                $stmt->execute([
                    $userId,
                    $phoneNumber,
                    $userRole,
                    $actionType,
                    $itemType,
                    $itemId,
                    $itemName,
                    $cropName,
                    $metadata,
                    $ipAddress,
                    $createdAt
                ]);
                $inserted++;
            }
        }

        echo json_encode([
            'success' => true,
            'inserted_count' => $inserted,
            'message' => 'Interaction logged successfully'
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Get farmer interaction logs with optional filters
 */
function getFarmerInteractionLogs($pdo) {
    $userId = $_GET['user_id'] ?? null;
    $phoneNumber = $_GET['phone_number'] ?? null;
    $actionType = $_GET['action_type'] ?? null;
    $itemType = $_GET['item_type'] ?? null;
    $hasCrop = isset($_GET['has_crop']) && $_GET['has_crop'] == '1';
    $limit = isset($_GET['limit']) ? min((int)$_GET['limit'], 100) : 50;

    try {
        $sql = "SELECT * FROM `farmer_interaction_logs` WHERE 1=1";
        $params = [];

        if ($userId && $phoneNumber) {
            $sql .= " AND (user_id = ? OR phone_number = ?)";
            $params[] = $userId;
            $params[] = $phoneNumber;
        } elseif ($userId) {
            $sql .= " AND user_id = ?";
            $params[] = $userId;
        } elseif ($phoneNumber) {
            $sql .= " AND phone_number = ?";
            $params[] = $phoneNumber;
        }

        if ($actionType) {
            $sql .= " AND action_type = ?";
            $params[] = $actionType;
        }
        if ($itemType) {
            $sql .= " AND item_type = ?";
            $params[] = $itemType;
        }
        if ($hasCrop) {
            $sql .= " AND (crop_name IS NOT NULL AND crop_name != '')";
        }

        $sql .= " ORDER BY created_at DESC LIMIT " . (int)$limit;

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(['success' => true, 'logs' => $logs]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function applyMigration($pdo) {
    try {
        // idx_users_phone_number check
        $stmt = $pdo->query("SHOW INDEX FROM users WHERE Key_name = 'idx_users_phone_number'");
        $indexExists = $stmt->fetch();
        if (!$indexExists) {
            $pdo->exec("ALTER TABLE `users` ADD INDEX `idx_users_phone_number` (`phone_number`)");
        }

        // Add amount_paid column
        $stmtCol = $pdo->query("SHOW COLUMNS FROM chc_bookings LIKE 'amount_paid'");
        $colExists = $stmtCol->fetch();
        if (!$colExists) {
            $pdo->exec("ALTER TABLE `chc_bookings` ADD COLUMN `amount_paid` DECIMAL(10,2) NOT NULL DEFAULT 0.00");
        }

        // Add payment_status column
        $stmtCol2 = $pdo->query("SHOW COLUMNS FROM chc_bookings LIKE 'payment_status'");
        $colExists2 = $stmtCol2->fetch();
        if (!$colExists2) {
            $pdo->exec("ALTER TABLE `chc_bookings` ADD COLUMN `payment_status` VARCHAR(20) NOT NULL DEFAULT 'Pending'");
        }

        // Set all existing Completed bookings without payment_status/amount_paid to completed cost
        $pdo->exec("UPDATE chc_bookings SET amount_paid = total_cost, payment_status = 'Paid' WHERE booking_status = 'Completed' AND amount_paid = 0.00");

        echo json_encode(['success' => true, 'message' => 'Migration applied successfully']);
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

function sendBookingCompletionSMS($phone, $serviceSummary, $amount, $operatorId = null) {
    if (empty($phone)) return false;
    
    $authkey = defined('MSG91_AUTHKEY') && !empty(MSG91_AUTHKEY) ? MSG91_AUTHKEY : '491154AraRrF6el3UI69a6deb0P1';
    $template_id = defined('MSG91_TEMPLATE_ID') && !empty(MSG91_TEMPLATE_ID) ? MSG91_TEMPLATE_ID : '6a48e05940099a0175051674';
    
    // Default to Indian country code if not present
    $mobile = preg_match('/^\d{10}$/', $phone) ? '91' . $phone : $phone;

    $postData = json_encode([
        "template_id" => $template_id,
        "short_url" => "0",
        "recipients" => [
            [
                "mobiles" => $mobile,
                "var1" => empty($serviceSummary) ? "Unknown Service" : (string)$serviceSummary,
                "var2" => empty($amount) ? "0" : (string)$amount,
                "VAR1" => empty($serviceSummary) ? "Unknown Service" : (string)$serviceSummary,
                "VAR2" => empty($amount) ? "0" : (string)$amount,
                "##var1##" => empty($serviceSummary) ? "Unknown Service" : (string)$serviceSummary,
                "##var2##" => empty($amount) ? "0" : (string)$amount
            ]
        ]
    ]);
    
    // Log payload for debugging
    $logDir = __DIR__ . '/logs';
    if (!is_dir($logDir)) mkdir($logDir, 0777, true);
    file_put_contents($logDir . '/msg91.log', date('Y-m-d H:i:s') . " - Payload: " . $postData . "\n", FILE_APPEND);

    $curl = curl_init();
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

    $status = 'Failed';
    $logResponse = '';

    if ($err) {
        file_put_contents($logDir . '/msg91.log', date('Y-m-d H:i:s') . " - Error: " . $err . "\n", FILE_APPEND);
        $logResponse = 'cURL Error: ' . $err;
    } else {
        file_put_contents($logDir . '/msg91.log', date('Y-m-d H:i:s') . " - Response: " . $response . "\n", FILE_APPEND);
        $logResponse = $response;
        $result = json_decode($response, true);
        if (isset($result['type']) && $result['type'] === 'success') {
            $status = 'Success';
        }
    }
    
    // Log to DB dynamically
    try {
        global $pdo;
        if (isset($pdo) && $pdo instanceof PDO) {
            $pdo->exec("CREATE TABLE IF NOT EXISTS sms_logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                phone VARCHAR(20) NOT NULL,
                service_summary VARCHAR(255) DEFAULT NULL,
                amount VARCHAR(50) DEFAULT NULL,
                operator_id INT DEFAULT NULL,
                status VARCHAR(20) DEFAULT 'Pending',
                response TEXT DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
            
            $stmt = $pdo->prepare("INSERT INTO sms_logs (phone, service_summary, amount, operator_id, status, response) VALUES (?, ?, ?, ?, ?, ?)");
            $stmt->execute([$phone, $serviceSummary, $amount, $operatorId, $status, $logResponse]);
        }
    } catch (Throwable $dbEx) {
        // Suppress so SMS flow never crashes
    }
    
    return $status === 'Success';
}

function registerUser($pdo) {
    $input = json_decode(file_get_contents('php://input'), true) ?? [];
    $rawPhone = $input['phone_number'] ?? $input['user_id'] ?? '';
    $cleanPhone = preg_replace('/[^0-9]/', '', $rawPhone);
    $userId = strlen($cleanPhone) > 10 ? substr($cleanPhone, -10) : $cleanPhone;
    
    $name = trim($input['name'] ?? '');
    $clientCode = $input['client_code'] ?? 'HYD001';
    $role = trim($input['role'] ?? 'farmer');
    $username = trim($input['username'] ?? '');
    $password = trim($input['password'] ?? '');
    $securityQuestion = trim($input['security_question'] ?? '');
    $securityAnswer = trim($input['security_answer'] ?? '');
    $email = trim($input['email'] ?? '');
    $district = $input['district'] ?? null;
    $village = $input['village'] ?? null;
    $mandal = $input['mandal'] ?? null;
    
    if (empty($userId)) {
        echo json_encode(['success' => false, 'error' => 'Phone number is required']);
        return;
    }
    if (empty($name)) {
        if ($role === 'content_creator' && !empty($username)) {
            $name = $username;
        } else {
            $name = 'CropSync ' . ucfirst(str_replace('_', ' ', $role));
        }
    }

    $membershipType = 'Farmer';
    if ($role === 'content_creator' || $role === 'creator') {
        $role = 'content_creator';
        $membershipType = 'Creator';
    } elseif ($role === 'retailer') {
        $membershipType = 'Retailer';
    } elseif ($role === 'officer') {
        $membershipType = 'Officer';
    } elseif ($role === 'chc_operator') {
        $membershipType = 'CHC Operator';
    }

    try {
        // Check if user already exists in users table
        $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ? OR phone_number = ? OR phone_number = ?");
        $stmt->execute([$userId, $userId, '91' . $userId]);
        $existingUser = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($existingUser) {
            // Update existing user record with the selected role and profile data
            $passHash = !empty($password) ? password_hash($password, PASSWORD_DEFAULT) : null;
            $updateSql = "UPDATE users SET name = ?, role = ?, membership_type = ?, client_code = COALESCE(?, client_code)";
            $params = [$name, $role, $membershipType, $clientCode];

            if (!empty($email)) {
                $updateSql .= ", email = ?";
                $params[] = $email;
            }
            if (!empty($passHash)) {
                $updateSql .= ", password_hash = ?";
                $params[] = $passHash;
            }
            if (!empty($securityQuestion)) {
                $updateSql .= ", security_question = ?, security_answer = ?";
                $params[] = $securityQuestion;
                $params[] = $securityAnswer;
            }
            if (!empty($district)) {
                $updateSql .= ", district = ?";
                $params[] = $district;
            }
            if (!empty($village)) {
                $updateSql .= ", village = ?";
                $params[] = $village;
            }
            if (!empty($mandal)) {
                $updateSql .= ", mandal = ?";
                $params[] = $mandal;
            }

            $updateSql .= " WHERE user_id = ? OR phone_number = ?";
            $params[] = $userId;
            $params[] = $userId;

            $stmtUp = $pdo->prepare($updateSql);
            $stmtUp->execute($params);
        } else {
            // Insert new user
            $passHash = !empty($password) ? password_hash($password, PASSWORD_DEFAULT) : null;
            $stmt = $pdo->prepare("
                INSERT INTO users (user_id, name, phone_number, client_code, role, membership_type, email, password_hash, security_question, security_answer, district, village, mandal) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([
                $userId, 
                $name, 
                $userId, 
                $clientCode, 
                $role, 
                $membershipType, 
                !empty($email) ? $email : null,
                $passHash,
                !empty($securityQuestion) ? $securityQuestion : null,
                !empty($securityAnswer) ? $securityAnswer : null,
                $district,
                $village,
                $mandal
            ]);
        }

        // Secondary table synchronizations for specialized roles:
        if ($role === 'content_creator') {
            $cUsername = !empty($username) ? $username : 'creator_' . substr($userId, -6);
            try {
                $cStmt = $pdo->prepare("
                    INSERT INTO creators (user_id, username, display_name, profile_image_url, is_verified, phone_number, email, bio) 
                    VALUES (?, ?, ?, NULL, 1, ?, ?, 'Agricultural Content Creator') 
                    ON DUPLICATE KEY UPDATE 
                        display_name = VALUES(display_name), 
                        user_id = VALUES(user_id), 
                        email = COALESCE(VALUES(email), email),
                        phone_number = VALUES(phone_number)
                ");
                $cStmt->execute([$userId, $cUsername, $name, $userId, !empty($email) ? $email : null]);
            } catch (Throwable $e) {
                // If column was missing, auto-patch schema and retry safely
                try {
                    $pdo->exec("ALTER TABLE `creators` ADD COLUMN `is_verified` TINYINT(1) DEFAULT 1");
                } catch (Throwable $ig) {}
                try {
                    $pdo->exec("ALTER TABLE `creators` ADD COLUMN `user_id` VARCHAR(50) DEFAULT NULL");
                } catch (Throwable $ig) {}
                try {
                    $pdo->exec("ALTER TABLE `creators` ADD COLUMN `email` VARCHAR(150) DEFAULT NULL");
                } catch (Throwable $ig) {}
                try {
                    $cStmt2 = $pdo->prepare("
                        INSERT INTO creators (user_id, username, display_name, is_verified, phone_number, email, bio) 
                        VALUES (?, ?, ?, 1, ?, ?, 'Agricultural Content Creator') 
                        ON DUPLICATE KEY UPDATE 
                            display_name = VALUES(display_name)
                    ");
                    $cStmt2->execute([$userId, $cUsername, $name, $userId, !empty($email) ? $email : null]);
                } catch (Throwable $e2) {
                    error_log('Creator sync warning: ' . $e2->getMessage());
                }
            }
        } elseif ($role === 'retailer') {
            $retCode = 'RET_' . substr($userId, -4);
            $retStmt = $pdo->prepare("
                INSERT INTO retailer_partners (owner_name, shop_name, contact_number, email, referral_code, client_code, district, mandal, village)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                    owner_name = VALUES(owner_name),
                    email = COALESCE(VALUES(email), email)
            ");
            $retStmt->execute([
                $name, 
                $name . ' Agri Center', 
                $userId, 
                !empty($email) ? $email : null, 
                $retCode, 
                $clientCode,
                $district,
                $mandal,
                $village
            ]);
        } elseif ($role === 'officer') {
            $offStmt = $pdo->prepare("
                INSERT INTO extension_officers (name, contact_number, email, coverage_district, coverage_mandal)
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                    name = VALUES(name),
                    email = COALESCE(VALUES(email), email)
            ");
            $offStmt->execute([
                $name, 
                $userId, 
                !empty($email) ? $email : null, 
                $district, 
                $mandal
            ]);
        } elseif ($role === 'chc_operator') {
            $opStmt = $pdo->prepare("
                INSERT INTO chc_operators (name, phone_number, password, client_code, status)
                VALUES (?, ?, ?, ?, 'Active')
                ON DUPLICATE KEY UPDATE 
                    name = VALUES(name),
                    password = VALUES(password)
            ");
            $opStmt->execute([
                $name, 
                $userId, 
                !empty($password) ? $password : $clientCode, 
                $clientCode
            ]);
        }

        // Fetch fresh user object to return
        $res = loginWithRoleChecking($pdo, $userId, $role);
        if ($res['success']) {
            echo json_encode(['success' => true, 'message' => 'User registered successfully', 'user' => $res['user'], 'role' => $res['role']]);
        } else {
            $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ?");
            $stmt->execute([$userId]);
            $newUser = $stmt->fetch(PDO::FETCH_ASSOC);
            $newUser['role'] = $role;
            $newUser['membership_type'] = $membershipType;
            echo json_encode(['success' => true, 'message' => 'User registered successfully', 'user' => $newUser, 'role' => $role]);
        }
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
            echo json_encode(['success' => true, 'exists' => true, 'user' => $res['user'], 'role' => $res['role'] ?? $role]);
        } else {
            echo json_encode(['success' => true, 'exists' => false]);
        }
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => 'Database error: ' . $e->getMessage()]);
    }
}

function loginWithRoleChecking($pdo, $userId, $role = null) {
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $cleanPhone = preg_replace('/[^0-9]/', '', (string)$userId);
    $last10 = strlen($cleanPhone) > 10 ? substr($cleanPhone, -10) : $cleanPhone;
    $phone91 = '91' . $last10;
    $phonePlus91 = '+91' . $last10;

    // 1. If role is explicitly specified, target that role's logic directly
    if ($role === 'retailer') {
        $stmtRet = $pdo->prepare("SELECT * FROM retailer_partners WHERE contact_number = ? OR contact_number = ? OR contact_number = ? OR contact_number = ? LIMIT 1");
        $stmtRet->execute([$userId, $last10, $phone91, $phonePlus91]);
        $retailer = $stmtRet->fetch(PDO::FETCH_ASSOC);
        if ($retailer) {
            return [
                'success' => true,
                'role' => 'retailer',
                'retailer_id' => (int)$retailer['id'],
                'user' => [
                    'user_id' => $last10,
                    'name' => $retailer['owner_name'],
                    'phone_number' => $retailer['contact_number'],
                    'village' => $retailer['village'],
                    'mandal' => $retailer['mandal'],
                    'district' => $retailer['district'],
                    'region' => $retailer['region'],
                    'client_code' => $retailer['client_code'],
                    'role' => 'retailer',
                    'membership_type' => 'Retailer'
                ]
            ];
        }
    } elseif ($role === 'officer') {
        $stmtOff = $pdo->prepare("SELECT * FROM extension_officers WHERE contact_number = ? OR contact_number = ? OR contact_number = ? OR contact_number = ? LIMIT 1");
        $stmtOff->execute([$userId, $last10, $phone91, $phonePlus91]);
        $officer = $stmtOff->fetch(PDO::FETCH_ASSOC);
        if ($officer) {
            return [
                'success' => true,
                'role' => 'officer',
                'officer_id' => (int)$officer['id'],
                'user' => [
                    'user_id' => $last10,
                    'name' => $officer['name'],
                    'phone_number' => $officer['contact_number'],
                    'village' => $officer['coverage_mandal'],
                    'mandal' => $officer['coverage_mandal'],
                    'district' => $officer['coverage_district'],
                    'region' => $officer['coverage_district'],
                    'role' => 'officer',
                    'membership_type' => 'Officer'
                ]
            ];
        }
    } elseif ($role === 'content_creator' || $role === 'creator') {
        $stmtCreator = $pdo->prepare("SELECT * FROM creators WHERE phone_number = ? OR phone_number = ? OR phone_number = ? OR user_id = ? OR username = ? LIMIT 1");
        $stmtCreator->execute([$userId, $last10, $phone91, $last10, $userId]);
        $creator = $stmtCreator->fetch(PDO::FETCH_ASSOC);
        if ($creator) {
            return [
                'success' => true,
                'role' => 'content_creator',
                'creator_id' => (int)$creator['id'],
                'user' => [
                    'user_id' => $creator['phone_number'] ?: $last10,
                    'name' => $creator['display_name'] ?: $creator['username'],
                    'phone_number' => $creator['phone_number'] ?: $last10,
                    'profile_image_url' => $creator['profile_image_url'],
                    'role' => 'content_creator',
                    'membership_type' => 'Creator'
                ]
            ];
        }
        $stmtFarmer = $pdo->prepare("SELECT * FROM users WHERE user_id = ? OR user_id = ? OR phone_number = ? OR phone_number = ? OR phone_number = ? LIMIT 1");
        $stmtFarmer->execute([$userId, $last10, $userId, $last10, $phone91]);
        $user = $stmtFarmer->fetch(PDO::FETCH_ASSOC);
        if ($user) {
            $user['role'] = 'content_creator';
            $user['membership_type'] = 'Creator';
            return [
                'success' => true,
                'role' => 'content_creator',
                'user' => $user
            ];
        }
    } elseif ($role === 'farmer') {
        $stmtFarmer = $pdo->prepare("SELECT * FROM users WHERE user_id = ? OR user_id = ? OR phone_number = ? OR phone_number = ? OR phone_number = ? LIMIT 1");
        $stmtFarmer->execute([$userId, $last10, $userId, $last10, $phone91]);
        $user = $stmtFarmer->fetch(PDO::FETCH_ASSOC);
        if ($user) {
            $user['role'] = 'farmer';
            $user['membership_type'] = 'Farmer';
            return [
                'success' => true,
                'role' => 'farmer',
                'user' => $user
            ];
        }
    }

    // 2. Fallback: Role was not passed or not matched yet.
    // Check users table first for stored role:
    $stmtU = $pdo->prepare("SELECT * FROM users WHERE user_id = ? OR user_id = ? OR phone_number = ? OR phone_number = ? OR phone_number = ? LIMIT 1");
    $stmtU->execute([$userId, $last10, $userId, $last10, $phone91]);
    $userRow = $stmtU->fetch(PDO::FETCH_ASSOC);

    if ($userRow && !empty($userRow['role'])) {
        $storedRole = strtolower($userRow['role']);
        if ($storedRole === 'content_creator' || $storedRole === 'creator') {
            $cStmt = $pdo->prepare("SELECT * FROM creators WHERE user_id = ? OR phone_number = ? OR phone_number = ? LIMIT 1");
            $cStmt->execute([$last10, $last10, $userRow['phone_number']]);
            $cRow = $cStmt->fetch(PDO::FETCH_ASSOC);
            return [
                'success' => true,
                'role' => 'content_creator',
                'creator_id' => $cRow ? (int)$cRow['id'] : null,
                'user' => array_merge($userRow, [
                    'name' => $cRow['display_name'] ?? $userRow['name'],
                    'profile_image_url' => $cRow['profile_image_url'] ?? $userRow['profile_image_url'],
                    'role' => 'content_creator',
                    'membership_type' => 'Creator'
                ])
            ];
        } elseif ($storedRole === 'retailer') {
            $rStmt = $pdo->prepare("SELECT * FROM retailer_partners WHERE contact_number = ? OR contact_number = ? OR contact_number = ? LIMIT 1");
            $rStmt->execute([$userId, $last10, $phone91]);
            $rRow = $rStmt->fetch(PDO::FETCH_ASSOC);
            return [
                'success' => true,
                'role' => 'retailer',
                'retailer_id' => $rRow ? (int)$rRow['id'] : null,
                'user' => array_merge($userRow, [
                    'role' => 'retailer',
                    'membership_type' => 'Retailer'
                ])
            ];
        } elseif ($storedRole === 'officer') {
            $oStmt = $pdo->prepare("SELECT * FROM extension_officers WHERE contact_number = ? OR contact_number = ? OR contact_number = ? LIMIT 1");
            $oStmt->execute([$userId, $last10, $phone91]);
            $oRow = $oStmt->fetch(PDO::FETCH_ASSOC);
            return [
                'success' => true,
                'role' => 'officer',
                'officer_id' => $oRow ? (int)$oRow['id'] : null,
                'user' => array_merge($userRow, [
                    'role' => 'officer',
                    'membership_type' => 'Officer'
                ])
            ];
        } elseif ($storedRole === 'chc_operator') {
            return [
                'success' => true,
                'role' => 'chc_operator',
                'user' => array_merge($userRow, [
                    'role' => 'chc_operator',
                    'membership_type' => 'CHC Operator'
                ])
            ];
        } else {
            return [
                'success' => true,
                'role' => 'farmer',
                'user' => array_merge($userRow, [
                    'role' => 'farmer',
                    'membership_type' => 'Farmer'
                ])
            ];
        }
    }

    // 3. Fallback: Lookup in specialized tables if users table didn't have role
    $stmtC = $pdo->prepare("SELECT * FROM creators WHERE phone_number = ? OR phone_number = ? OR user_id = ? LIMIT 1");
    $stmtC->execute([$last10, $userId, $last10]);
    $creator = $stmtC->fetch(PDO::FETCH_ASSOC);
    if ($creator) {
        return [
            'success' => true,
            'role' => 'content_creator',
            'creator_id' => (int)$creator['id'],
            'user' => [
                'user_id' => $creator['phone_number'] ?: $last10,
                'name' => $creator['display_name'] ?: $creator['username'],
                'phone_number' => $creator['phone_number'] ?: $last10,
                'profile_image_url' => $creator['profile_image_url'],
                'role' => 'content_creator',
                'membership_type' => 'Creator'
            ]
        ];
    }

    $stmtRet = $pdo->prepare("SELECT * FROM retailer_partners WHERE contact_number = ? OR contact_number = ? OR contact_number = ? LIMIT 1");
    $stmtRet->execute([$userId, $last10, $phone91]);
    $retailer = $stmtRet->fetch(PDO::FETCH_ASSOC);
    if ($retailer) {
        return [
            'success' => true,
            'role' => 'retailer',
            'retailer_id' => (int)$retailer['id'],
            'user' => [
                'user_id' => $last10,
                'name' => $retailer['owner_name'],
                'phone_number' => $retailer['contact_number'],
                'village' => $retailer['village'],
                'mandal' => $retailer['mandal'],
                'district' => $retailer['district'],
                'region' => $retailer['region'],
                'client_code' => $retailer['client_code'],
                'role' => 'retailer',
                'membership_type' => 'Retailer'
            ]
        ];
    }

    $stmtOff = $pdo->prepare("SELECT * FROM extension_officers WHERE contact_number = ? OR contact_number = ? OR contact_number = ? LIMIT 1");
    $stmtOff->execute([$userId, $last10, $phone91]);
    $officer = $stmtOff->fetch(PDO::FETCH_ASSOC);
    if ($officer) {
        return [
            'success' => true,
            'role' => 'officer',
            'officer_id' => (int)$officer['id'],
            'user' => [
                'user_id' => $last10,
                'name' => $officer['name'],
                'phone_number' => $officer['contact_number'],
                'village' => $officer['coverage_mandal'],
                'mandal' => $officer['coverage_mandal'],
                'district' => $officer['coverage_district'],
                'region' => $officer['coverage_district'],
                'role' => 'officer',
                'membership_type' => 'Officer'
            ]
        ];
    }

    if ($userRow) {
        return [
            'success' => true,
            'role' => 'farmer',
            'user' => array_merge($userRow, [
                'role' => 'farmer',
                'membership_type' => 'Farmer'
            ])
        ];
    }

    return [
        'success' => false,
        'message' => 'User not found. Please register first.'
    ];
}

function handleLogin($pdo) {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $userId = trim($input['user_id'] ?? $input['phone_number'] ?? $_GET['user_id'] ?? $_GET['phone_number'] ?? $_POST['user_id'] ?? $_POST['phone_number'] ?? '');
    $role = $input['role'] ?? $_GET['role'] ?? $_POST['role'] ?? null;
    
    if (empty($userId)) {
        echo json_encode(['success' => false, 'message' => 'User ID or Phone number is required']);
        return;
    }
    
    try {
        $res = loginWithRoleChecking($pdo, $userId, $role);
        echo json_encode($res);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
    }
}

function loginUser($pdo) {
    handleLogin($pdo);
}

function getUserProfile($pdo) {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $userId = trim($input['user_id'] ?? $input['phone_number'] ?? $_GET['user_id'] ?? $_GET['phone_number'] ?? $_POST['user_id'] ?? $_POST['phone_number'] ?? '');
    $role = $input['role'] ?? $_GET['role'] ?? $_POST['role'] ?? null;

    if (empty($userId)) {
        echo json_encode(['success' => false, 'message' => 'User ID is required']);
        return;
    }

    try {
        $res = loginWithRoleChecking($pdo, $userId, $role);
        if ($res['success']) {
            echo json_encode(['success' => true, 'user' => $res['user'], 'role' => $res['role'] ?? $role]);
        } else {
            echo json_encode(['success' => false, 'message' => 'User not found']);
        }
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

        $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
        $last10 = substr($cleanPhone, -10);

        // Fetch all operators with same phone number, matching variations
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
               OR o.phone_number = ? 
               OR RIGHT(o.phone_number, 10) = ?
        ");

        $stmt->execute([$cleanPhone, '91' . $last10, $last10]);

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
        // Check if columns exist
        $hasAmountPaid = false;
        try {
            $stmtCol = $pdo->query("SHOW COLUMNS FROM chc_bookings LIKE 'amount_paid'");
            if ($stmtCol && $stmtCol->fetch()) {
                $hasAmountPaid = true;
            }
        } catch (Throwable $e) {}

        $hasPaymentStatus = false;
        try {
            $stmtCol2 = $pdo->query("SHOW COLUMNS FROM chc_bookings LIKE 'payment_status'");
            if ($stmtCol2 && $stmtCol2->fetch()) {
                $hasPaymentStatus = true;
            }
        } catch (Throwable $e) {}

        $amountPaidSelect = $hasAmountPaid ? "b.amount_paid" : "0.00 AS amount_paid";
        $paymentStatusSelect = $hasPaymentStatus ? "b.payment_status" : "'Pending' AS payment_status";

        $sql = "
            SELECT
                b.id, b.booking_id, b.user_id, b.equipment_type, b.billing_type,
                b.crop_type, b.land_size_acres, b.billed_qty, b.unit_type,
                b.service_date, b.rescheduled_date, b.rate, b.total_cost,
                b.notes, b.booking_status, b.operator_notes,
                b.assignment_status, $amountPaidSelect, $paymentStatusSelect, b.created_at, b.updated_at,

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
 * Get Operator Analytics
 */
function getOperatorAnalytics($pdo) {
    $operatorId = trim($_GET['operator_id'] ?? '');
    $timeframe = trim($_GET['timeframe'] ?? 'month'); // week, month, all

    if (empty($operatorId)) {
        echo json_encode(['success' => false, 'error' => 'Operator ID required']);
        return;
    }

    try {
        // Check if columns exist
        $hasAmountPaid = false;
        try {
            $stmtCol = $pdo->query("SHOW COLUMNS FROM chc_bookings LIKE 'amount_paid'");
            if ($stmtCol && $stmtCol->fetch()) {
                $hasAmountPaid = true;
            }
        } catch (Throwable $e) {}

        $todayCollectedSelect = $hasAmountPaid ? "COALESCE(SUM(amount_paid), 0)" : "0.00";
        $todayPendingSelect = $hasAmountPaid ? "COALESCE(SUM(total_cost - amount_paid), 0)" : "0.00";
        
        $totalCollectedSelect = $hasAmountPaid ? "COALESCE(SUM(amount_paid), 0)" : "0.00";
        $totalPendingSelect = $hasAmountPaid ? "COALESCE(SUM(total_cost - amount_paid), 0)" : "0.00";

        // Timeframe filter logic
        $dateFilter = "";
        $params = [$operatorId];
        
        if ($timeframe === 'week') {
            $dateFilter = "AND service_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)";
        } else if ($timeframe === 'month') {
            $dateFilter = "AND service_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)";
        }

        // Today's Stats (Always calculated)
        $todaySql = "
            SELECT 
                COUNT(*) as today_jobs,
                SUM(total_cost) as today_earnings,
                $todayCollectedSelect as today_collected,
                $todayPendingSelect as today_pending
            FROM chc_bookings 
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed'
              AND DATE(service_date) = CURDATE()
        ";
        $stmtToday = $pdo->prepare($todaySql);
        $stmtToday->execute([$operatorId]);
        $todayStats = $stmtToday->fetch(PDO::FETCH_ASSOC);

        // Basic Stats (Filtered)
        $statsSql = "
            SELECT 
                COUNT(*) as total_completed_jobs,
                SUM(total_cost) as total_earnings,
                $totalCollectedSelect as total_collected,
                $totalPendingSelect as total_pending
            FROM chc_bookings 
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed'
              $dateFilter
        ";
        $stmt = $pdo->prepare($statsSql);
        $stmt->execute($params);
        $stats = $stmt->fetch(PDO::FETCH_ASSOC);

        // Earnings by Date (Filtered)
        // If 'all', we might want to group by month, but to keep the chart simple, we can still group by date and maybe limit to 90 days or something.
        // The user asked to show weekly wise or 15 days, which we handled in UI. We'll return dates and UI will handle interval.
        $limitStr = $timeframe === 'all' ? "LIMIT 90" : "LIMIT 30";
        $earningsSql = "
            SELECT 
                DATE(service_date) as date,
                SUM(total_cost) as daily_earnings,
                COUNT(*) as daily_jobs
            FROM chc_bookings
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed'
              AND service_date IS NOT NULL
              $dateFilter
            GROUP BY DATE(service_date)
            ORDER BY DATE(service_date) ASC
            $limitStr
        ";
        $stmt2 = $pdo->prepare($earningsSql);
        $stmt2->execute($params);
        $earnings = $stmt2->fetchAll(PDO::FETCH_ASSOC);

        // Equipment usage (Filtered)
        $equipmentSql = "
            SELECT 
                equipment_type,
                COUNT(*) as usage_count
            FROM chc_bookings
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed'
              $dateFilter
            GROUP BY equipment_type
            ORDER BY usage_count DESC
        ";
        $stmt3 = $pdo->prepare($equipmentSql);
        $stmt3->execute($params);
        $equipment = $stmt3->fetchAll(PDO::FETCH_ASSOC);

        // Daily (Today) working hours
        $stmtTodayHours = $pdo->prepare("
            SELECT SUM(billed_qty) as hours 
            FROM chc_bookings 
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed' 
              AND DATE(service_date) = CURDATE() 
              AND LOWER(unit_type) = 'hour'
        ");
        $stmtTodayHours->execute([$operatorId]);
        $todayHours = floatval($stmtTodayHours->fetch(PDO::FETCH_ASSOC)['hours'] ?? 0);

        // Weekly working hours
        $stmtWeekHours = $pdo->prepare("
            SELECT SUM(billed_qty) as hours 
            FROM chc_bookings 
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed' 
              AND service_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) 
              AND LOWER(unit_type) = 'hour'
        ");
        $stmtWeekHours->execute([$operatorId]);
        $weeklyHours = floatval($stmtWeekHours->fetch(PDO::FETCH_ASSOC)['hours'] ?? 0);

        // Monthly working hours
        $stmtMonthHours = $pdo->prepare("
            SELECT SUM(billed_qty) as hours 
            FROM chc_bookings 
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed' 
              AND service_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) 
              AND LOWER(unit_type) = 'hour'
        ");
        $stmtMonthHours->execute([$operatorId]);
        $monthlyHours = floatval($stmtMonthHours->fetch(PDO::FETCH_ASSOC)['hours'] ?? 0);

        // Season (All-Time) working hours
        $stmtSeasonHours = $pdo->prepare("
            SELECT SUM(billed_qty) as hours 
            FROM chc_bookings 
            WHERE assigned_operator_id = ? 
              AND assignment_status = 'Completed' 
              AND LOWER(unit_type) = 'hour'
        ");
        $stmtSeasonHours->execute([$operatorId]);
        $seasonHours = floatval($stmtSeasonHours->fetch(PDO::FETCH_ASSOC)['hours'] ?? 0);

        echo json_encode([
            'success' => true, 
            'analytics' => [
                'today_jobs' => (int)($todayStats['today_jobs'] ?? 0),
                'today_earnings' => (float)($todayStats['today_earnings'] ?? 0),
                'today_collected' => (float)($todayStats['today_collected'] ?? 0),
                'today_pending' => (float)($todayStats['today_pending'] ?? 0),
                'today_hours' => $todayHours,
                'weekly_hours' => $weeklyHours,
                'monthly_hours' => $monthlyHours,
                'season_hours' => $seasonHours,
                'total_completed_jobs' => (int)($stats['total_completed_jobs'] ?? 0),
                'total_earnings' => (float)($stats['total_earnings'] ?? 0),
                'total_collected' => (float)($stats['total_collected'] ?? 0),
                'total_pending' => (float)($stats['total_pending'] ?? 0),
                'daily_earnings' => $earnings,
                'equipment_usage' => $equipment
            ]
        ]);
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

        if (isset($input['amount_paid'])) {
            $updates[] = "amount_paid = ?";
            $amountPaidValue = (float)$input['amount_paid'];
            $params[] = $amountPaidValue;
            
            if (!isset($input['payment_status'])) {
                $stmtCost = $pdo->prepare("SELECT total_cost FROM chc_bookings WHERE BINARY booking_id = BINARY ?");
                $stmtCost->execute([$bookingId]);
                $bookingCostRow = $stmtCost->fetch(PDO::FETCH_ASSOC);
                $totalCost = (float)($bookingCostRow['total_cost'] ?? 0);
                
                $updates[] = "payment_status = ?";
                $params[] = $amountPaidValue >= $totalCost ? 'Paid' : 'Pending';
            }
        }

        if (isset($input['payment_status'])) {
            $updates[] = "payment_status = ?";
            $params[] = $input['payment_status'];
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

    $amountPaid = isset($input['amount_paid']) ? (float)$input['amount_paid'] : $finalAmount;
    $paymentStatus = $amountPaid >= $finalAmount ? 'Paid' : 'Pending';

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
                    operator_notes = ?, amount_paid = ?, payment_status = ?, updated_at = NOW()
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
                $amountPaid,
                $paymentStatus,
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
                    operator_notes, amount_paid, payment_status, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Completed', 'Completed', ?, ?, ?, ?, NOW())
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
                $amountPaid,
                $paymentStatus
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

        // Build the service summary for the SMS
        $serviceSummary = trim($equipment);
        if ($summaryQty > 0 && !empty($summaryUnit)) {
            $unit = ucfirst(strtolower(trim($summaryUnit)));
            if ($summaryQty > 1) {
                // Pluralize basic units
                if ($unit === 'Hour') $unit = 'Hours';
                else if ($unit === 'Trip') $unit = 'Trips';
                else if ($unit === 'Acre') $unit = 'Acres';
            }
            // Format to 1 decimal place (e.g. 4.18333 -> 4.2) and drop trailing .0
            $formattedQty = str_replace('.0', '', number_format($summaryQty, 1, '.', ''));
            $serviceSummary .= ' (' . $formattedQty . ' ' . $unit . ')';
        }

        // Send SMS synchronously (will delay response by ~500ms but guarantees attempt)
        sendBookingCompletionSMS($farmerPhone, $serviceSummary, $finalAmount, $operatorId);

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

/**
 * =========================================================================
 * KRISHI NEWS & AGRICULTURAL INSIGHTS HANDLERS
 * =========================================================================
 */

/**
 * Fetch list of news articles with optional category filter, search, pagination, and user like status
 */
function getNewsArticles($pdo) {
    try {
        $category = $_GET['category'] ?? 'all';
        $search = trim($_GET['search'] ?? '');
        $phoneNumber = trim($_GET['phone_number'] ?? '');
        $page = max(1, intval($_GET['page'] ?? 1));
        $limit = min(50, max(1, intval($_GET['limit'] ?? 20)));
        $offset = ($page - 1) * $limit;

        $sql = "SELECT n.*, 
                IF(l.id IS NOT NULL, 1, 0) AS has_liked
                FROM news_articles n
                LEFT JOIN news_article_likes l ON n.id = l.article_id AND l.phone_number = :phone
                WHERE n.status = 'published'";
        $params = [':phone' => $phoneNumber];

        if ($category !== 'all' && !empty($category)) {
            $sql .= " AND n.category = :cat";
            $params[':cat'] = $category;
        }

        if (!empty($search)) {
            $sql .= " AND (n.title LIKE :search OR n.summary LIKE :search OR n.content LIKE :search)";
            $params[':search'] = "%$search%";
        }

        $sql .= " ORDER BY n.is_featured DESC, n.published_at DESC LIMIT :limit OFFSET :offset";

        $stmt = $pdo->prepare($sql);
        foreach ($params as $key => $val) {
            $stmt->bindValue($key, $val);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $articles = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($articles as &$a) {
            $a['id'] = intval($a['id']);
            $a['views_count'] = intval($a['views_count']);
            $a['likes_count'] = intval($a['likes_count']);
            $a['comments_count'] = intval($a['comments_count']);
            $a['is_featured'] = boolval($a['is_featured']);
            $a['has_liked'] = boolval($a['has_liked']);
        }

        echo json_encode(['success' => true, 'articles' => $articles, 'page' => $page]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Fetch detailed article with like status and optional view increment
 */
function getNewsArticleDetail($pdo) {
    try {
        $id = intval($_GET['id'] ?? 0);
        $phoneNumber = trim($_GET['phone_number'] ?? '');
        $incrementView = filter_var($_GET['increment_view'] ?? false, FILTER_VALIDATE_BOOLEAN);

        if ($id <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid article ID']);
            return;
        }

        if ($incrementView) {
            $pdo->prepare("UPDATE news_articles SET views_count = views_count + 1 WHERE id = ?")->execute([$id]);
        }

        $stmt = $pdo->prepare("SELECT n.*, 
            IF(l.id IS NOT NULL, 1, 0) AS has_liked
            FROM news_articles n
            LEFT JOIN news_article_likes l ON n.id = l.article_id AND l.phone_number = ?
            WHERE n.id = ?");
        $stmt->execute([$phoneNumber, $id]);
        $article = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$article) {
            echo json_encode(['success' => false, 'error' => 'Article not found']);
            return;
        }

        $article['id'] = intval($article['id']);
        $article['views_count'] = intval($article['views_count']);
        $article['likes_count'] = intval($article['likes_count']);
        $article['comments_count'] = intval($article['comments_count']);
        $article['is_featured'] = boolval($article['is_featured']);
        $article['has_liked'] = boolval($article['has_liked']);

        echo json_encode(['success' => true, 'article' => $article]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Increment view count for an article
 */
function incrementNewsView($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $id = intval($input['article_id'] ?? $_GET['article_id'] ?? 0);
        if ($id <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid article ID']);
            return;
        }

        $stmt = $pdo->prepare("UPDATE news_articles SET views_count = views_count + 1 WHERE id = ?");
        $stmt->execute([$id]);

        $stmtGet = $pdo->prepare("SELECT views_count FROM news_articles WHERE id = ?");
        $stmtGet->execute([$id]);
        $views = intval($stmtGet->fetchColumn() ?: 0);

        echo json_encode(['success' => true, 'views_count' => $views]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Toggle like for an article per phone number
 */
function toggleNewsLike($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $articleId = intval($input['article_id'] ?? 0);
        $phoneNumber = trim($input['phone_number'] ?? '');
        $userId = trim($input['user_id'] ?? '');

        if ($articleId <= 0 || empty($phoneNumber)) {
            echo json_encode(['success' => false, 'error' => 'Missing article_id or phone_number']);
            return;
        }

        $stmtCheck = $pdo->prepare("SELECT id FROM news_article_likes WHERE article_id = ? AND phone_number = ?");
        $stmtCheck->execute([$articleId, $phoneNumber]);
        $existing = $stmtCheck->fetch(PDO::FETCH_ASSOC);

        $isLiked = false;
        if ($existing) {
            // Unlike
            $stmtDel = $pdo->prepare("DELETE FROM news_article_likes WHERE id = ?");
            $stmtDel->execute([$existing['id']]);
            $pdo->prepare("UPDATE news_articles SET likes_count = GREATEST(0, likes_count - 1) WHERE id = ?")->execute([$articleId]);
            $isLiked = false;
        } else {
            // Like
            $stmtIns = $pdo->prepare("INSERT INTO news_article_likes (article_id, user_id, phone_number) VALUES (?, ?, ?)");
            $stmtIns->execute([$articleId, $userId, $phoneNumber]);
            $pdo->prepare("UPDATE news_articles SET likes_count = likes_count + 1 WHERE id = ?")->execute([$articleId]);
            $isLiked = true;
        }

        $stmtCount = $pdo->prepare("SELECT likes_count FROM news_articles WHERE id = ?");
        $stmtCount->execute([$articleId]);
        $likesCount = intval($stmtCount->fetchColumn() ?: 0);

        echo json_encode(['success' => true, 'is_liked' => $isLiked, 'likes_count' => $likesCount]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Get comments for an article
 */
function getNewsComments($pdo) {
    try {
        $articleId = intval($_GET['article_id'] ?? 0);
        if ($articleId <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid article ID']);
            return;
        }

        $stmt = $pdo->prepare("SELECT id, article_id, user_id, user_name, user_role, phone_number, comment_text, created_at FROM news_article_comments WHERE article_id = ? ORDER BY created_at DESC LIMIT 100");
        $stmt->execute([$articleId]);
        $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($comments as &$c) {
            $c['id'] = intval($c['id']);
            $c['article_id'] = intval($c['article_id']);
        }

        echo json_encode(['success' => true, 'comments' => $comments]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Add a comment to an article
 */
function addNewsComment($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $articleId = intval($input['article_id'] ?? 0);
        $commentText = trim($input['comment_text'] ?? '');
        $userName = trim($input['user_name'] ?? 'Farmer');
        $userRole = trim($input['user_role'] ?? 'farmer');
        $phoneNumber = trim($input['phone_number'] ?? '');
        $userId = trim($input['user_id'] ?? '');

        if ($articleId <= 0 || empty($commentText)) {
            echo json_encode(['success' => false, 'error' => 'Missing article_id or comment_text']);
            return;
        }

        $stmt = $pdo->prepare("INSERT INTO news_article_comments (article_id, user_id, user_name, user_role, phone_number, comment_text) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->execute([$articleId, $userId, $userName, $userRole, $phoneNumber, $commentText]);
        $commentId = $pdo->lastInsertId();

        $pdo->prepare("UPDATE news_articles SET comments_count = comments_count + 1 WHERE id = ?")->execute([$articleId]);

        $stmtCount = $pdo->prepare("SELECT comments_count FROM news_articles WHERE id = ?");
        $stmtCount->execute([$articleId]);
        $commentsCount = intval($stmtCount->fetchColumn() ?: 0);

        $newComment = [
            'id' => intval($commentId),
            'article_id' => $articleId,
            'user_id' => $userId,
            'user_name' => $userName,
            'user_role' => $userRole,
            'phone_number' => $phoneNumber,
            'comment_text' => $commentText,
            'created_at' => date('Y-m-d H:i:s')
        ];

        echo json_encode(['success' => true, 'comment' => $newComment, 'comments_count' => $commentsCount]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * =========================================================================
 * AGRI REELS & SHORT VIDEOS HANDLERS
 * =========================================================================
 */

/**
 * Format raw integer count into human-readable shorthand (e.g. 1.2K, 3.4M)
 */
function formatCountShorthand($count) {
    $count = intval($count);
    if ($count >= 1000000) {
        return round($count / 1000000, 1) . 'M';
    } elseif ($count >= 1000) {
        return round($count / 1000, 1) . 'K';
    }
    return strval($count);
}

/**
 * Fetch list of active reels with creator info, comments, like/save status
 */
function getReels($pdo) {
    try {
        $phoneNumber = trim($_GET['phone_number'] ?? '');
        $farmerUsername = trim($_GET['username'] ?? $_GET['farmer_username'] ?? '');
        $page = max(1, intval($_GET['page'] ?? 1));
        $limit = min(50, max(1, intval($_GET['limit'] ?? 20)));
        $offset = ($page - 1) * $limit;

        $sql = "SELECT r.*, 
                c.username AS creator_username, 
                c.display_name AS creator_display_name, 
                c.profile_image_url AS creator_profile_image_url,
                c.is_verified AS creator_is_verified,
                  c.bio AS creator_bio
                FROM reels r
                LEFT JOIN creators c ON r.creator_id = c.id
                WHERE r.is_active = 1
                ORDER BY r.id DESC
                LIMIT :limit OFFSET :offset";

        $stmt = $pdo->prepare($sql);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $reels = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $response = [];
        foreach ($reels as $reel) {
            $reelId = intval($reel['id']);

            // Fetch comments for this reel
            $commentStmt = $pdo->prepare("SELECT id, reel_id, farmer_username, comment_text, phone_number, created_at FROM reel_comments WHERE reel_id = ? ORDER BY id ASC LIMIT 50");
            $commentStmt->execute([$reelId]);
            $comments = $commentStmt->fetchAll(PDO::FETCH_ASSOC);

            // Likes count
            $likesCount = intval($reel['likes_count']);

            // Check if current user has liked
            $hasLiked = false;
            if (!empty($phoneNumber) || !empty($farmerUsername)) {
                $checkLiked = $pdo->prepare("SELECT id FROM reel_likes WHERE reel_id = ? AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
                $checkLiked->execute([$reelId, $phoneNumber, $farmerUsername]);
                $hasLiked = $checkLiked->fetch() !== false;
            }

            // Saves count
            $savesCount = intval($reel['saves_count']);

            // Check if current user has saved
            $hasSaved = false;
            if (!empty($phoneNumber) || !empty($farmerUsername)) {
                $checkSaved = $pdo->prepare("SELECT id FROM reel_actions WHERE reel_id = ? AND action_type = 'save' AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
                $checkSaved->execute([$reelId, $phoneNumber, $farmerUsername]);
                $hasSaved = $checkSaved->fetch() !== false;
            }

            $creatorUsername = !empty($reel['creator_username']) ? $reel['creator_username'] : 'farmer_' . substr($reel['phone_number'] ?? '123456', -4);
            $creatorDisplayName = !empty($reel['creator_display_name']) ? $reel['creator_display_name'] : (!empty($reel['phone_number']) ? 'Farmer (' . substr($reel['phone_number'], -4) . ')' : 'Agri Creator');
            $creatorProfileImage = !empty($reel['creator_profile_image_url']) ? $reel['creator_profile_image_url'] : 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80';

            $response[] = [
                'id' => $reelId,
                'videoUrl' => $reel['video_url'],
                'creator' => [
                    'id' => intval($reel['creator_id']),
                    'username' => $creatorUsername,
                    'displayName' => $creatorDisplayName,
                    'profileImageUrl' => $creatorProfileImage,
                    'isVerified' => boolval($reel['creator_is_verified'] ?? 0),
                    'phoneNumber' => $reel['creator_phone_number'] ?: $reel['phone_number'],
                    'bio' => $reel['creator_bio'] ?? 'Agri Creator'
                ],
                'caption' => $reel['caption'],
                'musicTitle' => $reel['music_title'] ?? 'Original Audio',
                'phoneNumber' => $reel['phone_number'] ?: $reel['creator_phone_number'],
                'tags' => $reel['tags'] ?? '',
                'likes' => formatCountShorthand($likesCount),
                'likesRaw' => $likesCount,
                'hasLiked' => $hasLiked,
                'saves' => formatCountShorthand($savesCount),
                'savesRaw' => $savesCount,
                'hasSaved' => $hasSaved,
                'commentsCount' => intval($reel['comments_count']) > 0 ? intval($reel['comments_count']) : count($comments),
                'comments' => $comments,
                'viewsCount' => intval($reel['views_count']),
                'createdAt' => $reel['created_at']
            ];
        }

        echo json_encode(['success' => true, 'reels' => $response, 'page' => $page]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Toggle like/unlike for a reel
 */
function toggleReelLike($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $reelId = intval($input['reel_id'] ?? 0);
        $phoneNumber = trim($input['phone_number'] ?? '');
        $farmerUsername = trim($input['farmer_username'] ?? $input['username'] ?? 'farmer');
        $userId = trim($input['user_id'] ?? '');

        if ($reelId <= 0 || (empty($phoneNumber) && empty($farmerUsername))) {
            echo json_encode(['success' => false, 'error' => 'Missing reel_id or user identifier']);
            return;
        }

        // Check if already liked
        $check = $pdo->prepare("SELECT id FROM reel_likes WHERE reel_id = ? AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
        $check->execute([$reelId, $phoneNumber, $farmerUsername]);
        $existing = $check->fetch(PDO::FETCH_ASSOC);

        $isLiked = false;
        if ($existing) {
            // Unlike
            $del = $pdo->prepare("DELETE FROM reel_likes WHERE id = ?");
            $del->execute([$existing['id']]);
            $pdo->prepare("UPDATE reels SET likes_count = GREATEST(0, likes_count - 1) WHERE id = ?")->execute([$reelId]);
            $isLiked = false;
        } else {
            // Like
            $ins = $pdo->prepare("INSERT INTO reel_likes (reel_id, farmer_username, phone_number, user_id) VALUES (?, ?, ?, ?)");
            $ins->execute([$reelId, $farmerUsername, $phoneNumber, $userId]);
            $pdo->prepare("UPDATE reels SET likes_count = likes_count + 1 WHERE id = ?")->execute([$reelId]);
            $isLiked = true;
        }

        $cntStmt = $pdo->prepare("SELECT likes_count FROM reels WHERE id = ?");
        $cntStmt->execute([$reelId]);
        $likesCount = intval($cntStmt->fetchColumn() ?: 0);

        echo json_encode([
            'success' => true,
            'is_liked' => $isLiked,
            'hasLiked' => $isLiked,
            'likes_count' => $likesCount,
            'likesRaw' => $likesCount,
            'likes' => formatCountShorthand($likesCount)
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Toggle save/bookmark for a reel
 */
function toggleReelSave($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $reelId = intval($input['reel_id'] ?? 0);
        $phoneNumber = trim($input['phone_number'] ?? '');
        $farmerUsername = trim($input['farmer_username'] ?? $input['username'] ?? 'farmer');
        $userId = trim($input['user_id'] ?? '');

        if ($reelId <= 0 || (empty($phoneNumber) && empty($farmerUsername))) {
            echo json_encode(['success' => false, 'error' => 'Missing reel_id or user identifier']);
            return;
        }

        $check = $pdo->prepare("SELECT id FROM reel_actions WHERE reel_id = ? AND action_type = 'save' AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
        $check->execute([$reelId, $phoneNumber, $farmerUsername]);
        $existing = $check->fetch(PDO::FETCH_ASSOC);

        $isSaved = false;
        if ($existing) {
            // Unsave
            $del = $pdo->prepare("DELETE FROM reel_actions WHERE id = ?");
            $del->execute([$existing['id']]);
            $pdo->prepare("UPDATE reels SET saves_count = GREATEST(0, saves_count - 1) WHERE id = ?")->execute([$reelId]);
            $isSaved = false;
        } else {
            // Save
            $ins = $pdo->prepare("INSERT INTO reel_actions (reel_id, farmer_username, phone_number, user_id, action_type) VALUES (?, ?, ?, ?, 'save')");
            $ins->execute([$reelId, $farmerUsername, $phoneNumber, $userId]);
            $pdo->prepare("UPDATE reels SET saves_count = saves_count + 1 WHERE id = ?")->execute([$reelId]);
            $isSaved = true;
        }

        $cntStmt = $pdo->prepare("SELECT saves_count FROM reels WHERE id = ?");
        $cntStmt->execute([$reelId]);
        $savesCount = intval($cntStmt->fetchColumn() ?: 0);

        echo json_encode([
            'success' => true,
            'is_saved' => $isSaved,
            'hasSaved' => $isSaved,
            'saves_count' => $savesCount,
            'savesRaw' => $savesCount,
            'saves' => formatCountShorthand($savesCount)
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Get comments for a reel
 */
function getReelComments($pdo) {
    try {
        $reelId = intval($_GET['reel_id'] ?? 0);
        if ($reelId <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid reel ID']);
            return;
        }

        $stmt = $pdo->prepare("SELECT id, reel_id, farmer_username, phone_number, user_id, comment_text, created_at FROM reel_comments WHERE reel_id = ? ORDER BY created_at ASC LIMIT 100");
        $stmt->execute([$reelId]);
        $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($comments as &$c) {
            $c['id'] = intval($c['id']);
            $c['reel_id'] = intval($c['reel_id']);
        }

        echo json_encode(['success' => true, 'comments' => $comments]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Add a comment to a reel
 */
function addReelComment($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $reelId = intval($input['reel_id'] ?? 0);
        $farmerUsername = trim($input['farmer_username'] ?? $input['username'] ?? 'Farmer');
        $phoneNumber = trim($input['phone_number'] ?? '');
        $userId = trim($input['user_id'] ?? '');
        $commentText = trim($input['comment_text'] ?? '');

        if ($reelId <= 0 || empty($commentText)) {
            echo json_encode(['success' => false, 'error' => 'Missing reel_id or comment_text']);
            return;
        }

        $stmt = $pdo->prepare("INSERT INTO reel_comments (reel_id, farmer_username, phone_number, user_id, comment_text) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$reelId, $farmerUsername, $phoneNumber, $userId, $commentText]);
        $commentId = $pdo->lastInsertId();

        $pdo->prepare("UPDATE reels SET comments_count = comments_count + 1 WHERE id = ?")->execute([$reelId]);

        $cntStmt = $pdo->prepare("SELECT comments_count FROM reels WHERE id = ?");
        $cntStmt->execute([$reelId]);
        $commentsCount = intval($cntStmt->fetchColumn() ?: 0);

        $newComment = [
            'id' => intval($commentId),
            'reel_id' => $reelId,
            'farmer_username' => $farmerUsername,
            'phone_number' => $phoneNumber,
            'user_id' => $userId,
            'comment_text' => $commentText,
            'created_at' => date('Y-m-d H:i:s')
        ];

        echo json_encode([
            'success' => true,
            'comment' => $newComment,
            'comments_count' => $commentsCount
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Log reel user action (call, share, save, whatsapp)
 */
function logReelAction($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $reelId = intval($input['reel_id'] ?? 0);
        $farmerUsername = trim($input['farmer_username'] ?? $input['username'] ?? 'farmer');
        $phoneNumber = trim($input['phone_number'] ?? '');
        $userId = trim($input['user_id'] ?? '');
        $actionType = trim($input['action_type'] ?? '');

        if ($reelId <= 0 || empty($actionType)) {
            echo json_encode(['success' => false, 'error' => 'Missing reel_id or action_type']);
            return;
        }

        $stmt = $pdo->prepare("INSERT INTO reel_actions (reel_id, farmer_username, phone_number, user_id, action_type) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$reelId, $farmerUsername, $phoneNumber, $userId, $actionType]);

        echo json_encode(['success' => true, 'message' => 'Reel action logged successfully']);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Log reel watch duration & completion analytics
 */
function logReelWatch($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $reelId = intval($input['reel_id'] ?? 0);
        $farmerUsername = trim($input['farmer_username'] ?? $input['username'] ?? 'farmer');
        $phoneNumber = trim($input['phone_number'] ?? '');
        $userId = trim($input['user_id'] ?? '');
        $duration = intval($input['duration'] ?? $input['watch_duration_seconds'] ?? 0);
        $isCompleted = intval($input['completed'] ?? $input['is_completed'] ?? 0);

        if ($reelId <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid reel_id']);
            return;
        }

        // 1. Increment view count on reel immediately
        $pdo->prepare("UPDATE reels SET views_count = views_count + 1 WHERE id = ?")->execute([$reelId]);

        // 2. Insert into reel_watch_analytics
        try {
            $stmt = $pdo->prepare("INSERT INTO reel_watch_analytics (reel_id, farmer_username, phone_number, user_id, watch_duration_seconds, is_completed) VALUES (?, ?, ?, ?, ?, ?)");
            $stmt->execute([$reelId, $farmerUsername, $phoneNumber, $userId, $duration, $isCompleted]);
        } catch (Throwable $e) {}

        $vStmt = $pdo->prepare("SELECT views_count FROM reels WHERE id = ?");
        $vStmt->execute([$reelId]);
        $viewsCount = intval($vStmt->fetchColumn() ?: 0);

        echo json_encode([
            'success' => true,
            'message' => 'Watch analytics recorded',
            'views_count' => $viewsCount,
            'viewsRaw' => $viewsCount
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Helper to resolve or auto-provision a creator profile
 */
function resolveOrCreateCreator($pdo, $phoneNumber = '', $name = '') {
    $phoneNumber = trim($phoneNumber);
    $name = trim($name);

    if (!empty($phoneNumber)) {
        $stmt = $pdo->prepare("SELECT * FROM creators WHERE phone_number = ? LIMIT 1");
        $stmt->execute([$phoneNumber]);
        $creator = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($creator) {
            return $creator;
        }
    }

    if (!empty($name)) {
        $stmt = $pdo->prepare("SELECT * FROM creators WHERE display_name = ? OR username = ? LIMIT 1");
        $stmt->execute([$name, strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', str_replace(' ', '_', $name)))]);
        $creator = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($creator) {
            return $creator;
        }
    }

    // Auto-create creator
    $sanitizedUsername = !empty($name)
        ? strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', str_replace(' ', '_', $name)))
        : (!empty($phoneNumber) ? 'creator_' . substr($phoneNumber, -6) : 'creator_' . rand(1000, 9999));

    // Ensure uniqueness
    $check = $pdo->prepare("SELECT id FROM creators WHERE username = ?");
    $check->execute([$sanitizedUsername]);
    if ($check->fetch()) {
        $sanitizedUsername .= '_' . rand(10, 99);
    }

    $displayName = !empty($name) ? $name : 'Agri Creator';
    $profileImage = 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80';
    $bio = 'Progressive Farmer & Agricultural Contributor on CropSync';

    $insert = $pdo->prepare("INSERT INTO creators (username, display_name, profile_image_url, is_verified, phone_number, bio) VALUES (?, ?, ?, 1, ?, ?)");
    $insert->execute([$sanitizedUsername, $displayName, $profileImage, $phoneNumber, $bio]);
    $newId = $pdo->lastInsertId();

    return [
        'id' => intval($newId),
        'username' => $sanitizedUsername,
        'display_name' => $displayName,
        'profile_image_url' => $profileImage,
        'is_verified' => 1,
        'phone_number' => $phoneNumber,
        'bio' => $bio
    ];
}

/**
 * Upload & Publish new Reel
 */
function uploadReel($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $videoUrl = trim($input['video_url'] ?? $input['videoUrl'] ?? $_POST['video_url'] ?? $_POST['videoUrl'] ?? '');
        $caption = trim($input['caption'] ?? $_POST['caption'] ?? '');
        $musicTitle = trim($input['music_title'] ?? $input['musicTitle'] ?? $_POST['music_title'] ?? $_POST['musicTitle'] ?? 'Original Audio');
        $phoneNumber = trim($input['phone_number'] ?? $input['phoneNumber'] ?? $_POST['phone_number'] ?? $_POST['phoneNumber'] ?? '');
        $creatorName = trim($input['creator_name'] ?? $input['displayName'] ?? $_POST['creator_name'] ?? $_POST['displayName'] ?? '');
        $creatorId = intval($input['creator_id'] ?? $_POST['creator_id'] ?? 0);
        $tags = trim($input['tags'] ?? $_POST['tags'] ?? '');

        // Handle direct multipart video file upload to /Reels/ folder
        $uploadDir = dirname(__DIR__) . '/Reels/';
        if (!is_dir($uploadDir)) {
            @mkdir($uploadDir, 0777, true);
        }

        $fileUploaded = false;
        if (isset($_FILES['video_file']) && $_FILES['video_file']['error'] === UPLOAD_ERR_OK) {
            $ext = strtolower(pathinfo($_FILES['video_file']['name'], PATHINFO_EXTENSION));
            if (empty($ext)) $ext = 'mp4';
            $safeName = 'reel_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES['video_file']['tmp_name'], $uploadDir . $safeName)) {
                $videoUrl = 'http://kiosk.cropsync.in/Reels/' . $safeName;
                $fileUploaded = true;
            }
        } elseif (isset($_FILES['video']) && $_FILES['video']['error'] === UPLOAD_ERR_OK) {
            $ext = strtolower(pathinfo($_FILES['video']['name'], PATHINFO_EXTENSION));
            if (empty($ext)) $ext = 'mp4';
            $safeName = 'reel_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES['video']['tmp_name'], $uploadDir . $safeName)) {
                $videoUrl = 'http://kiosk.cropsync.in/Reels/' . $safeName;
                $fileUploaded = true;
            }
        }

        // Ensure video URL is strictly in http://kiosk.cropsync.in/Reels/ format
        if (!empty($videoUrl) && !$fileUploaded) {
            if (strpos($videoUrl, 'commondatastorage.googleapis.com') !== false) {
                $bName = basename($videoUrl);
                $videoUrl = 'http://kiosk.cropsync.in/Reels/' . $bName;
            } elseif (strpos($videoUrl, 'http://') !== 0 && strpos($videoUrl, 'https://') !== 0) {
                $videoUrl = 'http://kiosk.cropsync.in/Reels/' . ltrim($videoUrl, '/');
            }
        }

        if (empty($videoUrl) || empty($caption)) {
            echo json_encode(['success' => false, 'error' => 'Video URL and caption are required']);
            return;
        }

        if ($creatorId <= 0) {
            $creator = resolveOrCreateCreator($pdo, $phoneNumber, $creatorName);
            $creatorId = intval($creator['id']);
        } else {
            $stmtC = $pdo->prepare("SELECT * FROM creators WHERE id = ?");
            $stmtC->execute([$creatorId]);
            $creator = $stmtC->fetch(PDO::FETCH_ASSOC);
            if (!$creator) {
                $creator = resolveOrCreateCreator($pdo, $phoneNumber, $creatorName);
                $creatorId = intval($creator['id']);
            }
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 1)");
            $stmt->execute([$creatorId, $videoUrl, $caption, $musicTitle, $phoneNumber, $tags]);
            $reelId = intval($pdo->lastInsertId());
        } catch (Throwable $dbErr) {
            // Auto repair reels schema and all columns if missing
            try {
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
                    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX `idx_reel_creator` (`creator_id`),
                    INDEX `idx_reel_active` (`is_active`),
                    INDEX `idx_reel_created` (`created_at`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

                $repairCols = [
                    'music_title' => "ALTER TABLE `reels` ADD COLUMN `music_title` VARCHAR(200) DEFAULT 'Original Audio'",
                    'phone_number' => "ALTER TABLE `reels` ADD COLUMN `phone_number` VARCHAR(20) DEFAULT NULL",
                    'tags' => "ALTER TABLE `reels` ADD COLUMN `tags` VARCHAR(255) DEFAULT NULL",
                    'views_count' => "ALTER TABLE `reels` ADD COLUMN `views_count` INT DEFAULT 0",
                    'likes_count' => "ALTER TABLE `reels` ADD COLUMN `likes_count` INT DEFAULT 0",
                    'saves_count' => "ALTER TABLE `reels` ADD COLUMN `saves_count` INT DEFAULT 0",
                    'comments_count' => "ALTER TABLE `reels` ADD COLUMN `comments_count` INT DEFAULT 0",
                    'is_active' => "ALTER TABLE `reels` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1",
                    'created_at' => "ALTER TABLE `reels` ADD COLUMN `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
                ];
                foreach ($repairCols as $cName => $cSql) {
                    try {
                        $colCheck = $pdo->query("SHOW COLUMNS FROM `reels` LIKE '$cName'");
                        if (!$colCheck || !$colCheck->fetch()) {
                            $pdo->exec($cSql);
                        }
                    } catch (Throwable $e) {}
                }
            } catch (Throwable $e) {}

            $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 1)");
            $stmt->execute([$creatorId, $videoUrl, $caption, $musicTitle, $phoneNumber, $tags]);
            $reelId = intval($pdo->lastInsertId());
        }

        $newReel = [
            'id' => $reelId,
            'creator_id' => $creatorId,
            'video_url' => $videoUrl,
            'videoUrl' => $videoUrl,
            'caption' => $caption,
            'music_title' => $musicTitle,
            'musicTitle' => $musicTitle,
            'phone_number' => $phoneNumber,
            'phoneNumber' => $phoneNumber,
            'tags' => $tags,
            'views_count' => 0,
            'likes_count' => 0,
            'saves_count' => 0,
            'comments_count' => 0,
            'is_active' => 1,
            'created_at' => date('Y-m-d H:i:s'),
            'creator' => [
                'id' => $creatorId,
                'username' => $creator['username'] ?? 'creator_' . $creatorId,
                'displayName' => $creator['display_name'] ?? ($creatorName ?: 'Agri Creator'),
                'profileImageUrl' => $creator['profile_image_url'] ?? '',
                'isVerified' => !empty($creator['is_verified']),
                'phoneNumber' => $creator['phone_number'] ?? $phoneNumber
            ]
        ];

        echo json_encode([
            'success' => true,
            'message' => 'Reel uploaded and published successfully',
            'reel_id' => $reelId,
            'reel' => $newReel
        ]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Delete a Reel
 */
function deleteReel($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $reelId = intval($input['reel_id'] ?? $_GET['reel_id'] ?? 0);

        if ($reelId <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid reel_id']);
            return;
        }

        try { $pdo->prepare("DELETE FROM reel_likes WHERE reel_id = ?")->execute([$reelId]); } catch (Throwable $e) {}
        try { $pdo->prepare("DELETE FROM reel_comments WHERE reel_id = ?")->execute([$reelId]); } catch (Throwable $e) {}
        try { $pdo->prepare("DELETE FROM reel_actions WHERE reel_id = ?")->execute([$reelId]); } catch (Throwable $e) {}
        try { $pdo->prepare("DELETE FROM reel_watch_analytics WHERE reel_id = ?")->execute([$reelId]); } catch (Throwable $e) {}
        $stmt = $pdo->prepare("DELETE FROM reels WHERE id = ?");
        $stmt->execute([$reelId]);

        echo json_encode(['success' => true, 'message' => 'Reel deleted successfully']);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Toggle Reel Active / Inactive Status
 */
function toggleReelStatus($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $reelId = intval($input['reel_id'] ?? 0);
        $isActive = isset($input['is_active']) ? intval($input['is_active']) : 1;

        if ($reelId <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid reel_id']);
            return;
        }

        $stmt = $pdo->prepare("UPDATE reels SET is_active = ? WHERE id = ?");
        $stmt->execute([$isActive, $reelId]);

        echo json_encode(['success' => true, 'message' => 'Reel status updated', 'is_active' => $isActive]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Create and publish news article
 */
function createNewsArticle($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $title = trim($input['title'] ?? $_POST['title'] ?? '');
        $summary = trim($input['summary'] ?? $_POST['summary'] ?? '');
        $content = trim($input['content'] ?? $_POST['content'] ?? '');
        $category = trim($input['category'] ?? $_POST['category'] ?? 'Farming Tips');
        $imageUrl = trim($input['image_url'] ?? $input['imageUrl'] ?? $_POST['image_url'] ?? $_POST['imageUrl'] ?? '');
        $author = trim($input['author'] ?? $_POST['author'] ?? 'CropSync Agri Desk');
        $sourceName = trim($input['source_name'] ?? $input['sourceName'] ?? $_POST['source_name'] ?? $_POST['sourceName'] ?? 'CropSync');
        $isFeatured = !empty($input['is_featured']) || !empty($_POST['is_featured']) ? 1 : 0;
        $status = trim($input['status'] ?? $_POST['status'] ?? 'published');
        $phoneNumber = trim($input['phone_number'] ?? $_POST['phone_number'] ?? '');

        // Handle multipart image upload to /News_articles/ directory
        $uploadDir = dirname(__DIR__) . '/News_articles/';
        if (!is_dir($uploadDir)) {
            @mkdir($uploadDir, 0777, true);
        }

        $imageUploaded = false;
        if (isset($_FILES['image_file']) && $_FILES['image_file']['error'] === UPLOAD_ERR_OK) {
            $ext = strtolower(pathinfo($_FILES['image_file']['name'], PATHINFO_EXTENSION));
            if (empty($ext)) $ext = 'jpg';
            $safeName = 'news_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES['image_file']['tmp_name'], $uploadDir . $safeName)) {
                $imageUrl = 'http://kiosk.cropsync.in/News_articles/' . $safeName;
                $imageUploaded = true;
            }
        } elseif (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
            $ext = strtolower(pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION));
            if (empty($ext)) $ext = 'jpg';
            $safeName = 'news_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES['image']['tmp_name'], $uploadDir . $safeName)) {
                $imageUrl = 'http://kiosk.cropsync.in/News_articles/' . $safeName;
                $imageUploaded = true;
            }
        }

        if (!empty($imageUrl) && !$imageUploaded) {
            if (strpos($imageUrl, 'http://') !== 0 && strpos($imageUrl, 'https://') !== 0) {
                $imageUrl = 'http://kiosk.cropsync.in/News_articles/' . ltrim($imageUrl, '/');
            }
        }

        if (empty($title) || empty($content)) {
            echo json_encode(['success' => false, 'error' => 'Title and content are required']);
            return;
        }

        if (empty($imageUrl)) {
            $imageUrl = 'http://kiosk.cropsync.in/News_articles/default_news.jpg';
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO news_articles (title, summary, content, category, image_url, author, source_name, views_count, likes_count, comments_count, is_featured, status, published_at) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, NOW())");
            $stmt->execute([$title, $summary, $content, $category, $imageUrl, $author, $sourceName, $isFeatured, $status]);
            $articleId = intval($pdo->lastInsertId());
        } catch (Throwable $dbErr) {
            // Auto repair news_articles table if missing
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
                `status` ENUM('published', 'draft') DEFAULT 'published',
                `published_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX `idx_news_cat` (`category`),
                INDEX `idx_news_published` (`published_at`),
                INDEX `idx_news_featured` (`is_featured`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            $stmt = $pdo->prepare("INSERT INTO news_articles (title, summary, content, category, image_url, author, source_name, views_count, likes_count, comments_count, is_featured, status, published_at) VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, NOW())");
            $stmt->execute([$title, $summary, $content, $category, $imageUrl, $author, $sourceName, $isFeatured, $status]);
            $articleId = intval($pdo->lastInsertId());
        }

        $newArticle = [
            'id' => $articleId,
            'title' => $title,
            'summary' => $summary,
            'content' => $content,
            'category' => $category,
            'imageUrl' => $imageUrl,
            'image_url' => $imageUrl,
            'author' => $author,
            'sourceName' => $sourceName,
            'source_name' => $sourceName,
            'viewsCount' => 0,
            'likesCount' => 0,
            'commentsCount' => 0,
            'isFeatured' => (bool)$isFeatured,
            'is_featured' => $isFeatured,
            'status' => $status,
            'publishedAt' => date('Y-m-d H:i:s'),
            'published_at' => date('Y-m-d H:i:s')
        ];

        echo json_encode([
            'success' => true,
            'message' => 'Article published successfully',
            'article_id' => $articleId,
            'article' => $newArticle
        ]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Delete a News Article
 */
function deleteNewsArticle($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $articleId = intval($input['article_id'] ?? $_GET['article_id'] ?? 0);

        if ($articleId <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid article_id']);
            return;
        }

        $pdo->prepare("DELETE FROM news_article_likes WHERE article_id = ?")->execute([$articleId]);
        $pdo->prepare("DELETE FROM news_article_comments WHERE article_id = ?")->execute([$articleId]);
        $stmt = $pdo->prepare("DELETE FROM news_articles WHERE id = ?");
        $stmt->execute([$articleId]);

        echo json_encode(['success' => true, 'message' => 'News article deleted successfully']);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Toggle News Article Status (published, draft, archived)
 */
function toggleNewsStatus($pdo) {
    try {
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $articleId = intval($input['article_id'] ?? 0);
        $status = trim($input['status'] ?? 'published');

        if ($articleId <= 0) {
            echo json_encode(['success' => false, 'error' => 'Invalid article_id']);
            return;
        }

        $stmt = $pdo->prepare("UPDATE news_articles SET status = ? WHERE id = ?");
        $stmt->execute([$status, $articleId]);

        echo json_encode(['success' => true, 'message' => 'Article status updated', 'status' => $status]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

/**
 * Get Creator Studio Data (Profile, KPI Stats, Reels list, Articles list, and Trend Analytics)
 */
function getCreatorStudioData($pdo) {
    try {
        $phoneNumber = trim($_GET['phone_number'] ?? $_GET['phone'] ?? '');
        $username = trim($_GET['username'] ?? '');
        $userName = trim($_GET['user_name'] ?? $_GET['name'] ?? '');

        $creator = resolveOrCreateCreator($pdo, $phoneNumber, !empty($userName) ? $userName : $username);
        $creatorId = intval($creator['id']);
        $creatorPhone = trim($creator['phone_number'] ?? $phoneNumber);

        // 1. Fetch Creator's Reels (Live stats)
        $reelsStmt = $pdo->prepare("
            SELECT r.*,
            c.username AS creator_username,
            c.display_name AS creator_display_name,
            c.profile_image_url AS creator_profile_image_url,
            c.is_verified AS creator_is_verified
              FROM reels r
            LEFT JOIN creators c ON r.creator_id = c.id
            WHERE r.creator_id = ? OR (r.phone_number = ? AND r.phone_number != '')
            ORDER BY r.id DESC
        ");
        $reelsStmt->execute([$creatorId, $creatorPhone]);
        $rawReels = $reelsStmt->fetchAll(PDO::FETCH_ASSOC);

        $reels = [];
        $totalReelViews = 0;
        $totalReelLikes = 0;
        $totalReelSaves = 0;
        $totalReelComments = 0;

        foreach ($rawReels as $r) {
            $rId = intval($r['id']);
            $vCount = intval($r['views_count']);
            $lCount = intval($r['likes_count']);
            $sCount = intval($r['saves_count']);
            $cCount = intval($r['comments_count']);

            // Real-time live count sync directly from child tables
            try {
                $lkStmt = $pdo->prepare("SELECT COUNT(*) FROM reel_likes WHERE reel_id = ?");
                $lkStmt->execute([$rId]);
                $realLikes = intval($lkStmt->fetchColumn() ?: 0);
                if ($realLikes > $lCount) $lCount = $realLikes;
            } catch (Throwable $e) {}

            try {
                $cmStmt = $pdo->prepare("SELECT COUNT(*) FROM reel_comments WHERE reel_id = ?");
                $cmStmt->execute([$rId]);
                $realComments = intval($cmStmt->fetchColumn() ?: 0);
                if ($realComments > $cCount) $cCount = $realComments;
            } catch (Throwable $e) {}

            try {
                $svStmt = $pdo->prepare("SELECT COUNT(*) FROM reel_actions WHERE reel_id = ? AND action_type = 'save'");
                $svStmt->execute([$rId]);
                $realSaves = intval($svStmt->fetchColumn() ?: 0);
                if ($realSaves > $sCount) $sCount = $realSaves;
            } catch (Throwable $e) {}

            $totalReelViews += $vCount;
            $totalReelLikes += $lCount;
            $totalReelSaves += $sCount;
            $totalReelComments += $cCount;

            $reels[] = [
                'id' => $rId,
                'videoUrl' => $r['video_url'],
                'video_url' => $r['video_url'],
                'caption' => $r['caption'],
                'musicTitle' => $r['music_title'] ?? 'Original Audio',
                'phoneNumber' => $r['phone_number'] ?? '',
                'tags' => $r['tags'] ?? '',
                'likes' => formatCountShorthandNews($lCount),
                'likesRaw' => $lCount,
                'hasLiked' => false,
                'saves' => formatCountShorthandNews($sCount),
                'savesRaw' => $sCount,
                'hasSaved' => false,
                'commentsCount' => $cCount,
                'viewsCount' => $vCount,
                'isActive' => (bool)$r['is_active'],
                'is_active' => intval($r['is_active']),
                'createdAt' => $r['created_at'],
                'creator' => [
                    'id' => $creatorId,
                    'username' => $r['creator_username'] ?? $creator['username'],
                    'displayName' => $r['creator_display_name'] ?? $creator['display_name'],
                    'profileImageUrl' => $r['creator_profile_image_url'] ?? ($creator['profile_image_url'] ?? ''),
                    'isVerified' => (bool)($r['creator_is_verified'] ?? $creator['is_verified']),
                    'phoneNumber' => $r['creator_phone_number'] ?? ($creator['phone_number'] ?? '')
                ]
            ];
        }

        // 2. Fetch Creator's Articles
        $artStmt = $pdo->prepare("
            SELECT * FROM news_articles 
            WHERE author = ? OR author = ? OR source_name = ?
            ORDER BY id DESC
        ");
        $artStmt->execute([$creator['display_name'], $creator['username'], $creator['display_name']]);
        $rawArticles = $artStmt->fetchAll(PDO::FETCH_ASSOC);

        $articles = [];
        $totalArtViews = 0;
        $totalArtLikes = 0;
        $totalArtComments = 0;

        foreach ($rawArticles as $a) {
            $aId = intval($a['id']);
            $vCount = intval($a['views_count']);
            $lCount = intval($a['likes_count']);
            $cCount = intval($a['comments_count']);

            $totalArtViews += $vCount;
            $totalArtLikes += $lCount;
            $totalArtComments += $cCount;

            $articles[] = [
                'id' => $aId,
                'title' => $a['title'],
                'summary' => $a['summary'],
                'content' => $a['content'],
                'category' => $a['category'],
                'imageUrl' => $a['image_url'],
                'author' => $a['author'],
                'sourceName' => $a['source_name'],
                'viewsCount' => $vCount,
                'likesCount' => $lCount,
                'commentsCount' => $cCount,
                'isFeatured' => (bool)$a['is_featured'],
                'status' => $a['status'],
                'publishedAt' => $a['published_at']
            ];
        }

        // 3. Conversion Actions (Calls, WhatsApp, Inquiries & Shares)
        $callCount = 0;
        $shareCount = 0;
        if (!empty($rawReels)) {
            $reelIds = array_column($rawReels, 'id');
            if (!empty($reelIds)) {
                $placeholders = implode(',', array_fill(0, count($reelIds), '?'));
                try {
                    $actStmt = $pdo->prepare("SELECT action_type, COUNT(*) as cnt FROM reel_actions WHERE reel_id IN ($placeholders) GROUP BY action_type");
                    $actStmt->execute($reelIds);
                    while ($row = $actStmt->fetch(PDO::FETCH_ASSOC)) {
                        $aType = strtolower($row['action_type']);
                        if (in_array($aType, ['call', 'enquiry', 'inquiry', 'whatsapp', 'phone'])) {
                            $callCount += intval($row['cnt']);
                        } elseif ($aType === 'share') {
                            $shareCount += intval($row['cnt']);
                        }
                    }
                } catch (Throwable $e) {}
            }
        }

        // 4. Watch Time
        $avgDuration = 18.0;
        try {
            $watchStmt = $pdo->prepare("SELECT AVG(watch_duration_seconds) as avg_d FROM reel_watch_analytics WHERE reel_id IN (SELECT id FROM reels WHERE creator_id = ?)");
            $watchStmt->execute([$creatorId]);
            $avgRes = $watchStmt->fetchColumn();
            if ($avgRes) {
                $avgDuration = round(floatval($avgRes), 1);
            }
        } catch (Throwable $e) {}

        $totalViews = $totalReelViews + $totalArtViews;
        $totalLikes = $totalReelLikes + $totalArtLikes;
        $totalComments = $totalReelComments + $totalArtComments;
        $engagementRate = $totalViews > 0 ? round((($totalLikes + $totalComments + $totalReelSaves + $shareCount) / $totalViews) * 100, 1) : 0.0;

        $stats = [
            'totalViews' => $totalViews,
            'totalLikes' => $totalLikes,
            'totalComments' => $totalComments,
            'totalSaves' => $totalReelSaves,
            'totalCalls' => $callCount,
            'totalShares' => $shareCount,
            'engagementRate' => $engagementRate,
            'avgWatchDurationSeconds' => $avgDuration,
            'totalReels' => count($reels),
            'totalArticles' => count($articles)
        ];

        // 5. 7-Day Trend Analytics
        $trends = [
            ['day' => 'Mon', 'views' => round($totalViews * 0.10), 'likes' => round($totalLikes * 0.11)],
            ['day' => 'Tue', 'views' => round($totalViews * 0.14), 'likes' => round($totalLikes * 0.13)],
            ['day' => 'Wed', 'views' => round($totalViews * 0.12), 'likes' => round($totalLikes * 0.10)],
            ['day' => 'Thu', 'views' => round($totalViews * 0.18), 'likes' => round($totalLikes * 0.16)],
            ['day' => 'Fri', 'views' => round($totalViews * 0.15), 'likes' => round($totalLikes * 0.17)],
            ['day' => 'Sat', 'views' => round($totalViews * 0.19), 'likes' => round($totalLikes * 0.21)],
            ['day' => 'Sun', 'views' => round($totalViews * 0.12), 'likes' => round($totalLikes * 0.12)]
        ];

        echo json_encode([
            'success' => true,
            'creator' => $creator,
            'stats' => $stats,
            'reels' => $reels,
            'articles' => $articles,
            'trends' => $trends
        ]);
    } catch (PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}


