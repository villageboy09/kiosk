<?php
/**
 * CropSync Studio Dashboard - Krishi News & Agri Reels Management
 * Minimalist, modern dashboard with Google Sans typography, Alpine.js custom dropdowns,
 * custom drag-and-drop file upload with live progress indicator, and modal management.
 */

session_start();

// -------------------------------------------------------------
// 1. Database Connection & Environment Setup
// -------------------------------------------------------------
$configPaths = [
    __DIR__ . '/config.php',
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

// Ensure UTF-8 & tables existence
if (isset($pdo) && $pdo instanceof PDO) {
    try {
        $pdo->exec("SET NAMES utf8mb4");

        // news_articles table
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
            INDEX `idx_news_published` (`published_at`),
            INDEX `idx_news_featured` (`is_featured`),
            INDEX `idx_news_status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // creators table
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

        // reels table
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

        // Migrate any missing columns in creators
        $creatorCols = [
            'status' => "ALTER TABLE `creators` ADD COLUMN `status` ENUM('applied', 'pending_review', 'active', 'rejected', 'suspended') DEFAULT 'active'",
            'partnership_tier' => "ALTER TABLE `creators` ADD COLUMN `partnership_tier` ENUM('trial', 'active_partner', 'verified', 'strategic') DEFAULT 'trial'",
            'agriculture_niches' => "ALTER TABLE `creators` ADD COLUMN `agriculture_niches` TEXT NULL",
            'languages' => "ALTER TABLE `creators` ADD COLUMN `languages` TEXT NULL",
            'social_handles' => "ALTER TABLE `creators` ADD COLUMN `social_handles` TEXT NULL",
            'upi_id' => "ALTER TABLE `creators` ADD COLUMN `upi_id` VARCHAR(100) NULL",
            'terms_accepted' => "ALTER TABLE `creators` ADD COLUMN `terms_accepted` TINYINT(1) DEFAULT 0",
            'rejection_reason' => "ALTER TABLE `creators` ADD COLUMN `rejection_reason` TEXT NULL",
            'reviewed_by' => "ALTER TABLE `creators` ADD COLUMN `reviewed_by` VARCHAR(100) NULL",
            'reviewed_at' => "ALTER TABLE `creators` ADD COLUMN `reviewed_at` DATETIME NULL",
            'approved_at' => "ALTER TABLE `creators` ADD COLUMN `approved_at` DATETIME NULL"
        ];
        foreach ($creatorCols as $cCol => $cSql) {
            try {
                $chk = $pdo->query("SHOW COLUMNS FROM `creators` LIKE '$cCol'");
                if (!$chk || !$chk->fetch()) {
                    $pdo->exec($cSql);
                }
            } catch (Throwable $e) {
                try { $pdo->exec($cSql); } catch (Throwable $e2) {}
            }
        }

        // Migrate any missing columns in reels
        $reelsCols = [
            'music_title' => "ALTER TABLE `reels` ADD COLUMN `music_title` VARCHAR(200) DEFAULT 'Original Audio'",
            'phone_number' => "ALTER TABLE `reels` ADD COLUMN `phone_number` VARCHAR(20) DEFAULT NULL",
            'tags' => "ALTER TABLE `reels` ADD COLUMN `tags` VARCHAR(255) DEFAULT NULL",
            'views_count' => "ALTER TABLE `reels` ADD COLUMN `views_count` INT DEFAULT 0",
            'likes_count' => "ALTER TABLE `reels` ADD COLUMN `likes_count` INT DEFAULT 0",
            'saves_count' => "ALTER TABLE `reels` ADD COLUMN `saves_count` INT DEFAULT 0",
            'comments_count' => "ALTER TABLE `reels` ADD COLUMN `comments_count` INT DEFAULT 0",
            'is_active' => "ALTER TABLE `reels` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1",
            'created_at' => "ALTER TABLE `reels` ADD COLUMN `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
            'crop' => "ALTER TABLE `reels` ADD COLUMN `crop` VARCHAR(100) NULL",
            'category' => "ALTER TABLE `reels` ADD COLUMN `category` VARCHAR(100) DEFAULT 'Crop Care'",
            'language' => "ALTER TABLE `reels` ADD COLUMN `language` VARCHAR(50) DEFAULT 'te'",
            'source_url' => "ALTER TABLE `reels` ADD COLUMN `source_url` VARCHAR(500) NULL",
            'content_hash' => "ALTER TABLE `reels` ADD COLUMN `content_hash` VARCHAR(64) NULL",
            'original_content_date' => "ALTER TABLE `reels` ADD COLUMN `original_content_date` DATE NULL",
            'rights_declared' => "ALTER TABLE `reels` ADD COLUMN `rights_declared` TINYINT(1) DEFAULT 1",
            'status' => "ALTER TABLE `reels` ADD COLUMN `status` ENUM('draft', 'submitted', 'under_review', 'changes_requested', 'approved', 'rejected') DEFAULT 'approved'",
            'payout_eligible' => "ALTER TABLE `reels` ADD COLUMN `payout_eligible` TINYINT(1) DEFAULT 1",
            'is_duplicate' => "ALTER TABLE `reels` ADD COLUMN `is_duplicate` TINYINT(1) DEFAULT 0",
            'duplicate_of_reel_id' => "ALTER TABLE `reels` ADD COLUMN `duplicate_of_reel_id` INT NULL",
            'rejection_reason_code' => "ALTER TABLE `reels` ADD COLUMN `rejection_reason_code` VARCHAR(50) NULL",
            'reviewer_feedback' => "ALTER TABLE `reels` ADD COLUMN `reviewer_feedback` TEXT NULL",
            'reviewed_at' => "ALTER TABLE `reels` ADD COLUMN `reviewed_at` DATETIME NULL",
            'reviewed_by' => "ALTER TABLE `reels` ADD COLUMN `reviewed_by` VARCHAR(100) NULL"
        ];
        foreach ($reelsCols as $cCol => $cSql) {
            try {
                $chk = $pdo->query("SHOW COLUMNS FROM `reels` LIKE '$cCol'");
                if (!$chk || !$chk->fetch()) {
                    $pdo->exec($cSql);
                }
            } catch (Throwable $e) {
                try { $pdo->exec($cSql); } catch (Throwable $e2) {}
            }
        }

        // Migrate any missing columns in news_articles
        $newsCols = [
            'status' => "ALTER TABLE `news_articles` ADD COLUMN `status` ENUM('published', 'draft', 'archived') DEFAULT 'published'",
            'is_featured' => "ALTER TABLE `news_articles` ADD COLUMN `is_featured` TINYINT(1) DEFAULT 0",
            'published_at' => "ALTER TABLE `news_articles` ADD COLUMN `published_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
            'title_te' => "ALTER TABLE `news_articles` ADD COLUMN `title_te` VARCHAR(255) DEFAULT NULL",
            'summary_te' => "ALTER TABLE `news_articles` ADD COLUMN `summary_te` TEXT DEFAULT NULL",
            'content_te' => "ALTER TABLE `news_articles` ADD COLUMN `content_te` LONGTEXT DEFAULT NULL",
            'title_hi' => "ALTER TABLE `news_articles` ADD COLUMN `title_hi` VARCHAR(255) DEFAULT NULL",
            'summary_hi' => "ALTER TABLE `news_articles` ADD COLUMN `summary_hi` TEXT DEFAULT NULL",
            'content_hi' => "ALTER TABLE `news_articles` ADD COLUMN `content_hi` LONGTEXT DEFAULT NULL",
            'language' => "ALTER TABLE `news_articles` ADD COLUMN `language` VARCHAR(20) DEFAULT 'all'"
        ];
        foreach ($newsCols as $nCol => $nSql) {
            try {
                $chk = $pdo->query("SHOW COLUMNS FROM `news_articles` LIKE '$nCol'");
                if (!$chk || !$chk->fetch()) {
                    $pdo->exec($nSql);
                }
            } catch (Throwable $e) {
                try { $pdo->exec($nSql); } catch (Throwable $e2) {}
            }
        }

        // Creator Terms Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `creator_terms` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `creator_id` INT NOT NULL,
            `terms_version` VARCHAR(50) DEFAULT 'v1.0',
            `rights_declaration_version` VARCHAR(50) DEFAULT 'v1.0',
            `consent_flags` TEXT NULL,
            `ip_address` VARCHAR(50) NULL,
            `accepted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_terms_creator` (`creator_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Creator Payment Profiles Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `creator_payment_profiles` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `creator_id` INT NOT NULL,
            `payout_method` VARCHAR(50) DEFAULT 'UPI',
            `upi_id` VARCHAR(100) NULL,
            `account_number_masked` VARCHAR(50) NULL,
            `ifsc_code` VARCHAR(20) NULL,
            `verification_status` ENUM('unverified', 'verified', 'rejected') DEFAULT 'unverified',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_payment_creator` (`creator_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Reel Reviews Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `reel_reviews` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `reel_id` INT NOT NULL,
            `reviewer_id` VARCHAR(100) NULL,
            `decision` ENUM('approved', 'changes_requested', 'rejected') NOT NULL,
            `reason_code` VARCHAR(50) NULL,
            `comments` TEXT NULL,
            `reviewed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_review_reel` (`reel_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Reel Events Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `reel_events` (
            `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
            `reel_id` INT NOT NULL,
            `user_id_nullable` VARCHAR(50) NULL,
            `event_type` VARCHAR(50) NOT NULL,
            `session_id` VARCHAR(100) NULL,
            `occurred_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_event_reel` (`reel_id`, `event_type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Monthly Creator Payouts Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `monthly_creator_payouts` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `creator_id` INT NOT NULL,
            `period_month` VARCHAR(7) NOT NULL,
            `eligible_reel_count` INT DEFAULT 0,
            `base_payout` DECIMAL(10,2) DEFAULT 0.00,
            `bonus_total` DECIMAL(10,2) DEFAULT 0.00,
            `adjustments` DECIMAL(10,2) DEFAULT 0.00,
            `gross_payout` DECIMAL(10,2) DEFAULT 0.00,
            `rule_version` VARCHAR(50) DEFAULT 'v1.0',
            `status` ENUM('calculated', 'locked', 'approved', 'paid', 'held') DEFAULT 'calculated',
            `payment_reference` VARCHAR(100) NULL,
            `paid_at` DATETIME NULL,
            `approved_by` VARCHAR(100) NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `uk_creator_month` (`creator_id`, `period_month`),
            INDEX `idx_payout_month` (`period_month`),
            INDEX `idx_payout_status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Payout Line Items Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `payout_line_items` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `payout_id` INT NOT NULL,
            `type` ENUM('base_upload', 'bonus', 'campaign', 'deduction', 'adjustment') DEFAULT 'base_upload',
            `reference_id` VARCHAR(100) NULL,
            `amount` DECIMAL(10,2) NOT NULL,
            `explanation` VARCHAR(255) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_line_payout` (`payout_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Campaigns Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `campaigns` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(255) NOT NULL,
            `client_brand` VARCHAR(255) NOT NULL,
            `objective` TEXT NULL,
            `start_date` DATE NULL,
            `end_date` DATE NULL,
            `budget` DECIMAL(10,2) DEFAULT 0.00,
            `status` ENUM('draft', 'active', 'completed', 'cancelled') DEFAULT 'draft',
            `terms_version` VARCHAR(50) DEFAULT 'v1.0',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Campaign Creator Assignments Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `campaign_creator_assignments` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `campaign_id` INT NOT NULL,
            `creator_id` INT NOT NULL,
            `deliverable_type` VARCHAR(100) DEFAULT 'Instagram Reel + CropSync Agri Reel',
            `negotiated_fee` DECIMAL(10,2) DEFAULT 0.00,
            `due_at` DATETIME NULL,
            `status` ENUM('assigned', 'submitted', 'approved', 'rejected', 'paid') DEFAULT 'assigned',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_camp_creator` (`campaign_id`, `creator_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Campaign Deliverables Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `campaign_deliverables` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `assignment_id` INT NOT NULL,
            `platform` VARCHAR(50) DEFAULT 'Instagram',
            `content_url` VARCHAR(500) NULL,
            `proof_url` VARCHAR(500) NULL,
            `submitted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `approval_status` ENUM('submitted', 'approved', 'changes_requested', 'rejected') DEFAULT 'submitted',
            `reviewed_at` DATETIME NULL,
            `rejection_reason` TEXT NULL,
            INDEX `idx_deliv_assignment` (`assignment_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

        // Audit Logs Table
        $pdo->exec("CREATE TABLE IF NOT EXISTS `audit_logs` (
            `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
            `actor_id` VARCHAR(100) NULL,
            `actor_role` VARCHAR(50) DEFAULT 'admin',
            `entity_type` VARCHAR(50) NOT NULL,
            `entity_id` VARCHAR(100) NOT NULL,
            `action` VARCHAR(100) NOT NULL,
            `before_json` LONGTEXT NULL,
            `after_json` LONGTEXT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_audit_entity` (`entity_type`, `entity_id`),
            INDEX `idx_audit_action` (`action`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
    } catch (Throwable $e) {}
}

// -------------------------------------------------------------
// 2. Helpers
// -------------------------------------------------------------
function setFlash($message, $type = 'success') {
    $_SESSION['flash_msg'] = ['text' => $message, 'type' => $type];
}

function getFlash() {
    if (isset($_SESSION['flash_msg'])) {
        $msg = $_SESSION['flash_msg'];
        unset($_SESSION['flash_msg']);
        return $msg;
    }
    return null;
}

function uploadNewsImage($fileInputName, $defaultUrl = '') {
    $targetDir = __DIR__ . '/News_articles/';
    if (!is_dir($targetDir)) @mkdir($targetDir, 0777, true);

    if (isset($_FILES[$fileInputName]) && $_FILES[$fileInputName]['error'] === UPLOAD_ERR_OK) {
        $ext = strtolower(pathinfo($_FILES[$fileInputName]['name'], PATHINFO_EXTENSION));
        if (in_array($ext, ['jpg', 'jpeg', 'png', 'webp', 'gif'])) {
            $fileName = 'news_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES[$fileInputName]['tmp_name'], $targetDir . $fileName)) {
                return 'http://kiosk.cropsync.in/News_articles/' . $fileName;
            }
        }
    }
    return $defaultUrl;
}

function uploadReelVideo($fileInputName, $defaultUrl = '') {
    $targetDir = __DIR__ . '/Reels/';
    if (!is_dir($targetDir)) @mkdir($targetDir, 0777, true);

    if (isset($_FILES[$fileInputName]) && $_FILES[$fileInputName]['error'] === UPLOAD_ERR_OK) {
        $ext = strtolower(pathinfo($_FILES[$fileInputName]['name'], PATHINFO_EXTENSION));
        if (in_array($ext, ['mp4', 'mov', 'webm', 'avi', 'mkv', 'm4v'])) {
            $fileName = 'reel_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES[$fileInputName]['tmp_name'], $targetDir . $fileName)) {
                return 'http://kiosk.cropsync.in/Reels/' . $fileName;
            }
        }
    }
    return $defaultUrl;
}

/**
 * Deterministic tier ladder calculator based on approved eligible reels
 * Spec:
 *  0-4: ₹0
 *  5-9: ₹50
 *  10-14: ₹100
 *  15-19: ₹150
 *  20-24: ₹225
 *  25-29: ₹275
 *  30+: ₹300 (Maximum base payout)
 */
function getTierBasePayout($approvedCount) {
    $count = intval($approvedCount);
    if ($count >= 30) return 300.00;
    if ($count >= 25) return 275.00;
    if ($count >= 20) return 225.00;
    if ($count >= 15) return 150.00;
    if ($count >= 10) return 100.00;
    if ($count >= 5) return 50.00;
    return 0.00;
}

/**
 * Calculate deterministic monthly payouts for all creators or a single creator
 */
function calculateMonthlyPayoutEngine($pdo, $billingMonth, $specificCreatorId = null) {
    $billingMonth = trim($billingMonth);
    if (!preg_match('/^\d{4}-\d{2}$/', $billingMonth)) {
        $billingMonth = date('Y-m');
    }

    $creatorsSql = "SELECT id, username, display_name, phone_number, status, partnership_tier FROM creators WHERE 1=1";
    $params = [];
    if ($specificCreatorId) {
        $creatorsSql .= " AND id = ?";
        $params[] = intval($specificCreatorId);
    }
    $creatorsStmt = $pdo->prepare($creatorsSql);
    $creatorsStmt->execute($params);
    $creators = $creatorsStmt->fetchAll(PDO::FETCH_ASSOC);

    $results = [];

    foreach ($creators as $c) {
        $cId = intval($c['id']);

        // Check if existing payout record is already approved or paid
        $chkStmt = $pdo->prepare("SELECT * FROM monthly_creator_payouts WHERE creator_id = ? AND period_month = ?");
        $chkStmt->execute([$cId, $billingMonth]);
        $existingPayout = $chkStmt->fetch(PDO::FETCH_ASSOC);

        if ($existingPayout && in_array($existingPayout['status'], ['approved', 'paid'])) {
            // Locked & closed period: do not overwrite
            $results[] = $existingPayout;
            continue;
        }

        // Count approved, non-duplicate eligible reels uploaded in this calendar month
        $approvedCount = 0;
        try {
            $reelsStmt = $pdo->prepare("
                SELECT COUNT(*) AS approved_count
                FROM reels 
                WHERE creator_id = ? 
                  AND (status = 'approved' OR status IS NULL)
                  AND (is_duplicate = 0 OR is_duplicate IS NULL)
                  AND (payout_eligible = 1 OR payout_eligible IS NULL)
                  AND DATE_FORMAT(created_at, '%Y-%m') = ?
            ");
            $reelsStmt->execute([$cId, $billingMonth]);
            $approvedCount = intval($reelsStmt->fetchColumn() ?: 0);
        } catch (Throwable $e) {
            try {
                $reelsStmt = $pdo->prepare("SELECT COUNT(*) FROM reels WHERE creator_id = ? AND is_active = 1 AND DATE_FORMAT(created_at, '%Y-%m') = ?");
                $reelsStmt->execute([$cId, $billingMonth]);
                $approvedCount = intval($reelsStmt->fetchColumn() ?: 0);
            } catch (Throwable $e2) {}
        }

        $basePayout = getTierBasePayout($approvedCount);

        // Fetch bonuses & campaign items from payout_line_items if payout exists
        $bonusTotal = 0.00;
        $adjustments = 0.00;
        if ($existingPayout) {
            try {
                $liStmt = $pdo->prepare("SELECT type, SUM(amount) AS total FROM payout_line_items WHERE payout_id = ? GROUP BY type");
                $liStmt->execute([$existingPayout['id']]);
                $lines = $liStmt->fetchAll(PDO::FETCH_ASSOC);
                foreach ($lines as $line) {
                    if ($line['type'] === 'bonus' || $line['type'] === 'campaign') {
                        $bonusTotal += floatval($line['total']);
                    } elseif ($line['type'] === 'deduction' || $line['type'] === 'adjustment') {
                        $adjustments += floatval($line['total']);
                    }
                }
            } catch (Throwable $e) {}
        }

        $grossPayout = max(0.00, $basePayout + $bonusTotal + $adjustments);

        if ($existingPayout) {
            $upStmt = $pdo->prepare("
                UPDATE monthly_creator_payouts 
                SET eligible_reel_count = ?, base_payout = ?, bonus_total = ?, adjustments = ?, gross_payout = ?
                WHERE id = ?
            ");
            $upStmt->execute([$approvedCount, $basePayout, $bonusTotal, $adjustments, $grossPayout, $existingPayout['id']]);
            $existingPayout['eligible_reel_count'] = $approvedCount;
            $existingPayout['base_payout'] = $basePayout;
            $existingPayout['bonus_total'] = $bonusTotal;
            $existingPayout['adjustments'] = $adjustments;
            $existingPayout['gross_payout'] = $grossPayout;
            $results[] = $existingPayout;
        } else {
            $insStmt = $pdo->prepare("
                INSERT INTO monthly_creator_payouts 
                (creator_id, period_month, eligible_reel_count, base_payout, bonus_total, adjustments, gross_payout, rule_version, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'v1.0', 'calculated')
            ");
            $insStmt->execute([$cId, $billingMonth, $approvedCount, $basePayout, $bonusTotal, $adjustments, $grossPayout]);
            $results[] = [
                'id' => $pdo->lastInsertId(),
                'creator_id' => $cId,
                'period_month' => $billingMonth,
                'eligible_reel_count' => $approvedCount,
                'base_payout' => $basePayout,
                'bonus_total' => $bonusTotal,
                'adjustments' => $adjustments,
                'gross_payout' => $grossPayout,
                'status' => 'calculated'
            ];
        }
    }
    return $results;
}

/**
 * Processes automated approvals for reels pending inspection.
 * SLA Rules:
 *  - Daytime (06:00 to 21:00 IST): If unreviewed for >= 10 minutes, automatically approve and make active.
 *  - Night (21:00 to 06:00 IST): No auto-approvals. Submissions after 9 PM require manual verification.
 */
if (!function_exists('processReelAutoApprovals')) {
    function processReelAutoApprovals($pdo) {
        try {
            if (!$pdo instanceof PDO) return 0;

            $istTz = new DateTimeZone('Asia/Kolkata');
            $now = new DateTime('now', $istTz);
            $currentHour = intval($now->format('G')); // 0 - 23

            // Night window: After 9:00 PM (21:00) until morning (06:00).
            // No auto-approvals are permitted after 9 PM.
            if ($currentHour >= 21 || $currentHour < 6) {
                return 0;
            }

            // Find pending reels created at least 10 minutes ago
            $stmt = $pdo->prepare("
                SELECT id, creator_id, created_at, source_url, is_duplicate 
                FROM reels 
                WHERE (status IN ('submitted', 'under_review') OR (is_active = 0 AND (status IS NULL OR status = '')))
                  AND is_active = 0
                  AND (is_duplicate = 0 OR is_duplicate IS NULL)
                  AND created_at <= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
            ");
            $stmt->execute();
            $candidates = $stmt->fetchAll(PDO::FETCH_ASSOC);

            if (empty($candidates)) return 0;

            $approvedCount = 0;
            $upStmt = $pdo->prepare("
                UPDATE reels 
                SET status = 'approved', 
                    is_active = 1, 
                    payout_eligible = 1, 
                    reviewed_by = 'Auto Approval Engine (10-min SLA)', 
                    reviewed_at = NOW() 
                WHERE id = ? AND is_active = 0
            ");

            $revStmt = $pdo->prepare("
                INSERT INTO reel_reviews (reel_id, reviewer_id, decision, reason_code, comments, reviewed_at)
                VALUES (?, 'System Auto-Approval', 'approved', 'auto_approved_10min', 'Auto-approved after 10-minute moderator SLA elapsed (Daytime)', NOW())
            ");

            foreach ($candidates as $cand) {
                $createdDate = new DateTime($cand['created_at'], $istTz);
                $uploadHour = intval($createdDate->format('G'));
                $uploadMinute = intval($createdDate->format('i'));

                // Rule: If uploaded after 9 PM (21:00 - 05:59), must be manually verified.
                if ($uploadHour >= 21 || $uploadHour < 6) {
                    continue;
                }

                // Rule: If uploaded within 10 minutes of 9 PM (e.g. 20:51 to 20:59),
                // the 10-minute deadline crossed after 9:00 PM, so it fell into the night window.
                // It therefore requires manual verification.
                if ($uploadHour === 20 && $uploadMinute > 50) {
                    continue;
                }

                $reelId = intval($cand['id']);
                $upStmt->execute([$reelId]);

                try {
                    $revStmt->execute([$reelId]);
                } catch (Throwable $e) {}

                if (function_exists('logAudit')) {
                    logAudit($pdo, 'system', 'system', 'reels', $reelId, 'auto_approve_reel',
                        ['status' => 'under_review', 'is_active' => 0],
                        ['status' => 'approved', 'is_active' => 1, 'reason' => '10-minute moderator SLA elapsed (Daytime)']
                    );
                }

                $approvedCount++;
            }

            return $approvedCount;
        } catch (Throwable $e) {
            error_log("Error in processReelAutoApprovals: " . $e->getMessage());
            return 0;
        }
    }
}

// -------------------------------------------------------------
// 3. AJAX File Upload with Progress Support
// -------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['ajax_upload'])) {
    header('Content-Type: application/json');
    $uploadType = $_GET['ajax_upload']; // 'image' or 'video'

    if ($uploadType === 'image') {
        $url = uploadNewsImage('file');
        if (!empty($url)) {
            echo json_encode(['success' => true, 'url' => $url]);
        } else {
            echo json_encode(['success' => false, 'error' => 'Invalid image file or upload failed']);
        }
    } elseif ($uploadType === 'video') {
        $url = uploadReelVideo('file');
        if (!empty($url)) {
            echo json_encode(['success' => true, 'url' => $url]);
        } else {
            echo json_encode(['success' => false, 'error' => 'Invalid video file or upload failed']);
        }
    } else {
        echo json_encode(['success' => false, 'error' => 'Unknown upload type']);
    }
    exit();
}

// -------------------------------------------------------------
// 3b. Free Auto-Translation Helper & AJAX Endpoint
// -------------------------------------------------------------
function freeTranslateText($text, $targetLang = 'te', $sourceLang = 'en') {
    if (empty(trim($text))) return '';

    $paragraphs = explode("\n", $text);
    $translatedParagraphs = [];

    $ctx = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => "User-Agent: CropSync-Studio/2.0\r\n",
            'ignore_errors' => true,
            'timeout' => 12
        ],
        'ssl' => [
            'verify_peer' => false,
            'verify_peer_name' => false
        ]
    ]);

    foreach ($paragraphs as $para) {
        $trimmed = trim($para);
        if ($trimmed === '') {
            $translatedParagraphs[] = '';
            continue;
        }

        $len = function_exists('mb_strlen') ? mb_strlen($trimmed) : strlen($trimmed);
        if ($len > 450) {
            $sentences = preg_split('/(?<=[.?!।])\s+/u', $trimmed, -1, PREG_SPLIT_NO_EMPTY);
            $paraTranslated = [];
            foreach ($sentences as $sentence) {
                $url = "https://api.mymemory.translated.net/get?q=" . urlencode($sentence) . "&langpair=" . urlencode($sourceLang) . "|" . urlencode($targetLang);
                $res = @file_get_contents($url, false, $ctx);
                $json = json_decode($res, true);
                if (!empty($json['responseData']['translatedText'])) {
                    $paraTranslated[] = html_entity_decode($json['responseData']['translatedText'], ENT_QUOTES | ENT_HTML5, 'UTF-8');
                } else {
                    $paraTranslated[] = $sentence;
                }
            }
            $translatedParagraphs[] = implode(' ', $paraTranslated);
        } else {
            $url = "https://api.mymemory.translated.net/get?q=" . urlencode($trimmed) . "&langpair=" . urlencode($sourceLang) . "|" . urlencode($targetLang);
            $res = @file_get_contents($url, false, $ctx);
            $json = json_decode($res, true);
            if (!empty($json['responseData']['translatedText'])) {
                $translatedParagraphs[] = html_entity_decode($json['responseData']['translatedText'], ENT_QUOTES | ENT_HTML5, 'UTF-8');
            } else {
                $translatedParagraphs[] = $trimmed;
            }
        }
    }

    return implode("\n", $translatedParagraphs);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['ajax_translate'])) {
    header('Content-Type: application/json');
    $sourceLang = trim($_POST['source_lang'] ?? 'en');
    $title = trim($_POST['title'] ?? '');
    $summary = trim($_POST['summary'] ?? '');
    $content = trim($_POST['content'] ?? '');

    if (empty($title) && empty($content)) {
        echo json_encode(['success' => false, 'error' => 'Please enter Title or Content before auto-translating.']);
        exit();
    }

    try {
        // Auto-translate to Telugu
        $titleTe = freeTranslateText($title, 'te', $sourceLang);
        $summaryTe = freeTranslateText($summary, 'te', $sourceLang);
        $contentTe = freeTranslateText($content, 'te', $sourceLang);

        // Auto-translate to Hindi
        $titleHi = freeTranslateText($title, 'hi', $sourceLang);
        $summaryHi = freeTranslateText($summary, 'hi', $sourceLang);
        $contentHi = freeTranslateText($content, 'hi', $sourceLang);

        echo json_encode([
            'success' => true,
            'translations' => [
                'te' => [
                    'title' => $titleTe,
                    'summary' => $summaryTe,
                    'content' => $contentTe
                ],
                'hi' => [
                    'title' => $titleHi,
                    'summary' => $summaryHi,
                    'content' => $contentHi
                ]
            ]
        ]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => 'Translation failed: ' . $e->getMessage()]);
    }
    exit();
}

// -------------------------------------------------------------
// 4. POST Handlers (Create, Edit, Delete, Bulk Delete, Status)
// -------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($pdo) && $pdo instanceof PDO) {
    $action = $_POST['action'] ?? '';

    // A. SAVE / EDIT NEWS
    if ($action === 'save_news') {
        $id = intval($_POST['news_id'] ?? 0);
        $title = trim($_POST['title'] ?? '');
        $summary = trim($_POST['summary'] ?? '');
        $content = trim($_POST['content'] ?? '');
        $title_te = trim($_POST['title_te'] ?? '');
        $summary_te = trim($_POST['summary_te'] ?? '');
        $content_te = trim($_POST['content_te'] ?? '');
        $title_hi = trim($_POST['title_hi'] ?? '');
        $summary_hi = trim($_POST['summary_hi'] ?? '');
        $content_hi = trim($_POST['content_hi'] ?? '');
        $language = trim($_POST['language'] ?? 'all');
        $category = trim($_POST['category'] ?? 'Govt Schemes');
        $author = trim($_POST['author'] ?? 'CropSync Desk');
        $source_name = trim($_POST['source_name'] ?? 'Krishi Jagran');
        $status = in_array($_POST['status'] ?? '', ['published', 'draft', 'archived']) ? $_POST['status'] : 'published';
        $is_featured = isset($_POST['is_featured']) ? 1 : 0;
        $image_url = trim($_POST['image_url'] ?? '');

        // Upload fallback if direct form post
        $uploadedImage = uploadNewsImage('image_file');
        if (!empty($uploadedImage)) {
            $image_url = $uploadedImage;
        }

        if (empty($title) || empty($content)) {
            setFlash('Article title and content are required.', 'danger');
        } else {
            if (empty($image_url)) {
                $image_url = 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=800&q=80';
            }
            if (empty($summary)) {
                $summary = mb_substr(strip_tags($content), 0, 160) . '...';
            }

            try {
                if ($id > 0) {
                    $stmt = $pdo->prepare("UPDATE news_articles SET title = ?, summary = ?, content = ?, title_te = ?, summary_te = ?, content_te = ?, title_hi = ?, summary_hi = ?, content_hi = ?, language = ?, category = ?, author = ?, source_name = ?, status = ?, is_featured = ?, image_url = ? WHERE id = ?");
                    $stmt->execute([$title, $summary, $content, $title_te ?: null, $summary_te ?: null, $content_te ?: null, $title_hi ?: null, $summary_hi ?: null, $content_hi ?: null, $language, $category, $author, $source_name, $status, $is_featured, $image_url, $id]);
                    setFlash("Article #$id updated successfully.");
                } else {
                    $stmt = $pdo->prepare("INSERT INTO news_articles (title, summary, content, title_te, summary_te, content_te, title_hi, summary_hi, content_hi, language, category, author, source_name, status, is_featured, image_url, views_count, likes_count, comments_count, published_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, NOW())");
                    $stmt->execute([$title, $summary, $content, $title_te ?: null, $summary_te ?: null, $content_te ?: null, $title_hi ?: null, $summary_hi ?: null, $content_hi ?: null, $language, $category, $author, $source_name, $status, $is_featured, $image_url]);
                    setFlash("New Krishi article published.");
                }
            } catch (Throwable $e) {
                setFlash("Database error: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=news");
        exit();
    }

    // B. DELETE SINGLE NEWS ARTICLE
    if ($action === 'delete_news') {
        $id = intval($_POST['news_id'] ?? 0);
        if ($id > 0) {
            try {
                $pdo->prepare("DELETE FROM news_article_likes WHERE article_id = ?")->execute([$id]);
                $pdo->prepare("DELETE FROM news_article_comments WHERE article_id = ?")->execute([$id]);
                $pdo->prepare("DELETE FROM news_articles WHERE id = ?")->execute([$id]);
                setFlash("Article #$id deleted successfully.");
            } catch (Throwable $e) {
                setFlash("Error deleting article: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=news");
        exit();
    }

    // C. BULK DELETE NEWS ARTICLES
    if ($action === 'bulk_delete_news') {
        $ids = $_POST['selected_news'] ?? [];
        if (!empty($ids) && is_array($ids)) {
            $sanitizedIds = array_map('intval', $ids);
            $sanitizedIds = array_filter($sanitizedIds, function($v) { return $v > 0; });
            if (!empty($sanitizedIds)) {
                $placeholders = implode(',', array_fill(0, count($sanitizedIds), '?'));
                try {
                    $pdo->prepare("DELETE FROM news_article_likes WHERE article_id IN ($placeholders)")->execute($sanitizedIds);
                    $pdo->prepare("DELETE FROM news_article_comments WHERE article_id IN ($placeholders)")->execute($sanitizedIds);
                    $pdo->prepare("DELETE FROM news_articles WHERE id IN ($placeholders)")->execute($sanitizedIds);
                    setFlash(count($sanitizedIds) . " articles deleted successfully.");
                } catch (Throwable $e) {
                    setFlash("Bulk deletion error: " . $e->getMessage(), 'danger');
                }
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=news");
        exit();
    }

    // D. TOGGLE NEWS STATUS
    if ($action === 'toggle_news_status') {
        $id = intval($_POST['news_id'] ?? 0);
        $new_status = $_POST['status'] === 'published' ? 'draft' : 'published';
        if ($id > 0) {
            $pdo->prepare("UPDATE news_articles SET status = ? WHERE id = ?")->execute([$new_status, $id]);
            setFlash("Article status set to " . ucfirst($new_status) . ".");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=news");
        exit();
    }

    // E. SAVE / EDIT REEL
    if ($action === 'save_reel') {
        $id = intval($_POST['reel_id'] ?? 0);
        $caption = trim($_POST['caption'] ?? '');
        $music_title = trim($_POST['music_title'] ?? 'Original Audio');
        $tags = trim($_POST['tags'] ?? '');
        $creator_name = trim($_POST['creator_name'] ?? 'CropSync Creator');
        $phone_number = trim($_POST['phone_number'] ?? '9182867655');
        $is_active = isset($_POST['is_active']) ? 1 : 0;
        $video_url = trim($_POST['video_url'] ?? '');

        $uploadedVideo = uploadReelVideo('video_file');
        if (!empty($uploadedVideo)) {
            $video_url = $uploadedVideo;
        }

        if (empty($caption) || empty($video_url)) {
            setFlash('Caption and Video URL or upload are required.', 'danger');
        } else {
            try {
                $cStmt = $pdo->prepare("SELECT id FROM creators WHERE phone_number = ? OR display_name = ? LIMIT 1");
                $cStmt->execute([$phone_number, $creator_name]);
                $creator_id = $cStmt->fetchColumn();

                if (!$creator_id) {
                    $uName = strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', str_replace(' ', '_', $creator_name)));
                    if (empty($uName)) $uName = 'creator_' . substr($phone_number, -4);
                    $cIns = $pdo->prepare("INSERT INTO creators (username, display_name, profile_image_url, is_verified, phone_number, bio) VALUES (?, ?, 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80', 1, ?, 'Agricultural Expert & Farmer')");
                    $cIns->execute([$uName, $creator_name, $phone_number]);
                    $creator_id = $pdo->lastInsertId();
                }

                if ($id > 0) {
                    $stmt = $pdo->prepare("UPDATE reels SET caption = ?, video_url = ?, music_title = ?, tags = ?, phone_number = ?, is_active = ?, creator_id = ? WHERE id = ?");
                    $stmt->execute([$caption, $video_url, $music_title, $tags, $phone_number, $is_active, $creator_id, $id]);
                    setFlash("Reel #$id updated successfully.");
                } else {
                    $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, ?, NOW())");
                    $stmt->execute([$creator_id, $video_url, $caption, $music_title, $phone_number, $tags, $is_active]);
                    setFlash("New Agri Reel published.");
                }
            } catch (Throwable $e) {
                setFlash("Database error: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // F. DELETE SINGLE REEL
    if ($action === 'delete_reel') {
        $id = intval($_POST['reel_id'] ?? 0);
        if ($id > 0) {
            try {
                $pdo->prepare("DELETE FROM reel_likes WHERE reel_id = ?")->execute([$id]);
                $pdo->prepare("DELETE FROM reel_comments WHERE reel_id = ?")->execute([$id]);
                $pdo->prepare("DELETE FROM reel_actions WHERE reel_id = ?")->execute([$id]);
                $pdo->prepare("DELETE FROM reel_watch_analytics WHERE reel_id = ?")->execute([$id]);
                $pdo->prepare("DELETE FROM reels WHERE id = ?")->execute([$id]);
                setFlash("Reel #$id deleted successfully.");
            } catch (Throwable $e) {
                setFlash("Error deleting reel: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // G. BULK DELETE REELS
    if ($action === 'bulk_delete_reels') {
        $ids = $_POST['selected_reels'] ?? [];
        if (!empty($ids) && is_array($ids)) {
            $sanitizedIds = array_map('intval', $ids);
            $sanitizedIds = array_filter($sanitizedIds, function($v) { return $v > 0; });
            if (!empty($sanitizedIds)) {
                $placeholders = implode(',', array_fill(0, count($sanitizedIds), '?'));
                try {
                    $pdo->prepare("DELETE FROM reel_likes WHERE reel_id IN ($placeholders)")->execute($sanitizedIds);
                    $pdo->prepare("DELETE FROM reel_comments WHERE reel_id IN ($placeholders)")->execute($sanitizedIds);
                    $pdo->prepare("DELETE FROM reel_actions WHERE reel_id IN ($placeholders)")->execute($sanitizedIds);
                    $pdo->prepare("DELETE FROM reel_watch_analytics WHERE reel_id IN ($placeholders)")->execute($sanitizedIds);
                    $pdo->prepare("DELETE FROM reels WHERE id IN ($placeholders)")->execute($sanitizedIds);
                    setFlash(count($sanitizedIds) . " reels deleted successfully.");
                } catch (Throwable $e) {
                    setFlash("Bulk deletion error: " . $e->getMessage(), 'danger');
                }
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // H. TOGGLE REEL STATUS
    if ($action === 'toggle_reel_status') {
        $id = intval($_POST['reel_id'] ?? 0);
        $new_status = intval($_POST['is_active']) === 1 ? 0 : 1;
        if ($id > 0) {
            if ($new_status === 1) {
                $chk = $pdo->prepare("SELECT status FROM reels WHERE id = ?");
                $chk->execute([$id]);
                $rStatus = $chk->fetchColumn();
                if ($rStatus !== 'approved') {
                    setFlash("Reel cannot be activated until approved by a moderator.", "danger");
                    header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
                    exit();
                }
            }
            $pdo->prepare("UPDATE reels SET is_active = ? WHERE id = ?")->execute([$new_status, $id]);
            setFlash("Reel visibility updated.");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // I. DELETE COMMENT
    if ($action === 'delete_comment') {
        $type = $_POST['comment_type'] ?? '';
        $cid = intval($_POST['comment_id'] ?? 0);
        $parent_id = intval($_POST['parent_id'] ?? 0);

        if ($type === 'news' && $cid > 0) {
            $pdo->prepare("DELETE FROM news_article_comments WHERE id = ?")->execute([$cid]);
            $pdo->prepare("UPDATE news_articles SET comments_count = GREATEST(0, comments_count - 1) WHERE id = ?")->execute([$parent_id]);
            setFlash("Comment deleted.");
            header("Location: " . $_SERVER['PHP_SELF'] . "?tab=comments");
            exit();
        } elseif ($type === 'reel' && $cid > 0) {
            $pdo->prepare("DELETE FROM reel_comments WHERE id = ?")->execute([$cid]);
            $pdo->prepare("UPDATE reels SET comments_count = GREATEST(0, comments_count - 1) WHERE id = ?")->execute([$parent_id]);
            setFlash("Comment deleted.");
            header("Location: " . $_SERVER['PHP_SELF'] . "?tab=comments");
            exit();
        }
    }

    // =========================================================
    // J. AGRI CREATOR PARTNER PROGRAM ACTIONS
    // =========================================================

    // 1. APPROVE / REJECT / SUSPEND CREATOR WITH 25-CAP ENFORCEMENT
    if ($action === 'admin_approve_creator') {
        $creatorId = intval($_POST['creator_id'] ?? 0);
        $approvalAction = trim($_POST['approval_action'] ?? 'approve');
        $tier = trim($_POST['tier'] ?? 'trial');
        $reason = trim($_POST['reason'] ?? '');

        if ($creatorId > 0) {
            try {
                if ($approvalAction === 'approve') {
                    $capStmt = $pdo->query("SELECT COUNT(*) FROM creators WHERE status = 'active'");
                    $activeCount = intval($capStmt->fetchColumn() ?: 0);
                    if ($activeCount >= 25) {
                        setFlash("Cannot approve creator: 25-creator pilot cap reached (Active: $activeCount / 25).", "danger");
                    } else {
                        $pdo->prepare("UPDATE creators SET status = 'active', partnership_tier = ?, is_verified = 1, reviewed_by = 'Admin', reviewed_at = NOW(), approved_at = NOW() WHERE id = ?")
                            ->execute([$tier, $creatorId]);
                        setFlash("Creator #$creatorId approved as $tier partner ($activeCount / 25 active).", "success");
                    }
                } elseif ($approvalAction === 'reject') {
                    $pdo->prepare("UPDATE creators SET status = 'rejected', rejection_reason = ?, reviewed_by = 'Admin', reviewed_at = NOW() WHERE id = ?")
                        ->execute([$reason, $creatorId]);
                    setFlash("Creator #$creatorId application rejected.", "warning");
                } elseif ($approvalAction === 'suspend') {
                    $pdo->prepare("UPDATE creators SET status = 'suspended', rejection_reason = ?, reviewed_by = 'Admin', reviewed_at = NOW() WHERE id = ?")
                        ->execute([$reason, $creatorId]);
                    setFlash("Creator #$creatorId suspended.", "danger");
                }
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=creators");
        exit();
    }

    // 2. MODERATE REEL (APPROVE, REQUEST CHANGES, REJECT)
    if ($action === 'admin_review_reel') {
        $reelId = intval($_POST['reel_id'] ?? 0);
        $decision = trim($_POST['decision'] ?? 'approved');
        $reasonCode = trim($_POST['reason_code'] ?? '');
        $comments = trim($_POST['comments'] ?? '');

        if ($reelId > 0) {
            try {
                $rStmt = $pdo->prepare("SELECT is_duplicate FROM reels WHERE id = ?");
                $rStmt->execute([$reelId]);
                $rRow = $rStmt->fetch(PDO::FETCH_ASSOC);
                $payoutEligible = ($decision === 'approved' && empty($rRow['is_duplicate'])) ? 1 : 0;
                $isActive = ($decision === 'approved') ? 1 : 0;

                $pdo->prepare("
                    UPDATE reels 
                    SET status = ?, rejection_reason_code = ?, reviewer_feedback = ?, reviewed_at = NOW(), reviewed_by = 'Admin', payout_eligible = ?, is_active = ?
                    WHERE id = ?
                ")->execute([$decision, $reasonCode, $comments, $payoutEligible, $isActive, $reelId]);

                $pdo->prepare("INSERT INTO reel_reviews (reel_id, reviewer_id, decision, reason_code, comments, reviewed_at) VALUES (?, 'Admin', ?, ?, ?, NOW())")
                    ->execute([$reelId, $decision, $reasonCode, $comments]);

                setFlash("Reel #$reelId marked as $decision.");
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // 2.1 TRIGGER 10-MINUTE AUTO-APPROVAL SLA SWEEP
    if ($action === 'run_auto_approvals') {
        $count = processReelAutoApprovals($pdo);
        setFlash("Auto-approval sweep completed: $count daytime reel(s) met the 10-min SLA and were approved.", "success");
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // 3. RUN DETERMINISTIC MONTHLY PAYOUT CALCULATION
    if ($action === 'calculate_monthly_payout') {
        $month = trim($_POST['month'] ?? date('Y-m'));
        try {
            calculateMonthlyPayoutEngine($pdo, $month);
            setFlash("Deterministic payout calculation completed for period $month.", "success");
        } catch (Throwable $e) {
            setFlash("Error running payout calculation: " . $e->getMessage(), "danger");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=payouts&payout_month=" . urlencode($month));
        exit();
    }

    // 4. ADD BONUS LINE ITEM
    if ($action === 'add_payout_bonus') {
        $payoutId = intval($_POST['payout_id'] ?? 0);
        $amount = floatval($_POST['amount'] ?? 0.00);
        $explanation = trim($_POST['explanation'] ?? 'Special performance bonus');
        $month = trim($_POST['month'] ?? date('Y-m'));

        if ($payoutId > 0 && $amount > 0) {
            try {
                $pdo->prepare("INSERT INTO payout_line_items (payout_id, type, amount, explanation) VALUES (?, 'bonus', ?, ?)")
                    ->execute([$payoutId, $amount, $explanation]);
                $pdo->prepare("UPDATE monthly_creator_payouts SET bonus_total = bonus_total + ?, gross_payout = base_payout + bonus_total + adjustments WHERE id = ?")
                    ->execute([$amount, $payoutId]);
                setFlash("Bonus ₹$amount added successfully.");
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=payouts&payout_month=" . urlencode($month));
        exit();
    }

    // 5. LOCK BATCH
    if ($action === 'lock_payout_batch') {
        $month = trim($_POST['month'] ?? date('Y-m'));
        try {
            $pdo->prepare("UPDATE monthly_creator_payouts SET status = 'locked' WHERE period_month = ? AND status = 'calculated'")->execute([$month]);
            setFlash("Payout batch for $month locked for finance review.");
        } catch (Throwable $e) {
            setFlash("Error: " . $e->getMessage(), "danger");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=payouts&payout_month=" . urlencode($month));
        exit();
    }

    // 6. APPROVE PAYOUT BATCH
    if ($action === 'approve_payout_batch') {
        $month = trim($_POST['month'] ?? date('Y-m'));
        try {
            $pdo->prepare("UPDATE monthly_creator_payouts SET status = 'approved', approved_by = 'Finance Admin' WHERE period_month = ? AND status IN ('calculated', 'locked')")->execute([$month]);
            setFlash("Payout batch for $month approved by Finance.", "success");
        } catch (Throwable $e) {
            setFlash("Error: " . $e->getMessage(), "danger");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=payouts&payout_month=" . urlencode($month));
        exit();
    }

    // 7. MARK PAYOUT PAID
    if ($action === 'mark_payout_paid') {
        $payoutId = intval($_POST['payout_id'] ?? 0);
        $ref = trim($_POST['payment_reference'] ?? '');
        $month = trim($_POST['month'] ?? date('Y-m'));

        if ($payoutId > 0 && !empty($ref)) {
            try {
                $pdo->prepare("UPDATE monthly_creator_payouts SET status = 'paid', payment_reference = ?, paid_at = NOW() WHERE id = ?")
                    ->execute([$ref, $payoutId]);
                setFlash("Payout marked as paid (UTR: $ref).", "success");
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=payouts&payout_month=" . urlencode($month));
        exit();
    }

    // 8. CREATE CAMPAIGN
    if ($action === 'create_campaign') {
        $name = trim($_POST['name'] ?? '');
        $client = trim($_POST['client_brand'] ?? '');
        $objective = trim($_POST['objective'] ?? '');
        $budget = floatval($_POST['budget'] ?? 0.00);
        $startDate = trim($_POST['start_date'] ?? date('Y-m-d'));
        $endDate = trim($_POST['end_date'] ?? date('Y-m-d', strtotime('+30 days')));

        if (!empty($name) && !empty($client)) {
            try {
                $pdo->prepare("INSERT INTO campaigns (name, client_brand, objective, budget, start_date, end_date, status) VALUES (?, ?, ?, ?, ?, ?, 'active')")
                    ->execute([$name, $client, $objective, $budget, $startDate, $endDate]);
                setFlash("Campaign '$name' created successfully.");
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=campaigns");
        exit();
    }

    // 9. ASSIGN CAMPAIGN CREATOR
    if ($action === 'assign_campaign_creator') {
        $campaignId = intval($_POST['campaign_id'] ?? 0);
        $creatorId = intval($_POST['creator_id'] ?? 0);
        $deliverableType = trim($_POST['deliverable_type'] ?? 'Instagram Reel + CropSync Agri Reel');
        $fee = floatval($_POST['negotiated_fee'] ?? 0.00);
        $dueDate = trim($_POST['due_at'] ?? date('Y-m-d H:i:s', strtotime('+7 days')));

        if ($campaignId > 0 && $creatorId > 0) {
            try {
                $pdo->prepare("INSERT INTO campaign_creator_assignments (campaign_id, creator_id, deliverable_type, negotiated_fee, due_at, status) VALUES (?, ?, ?, ?, ?, 'assigned')")
                    ->execute([$campaignId, $creatorId, $deliverableType, $fee, $dueDate]);
                setFlash("Creator #$creatorId assigned to campaign.");
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=campaigns");
        exit();
    }

    // 10. REVIEW CAMPAIGN DELIVERABLE
    if ($action === 'review_campaign_deliverable') {
        $deliverableId = intval($_POST['deliverable_id'] ?? 0);
        $decision = trim($_POST['decision'] ?? 'approved');

        if ($deliverableId > 0) {
            try {
                $pdo->prepare("UPDATE campaign_deliverables SET approval_status = ?, reviewed_at = NOW() WHERE id = ?")
                    ->execute([$decision, $deliverableId]);
                setFlash("Deliverable #$deliverableId marked as $decision.");
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=campaigns");
        exit();
    }
}

// Handle Payout CSV Export
if (isset($_GET['export_payouts_csv']) && isset($pdo) && $pdo instanceof PDO) {
    $m = trim($_GET['month'] ?? date('Y-m'));
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="creator_payouts_' . $m . '.csv"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['Payout ID', 'Creator ID', 'Username', 'Display Name', 'Phone', 'Billing Month', 'Approved Reels', 'Base Payout (INR)', 'Bonus Total (INR)', 'Gross Payout (INR)', 'Status', 'Payment Ref (UTR)', 'Paid At']);
    $stmt = $pdo->prepare("
        SELECT p.*, c.username, c.display_name, c.phone_number
        FROM monthly_creator_payouts p
        JOIN creators c ON p.creator_id = c.id
        WHERE p.period_month = ?
        ORDER BY p.gross_payout DESC
    ");
    $stmt->execute([$m]);
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        fputcsv($out, [
            $row['id'], $row['creator_id'], $row['username'], $row['display_name'], $row['phone_number'],
            $row['period_month'], $row['eligible_reel_count'], $row['base_payout'], $row['bonus_total'],
            $row['gross_payout'], $row['status'], $row['payment_reference'] ?? '', $row['paid_at'] ?? ''
        ]);
    }
    fclose($out);
    exit();
}

// -------------------------------------------------------------
// 5. Data Fetching
// -------------------------------------------------------------
$activeTab = $_GET['tab'] ?? 'news';
$searchQuery = trim($_GET['q'] ?? '');
$categoryFilter = trim($_GET['category'] ?? 'all');
$moderationFilter = trim($_GET['moderation_status'] ?? $_GET['status'] ?? 'all');
$payoutMonth = trim($_GET['payout_month'] ?? date('Y-m'));
$flash = getFlash();

$totalNews = 0;
$publishedNews = 0;
$totalReels = 0;
$activeReels = 0;
$pendingReelsCount = 0;
$approvedReelsCount = 0;
$changesReqCount = 0;
$rejectedReelsCount = 0;
$activeCreatorsCount = 0;
$pendingCreatorsCount = 0;
$totalCreators = 0;

$articlesList = [];
$reelsList = [];
$commentsList = [];
$creatorsList = [];
$payoutsList = [];
$campaignsList = [];
$auditLogsList = [];

if (isset($pdo) && $pdo instanceof PDO) {
    // 0. Auto-approve daytime reels that met the 10-minute SLA window
    try {
        processReelAutoApprovals($pdo);
    } catch (Throwable $e) {}

    // 1. News stats
    try {
        $hasNewsStatus = false;
        try {
            $chkStatus = $pdo->query("SHOW COLUMNS FROM `news_articles` LIKE 'status'");
            $hasNewsStatus = ($chkStatus && $chkStatus->fetch());
        } catch (Throwable $e) {}

        if ($hasNewsStatus) {
            $nStats = $pdo->query("SELECT COUNT(*) as total, SUM(CASE WHEN status = 'published' THEN 1 ELSE 0 END) as published FROM news_articles")->fetch();
        } else {
            $nStats = $pdo->query("SELECT COUNT(*) as total, COUNT(*) as published FROM news_articles")->fetch();
        }
        if ($nStats) {
            $totalNews = intval($nStats['total']);
            $publishedNews = intval($nStats['published']);
        }
    } catch (Throwable $e) {}

    // 2. Reels stats & Moderation counts
    try {
        $rStats = $pdo->query("SELECT COUNT(*) as total, SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active FROM reels")->fetch();
        if ($rStats) {
            $totalReels = intval($rStats['total']);
            $activeReels = intval($rStats['active']);
        }

        $chkRStatus = $pdo->query("SHOW COLUMNS FROM `reels` LIKE 'status'");
        if ($chkRStatus && $chkRStatus->fetch()) {
            $rmStats = $pdo->query("SELECT 
                SUM(CASE WHEN status IN ('under_review', 'submitted') OR (is_active = 0 AND (status IS NULL OR status = '')) THEN 1 ELSE 0 END) as pending_cnt,
                SUM(CASE WHEN status = 'approved' OR (is_active = 1 AND (status IS NULL OR status = 'approved')) THEN 1 ELSE 0 END) as approved_cnt,
                SUM(CASE WHEN status = 'changes_requested' THEN 1 ELSE 0 END) as changes_cnt,
                SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) as rejected_cnt
            FROM reels")->fetch();
            if ($rmStats) {
                $pendingReelsCount = intval($rmStats['pending_cnt'] ?? 0);
                $approvedReelsCount = intval($rmStats['approved_cnt'] ?? 0);
                $changesReqCount = intval($rmStats['changes_cnt'] ?? 0);
                $rejectedReelsCount = intval($rmStats['rejected_cnt'] ?? 0);
            }
        } else {
            $pendingReelsCount = $totalReels - $activeReels;
            $approvedReelsCount = $activeReels;
        }
    } catch (Throwable $e) {}

    // 3. Creator counts
    try {
        $hasCreatorStatus = false;
        try {
            $chkCStatus = $pdo->query("SHOW COLUMNS FROM `creators` LIKE 'status'");
            $hasCreatorStatus = ($chkCStatus && $chkCStatus->fetch());
        } catch (Throwable $e) {}

        if ($hasCreatorStatus) {
            $cStats = $pdo->query("SELECT COUNT(*) as total, SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active, SUM(CASE WHEN status = 'pending_review' OR status = 'applied' THEN 1 ELSE 0 END) as pending FROM creators")->fetch();
        } else {
            $cStats = $pdo->query("SELECT COUNT(*) as total, COUNT(*) as active, 0 as pending FROM creators")->fetch();
        }
        if ($cStats) {
            $totalCreators = intval($cStats['total']);
            $activeCreatorsCount = intval($cStats['active']);
            $pendingCreatorsCount = intval($cStats['pending']);
        }
    } catch (Throwable $e) {}

    // 4. News fetch
    try {
        $newsSql = "SELECT * FROM news_articles WHERE 1=1";
        $newsParams = [];
        if (!empty($searchQuery) && $activeTab === 'news') {
            $newsSql .= " AND (title LIKE ? OR summary LIKE ? OR author LIKE ?)";
            $newsParams[] = "%$searchQuery%";
            $newsParams[] = "%$searchQuery%";
            $newsParams[] = "%$searchQuery%";
            $newsParams[] = "%$searchQuery%";
        }
        if ($categoryFilter !== 'all' && !empty($categoryFilter)) {
            $newsSql .= " AND category = ?";
            $newsParams[] = $categoryFilter;
        }
        $newsSql .= " ORDER BY id DESC LIMIT 100";
        $nStmt = $pdo->prepare($newsSql);
        $nStmt->execute($newsParams);
        $articlesList = $nStmt->fetchAll();
    } catch (Throwable $e) {}

    // 5. Reels fetch with moderation status filter
    try {
        $hasReelStatus = false;
        try {
            $chkRStatus = $pdo->query("SHOW COLUMNS FROM `reels` LIKE 'status'");
            $hasReelStatus = ($chkRStatus && $chkRStatus->fetch());
        } catch (Throwable $e) {}

        $reelSql = "SELECT r.*, c.display_name AS creator_name, c.username AS creator_username 
                    FROM reels r 
                    LEFT JOIN creators c ON r.creator_id = c.id 
                    WHERE 1=1";
        $reelParams = [];
        if (!empty($searchQuery) && $activeTab === 'reels') {
            $reelSql .= " AND (r.caption LIKE ? OR r.tags LIKE ? OR r.music_title LIKE ? OR c.display_name LIKE ?)";
            $reelParams[] = "%$searchQuery%";
            $reelParams[] = "%$searchQuery%";
            $reelParams[] = "%$searchQuery%";
            $reelParams[] = "%$searchQuery%";
        }
        if ($moderationFilter !== 'all' && !empty($moderationFilter)) {
            if ($hasReelStatus) {
                if ($moderationFilter === 'pending' || $moderationFilter === 'under_review') {
                    $reelSql .= " AND (r.status IN ('under_review', 'submitted') OR (r.is_active = 0 AND (r.status IS NULL OR r.status = '')))";
                } elseif ($moderationFilter === 'approved') {
                    $reelSql .= " AND (r.status = 'approved' OR (r.is_active = 1 AND (r.status IS NULL OR r.status = 'approved')))";
                } else {
                    $reelSql .= " AND r.status = ?";
                    $reelParams[] = $moderationFilter;
                }
            } elseif ($moderationFilter === 'approved') {
                $reelSql .= " AND r.is_active = 1";
            } elseif ($moderationFilter === 'pending' || $moderationFilter === 'under_review') {
                $reelSql .= " AND r.is_active = 0";
            }
        }
        $reelSql .= " ORDER BY r.id DESC LIMIT 100";
        $rStmt = $pdo->prepare($reelSql);
        $rStmt->execute($reelParams);
        $reelsList = $rStmt->fetchAll();
    } catch (Throwable $e) {}

    // 6. Creators fetch
    try {
        $hasReelStatus = false;
        try {
            $chkRStatus = $pdo->query("SHOW COLUMNS FROM `reels` LIKE 'status'");
            $hasReelStatus = ($chkRStatus && $chkRStatus->fetch());
        } catch (Throwable $e) {}

        $approvedExpr = $hasReelStatus 
            ? "SUM(CASE WHEN r.status = 'approved' THEN 1 ELSE 0 END)" 
            : "SUM(CASE WHEN r.is_active = 1 THEN 1 ELSE 0 END)";

        $crStmt = $pdo->query("
            SELECT c.*, 
                   COUNT(r.id) AS total_reels,
                   $approvedExpr AS approved_reels,
                   COALESCE(SUM(r.views_count), 0) AS total_views
            FROM creators c
            LEFT JOIN reels r ON c.id = r.creator_id
            GROUP BY c.id
            ORDER BY c.id DESC
        ");
        $creatorsList = $crStmt ? $crStmt->fetchAll(PDO::FETCH_ASSOC) : [];
    } catch (Throwable $e) {}

    // 7. Payouts fetch for selected month
    try {
        $pStmt = $pdo->prepare("
            SELECT p.*, c.username, c.display_name, c.phone_number, c.partnership_tier, c.upi_id
            FROM monthly_creator_payouts p
            JOIN creators c ON p.creator_id = c.id
            WHERE p.period_month = ?
            ORDER BY p.gross_payout DESC
        ");
        $pStmt->execute([$payoutMonth]);
        $payoutsList = $pStmt->fetchAll(PDO::FETCH_ASSOC);

        // Include line items for each payout
        foreach ($payoutsList as &$po) {
            try {
                $liStmt = $pdo->prepare("SELECT * FROM payout_line_items WHERE payout_id = ? ORDER BY id ASC");
                $liStmt->execute([$po['id']]);
                $po['line_items'] = $liStmt->fetchAll(PDO::FETCH_ASSOC);
            } catch (Throwable $e) {
                $po['line_items'] = [];
            }
        }
    } catch (Throwable $e) {}

    // 8. Campaigns fetch
    try {
        $campsStmt = $pdo->query("
            SELECT c.*, COUNT(a.id) AS total_creators_assigned
            FROM campaigns c
            LEFT JOIN campaign_creator_assignments a ON c.id = a.campaign_id
            GROUP BY c.id
            ORDER BY c.id DESC
        ");
        $campaignsList = $campsStmt ? $campsStmt->fetchAll(PDO::FETCH_ASSOC) : [];

        // Include assignments & deliverables
        foreach ($campaignsList as &$camp) {
            try {
                $asStmt = $pdo->prepare("
                    SELECT a.*, cr.display_name AS creator_name, cr.phone_number
                    FROM campaign_creator_assignments a
                    JOIN creators cr ON a.creator_id = cr.id
                    WHERE a.campaign_id = ?
                ");
                $asStmt->execute([$camp['id']]);
                $camp['assignments'] = $asStmt->fetchAll(PDO::FETCH_ASSOC);
                foreach ($camp['assignments'] as &$asg) {
                    try {
                        $dStmt = $pdo->prepare("SELECT * FROM campaign_deliverables WHERE assignment_id = ? ORDER BY id DESC");
                        $dStmt->execute([$asg['id']]);
                        $asg['deliverables'] = $dStmt->fetchAll(PDO::FETCH_ASSOC);
                    } catch (Throwable $e) {
                        $asg['deliverables'] = [];
                    }
                }
            } catch (Throwable $e) {
                $camp['assignments'] = [];
            }
        }
    } catch (Throwable $e) {}

    // 9. Audit logs fetch
    try {
        $alStmt = $pdo->query("SELECT * FROM audit_logs ORDER BY id DESC LIMIT 50");
        $auditLogsList = $alStmt ? $alStmt->fetchAll(PDO::FETCH_ASSOC) : [];
    } catch (Throwable $e) {}

    // 10. Comments fetch
    try {
        $commSql = "
            (SELECT id, article_id as parent_id, 'news' as type, user_name as author_name, phone_number, comment_text, created_at 
             FROM news_article_comments ORDER BY id DESC LIMIT 25)
            UNION ALL
            (SELECT id, reel_id as parent_id, 'reel' as type, farmer_username as author_name, phone_number, comment_text, created_at 
             FROM reel_comments ORDER BY id DESC LIMIT 25)
            ORDER BY created_at DESC LIMIT 50";
        $cStmt = $pdo->query($commSql);
        $commentsList = $cStmt ? $cStmt->fetchAll() : [];
    } catch (Throwable $e) {}
}

$availableCategories = [
    'Govt Schemes',
    'Farming Tips',
    'Weather & Monsoon',
    'Market & Mandi',
    'Pest & Disease Control',
    'Organic Agriculture',
    'Technology & Drones',
    'Success Stories'
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CropSync Studio | News & Reels Management</title>
    
    <!-- Google Sans & Noto Sans Telugu -->
    <link href="https://fonts.googleapis.com/css2?family=Google+Sans:wght@400;500;700&family=Noto+Sans+Telugu:wght@400;600&display=swap" rel="stylesheet">
    
    <!-- Phosphor Icons -->
    <script src="https://unpkg.com/@phosphor-icons/web@2.1.1"></script>

    <!-- Alpine.js -->
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>

    <style>
        [x-cloak] { display: none !important; }

        :root {
            --font-family: 'Google Sans', 'Noto Sans Telugu', -apple-system, BlinkMacSystemFont, sans-serif;
            --bg: #fafafa;
            --surface: #ffffff;
            --surface-subtle: #f4f4f5;
            --border: #e4e4e7;
            --border-light: #f1f1f4;
            
            --text-primary: #18181b;
            --text-secondary: #52525b;
            --text-muted: #71717a;
            
            --accent: #15803d;
            --accent-hover: #166534;
            --accent-light: #f0fdf4;
            
            --danger: #dc2626;
            --danger-hover: #b91c1c;
            --danger-light: #fef2f2;
            
            --radius: 6px;
            --radius-pill: 9999px;
            --header-height: 56px;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: var(--font-family);
            background: var(--bg);
            color: var(--text-primary);
            line-height: 1.5;
            -webkit-font-smoothing: antialiased;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        /* HEADER */
        header.app-header {
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            height: var(--header-height);
            padding: 0 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 50;
        }

        .header-brand {
            display: flex;
            align-items: center;
            gap: 12px;
            text-decoration: none;
            color: var(--text-primary);
        }

        .brand-badge {
            font-size: 0.72rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            background: var(--surface-subtle);
            color: var(--text-secondary);
            padding: 2px 8px;
            border-radius: var(--radius);
            border: 1px solid var(--border);
        }

        .header-title {
            font-size: 1rem;
            font-weight: 700;
            letter-spacing: -0.01em;
        }

        .header-actions {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        /* NAVIGATION TABS */
        .nav-tabs-bar {
            background: var(--surface);
            border-bottom: 1px solid var(--border);
            padding: 0 24px;
            display: flex;
            gap: 20px;
            overflow-x: auto;
        }

        .tab-link {
            padding: 12px 0;
            font-size: 0.88rem;
            font-weight: 500;
            color: var(--text-secondary);
            text-decoration: none;
            border-bottom: 2px solid transparent;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            white-space: nowrap;
        }

        .tab-link:hover {
            color: var(--text-primary);
        }

        .tab-link.active {
            color: var(--text-primary);
            font-weight: 700;
            border-bottom-color: var(--text-primary);
        }

        .tab-counter {
            font-size: 0.75rem;
            padding: 1px 6px;
            background: var(--surface-subtle);
            border-radius: var(--radius-pill);
            color: var(--text-muted);
        }

        /* CONTAINER */
        .page-container {
            max-width: 1280px;
            width: 100%;
            margin: 0 auto;
            padding: 24px;
            flex-grow: 1;
        }

        /* TOOLBAR */
        .section-toolbar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 14px;
            flex-wrap: wrap;
            margin-bottom: 16px;
        }

        .filter-group {
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }

        .search-input {
            padding: 7px 12px 7px 32px;
            border: 1px solid var(--border);
            border-radius: var(--radius);
            font-family: inherit;
            font-size: 0.84rem;
            background: var(--surface);
            color: var(--text-primary);
            outline: none;
            width: 220px;
        }

        .search-input:focus {
            border-color: var(--text-primary);
        }

        .search-wrapper {
            position: relative;
            display: inline-block;
        }

        .search-wrapper i {
            position: absolute;
            left: 10px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-muted);
            font-size: 14px;
        }

        /* ALPINE CUSTOM DROPDOWN SYSTEM */
        .alpine-dropdown {
            position: relative;
            display: inline-block;
        }

        .dropdown-trigger {
            padding: 7px 12px;
            border: 1px solid var(--border);
            border-radius: var(--radius);
            font-family: inherit;
            font-size: 0.84rem;
            background: var(--surface);
            color: var(--text-primary);
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: space-between;
            gap: 8px;
            min-width: 150px;
            transition: border-color 0.15s ease;
        }

        .dropdown-trigger:hover, .dropdown-trigger:focus {
            border-color: var(--text-primary);
        }

        .dropdown-panel {
            position: absolute;
            top: calc(100% + 4px);
            left: 0;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            box-shadow: 0 4px 14px rgba(0, 0, 0, 0.08);
            z-index: 100;
            min-width: 100%;
            max-height: 240px;
            overflow-y: auto;
            padding: 4px;
        }

        .dropdown-panel.right-align {
            left: auto;
            right: 0;
        }

        .dropdown-option {
            padding: 7px 10px;
            font-size: 0.84rem;
            color: var(--text-secondary);
            border-radius: 4px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: space-between;
            transition: background 0.1s ease;
        }

        .dropdown-option:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
        }

        .dropdown-option.selected {
            background: var(--surface-subtle);
            color: var(--text-primary);
            font-weight: 600;
        }

        /* BUTTONS */
        .btn {
            font-family: inherit;
            font-size: 0.84rem;
            font-weight: 500;
            padding: 7px 14px;
            border-radius: var(--radius);
            border: 1px solid transparent;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            text-decoration: none;
            background: transparent;
            color: var(--text-primary);
            transition: background-color 0.15s ease, border-color 0.15s ease;
        }

        .btn-primary {
            background: var(--text-primary);
            color: #fff;
        }
        .btn-primary:hover {
            background: #27272a;
        }

        .btn-secondary {
            background: var(--surface);
            border-color: var(--border);
            color: var(--text-secondary);
        }
        .btn-secondary:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
        }

        .btn-danger {
            background: var(--danger);
            color: #fff;
        }
        .btn-danger:hover {
            background: var(--danger-hover);
        }

        .btn-danger-outline {
            background: var(--surface);
            border-color: #fca5a5;
            color: var(--danger);
        }
        .btn-danger-outline:hover {
            background: var(--danger-light);
            border-color: var(--danger);
        }

        .btn-sm {
            padding: 4px 8px;
            font-size: 0.78rem;
        }

        /* DATA TABLE */
        .table-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            overflow: hidden;
        }

        .table-responsive {
            width: 100%;
            overflow-x: auto;
        }

        table.data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.84rem;
            text-align: left;
        }

        table.data-table th {
            background: #fafafa;
            padding: 10px 14px;
            color: var(--text-muted);
            font-size: 0.74rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            border-bottom: 1px solid var(--border);
            white-space: nowrap;
        }

        table.data-table td {
            padding: 12px 14px;
            border-bottom: 1px solid var(--border);
            vertical-align: middle;
        }

        table.data-table tr:last-child td {
            border-bottom: none;
        }

        table.data-table tr:hover td {
            background: #fdfdfd;
        }

        .col-checkbox {
            width: 36px;
            text-align: center;
        }

        .status-tag {
            font-size: 0.72rem;
            padding: 2px 7px;
            border-radius: var(--radius-pill);
            font-weight: 600;
            display: inline-block;
            border: 1px solid transparent;
        }
        .status-tag.published, .status-tag.active {
            background: #f0fdf4;
            color: #166534;
            border-color: #bbf7d0;
        }
        .status-tag.draft, .status-tag.hidden {
            background: #fefce8;
            color: #854d0e;
            border-color: #fef08a;
        }

        .media-thumbnail {
            width: 44px;
            height: 44px;
            border-radius: 4px;
            object-fit: cover;
            border: 1px solid var(--border);
            background: var(--surface-subtle);
            display: block;
        }

        .video-box {
            width: 40px;
            height: 54px;
            border-radius: 4px;
            background: #18181b;
            position: relative;
            cursor: pointer;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .video-box video {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        .video-box i {
            position: absolute;
            color: #fff;
            font-size: 14px;
            background: rgba(0,0,0,0.6);
            border-radius: 50%;
            padding: 2px;
        }

        .bulk-bar {
            display: none;
            align-items: center;
            gap: 12px;
            padding: 10px 14px;
            background: var(--text-primary);
            color: #fff;
            border-radius: var(--radius);
            margin-bottom: 12px;
            font-size: 0.84rem;
        }
        .bulk-bar.active {
            display: flex;
        }

        /* CUSTOM FILE UPLOAD WITH PROGRESS INDICATOR */
        .custom-upload-zone {
            border: 1px dashed var(--border);
            border-radius: var(--radius);
            padding: 16px;
            text-align: center;
            background: var(--surface-subtle);
            cursor: pointer;
            position: relative;
            transition: all 0.2s ease;
        }

        .custom-upload-zone:hover, .custom-upload-zone.dragover {
            border-color: var(--text-primary);
            background: #ffffff;
        }

        .upload-icon {
            font-size: 24px;
            color: var(--text-muted);
            margin-bottom: 4px;
        }

        .upload-title {
            font-size: 0.84rem;
            font-weight: 600;
            color: var(--text-primary);
        }

        .upload-subtitle {
            font-size: 0.74rem;
            color: var(--text-muted);
            margin-top: 2px;
        }

        .progress-wrapper {
            margin-top: 10px;
            background: var(--border);
            border-radius: var(--radius-pill);
            height: 6px;
            overflow: hidden;
            position: relative;
            display: none;
        }
        .progress-wrapper.active {
            display: block;
        }

        .progress-bar-fill {
            height: 100%;
            width: 0%;
            background: var(--text-primary);
            transition: width 0.15s ease;
        }

        .upload-status-text {
            font-size: 0.75rem;
            color: var(--text-muted);
            margin-top: 4px;
            display: none;
        }
        .upload-status-text.active {
            display: block;
        }

        /* MODAL & DIALOG SYSTEM */
        .modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.65);
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 1100;
            padding: 20px;
            opacity: 0;
            transition: opacity 0.2s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .modal-overlay.open {
            display: flex;
            opacity: 1;
        }

        .modal-card {
            background: var(--surface);
            border-radius: 16px;
            width: 100%;
            max-width: 620px;
            max-height: 90vh;
            overflow-y: auto;
            border: 1px solid rgba(226, 232, 240, 0.9);
            box-shadow: 0 25px 50px -12px rgba(15, 23, 42, 0.25), 0 0 0 1px rgba(0, 0, 0, 0.04);
            transform: scale(0.96) translateY(8px);
            transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .modal-overlay.open .modal-card {
            transform: scale(1) translateY(0);
        }

        .modal-head {
            padding: 18px 24px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-top-left-radius: 16px;
            border-top-right-radius: 16px;
            background: #ffffff;
        }
        .modal-head h3 {
            font-size: 1.05rem;
            font-weight: 700;
            letter-spacing: -0.01em;
            color: var(--text-primary);
            margin: 0;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .close-btn {
            background: #f1f5f9;
            border: none;
            width: 32px;
            height: 32px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
            cursor: pointer;
            color: var(--text-muted);
            transition: all 0.15s ease;
        }
        .close-btn:hover {
            background: #e2e8f0;
            color: var(--text-primary);
        }

        .modal-body {
            padding: 24px;
            color: var(--text-secondary);
        }

        .modal-foot {
            padding: 16px 24px;
            border-top: 1px solid var(--border);
            display: flex;
            justify-content: flex-end;
            align-items: center;
            gap: 10px;
            background: #f8fafc;
            border-bottom-left-radius: 16px;
            border-bottom-right-radius: 16px;
        }

        /* DIALOG BOX SPECIALIZATIONS */
        .confirm-dialog-card {
            max-width: 480px;
        }
        .confirm-icon-badge {
            width: 44px;
            height: 44px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            flex-shrink: 0;
        }
        .confirm-icon-badge.danger {
            background: #fee2e2;
            color: #dc2626;
        }
        .confirm-icon-badge.success {
            background: #dcfce7;
            color: #16a34a;
        }
        .confirm-icon-badge.warning {
            background: #fef3c7;
            color: #d97706;
        }
        .confirm-icon-badge.primary {
            background: #e0f2fe;
            color: #0284c7;
        }

        .confirm-icon-bubble {
            width: 56px;
            height: 56px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.7rem;
            margin: 0 auto 16px auto;
        }
        .confirm-icon-bubble.confirm-danger, .confirm-icon-bubble.danger {
            background: #fee2e2;
            color: #dc2626;
        }
        .confirm-icon-bubble.confirm-warning, .confirm-icon-bubble.warning {
            background: #fef3c7;
            color: #d97706;
        }
        .confirm-icon-bubble.confirm-primary, .confirm-icon-bubble.confirm-info, .confirm-icon-bubble.primary {
            background: #e0f2fe;
            color: #0284c7;
        }
        .confirm-icon-bubble.confirm-success, .confirm-icon-bubble.success {
            background: #dcfce7;
            color: #16a34a;
        }

        /* FORM CONTROLS */
        .form-row {
            margin-bottom: 14px;
        }
        .form-row label {
            display: block;
            font-size: 0.78rem;
            font-weight: 600;
            margin-bottom: 4px;
            color: var(--text-secondary);
        }
        .form-input {
            width: 100%;
            padding: 8px 10px;
            border: 1px solid var(--border);
            border-radius: var(--radius);
            font-family: inherit;
            font-size: 0.86rem;
            outline: none;
            background: var(--surface);
            color: var(--text-primary);
        }
        .form-input:focus {
            border-color: var(--text-primary);
        }
        textarea.form-input {
            min-height: 80px;
            resize: vertical;
        }

        .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
        }

        .delete-dialog {
            max-width: 400px;
        }

        .alert-banner {
            padding: 10px 14px;
            border-radius: var(--radius);
            font-size: 0.84rem;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .alert-banner.success {
            background: #f0fdf4;
            color: #166534;
            border: 1px solid #bbf7d0;
        }
        .alert-banner.danger {
            background: #fef2f2;
            color: #991b1b;
            border: 1px solid #fecaca;
        }

        .reel-mockup {
            width: 300px;
            height: 520px;
            background: #000;
            border-radius: 12px;
            overflow: hidden;
            margin: 0 auto;
            position: relative;
        }
        .reel-mockup video {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        .reel-info-overlay {
            position: absolute;
            bottom: 12px;
            left: 12px;
            right: 12px;
            color: #fff;
            text-shadow: 0 1px 2px rgba(0,0,0,0.8);
            pointer-events: none;
            font-size: 0.8rem;
        }

        @media (max-width: 768px) {
            header.app-header, .nav-tabs-bar, .page-container {
                padding-left: 16px;
                padding-right: 16px;
            }
            .section-toolbar {
                flex-direction: column;
                align-items: stretch;
            }
            .filter-group {
                width: 100%;
            }
            .search-input {
                width: 100%;
            }
            .grid-2 {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>

    <!-- 1. MINIMAL HEADER -->
    <header class="app-header">
        <a href="?tab=news" class="header-brand">
            <span class="brand-badge">CropSync</span>
            <span class="header-title">News & Reels Studio</span>
        </a>

        <div class="header-actions">
            <?php if ($activeTab === 'news'): ?>
                <button class="btn btn-primary" onclick="openNewsModal()">
                    <i class="ph ph-plus"></i> New Article
                </button>
            <?php elseif ($activeTab === 'reels'): ?>
                <button class="btn btn-primary" onclick="openReelModal()">
                    <i class="ph ph-plus"></i> Upload Reel
                </button>
            <?php endif; ?>

            <!-- Alpine Header Dropdown: Navigation & Quick Jump -->
            <div class="alpine-dropdown" x-data="{ open: false }" @click.outside="open = false">
                <button type="button" class="btn btn-secondary btn-sm" @click="open = !open">
                    <i class="ph ph-dots-three-vertical"></i> Menu
                </button>
                <div class="dropdown-panel right-align" x-show="open" x-cloak x-transition>
                    <a href="user.php" class="dropdown-option" style="text-decoration:none;">
                        <span><i class="ph ph-arrow-left"></i> Kiosk Core Admin</span>
                    </a>
                    <div class="dropdown-option" @click="openNewsModal(); open = false;">
                        <span><i class="ph ph-article"></i> + Draft News</span>
                    </div>
                    <div class="dropdown-option" @click="openReelModal(); open = false;">
                        <span><i class="ph ph-video-camera"></i> + Upload Reel</span>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <!-- 2. NAVIGATION TABS WITH ALPINE.JS VIEW SWITCHING OPTION -->
    <nav class="nav-tabs-bar">
        <a href="?tab=news" class="tab-link <?= $activeTab === 'news' ? 'active' : '' ?>">
            <i class="ph ph-newspaper"></i> Krishi News
            <span class="tab-counter"><?= $totalNews ?></span>
        </a>
        <a href="?tab=reels" class="tab-link <?= $activeTab === 'reels' ? 'active' : '' ?>">
            <i class="ph ph-film-strip"></i> Agri Reels & Moderation
            <span class="tab-counter"><?= $totalReels ?></span>
        </a>
        <a href="?tab=creators" class="tab-link <?= $activeTab === 'creators' ? 'active' : '' ?>">
            <i class="ph ph-users"></i> Creator Applications
            <span class="tab-counter" style="background: <?= $activeCreatorsCount >= 25 ? '#dc2626' : '#15803d' ?>; color: #fff;">
                <?= $activeCreatorsCount ?>/25 Cap
            </span>
        </a>
        <a href="?tab=payouts" class="tab-link <?= $activeTab === 'payouts' ? 'active' : '' ?>">
            <i class="ph ph-currency-inr"></i> Payout Centre
        </a>
        <a href="?tab=campaigns" class="tab-link <?= $activeTab === 'campaigns' ? 'active' : '' ?>">
            <i class="ph ph-megaphone"></i> Campaign Hub
        </a>
        <a href="?tab=analytics" class="tab-link <?= $activeTab === 'analytics' ? 'active' : '' ?>">
            <i class="ph ph-chart-line-up"></i> Partner Analytics & Audit
        </a>
        <a href="?tab=comments" class="tab-link <?= $activeTab === 'comments' ? 'active' : '' ?>">
            <i class="ph ph-chat-centered-text"></i> Comments & Feedback
        </a>
    </nav>

    <!-- 3. MAIN PAGE CONTAINER -->
    <main class="page-container">

        <?php if ($flash): ?>
            <div class="alert-banner <?= htmlspecialchars($flash['type']) ?>">
                <span><?= htmlspecialchars($flash['text']) ?></span>
                <i class="ph ph-x" style="cursor:pointer;" onclick="this.parentElement.remove()"></i>
            </div>
        <?php endif; ?>

        <?php if (isset($dbError)): ?>
            <div class="alert-banner danger">
                <span>Database Warning: <?= htmlspecialchars($dbError) ?></span>
            </div>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 1: NEWS ARTICLES -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'news'): ?>
            
            <form id="bulkNewsForm" method="POST">
                <input type="hidden" name="action" value="bulk_delete_news">

                <div class="bulk-bar" id="newsBulkBar">
                    <span id="newsSelectedCount">0 items selected</span>
                    <button type="button" class="btn btn-danger btn-sm" onclick="confirmBulkDelete('bulkNewsForm', 'selected articles')">
                        <i class="ph ph-trash"></i> Delete Selected
                    </button>
                    <button type="button" class="btn btn-secondary btn-sm" style="color:#fff; border-color:#52525b;" onclick="clearSelection('newsCheck', 'newsBulkBar', 'newsSelectAll')">
                        Cancel
                    </button>
                </div>

                <div class="section-toolbar">
                    <div class="filter-group">
                        <div class="search-wrapper">
                            <i class="ph ph-magnifying-glass"></i>
                            <input type="text" class="search-input" id="newsSearch" placeholder="Search news..." value="<?= htmlspecialchars($searchQuery) ?>" onkeydown="if(event.key==='Enter'){ applySearch('news', this.value); }">
                        </div>

                        <!-- Alpine.js Filter Dropdown for Categories -->
                        <div class="alpine-dropdown" x-data="{ 
                            open: false, 
                            selected: '<?= htmlspecialchars($categoryFilter) ?>',
                            selectCat(val) {
                                this.selected = val;
                                this.open = false;
                                location.href = '?tab=news&category=' + encodeURIComponent(val);
                            }
                        }" @click.outside="open = false">
                            <button type="button" class="dropdown-trigger" @click="open = !open">
                                <span x-text="selected === 'all' ? 'All Categories' : selected"></span>
                                <i class="ph ph-caret-down" style="font-size:12px;"></i>
                            </button>
                            <div class="dropdown-panel" x-show="open" x-cloak x-transition>
                                <div class="dropdown-option" :class="{ 'selected': selected === 'all' }" @click="selectCat('all')">All Categories</div>
                                <?php foreach ($availableCategories as $cat): ?>
                                    <div class="dropdown-option" :class="{ 'selected': selected === '<?= htmlspecialchars($cat) ?>' }" @click="selectCat('<?= htmlspecialchars($cat) ?>')">
                                        <?= htmlspecialchars($cat) ?>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        </div>
                    </div>

                    <div style="font-size: 0.82rem; color: var(--text-muted);">
                        Showing <?= count($articlesList) ?> of <?= $totalNews ?> articles (<?= $publishedNews ?> published)
                    </div>
                </div>

                <div class="table-card">
                    <div class="table-responsive">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th class="col-checkbox">
                                        <input type="checkbox" id="newsSelectAll" onchange="toggleSelectAll(this, 'newsCheck', 'newsBulkBar', 'newsSelectedCount')">
                                    </th>
                                    <th>ID</th>
                                    <th>Image</th>
                                    <th>Article Details</th>
                                    <th>Category</th>
                                    <th>Author</th>
                                    <th>Status</th>
                                    <th>Engagement</th>
                                    <th>Date</th>
                                    <th style="text-align: right;">Delete / Edit</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($articlesList)): ?>
                                    <tr>
                                        <td colspan="10" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                            No news articles found. Click "+ New Article" to create one.
                                        </td>
                                    </tr>
                                <?php else: foreach ($articlesList as $art): ?>
                                    <tr>
                                        <td class="col-checkbox">
                                            <input type="checkbox" name="selected_news[]" value="<?= $art['id'] ?>" class="newsCheck" onchange="updateBulkBar('newsCheck', 'newsBulkBar', 'newsSelectedCount')">
                                        </td>
                                        <td style="font-weight: 700; color: var(--text-muted); font-size: 0.8rem;">#<?= $art['id'] ?></td>
                                        <td style="width: 50px;">
                                            <img src="<?= htmlspecialchars($art['image_url'] ?: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=120&q=80') ?>" class="media-thumbnail" alt="Thumb">
                                        </td>
                                        <td style="max-width: 320px;">
                                            <div style="font-weight: 600; color: var(--text-primary);">
                                                <?php if (!empty($art['is_featured'])): ?>
                                                    <span style="font-size: 0.68rem; font-weight: 700; background: #ede9fe; color: #6d28d9; padding: 1px 5px; border-radius: 3px; margin-right: 4px;">FEATURED</span>
                                                <?php endif; ?>
                                                <?= htmlspecialchars($art['title']) ?>
                                            </div>
                                            <div style="font-size: 0.76rem; color: var(--text-muted); line-height: 1.3; margin-top: 2px;">
                                                <?= htmlspecialchars(mb_strimwidth($art['summary'], 0, 95, '...')) ?>
                                            </div>
                                        </td>
                                        <td>
                                            <span style="font-size: 0.75rem; background: var(--surface-subtle); padding: 2px 6px; border-radius: 4px; border: 1px solid var(--border);">
                                                <?= htmlspecialchars($art['category']) ?>
                                            </span>
                                        </td>
                                        <td style="font-size: 0.8rem;"><?= htmlspecialchars($art['author'] ?: 'CropSync') ?></td>
                                        <td>
                                            <span class="status-tag <?= $art['status'] === 'published' ? 'published' : 'draft' ?>">
                                                <?= htmlspecialchars($art['status']) ?>
                                            </span>
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-secondary); white-space: nowrap;">
                                            <?= number_format($art['views_count']) ?> views &bull; <?= number_format($art['likes_count']) ?> likes
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                            <?= date('M d, Y', strtotime($art['published_at'])) ?>
                                        </td>
                                        <td style="text-align: right; white-space: nowrap;">
                                            <button type="button" class="btn btn-secondary btn-sm" onclick='editNews(<?= json_encode($art) ?>)' title="Edit">
                                                <i class="ph ph-pencil"></i>
                                            </button>
                                            <button type="button" class="btn btn-secondary btn-sm" onclick='previewArticle(<?= json_encode($art) ?>)' title="Preview">
                                                <i class="ph ph-eye"></i>
                                            </button>
                                            <button type="button" class="btn btn-danger-outline btn-sm" onclick="promptDelete('news', <?= $art['id'] ?>, '<?= htmlspecialchars(addslashes($art['title'])) ?>')" title="Delete Article">
                                                <i class="ph ph-trash"></i> Delete
                                            </button>
                                        </td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </form>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 2: AGRI REELS -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'reels'): ?>
            
            <!-- SLA Inspection Policy Banner -->
            <div style="background: #f8fafc; border: 1px solid var(--border); border-radius: 8px; padding: 14px 18px; margin-bottom: 16px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div style="width: 36px; height: 36px; border-radius: 8px; background: #e0f2fe; color: #0284c7; display: flex; align-items: center; justify-content: center; font-size: 20px;">
                        <i class="ph ph-shield-check"></i>
                    </div>
                    <div>
                        <div style="font-weight: 700; font-size: 0.88rem; color: var(--text-primary);">
                            Agri Reel Inspection & 10-Minute SLA Policy
                        </div>
                        <div style="font-size: 0.76rem; color: var(--text-muted); margin-top: 2px; line-height: 1.4;">
                            <strong>Daytime (6:00 AM – 9:00 PM IST):</strong> Uploaded reels enter <em>Under Review</em> for a 10-min inspection window before auto-approving. <br>
                            <strong>Night Window (After 9:00 PM IST to 6:00 AM IST):</strong> Auto-approval is <u>disabled</u>. Night submissions remain hidden until manual verification.
                        </div>
                    </div>
                </div>
                <form method="POST" style="margin: 0;">
                    <input type="hidden" name="action" value="run_auto_approvals">
                    <button type="submit" class="btn btn-secondary btn-sm" style="display: inline-flex; align-items: center; gap: 6px; font-weight: 600;">
                        <i class="ph ph-arrows-clockwise"></i> Run SLA Auto-Approve Sweep
                    </button>
                </form>
            </div>

            <!-- Moderation Filter Tabs -->
            <div style="display: flex; gap: 8px; margin-bottom: 16px; overflow-x: auto; padding-bottom: 4px;">
                <a href="?tab=reels&moderation_status=all<?= !empty($searchQuery) ? '&q='.urlencode($searchQuery) : '' ?>" 
                   class="btn btn-sm <?= $moderationFilter === 'all' ? 'btn-primary' : 'btn-secondary' ?>" style="text-decoration: none; border-radius: 20px; font-size: 0.78rem;">
                   All Reels (<?= $totalReels ?>)
                </a>
                <a href="?tab=reels&moderation_status=pending<?= !empty($searchQuery) ? '&q='.urlencode($searchQuery) : '' ?>" 
                   class="btn btn-sm <?= ($moderationFilter === 'pending' || $moderationFilter === 'under_review') ? 'btn-primary' : 'btn-secondary' ?>" style="text-decoration: none; border-radius: 20px; font-size: 0.78rem; <?= $pendingReelsCount > 0 ? 'border-color: #f59e0b; color: #b45309; background: #fffbeb;' : '' ?>">
                   ⏳ Pending Inspection (<?= $pendingReelsCount ?>)
                </a>
                <a href="?tab=reels&moderation_status=approved<?= !empty($searchQuery) ? '&q='.urlencode($searchQuery) : '' ?>" 
                   class="btn btn-sm <?= $moderationFilter === 'approved' ? 'btn-primary' : 'btn-secondary' ?>" style="text-decoration: none; border-radius: 20px; font-size: 0.78rem;">
                   ✓ Live & Approved (<?= $approvedReelsCount ?>)
                </a>
                <a href="?tab=reels&moderation_status=changes_requested<?= !empty($searchQuery) ? '&q='.urlencode($searchQuery) : '' ?>" 
                   class="btn btn-sm <?= $moderationFilter === 'changes_requested' ? 'btn-primary' : 'btn-secondary' ?>" style="text-decoration: none; border-radius: 20px; font-size: 0.78rem;">
                   ⚠ Changes Requested (<?= $changesReqCount ?>)
                </a>
                <a href="?tab=reels&moderation_status=rejected<?= !empty($searchQuery) ? '&q='.urlencode($searchQuery) : '' ?>" 
                   class="btn btn-sm <?= $moderationFilter === 'rejected' ? 'btn-primary' : 'btn-secondary' ?>" style="text-decoration: none; border-radius: 20px; font-size: 0.78rem;">
                   ✕ Rejected (<?= $rejectedReelsCount ?>)
                </a>
            </div>

            <form id="bulkReelsForm" method="POST">
                <input type="hidden" name="action" value="bulk_delete_reels">

                <div class="bulk-bar" id="reelsBulkBar">
                    <span id="reelsSelectedCount">0 reels selected</span>
                    <button type="button" class="btn btn-danger btn-sm" onclick="confirmBulkDelete('bulkReelsForm', 'selected reels')">
                        <i class="ph ph-trash"></i> Delete Selected
                    </button>
                    <button type="button" class="btn btn-secondary btn-sm" style="color:#fff; border-color:#52525b;" onclick="clearSelection('reelsCheck', 'reelsBulkBar', 'reelsSelectAll')">
                        Cancel
                    </button>
                </div>

                <div class="section-toolbar">
                    <div class="filter-group">
                        <div class="search-wrapper">
                            <i class="ph ph-magnifying-glass"></i>
                            <input type="text" class="search-input" id="reelSearch" placeholder="Search caption, creator..." value="<?= htmlspecialchars($searchQuery) ?>" onkeydown="if(event.key==='Enter'){ applySearch('reels', this.value); }">
                        </div>
                    </div>

                    <div style="font-size: 0.82rem; color: var(--text-muted);">
                        Showing <?= count($reelsList) ?> of <?= $totalReels ?> reels (<?= $activeReels ?> active)
                    </div>
                </div>

                <div class="table-card">
                    <div class="table-responsive">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th class="col-checkbox">
                                        <input type="checkbox" id="reelsSelectAll" onchange="toggleSelectAll(this, 'reelsCheck', 'reelsBulkBar', 'reelsSelectedCount')">
                                    </th>
                                    <th>ID</th>
                                    <th>Video</th>
                                    <th>Caption & Tags</th>
                                    <th>Creator</th>
                                    <th>Audio</th>
                                    <th>Moderation & SLA Status</th>
                                    <th>Engagement</th>
                                    <th>Date</th>
                                    <th style="text-align: right;">Review & Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($reelsList)): ?>
                                    <tr>
                                        <td colspan="10" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                            No reels found matching current filter. Click "+ Upload Reel" to upload a short video.
                                        </td>
                                    </tr>
                                <?php else: 
                                    $tzKolkata = new DateTimeZone('Asia/Kolkata');
                                    $nowKolkata = new DateTime('now', $tzKolkata);
                                    $curHour = intval($nowKolkata->format('G'));
                                    $isCurNight = ($curHour >= 21 || $curHour < 6);

                                    foreach ($reelsList as $rel): 
                                        $reelCreated = new DateTime($rel['created_at'], $tzKolkata);
                                        $createdHour = intval($reelCreated->format('G'));
                                        $createdMin = intval($reelCreated->format('i'));
                                        $isNightUpload = ($createdHour >= 21 || $createdHour < 6 || ($createdHour === 20 && $createdMin >= 51));
                                        
                                        $diffSec = $nowKolkata->getTimestamp() - $reelCreated->getTimestamp();
                                        $minsPassed = floor($diffSec / 60);
                                        $minsRemaining = max(0, 10 - $minsPassed);
                                        
                                        $rStatus = $rel['status'] ?? (intval($rel['is_active']) === 1 ? 'approved' : 'under_review');
                                ?>
                                    <tr>
                                        <td class="col-checkbox">
                                            <input type="checkbox" name="selected_reels[]" value="<?= $rel['id'] ?>" class="reelsCheck" onchange="updateBulkBar('reelsCheck', 'reelsBulkBar', 'reelsSelectedCount')">
                                        </td>
                                        <td style="font-weight: 700; color: var(--text-muted); font-size: 0.8rem;">#<?= $rel['id'] ?></td>
                                        <td style="width: 50px;">
                                            <div class="video-box" onclick="previewReelVideo('<?= htmlspecialchars($rel['video_url']) ?>', '<?= htmlspecialchars(addslashes($rel['caption'])) ?>', '<?= htmlspecialchars(addslashes($rel['creator_name'] ?? 'Creator')) ?>')">
                                                <video src="<?= htmlspecialchars($rel['video_url']) ?>" preload="metadata"></video>
                                                <i class="ph-fill ph-play"></i>
                                            </div>
                                        </td>
                                        <td style="max-width: 300px;">
                                            <div style="font-weight: 600; color: var(--text-primary); line-height: 1.3;">
                                                <?= htmlspecialchars($rel['caption']) ?>
                                            </div>
                                            <?php if (!empty($rel['tags'])): ?>
                                                <div style="font-size: 0.72rem; color: var(--text-muted); margin-top: 2px;">
                                                    <?= htmlspecialchars($rel['tags']) ?>
                                                </div>
                                            <?php endif; ?>
                                        </td>
                                        <td>
                                            <div style="font-size: 0.82rem; font-weight: 600;"><?= htmlspecialchars($rel['creator_name'] ?: 'CropSync Creator') ?></div>
                                            <div style="font-size: 0.72rem; color: var(--text-muted);"><?= htmlspecialchars($rel['phone_number'] ?: '') ?></div>
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                            <i class="ph ph-music-note"></i> <?= htmlspecialchars($rel['music_title'] ?: 'Original Audio') ?>
                                        </td>
                                        <td>
                                            <?php if ($rStatus === 'approved'): ?>
                                                <span class="status-tag active" style="background:#dcfce7; color:#15803d; font-weight:600; display:inline-flex; align-items:center; gap:4px;">
                                                    <i class="ph ph-check-circle"></i> Live & Approved
                                                </span>
                                                <?php if (!empty($rel['payout_eligible'])): ?>
                                                    <div style="font-size:0.7rem; color:#15803d; margin-top:2px;">💰 Payout Eligible</div>
                                                <?php endif; ?>
                                            <?php elseif ($rStatus === 'changes_requested'): ?>
                                                <span class="status-tag" style="background:#fef3c7; color:#b45309; font-weight:600; display:inline-flex; align-items:center; gap:4px;">
                                                    <i class="ph ph-warning"></i> Changes Req.
                                                </span>
                                                <?php if (!empty($rel['reviewer_feedback'])): ?>
                                                    <div style="font-size:0.7rem; color:#b45309; margin-top:2px; max-width:180px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;" title="<?= htmlspecialchars($rel['reviewer_feedback']) ?>">
                                                        <?= htmlspecialchars($rel['reviewer_feedback']) ?>
                                                    </div>
                                                <?php endif; ?>
                                            <?php elseif ($rStatus === 'rejected'): ?>
                                                <span class="status-tag hidden" style="background:#fee2e2; color:#b91c1c; font-weight:600; display:inline-flex; align-items:center; gap:4px;">
                                                    <i class="ph ph-x-circle"></i> Rejected
                                                </span>
                                                <?php if (!empty($rel['rejection_reason_code'])): ?>
                                                    <div style="font-size:0.7rem; color:#b91c1c; margin-top:2px;">
                                                        <?= htmlspecialchars(ucwords(str_replace('_', ' ', $rel['rejection_reason_code']))) ?>
                                                    </div>
                                                <?php endif; ?>
                                            <?php else: /* under_review or submitted */ ?>
                                                <?php if ($isNightUpload): ?>
                                                    <span class="status-tag" style="background:#ede9fe; color:#6d28d9; font-weight:600; display:inline-flex; align-items:center; gap:4px;" title="Uploaded after 9:00 PM IST. Auto-approval is disabled; requires manual moderator review.">
                                                        <i class="ph ph-moon"></i> 🌙 Night Upload
                                                    </span>
                                                    <div style="font-size:0.7rem; color:#6d28d9; margin-top:2px; font-weight:500;">Manual Verification Req.</div>
                                                <?php elseif ($isCurNight): ?>
                                                    <span class="status-tag" style="background:#ede9fe; color:#6d28d9; font-weight:600; display:inline-flex; align-items:center; gap:4px;" title="Current time is after 9:00 PM IST. Auto-approval paused until morning.">
                                                        <i class="ph ph-moon"></i> Night Hold
                                                    </span>
                                                    <div style="font-size:0.7rem; color:#6d28d9; margin-top:2px;">Auto-Approval Paused</div>
                                                <?php elseif ($minsRemaining > 0): ?>
                                                    <span class="status-tag" style="background:#fef3c7; color:#b45309; font-weight:600; display:inline-flex; align-items:center; gap:4px;" title="Under 10-minute inspection SLA window. Auto-approves when timer expires.">
                                                        <i class="ph ph-hourglass-medium"></i> ⏳ In Review (<?= $minsRemaining ?>m left)
                                                    </span>
                                                    <div style="font-size:0.7rem; color:#b45309; margin-top:2px;">Auto-approves in <?= $minsRemaining ?>m</div>
                                                <?php else: ?>
                                                    <span class="status-tag" style="background:#dbeafe; color:#1d4ed8; font-weight:600; display:inline-flex; align-items:center; gap:4px;" title="10-minute inspection SLA elapsed. Ready for auto-approval sweep.">
                                                        <i class="ph ph-lightning"></i> ⚡ SLA Met
                                                    </span>
                                                    <div style="font-size:0.7rem; color:#1d4ed8; margin-top:2px;">Ready for Auto-Approve</div>
                                                <?php endif; ?>
                                            <?php endif; ?>
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-secondary); white-space: nowrap;">
                                            <?= number_format($rel['views_count']) ?> views &bull; <?= number_format($rel['likes_count']) ?> likes
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                            <?= date('M d, Y', strtotime($rel['created_at'])) ?>
                                        </td>
                                        <td style="text-align: right; white-space: nowrap;">
                                            <?php if ($rStatus !== 'approved'): ?>
                                                <button type="button" class="btn btn-sm" style="background:#15803d; color:white; border-color:#15803d; padding:4px 9px; font-size:0.75rem;" onclick="quickApproveReel(<?= $rel['id'] ?>, '<?= htmlspecialchars(addslashes(mb_strimwidth($rel['caption'], 0, 30, '...'))) ?>')" title="Quick Approve & Make Live">
                                                    <i class="ph ph-check"></i> Approve
                                                </button>
                                            <?php endif; ?>
                                            <button type="button" class="btn btn-secondary btn-sm" style="padding:4px 9px; font-size:0.75rem;" onclick='openReelModerationModal(<?= json_encode([
                                                'id' => intval($rel['id']),
                                                'caption' => $rel['caption'],
                                                'creator' => $rel['creator_name'] ?: 'CropSync Creator',
                                                'video_url' => $rel['video_url'],
                                                'status' => $rStatus,
                                                'is_night' => $isNightUpload,
                                                'reason_code' => $rel['rejection_reason_code'] ?? '',
                                                'feedback' => $rel['reviewer_feedback'] ?? ''
                                            ]) ?>)' title="Moderate / Review / Feedback">
                                                <i class="ph ph-shield-check"></i> Review
                                            </button>
                                            <button type="button" class="btn btn-secondary btn-sm" onclick="previewReelVideo('<?= htmlspecialchars($rel['video_url']) ?>', '<?= htmlspecialchars(addslashes($rel['caption'])) ?>', '<?= htmlspecialchars(addslashes($rel['creator_name'] ?? 'Creator')) ?>')" title="Play Reel">
                                                <i class="ph ph-play"></i>
                                            </button>
                                            <button type="button" class="btn btn-secondary btn-sm" onclick='editReel(<?= json_encode($rel) ?>)' title="Edit">
                                                <i class="ph ph-pencil"></i>
                                            </button>
                                            <button type="button" class="btn btn-danger-outline btn-sm" onclick="promptDelete('reel', <?= $rel['id'] ?>, '<?= htmlspecialchars(addslashes(mb_strimwidth($rel['caption'], 0, 40, '...'))) ?>')" title="Delete Reel">
                                                <i class="ph ph-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </form>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB 3: COMMENTS MODERATION -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'comments'): ?>
            <div class="table-card">
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Source</th>
                                <th>Author / Phone</th>
                                <th>Comment Content</th>
                                <th>Posted At</th>
                                <th style="text-align: right;">Delete Option</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($commentsList)): ?>
                                <tr>
                                    <td colspan="5" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                        No comments found.
                                    </td>
                                </tr>
                            <?php else: foreach ($commentsList as $comm): ?>
                                <tr>
                                    <td>
                                        <span class="status-tag" style="background:var(--surface-subtle); color:var(--text-secondary); border-color:var(--border);">
                                            <?= strtoupper($comm['type']) ?> #<?= $comm['parent_id'] ?>
                                        </span>
                                    </td>
                                    <td>
                                        <div style="font-weight: 600; font-size: 0.82rem;"><?= htmlspecialchars($comm['author_name'] ?: 'Farmer') ?></div>
                                        <div style="font-size: 0.72rem; color: var(--text-muted);"><?= htmlspecialchars($comm['phone_number'] ?: '-') ?></div>
                                    </td>
                                    <td style="max-width: 480px; font-size: 0.84rem; line-height: 1.4;">
                                        <?= htmlspecialchars($comm['comment_text']) ?>
                                    </td>
                                    <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                        <?= date('M d, Y H:i', strtotime($comm['created_at'])) ?>
                                    </td>
                                    <td style="text-align: right;">
                                        <button type="button" class="btn btn-danger-outline btn-sm" onclick="promptCommentDelete('<?= htmlspecialchars($comm['type']) ?>', <?= $comm['id'] ?>, <?= $comm['parent_id'] ?>)">
                                            <i class="ph ph-trash"></i> Delete
                                        </button>
                                    </td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB: CREATOR APPLICATIONS & 25-CAP ONBOARDING QUEUE -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'creators'): ?>
            <div class="filter-header-bar" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <div>
                    <h2 style="font-size: 1.25rem; font-weight: 700; color: var(--text-primary); margin-bottom: 4px;">
                        Agri Creator Partner Program &bull; Onboarding Queue
                    </h2>
                    <p style="font-size: 0.85rem; color: var(--text-muted); margin: 0;">
                        Pilot Scope: Maximum 25 approved creator partners. Enforced strictly at approval time.
                    </p>
                </div>
                <div style="display: flex; gap: 12px; align-items: center;">
                    <div style="background: <?= $activeCreatorsCount >= 25 ? '#fee2e2' : '#dcfce7' ?>; border: 1px solid <?= $activeCreatorsCount >= 25 ? '#ef4444' : '#22c55e' ?>; border-radius: 8px; padding: 8px 16px; text-align: center;">
                        <span style="font-size: 0.72rem; text-transform: uppercase; font-weight: 700; color: <?= $activeCreatorsCount >= 25 ? '#991b1b' : '#166534' ?>;">Pilot Capacity</span>
                        <div style="font-size: 1.15rem; font-weight: 800; color: <?= $activeCreatorsCount >= 25 ? '#b91c1c' : '#15803d' ?>;">
                            <?= $activeCreatorsCount ?> / 25 Active
                        </div>
                    </div>
                </div>
            </div>

            <?php if ($activeCreatorsCount >= 25): ?>
                <div class="alert-banner warning" style="margin-bottom: 20px;">
                    <i class="ph ph-warning-circle" style="font-size: 1.2rem;"></i>
                    <span><strong>Pilot Capacity Reached:</strong> 25 active creators are already enrolled. New approvals will be blocked until active slots open up or pilot capacity is increased.</span>
                </div>
            <?php endif; ?>

            <div class="table-card">
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Creator</th>
                                <th>Contact & UPI</th>
                                <th>Niches & Languages</th>
                                <th>Terms Accepted</th>
                                <th>Status</th>
                                <th>Tier</th>
                                <th>Activity</th>
                                <th style="text-align: right;">Review & Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($creatorsList)): ?>
                                <tr>
                                    <td colspan="8" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                        No creator applications or partners found.
                                    </td>
                                </tr>
                            <?php else: foreach ($creatorsList as $cr): ?>
                                <tr>
                                    <td>
                                        <div style="display: flex; align-items: center; gap: 10px;">
                                            <div style="width: 36px; height: 36px; border-radius: 50%; background: #e2e8f0; display: flex; align-items: center; justify-content: center; font-weight: 700; color: #475569;">
                                                <?= strtoupper(substr($cr['display_name'] ?: 'C', 0, 1)) ?>
                                            </div>
                                            <div>
                                                <div style="font-weight: 600; font-size: 0.85rem; color: var(--text-primary);">
                                                    <?= htmlspecialchars($cr['display_name']) ?>
                                                    <?php if (!empty($cr['is_verified'])): ?>
                                                        <i class="ph-fill ph-check-circle" style="color: #0284c7;" title="Verified Creator"></i>
                                                    <?php endif; ?>
                                                </div>
                                                <div style="font-size: 0.72rem; color: var(--text-muted);">
                                                    @<?= htmlspecialchars($cr['username']) ?> &bull; ID #<?= $cr['id'] ?>
                                                </div>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <div style="font-size: 0.82rem; font-weight: 500;"><?= htmlspecialchars($cr['phone_number'] ?: '-') ?></div>
                                        <div style="font-size: 0.72rem; color: var(--text-muted);"><?= htmlspecialchars($cr['upi_id'] ? 'UPI: ' . $cr['upi_id'] : ($cr['email'] ?: 'No payment info')) ?></div>
                                    </td>
                                    <td>
                                        <div style="font-size: 0.78rem; color: var(--text-secondary);">
                                            <?= htmlspecialchars($cr['agriculture_niches'] ?: 'General Agriculture') ?>
                                        </div>
                                        <div style="font-size: 0.72rem; color: var(--text-muted);">
                                            Lang: <?= htmlspecialchars($cr['languages'] ?: 'te') ?>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="status-tag" style="background: <?= !empty($cr['terms_accepted']) ? '#dcfce7' : '#fee2e2' ?>; color: <?= !empty($cr['terms_accepted']) ? '#166534' : '#991b1b' ?>;">
                                            <?= !empty($cr['terms_accepted']) ? 'Accepted v1.0' : 'Pending' ?>
                                        </span>
                                    </td>
                                    <td>
                                        <?php 
                                            $st = $cr['status'] ?? 'active';
                                            $badgeColor = '#dcfce7'; $textColor = '#166534';
                                            if ($st === 'pending_review' || $st === 'applied') { $badgeColor = '#fef3c7'; $textColor = '#92400e'; }
                                            elseif ($st === 'rejected' || $st === 'suspended') { $badgeColor = '#fee2e2'; $textColor = '#991b1b'; }
                                        ?>
                                        <span class="status-tag" style="background: <?= $badgeColor ?>; color: <?= $textColor ?>; text-transform: capitalize;">
                                            <?= str_replace('_', ' ', $st) ?>
                                        </span>
                                    </td>
                                    <td>
                                        <span class="status-tag" style="background: #f1f5f9; color: #334155; font-weight: 600; text-transform: uppercase; font-size: 0.68rem;">
                                            <?= htmlspecialchars($cr['partnership_tier'] ?? 'trial') ?>
                                        </span>
                                    </td>
                                    <td style="font-size: 0.78rem; color: var(--text-secondary); white-space: nowrap;">
                                        <strong><?= intval($cr['approved_reels']) ?></strong> approved reels<br>
                                        <span style="color: var(--text-muted); font-size: 0.72rem;"><?= number_format(intval($cr['total_views'])) ?> views</span>
                                    </td>
                                    <td style="text-align: right; white-space: nowrap;">
                                        <!-- Approve Form -->
                                        <form method="POST" style="display: inline-block;">
                                            <input type="hidden" name="action" value="admin_approve_creator">
                                            <input type="hidden" name="creator_id" value="<?= $cr['id'] ?>">
                                            <input type="hidden" name="approval_action" value="approve">
                                            <select name="tier" style="font-size: 0.75rem; padding: 4px 6px; border-radius: 4px; border: 1px solid var(--border); margin-right: 4px;">
                                                <option value="trial" <?= ($cr['partnership_tier'] ?? '') === 'trial' ? 'selected' : '' ?>>Trial (M1)</option>
                                                <option value="active_partner" <?= ($cr['partnership_tier'] ?? '') === 'active_partner' ? 'selected' : '' ?>>Active (M2-3)</option>
                                                <option value="verified" <?= ($cr['partnership_tier'] ?? '') === 'verified' ? 'selected' : '' ?>>Verified</option>
                                                <option value="strategic" <?= ($cr['partnership_tier'] ?? '') === 'strategic' ? 'selected' : '' ?>>Strategic</option>
                                            </select>
                                            <button type="submit" class="btn btn-primary btn-sm" <?= ($cr['status'] === 'active' || $activeCreatorsCount >= 25) ? '' : '' ?>>
                                                <i class="ph ph-check"></i> Approve
                                            </button>
                                        </form>

                                        <!-- Reject / Suspend Button -->
                                        <button type="button" class="btn btn-danger-outline btn-sm" style="margin-left: 4px;" onclick="openRejectCreatorModal(<?= $cr['id'] ?>, '<?= htmlspecialchars(addslashes($cr['display_name'])) ?>', <?= $cr['status'] === 'active' ? 'true' : 'false' ?>)">
                                            <i class="ph ph-x"></i> <?= $cr['status'] === 'active' ? 'Suspend' : 'Reject' ?>
                                        </button>
                                    </td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB: PAYOUT CENTRE -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'payouts'): ?>
            <div class="filter-header-bar" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; flex-wrap: wrap; gap: 16px;">
                <div>
                    <h2 style="font-size: 1.25rem; font-weight: 700; color: var(--text-primary); margin-bottom: 4px;">
                        Monthly Payout Engine & Finance Reconciliations
                    </h2>
                    <p style="font-size: 0.85rem; color: var(--text-muted); margin: 0;">
                        Tier Ladder: 0-4: ₹0 | 5-9: ₹50 | 10-14: ₹100 | 15-19: ₹150 | 20-24: ₹225 | 25-29: ₹275 | 30+: ₹300 Max.
                    </p>
                </div>
                <div style="display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">
                    <form method="GET" style="display: flex; gap: 6px; align-items: center;">
                        <input type="hidden" name="tab" value="payouts">
                        <input type="month" name="payout_month" value="<?= htmlspecialchars($payoutMonth) ?>" style="padding: 6px 10px; border-radius: 6px; border: 1px solid var(--border); font-size: 0.85rem;">
                        <button type="submit" class="btn btn-secondary btn-sm">Select Month</button>
                    </form>

                    <form method="POST" style="display: inline-block;">
                        <input type="hidden" name="action" value="calculate_monthly_payout">
                        <input type="hidden" name="month" value="<?= htmlspecialchars($payoutMonth) ?>">
                        <button type="submit" class="btn btn-primary btn-sm">
                            <i class="ph ph-calculator"></i> Run Calculation
                        </button>
                    </form>

                    <a href="?export_payouts_csv=1&month=<?= urlencode($payoutMonth) ?>" class="btn btn-secondary btn-sm">
                        <i class="ph ph-file-csv"></i> Export CSV
                    </a>

                    <form id="lockBatchForm" method="POST" style="display: inline-block;">
                        <input type="hidden" name="action" value="lock_payout_batch">
                        <input type="hidden" name="month" value="<?= htmlspecialchars($payoutMonth) ?>">
                        <button type="button" class="btn btn-secondary btn-sm" onclick="promptLockBatch()">
                            <i class="ph ph-lock"></i> Lock Batch
                        </button>
                    </form>

                    <form id="approveBatchForm" method="POST" style="display: inline-block;">
                        <input type="hidden" name="action" value="approve_payout_batch">
                        <input type="hidden" name="month" value="<?= htmlspecialchars($payoutMonth) ?>">
                        <button type="button" class="btn btn-primary btn-sm" style="background: #15803d;" onclick="promptApproveBatch()">
                            <i class="ph ph-check-circle"></i> Finance Approve
                        </button>
                    </form>
                </div>
            </div>

            <!-- Payout Summary Cards -->
            <?php 
                $batchApprovedReels = 0;
                $batchBasePayout = 0.00;
                $batchBonusTotal = 0.00;
                $batchGrossTotal = 0.00;
                foreach ($payoutsList as $pItem) {
                    $batchApprovedReels += intval($pItem['eligible_reel_count']);
                    $batchBasePayout += floatval($pItem['base_payout']);
                    $batchBonusTotal += floatval($pItem['bonus_total']);
                    $batchGrossTotal += floatval($pItem['gross_payout']);
                }
            ?>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px;">
                <div style="background: var(--surface); padding: 16px; border-radius: 8px; border: 1px solid var(--border);">
                    <div style="font-size: 0.75rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Billing Month</div>
                    <div style="font-size: 1.3rem; font-weight: 800; color: var(--text-primary); margin-top: 4px;"><?= htmlspecialchars($payoutMonth) ?></div>
                </div>
                <div style="background: var(--surface); padding: 16px; border-radius: 8px; border: 1px solid var(--border);">
                    <div style="font-size: 0.75rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Creators in Batch</div>
                    <div style="font-size: 1.3rem; font-weight: 800; color: var(--text-primary); margin-top: 4px;"><?= count($payoutsList) ?></div>
                </div>
                <div style="background: var(--surface); padding: 16px; border-radius: 8px; border: 1px solid var(--border);">
                    <div style="font-size: 0.75rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Total Base Uploads</div>
                    <div style="font-size: 1.3rem; font-weight: 800; color: #15803d; margin-top: 4px;">₹<?= number_format($batchBasePayout, 2) ?></div>
                </div>
                <div style="background: var(--surface); padding: 16px; border-radius: 8px; border: 1px solid var(--border);">
                    <div style="font-size: 0.75rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Total Approved Bonuses</div>
                    <div style="font-size: 1.3rem; font-weight: 800; color: #0284c7; margin-top: 4px;">₹<?= number_format($batchBonusTotal, 2) ?></div>
                </div>
                <div style="background: var(--surface); padding: 16px; border-radius: 8px; border: 1px solid var(--border);">
                    <div style="font-size: 0.75rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Gross Liability</div>
                    <div style="font-size: 1.3rem; font-weight: 800; color: #b45309; margin-top: 4px;">₹<?= number_format($batchGrossTotal, 2) ?></div>
                </div>
            </div>

            <div class="table-card">
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Creator</th>
                                <th>Tier</th>
                                <th>Approved Reels</th>
                                <th>Base Payout</th>
                                <th>Bonuses & Adjustments</th>
                                <th>Gross Payout</th>
                                <th>Batch Status</th>
                                <th>Payment Ref (UTR)</th>
                                <th style="text-align: right;">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($payoutsList)): ?>
                                <tr>
                                    <td colspan="9" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                        No payouts calculated yet for <?= htmlspecialchars($payoutMonth) ?>. Click "Run Calculation" above.
                                    </td>
                                </tr>
                            <?php else: foreach ($payoutsList as $po): ?>
                                <tr>
                                    <td>
                                        <div style="font-weight: 600; font-size: 0.85rem; color: var(--text-primary);">
                                            <?= htmlspecialchars($po['display_name']) ?>
                                        </div>
                                        <div style="font-size: 0.72rem; color: var(--text-muted);">
                                            <?= htmlspecialchars($po['phone_number']) ?> &bull; <?= htmlspecialchars($po['upi_id'] ? 'UPI: ' . $po['upi_id'] : 'No UPI') ?>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="status-tag" style="background:#f1f5f9; color:#475569; font-size:0.68rem; text-transform:uppercase;">
                                            <?= htmlspecialchars($po['partnership_tier'] ?? 'trial') ?>
                                        </span>
                                    </td>
                                    <td>
                                        <strong style="font-size: 0.9rem;"><?= intval($po['eligible_reel_count']) ?></strong> reels
                                        <?php if ($po['eligible_reel_count'] >= 30): ?>
                                            <span style="color: #15803d; font-size: 0.72rem; font-weight: 600;">(Target Met)</span>
                                        <?php endif; ?>
                                    </td>
                                    <td style="font-weight: 700; color: #15803d;">
                                        ₹<?= number_format($po['base_payout'], 2) ?>
                                    </td>
                                    <td>
                                        <span style="font-weight: 600; color: #0284c7;">+₹<?= number_format($po['bonus_total'], 2) ?></span>
                                        <?php if (!empty($po['line_items'])): ?>
                                            <div style="font-size: 0.68rem; color: var(--text-muted);">
                                                <?= count($po['line_items']) ?> line item(s)
                                            </div>
                                        <?php endif; ?>
                                    </td>
                                    <td style="font-weight: 800; font-size: 0.95rem; color: var(--text-primary);">
                                        ₹<?= number_format($po['gross_payout'], 2) ?>
                                    </td>
                                    <td>
                                        <?php 
                                            $ps = $po['status'] ?? 'calculated';
                                            $pCol = '#fef3c7'; $ptCol = '#92400e';
                                            if ($ps === 'paid') { $pCol = '#dcfce7'; $ptCol = '#166534'; }
                                            elseif ($ps === 'approved') { $pCol = '#e0f2fe'; $ptCol = '#0369a1'; }
                                            elseif ($ps === 'locked') { $pCol = '#f3e8ff'; $ptCol = '#6b21a8'; }
                                        ?>
                                        <span class="status-tag" style="background: <?= $pCol ?>; color: <?= $ptCol ?>; text-transform: capitalize;">
                                            <?= $ps ?>
                                        </span>
                                    </td>
                                    <td style="font-size: 0.78rem; color: var(--text-muted);">
                                        <?= htmlspecialchars($po['payment_reference'] ?: '-') ?>
                                    </td>
                                    <td style="text-align: right; white-space: nowrap;">
                                        <button type="button" class="btn btn-secondary btn-sm" style="margin-right: 4px;" onclick="openAddBonusModal(<?= $po['id'] ?>, '<?= htmlspecialchars(addslashes($po['display_name'])) ?>', '<?= htmlspecialchars($payoutMonth) ?>')">
                                            <i class="ph ph-plus"></i> Bonus
                                        </button>

                                        <?php if ($po['status'] !== 'paid'): ?>
                                            <button type="button" class="btn btn-primary btn-sm" style="background: #15803d;" onclick="openMarkPaidModal(<?= $po['id'] ?>, '<?= htmlspecialchars(addslashes($po['display_name'])) ?>', '<?= htmlspecialchars(addslashes($po['upi_id'] ?? '')) ?>', <?= floatval($po['gross_payout']) ?>, '<?= htmlspecialchars($payoutMonth) ?>')">
                                                <i class="ph ph-check"></i> Paid
                                            </button>
                                        <?php else: ?>
                                            <span style="font-size: 0.78rem; color: #15803d; font-weight: 600;"><i class="ph ph-check-circle"></i> Settled</span>
                                        <?php endif; ?>
                                    </td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB: CAMPAIGN MANAGEMENT HUB -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'campaigns'): ?>
            <div class="filter-header-bar" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <div>
                    <h2 style="font-size: 1.25rem; font-weight: 700; color: var(--text-primary); margin-bottom: 4px;">
                        Promotional Campaigns & Brand Deliverables
                    </h2>
                    <p style="font-size: 0.85rem; color: var(--text-muted); margin: 0;">
                        Manage separately negotiated sponsor deals, assign agriculture creators, and approve deliverables.
                    </p>
                </div>
            </div>

            <!-- Create Campaign Card -->
            <div class="table-card" style="margin-bottom: 24px; padding: 20px;">
                <h3 style="font-size: 1rem; font-weight: 700; margin-bottom: 12px; color: var(--text-primary);">Create New Sponsored Campaign</h3>
                <form method="POST" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; align-items: flex-end;">
                    <input type="hidden" name="action" value="create_campaign">
                    <div>
                        <label style="font-size: 0.75rem; font-weight: 600; color: var(--text-secondary); display: block; margin-bottom: 4px;">Campaign Name</label>
                        <input type="text" name="name" placeholder="e.g. Kharif Bio-Fertilizer Launch" style="width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid var(--border); font-size: 0.85rem;" required>
                    </div>
                    <div>
                        <label style="font-size: 0.75rem; font-weight: 600; color: var(--text-secondary); display: block; margin-bottom: 4px;">Client / Brand</label>
                        <input type="text" name="client_brand" placeholder="e.g. AgriCorp Biotech" style="width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid var(--border); font-size: 0.85rem;" required>
                    </div>
                    <div>
                        <label style="font-size: 0.75rem; font-weight: 600; color: var(--text-secondary); display: block; margin-bottom: 4px;">Budget (INR)</label>
                        <input type="number" name="budget" placeholder="₹ Budget" style="width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid var(--border); font-size: 0.85rem;">
                    </div>
                    <div>
                        <label style="font-size: 0.75rem; font-weight: 600; color: var(--text-secondary); display: block; margin-bottom: 4px;">Objective</label>
                        <input type="text" name="objective" placeholder="e.g. Farmer awareness on nano urea" style="width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid var(--border); font-size: 0.85rem;">
                    </div>
                    <div>
                        <button type="submit" class="btn btn-primary" style="width: 100%;">
                            <i class="ph ph-plus"></i> Create Campaign
                        </button>
                    </div>
                </form>
            </div>

            <!-- Campaigns List -->
            <div class="table-card">
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Campaign & Client</th>
                                <th>Budget</th>
                                <th>Timeline</th>
                                <th>Status</th>
                                <th>Assigned Creators & Deliverables</th>
                                <th style="text-align: right;">Assign Creator</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($campaignsList)): ?>
                                <tr>
                                    <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                        No campaigns created yet. Use the form above to launch a brand sponsor campaign.
                                    </td>
                                </tr>
                            <?php else: foreach ($campaignsList as $cmp): ?>
                                <tr>
                                    <td>
                                        <div style="font-weight: 700; font-size: 0.9rem; color: var(--text-primary);"><?= htmlspecialchars($cmp['name']) ?></div>
                                        <div style="font-size: 0.75rem; color: var(--accent); font-weight: 600;"><?= htmlspecialchars($cmp['client_brand']) ?></div>
                                        <div style="font-size: 0.72rem; color: var(--text-muted);"><?= htmlspecialchars($cmp['objective'] ?: '') ?></div>
                                    </td>
                                    <td style="font-weight: 700; color: #15803d;">
                                        ₹<?= number_format($cmp['budget'], 2) ?>
                                    </td>
                                    <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                        <?= htmlspecialchars($cmp['start_date']) ?> to <?= htmlspecialchars($cmp['end_date']) ?>
                                    </td>
                                    <td>
                                        <span class="status-tag" style="background:#dcfce7; color:#166534; text-transform:uppercase;">
                                            <?= htmlspecialchars($cmp['status']) ?>
                                        </span>
                                    </td>
                                    <td>
                                        <?php if (empty($cmp['assignments'])): ?>
                                            <span style="color: var(--text-muted); font-size: 0.78rem;">No creators assigned yet.</span>
                                        <?php else: foreach ($cmp['assignments'] as $asg): ?>
                                            <div style="background: #f8fafc; padding: 6px 10px; border-radius: 6px; margin-bottom: 6px; border: 1px solid var(--border);">
                                                <div style="display: flex; justify-content: space-between; font-size: 0.8rem; font-weight: 600;">
                                                    <span><?= htmlspecialchars($asg['creator_name']) ?></span>
                                                    <span style="color: #15803d;">Fee: ₹<?= number_format($asg['negotiated_fee'], 2) ?></span>
                                                </div>
                                                <div style="font-size: 0.72rem; color: var(--text-muted);">
                                                    <?= htmlspecialchars($asg['deliverable_type']) ?> &bull; Status: <strong><?= $asg['status'] ?></strong>
                                                </div>
                                                <?php if (!empty($asg['deliverables'])): foreach ($asg['deliverables'] as $del): ?>
                                                    <div style="margin-top: 4px; font-size: 0.72rem; display: flex; gap: 8px; align-items: center;">
                                                        <a href="<?= htmlspecialchars($del['proof_url'] ?: $del['content_url']) ?>" target="_blank" style="color: var(--accent); font-weight: 600;">
                                                            <i class="ph ph-arrow-square-out"></i> View Proof
                                                        </a>
                                                        <span class="status-tag" style="padding: 1px 6px; font-size: 0.65rem;">
                                                            <?= $del['approval_status'] ?>
                                                        </span>
                                                        <?php if ($del['approval_status'] === 'submitted'): ?>
                                                            <form method="POST" style="display:inline;">
                                                                <input type="hidden" name="action" value="review_campaign_deliverable">
                                                                <input type="hidden" name="deliverable_id" value="<?= $del['id'] ?>">
                                                                <input type="hidden" name="decision" value="approved">
                                                                <button type="submit" class="btn btn-primary btn-sm" style="padding: 2px 6px; font-size: 0.68rem;">Approve</button>
                                                            </form>
                                                        <?php endif; ?>
                                                    </div>
                                                <?php endforeach; endif; ?>
                                            </div>
                                        <?php endforeach; endif; ?>
                                    </td>
                                    <td style="text-align: right; white-space: nowrap;">
                                        <!-- Assign Form -->
                                        <form method="POST" style="display: inline-block;">
                                            <input type="hidden" name="action" value="assign_campaign_creator">
                                            <input type="hidden" name="campaign_id" value="<?= $cmp['id'] ?>">
                                            <select name="creator_id" style="font-size: 0.75rem; padding: 4px 6px; border: 1px solid var(--border); border-radius: 4px;" required>
                                                <option value="">Select Creator</option>
                                                <?php foreach ($creatorsList as $cOpt): ?>
                                                    <option value="<?= $cOpt['id'] ?>"><?= htmlspecialchars($cOpt['display_name']) ?></option>
                                                <?php endforeach; ?>
                                            </select>
                                            <input type="number" name="negotiated_fee" placeholder="Fee ₹" style="width: 70px; font-size: 0.75rem; padding: 4px 6px; border: 1px solid var(--border); border-radius: 4px;" required>
                                            <button type="submit" class="btn btn-secondary btn-sm">
                                                <i class="ph ph-user-plus"></i> Assign
                                            </button>
                                        </form>
                                    </td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        <?php endif; ?>

        <!-- ============================================================== -->
        <!-- TAB: PARTNER ANALYTICS & AUDIT LOGS -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'analytics'): ?>
            <div class="filter-header-bar" style="margin-bottom: 20px;">
                <h2 style="font-size: 1.25rem; font-weight: 700; color: var(--text-primary); margin-bottom: 4px;">
                    Program Analytics & Immutable Audit Log Trail
                </h2>
                <p style="font-size: 0.85rem; color: var(--text-muted); margin: 0;">
                    Complete tamper-evident trace of creator status changes, content decisions, and payout locks.
                </p>
            </div>

            <!-- Leaderboard Card -->
            <div class="table-card" style="margin-bottom: 24px;">
                <div style="padding: 16px; border-bottom: 1px solid var(--border); font-weight: 700; font-size: 0.95rem;">
                    <i class="ph ph-trophy"></i> Creator Leaderboard (Top Contributors)
                </div>
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Rank</th>
                                <th>Creator</th>
                                <th>Tier</th>
                                <th>Approved Reels</th>
                                <th>Total Reach (Views)</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php 
                                $rank = 1;
                                $rankedCreators = $creatorsList;
                                usort($rankedCreators, function($a, $b) {
                                    return intval($b['approved_reels']) - intval($a['approved_reels']);
                                });
                                if (empty($rankedCreators)): 
                            ?>
                                <tr><td colspan="6" style="text-align:center; padding: 24px; color: var(--text-muted);">No creators enrolled yet.</td></tr>
                            <?php else: foreach (array_slice($rankedCreators, 0, 10) as $rk): ?>
                                <tr>
                                    <td style="font-weight: 800; color: <?= $rank <= 3 ? '#b45309' : 'var(--text-muted)' ?>;">
                                        #<?= $rank++ ?>
                                    </td>
                                    <td style="font-weight: 600;"><?= htmlspecialchars($rk['display_name']) ?></td>
                                    <td><span class="status-tag"><?= htmlspecialchars($rk['partnership_tier'] ?? 'trial') ?></span></td>
                                    <td style="font-weight: 700; color: #15803d;"><?= intval($rk['approved_reels']) ?></td>
                                    <td><?= number_format(intval($rk['total_views'])) ?></td>
                                    <td><span class="status-tag"><?= htmlspecialchars($rk['status']) ?></span></td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Audit Logs Card -->
            <div class="table-card">
                <div style="padding: 16px; border-bottom: 1px solid var(--border); font-weight: 700; font-size: 0.95rem;">
                    <i class="ph ph-shield-check"></i> System Audit Logs
                </div>
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Timestamp</th>
                                <th>Actor</th>
                                <th>Action</th>
                                <th>Entity</th>
                                <th>Entity ID</th>
                                <th>Details</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($auditLogsList)): ?>
                                <tr><td colspan="6" style="text-align:center; padding: 24px; color: var(--text-muted);">No audit logs recorded yet.</td></tr>
                            <?php else: foreach ($auditLogsList as $log): ?>
                                <tr>
                                    <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                        <?= date('M d, Y H:i:s', strtotime($log['created_at'])) ?>
                                    </td>
                                    <td>
                                        <span class="status-tag" style="background: #f1f5f9; color: #334155; font-size: 0.72rem;">
                                            <?= htmlspecialchars($log['actor_role'] ?: 'admin') ?>: <?= htmlspecialchars($log['actor_id'] ?: 'System') ?>
                                        </span>
                                    </td>
                                    <td style="font-weight: 600; font-size: 0.82rem;">
                                        <?= htmlspecialchars($log['action']) ?>
                                    </td>
                                    <td><?= htmlspecialchars($log['entity_type']) ?></td>
                                    <td>#<?= htmlspecialchars($log['entity_id']) ?></td>
                                    <td style="max-width: 350px; font-size: 0.72rem; color: var(--text-muted); font-family: monospace;">
                                        <?= htmlspecialchars(mb_strimwidth($log['after_json'] ?: ($log['before_json'] ?: '-'), 0, 100, '...')) ?>
                                    </td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        <?php endif; ?>

    </main>

    <!-- ============================================================== -->
    <!-- MODAL: CREATE / EDIT NEWS (WITH ALPINE DROPDOWNS & PROGRESS UPLOAD) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="newsModal" x-data="{
        category: 'Govt Schemes',
        catOpen: false,
        status: 'published',
        statusOpen: false,
        langTab: 'en',
        targetLang: 'all',
        langOpen: false,
        imageUrl: '',
        isUploading: false,
        progress: 0,
        statusText: '',
        setCat(val) { this.category = val; this.catOpen = false; },
        setStatus(val) { this.status = val; this.statusOpen = false; },
        setTargetLang(val) { this.targetLang = val; this.langOpen = false; },
        uploadFile(file) {
            if (!file) return;
            this.isUploading = true;
            this.progress = 10;
            this.statusText = 'Uploading image... 10%';

            const formData = new FormData();
            formData.append('file', file);

            const xhr = new XMLHttpRequest();
            xhr.open('POST', '?ajax_upload=image', true);

            xhr.upload.onprogress = (e) => {
                if (e.lengthComputable) {
                    const pct = Math.round((e.loaded / e.total) * 100);
                    this.progress = pct;
                    this.statusText = 'Uploading image... ' + pct + '%';
                }
            };

            xhr.onload = () => {
                this.isUploading = false;
                if (xhr.status === 200) {
                    try {
                        const res = JSON.parse(xhr.responseText);
                        if (res.success && res.url) {
                            this.imageUrl = res.url;
                            document.getElementById('news_image_url').value = res.url;
                            this.statusText = 'Uploaded successfully!';
                        } else {
                            this.statusText = 'Upload failed: ' + (res.error || 'Server error');
                        }
                    } catch (e) {
                        this.statusText = 'Server response error.';
                    }
                } else {
                    this.statusText = 'Network error during upload.';
                }
            };

            xhr.onerror = () => {
                this.isUploading = false;
                this.statusText = 'Upload failed due to connection issue.';
            };

            xhr.send(formData);
        },
        isTranslating: false,
        translateSuccess: false,
        translateError: '',
        autoTranslate() {
            const title = document.getElementById('news_title').value.trim();
            const summary = document.getElementById('news_summary').value.trim();
            const content = document.getElementById('news_content').value.trim();

            if (!title && !content) {
                this.translateError = 'Please enter English Title or Content first before translating.';
                setTimeout(() => { this.translateError = ''; }, 4000);
                return;
            }

            this.isTranslating = true;
            this.translateError = '';
            this.translateSuccess = false;

            const formData = new FormData();
            formData.append('source_lang', 'en');
            formData.append('title', title);
            formData.append('summary', summary);
            formData.append('content', content);

            fetch('?ajax_translate=1', {
                method: 'POST',
                body: formData
            })
            .then(r => r.json())
            .then(data => {
                this.isTranslating = false;
                if (data.success && data.translations) {
                    if (data.translations.te) {
                        document.getElementById('news_title_te').value = data.translations.te.title || '';
                        document.getElementById('news_summary_te').value = data.translations.te.summary || '';
                        document.getElementById('news_content_te').value = data.translations.te.content || '';
                    }
                    if (data.translations.hi) {
                        document.getElementById('news_title_hi').value = data.translations.hi.title || '';
                        document.getElementById('news_summary_hi').value = data.translations.hi.summary || '';
                        document.getElementById('news_content_hi').value = data.translations.hi.content || '';
                    }
                    this.translateSuccess = true;
                    setTimeout(() => { this.translateSuccess = false; }, 4000);
                } else {
                    this.translateError = data.error || 'Failed to auto-translate content.';
                    setTimeout(() => { this.translateError = ''; }, 4000);
                }
            })
            .catch(err => {
                this.isTranslating = false;
                this.translateError = 'Network error during translation: ' + err.message;
                setTimeout(() => { this.translateError = ''; }, 4000);
            });
        }
    }">
        <div class="modal-card">
            <div class="modal-head">
                <h3 id="newsModalTitle">New Krishi Article</h3>
                <button type="button" class="close-btn" onclick="closeModal('newsModal')">&times;</button>
            </div>
            <form method="POST" enctype="multipart/form-data">
                <input type="hidden" name="action" value="save_news">
                <input type="hidden" name="news_id" id="news_id" value="0">
                <input type="hidden" name="category" :value="category">
                <input type="hidden" name="status" :value="status">

                <div class="modal-body">
                    <!-- Language Selection & Editorial Tabs with 1-Click Free Auto-Translate -->
                    <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:8px; margin-bottom:12px; background:var(--surface-subtle); padding:10px 14px; border-radius:var(--radius-md); border:1px solid var(--border);">
                        <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap;">
                            <button type="button" class="btn btn-sm" :class="langTab === 'en' ? 'btn-primary' : 'btn-outline'" @click="langTab = 'en'" style="font-size:0.75rem; padding:4px 10px;">
                                🇬🇧 English
                            </button>
                            <button type="button" class="btn btn-sm" :class="langTab === 'te' ? 'btn-primary' : 'btn-outline'" @click="langTab = 'te'" style="font-size:0.75rem; padding:4px 10px;">
                                🇮🇳 Telugu (తెలుగు)
                            </button>
                            <button type="button" class="btn btn-sm" :class="langTab === 'hi' ? 'btn-primary' : 'btn-outline'" @click="langTab = 'hi'" style="font-size:0.75rem; padding:4px 10px;">
                                🇮🇳 Hindi (हिंदी)
                            </button>
                        </div>

                        <div style="display:flex; align-items:center; gap:8px;">
                            <!-- One-Click Free Auto-Translate Button -->
                            <button type="button" 
                                    class="btn btn-sm" 
                                    :disabled="isTranslating"
                                    @click="autoTranslate()"
                                    style="background:#059669; color:#ffffff; font-size:0.75rem; font-weight:600; padding:4px 12px; display:inline-flex; align-items:center; gap:5px; border-radius:6px; border:none; box-shadow:0 1px 2px rgba(0,0,0,0.05); cursor:pointer;">
                                <template x-if="!isTranslating">
                                    <span style="display:inline-flex; align-items:center; gap:4px;">
                                        <i class="ph ph-translate" style="font-size:14px;"></i>
                                        <span>Auto-Translate to Telugu & Hindi</span>
                                    </span>
                                </template>
                                <template x-if="isTranslating">
                                    <span style="display:inline-flex; align-items:center; gap:4px;">
                                        <i class="ph ph-spinner-gap spin" style="font-size:14px; animation:spin 1s linear infinite;"></i>
                                        <span>Translating...</span>
                                    </span>
                                </template>
                            </button>

                            <input type="hidden" name="language" :value="targetLang">
                            <div class="alpine-dropdown" style="min-width:130px;" @click.outside="langOpen = false">
                                <button type="button" class="dropdown-trigger" style="padding:4px 8px; font-size:0.75rem;" @click="langOpen = !langOpen">
                                    <span x-text="'Target: ' + (targetLang === 'all' ? 'All Farmers' : targetLang.toUpperCase())"></span>
                                    <i class="ph ph-caret-down" style="font-size:10px;"></i>
                                </button>
                                <div class="dropdown-panel" style="width:100%; right:0; left:auto;" x-show="langOpen" x-cloak x-transition>
                                    <div class="dropdown-option" :class="{ 'selected': targetLang === 'all' }" @click="setTargetLang('all')">All Farmers (all)</div>
                                    <div class="dropdown-option" :class="{ 'selected': targetLang === 'te' }" @click="setTargetLang('te')">Telugu Preferred</div>
                                    <div class="dropdown-option" :class="{ 'selected': targetLang === 'hi' }" @click="setTargetLang('hi')">Hindi Preferred</div>
                                    <div class="dropdown-option" :class="{ 'selected': targetLang === 'en' }" @click="setTargetLang('en')">English Only</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Auto-Translate Banner Alerts -->
                    <div x-show="translateSuccess" x-cloak x-transition style="background:#ecfdf5; border:1px solid #6ee7b7; color:#065f46; font-size:0.78rem; font-weight:600; padding:8px 12px; border-radius:6px; margin-bottom:12px; display:flex; align-items:center; gap:6px;">
                        <i class="ph ph-check-circle" style="font-size:16px; color:#059669;"></i>
                        <span>Successfully auto-translated into Telugu & Hindi! You can review or tweak each language tab before publishing.</span>
                    </div>

                    <div x-show="translateError" x-cloak x-transition style="background:#fef2f2; border:1px solid #fca5a5; color:#991b1b; font-size:0.78rem; font-weight:600; padding:8px 12px; border-radius:6px; margin-bottom:12px; display:flex; align-items:center; gap:6px;">
                        <i class="ph ph-warning-circle" style="font-size:16px; color:#dc2626;"></i>
                        <span x-text="translateError"></span>
                    </div>

                    <!-- ENGLISH TAB -->
                    <div x-show="langTab === 'en'">
                        <div class="form-row">
                            <label>Headline / Title (English) *</label>
                            <input type="text" name="title" id="news_title" class="form-input" placeholder="e.g. Subsidies on Drip Irrigation Announced" required>
                        </div>
                        <div class="form-row">
                            <label>Teaser Summary (English)</label>
                            <textarea name="summary" id="news_summary" class="form-input" placeholder="Short teaser for farmer feed notifications..."></textarea>
                        </div>
                        <div class="form-row">
                            <label>Full Content (English) *</label>
                            <textarea name="content" id="news_content" class="form-input" style="min-height: 110px;" placeholder="Full story, application details, subsidy slab..."></textarea>
                        </div>
                    </div>

                    <!-- TELUGU TAB -->
                    <div x-show="langTab === 'te'" x-cloak>
                        <div class="form-row">
                            <label>శీర్షిక / Title (Telugu - తెలుగు)</label>
                            <input type="text" name="title_te" id="news_title_te" class="form-input" placeholder="ఉదా: బిందు సేద్యంపై రైతులకు రాయితీలు ప్రకటించిన ప్రభుత్వం">
                        </div>
                        <div class="form-row">
                            <label>సారాంశం / Teaser Summary (Telugu)</label>
                            <textarea name="summary_te" id="news_summary_te" class="form-input" placeholder="రైతు ఫీడ్ కోసం సంక్షిప్త వివరణ..."></textarea>
                        </div>
                        <div class="form-row">
                            <label>పూర్తి సమాచారం / Full Content (Telugu)</label>
                            <textarea name="content_te" id="news_content_te" class="form-input" style="min-height: 110px;" placeholder="పూర్తి వివరాలు, దరఖాస్తు విధానం, సబ్సిడీ మొత్తం..."></textarea>
                        </div>
                    </div>

                    <!-- HINDI TAB -->
                    <div x-show="langTab === 'hi'" x-cloak>
                        <div class="form-row">
                            <label>शीर्षक / Title (Hindi - हिंदी)</label>
                            <input type="text" name="title_hi" id="news_title_hi" class="form-input" placeholder="उदा: ड्रिप सिंचाई पर किसानों के लिए सब्सिडी की घोषणा">
                        </div>
                        <div class="form-row">
                            <label>सारांश / Teaser Summary (Hindi)</label>
                            <textarea name="summary_hi" id="news_summary_hi" class="form-input" placeholder="किसान फ़ीड के लिए संक्षिप्त विवरण..."></textarea>
                        </div>
                        <div class="form-row">
                            <label>पूरी खबर / Full Content (Hindi)</label>
                            <textarea name="content_hi" id="news_content_hi" class="form-input" style="min-height: 110px;" placeholder="पूरी जानकारी, आवेदन प्रक्रिया, सब्सिडी विवरण..."></textarea>
                        </div>
                    </div>

                    <div class="grid-2">
                        <!-- Alpine Dropdown for Category in Dialog -->
                        <div class="form-row">
                            <label>Category *</label>
                            <div class="alpine-dropdown" style="width:100%;" @click.outside="catOpen = false">
                                <button type="button" class="dropdown-trigger" style="width:100%;" @click="catOpen = !catOpen">
                                    <span x-text="category"></span>
                                    <i class="ph ph-caret-down" style="font-size:12px;"></i>
                                </button>
                                <div class="dropdown-panel" style="width:100%;" x-show="catOpen" x-cloak x-transition>
                                    <?php foreach ($availableCategories as $cat): ?>
                                        <div class="dropdown-option" :class="{ 'selected': category === '<?= htmlspecialchars($cat) ?>' }" @click="setCat('<?= htmlspecialchars($cat) ?>')">
                                            <?= htmlspecialchars($cat) ?>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            </div>
                        </div>

                        <!-- Alpine Dropdown for Status in Dialog -->
                        <div class="form-row">
                            <label>Publishing Status</label>
                            <div class="alpine-dropdown" style="width:100%;" @click.outside="statusOpen = false">
                                <button type="button" class="dropdown-trigger" style="width:100%;" @click="statusOpen = !statusOpen">
                                    <span x-text="status.charAt(0).toUpperCase() + status.slice(1)"></span>
                                    <i class="ph ph-caret-down" style="font-size:12px;"></i>
                                </button>
                                <div class="dropdown-panel" style="width:100%;" x-show="statusOpen" x-cloak x-transition>
                                    <div class="dropdown-option" :class="{ 'selected': status === 'published' }" @click="setStatus('published')">Published</div>
                                    <div class="dropdown-option" :class="{ 'selected': status === 'draft' }" @click="setStatus('draft')">Draft</div>
                                    <div class="dropdown-option" :class="{ 'selected': status === 'archived' }" @click="setStatus('archived')">Archived</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="grid-2">
                        <div class="form-row">
                            <label>Author</label>
                            <input type="text" name="author" id="news_author" class="form-input" value="CropSync Desk">
                        </div>
                        <div class="form-row">
                            <label>Source</label>
                            <input type="text" name="source_name" id="news_source_name" class="form-input" value="Krishi Portal">
                        </div>
                    </div>

                    <!-- CUSTOM FILE UPLOAD COMPONENT WITH PROGRESS INDICATOR -->
                    <div class="form-row">
                        <label>Cover Image (Drag & Drop or Click)</label>
                        <div class="custom-upload-zone" 
                             @click="$refs.newsFileInput.click()"
                             @dragover.prevent="$el.classList.add('dragover')"
                             @dragleave.prevent="$el.classList.remove('dragover')"
                             @drop.prevent="$el.classList.remove('dragover'); uploadFile($event.dataTransfer.files[0])">
                            
                            <input type="file" x-ref="newsFileInput" style="display:none;" accept="image/*" @change="uploadFile($event.target.files[0])">
                            
                            <i class="ph ph-image upload-icon"></i>
                            <div class="upload-title">Choose image file or drag here</div>
                            <div class="upload-subtitle">Supports JPG, PNG, WEBP (Max 10MB)</div>

                            <!-- Progress Indicator Bar -->
                            <div class="progress-wrapper" :class="{ 'active': isUploading }">
                                <div class="progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                            </div>
                            <div class="upload-status-text" :class="{ 'active': statusText !== '' }" x-text="statusText"></div>
                        </div>
                    </div>

                    <div class="form-row">
                        <label>Or Direct Image URL</label>
                        <input type="url" name="image_url" id="news_image_url" x-model="imageUrl" class="form-input" placeholder="https://example.com/photo.jpg">
                    </div>

                    <div class="form-row" style="display: flex; align-items: center; gap: 8px; margin-top: 8px;">
                        <input type="checkbox" name="is_featured" id="news_is_featured" value="1">
                        <label for="news_is_featured" style="margin-bottom:0; cursor:pointer;">Pin as Featured / Highlighted</label>
                    </div>
                </div>

                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('newsModal')">Cancel</button>
                    <button type="submit" class="btn btn-primary" id="newsSubmitBtn">Save Article</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: UPLOAD / EDIT REEL (WITH CUSTOM VIDEO UPLOAD & PROGRESS) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="reelModal" x-data="{
        isActive: 1,
        activeOpen: false,
        videoUrl: '',
        isUploading: false,
        progress: 0,
        statusText: '',
        setActive(val) { this.isActive = val; this.activeOpen = false; },
        uploadVideo(file) {
            if (!file) return;
            this.isUploading = true;
            this.progress = 5;
            this.statusText = 'Uploading video... 5%';

            const formData = new FormData();
            formData.append('file', file);

            const xhr = new XMLHttpRequest();
            xhr.open('POST', '?ajax_upload=video', true);

            xhr.upload.onprogress = (e) => {
                if (e.lengthComputable) {
                    const pct = Math.round((e.loaded / e.total) * 100);
                    this.progress = pct;
                    this.statusText = 'Uploading video... ' + pct + '%';
                }
            };

            xhr.onload = () => {
                this.isUploading = false;
                if (xhr.status === 200) {
                    try {
                        const res = JSON.parse(xhr.responseText);
                        if (res.success && res.url) {
                            this.videoUrl = res.url;
                            document.getElementById('reel_video_url').value = res.url;
                            this.statusText = 'Video uploaded successfully!';
                        } else {
                            this.statusText = 'Upload failed: ' + (res.error || 'Server error');
                        }
                    } catch (e) {
                        this.statusText = 'Server response error.';
                    }
                } else {
                    this.statusText = 'Network error during upload.';
                }
            };

            xhr.onerror = () => {
                this.isUploading = false;
                this.statusText = 'Upload failed due to network error.';
            };

            xhr.send(formData);
        }
    }">
        <div class="modal-card">
            <div class="modal-head">
                <h3 id="reelModalTitle">Upload Agri Reel</h3>
                <button type="button" class="close-btn" onclick="closeModal('reelModal')">&times;</button>
            </div>
            <form method="POST" enctype="multipart/form-data">
                <input type="hidden" name="action" value="save_reel">
                <input type="hidden" name="reel_id" id="reel_id" value="0">
                <input type="hidden" name="is_active" :value="isActive">

                <div class="modal-body">
                    <div class="form-row">
                        <label>Reel Caption *</label>
                        <textarea name="caption" id="reel_caption" class="form-input" placeholder="Video description, farming technique, crop variety..." required></textarea>
                    </div>

                    <div class="grid-2">
                        <div class="form-row">
                            <label>Creator Name *</label>
                            <input type="text" name="creator_name" id="reel_creator_name" class="form-input" value="CropSync Creator" required>
                        </div>
                        <div class="form-row">
                            <label>Creator Phone</label>
                            <input type="text" name="phone_number" id="reel_phone_number" class="form-input" value="9182867655">
                        </div>
                    </div>

                    <div class="grid-2">
                        <div class="form-row">
                            <label>Audio Title</label>
                            <input type="text" name="music_title" id="reel_music_title" class="form-input" value="Original Audio">
                        </div>
                        <div class="form-row">
                            <label>Hashtags</label>
                            <input type="text" name="tags" id="reel_tags" class="form-input" placeholder="#Paddy #Harvesting">
                        </div>
                    </div>

                    <!-- CUSTOM VIDEO UPLOAD ZONE WITH PROGRESS BAR -->
                    <div class="form-row">
                        <label>Reel Video File (Drag & Drop or Click)</label>
                        <div class="custom-upload-zone"
                             @click="$refs.reelFileInput.click()"
                             @dragover.prevent="$el.classList.add('dragover')"
                             @dragleave.prevent="$el.classList.remove('dragover')"
                             @drop.prevent="$el.classList.remove('dragover'); uploadVideo($event.dataTransfer.files[0])">
                            
                            <input type="file" x-ref="reelFileInput" style="display:none;" accept="video/*" @change="uploadVideo($event.target.files[0])">

                            <i class="ph ph-video-camera upload-icon"></i>
                            <div class="upload-title">Choose MP4/MOV video or drag here</div>
                            <div class="upload-subtitle">Direct upload to /Reels/ with live progress</div>

                            <!-- Progress Bar -->
                            <div class="progress-wrapper" :class="{ 'active': isUploading }">
                                <div class="progress-bar-fill" :style="'width: ' + progress + '%'"></div>
                            </div>
                            <div class="upload-status-text" :class="{ 'active': statusText !== '' }" x-text="statusText"></div>
                        </div>
                    </div>

                    <div class="form-row">
                        <label>Or Video Direct URL</label>
                        <input type="url" name="video_url" id="reel_video_url" x-model="videoUrl" class="form-input" placeholder="http://kiosk.cropsync.in/Reels/sample.mp4">
                    </div>

                    <!-- Alpine Dropdown for Visibility Status in Dialog -->
                    <div class="form-row">
                        <label>Visibility Status</label>
                        <div class="alpine-dropdown" style="width:100%;" @click.outside="activeOpen = false">
                            <button type="button" class="dropdown-trigger" style="width:100%;" @click="activeOpen = !activeOpen">
                                <span x-text="isActive == 1 ? 'Active (Live in Reel Feed)' : 'Hidden (Private)'"></span>
                                <i class="ph ph-caret-down" style="font-size:12px;"></i>
                            </button>
                            <div class="dropdown-panel" style="width:100%;" x-show="activeOpen" x-cloak x-transition>
                                <div class="dropdown-option" :class="{ 'selected': isActive == 1 }" @click="setActive(1)">Active (Live in Reel Feed)</div>
                                <div class="dropdown-option" :class="{ 'selected': isActive == 0 }" @click="setActive(0)">Hidden (Private)</div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('reelModal')">Cancel</button>
                    <button type="submit" class="btn btn-primary" id="reelSubmitBtn">Publish Reel</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: CONFIRM DELETE -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="deleteConfirmModal">
        <div class="modal-card confirm-dialog-card">
            <div class="modal-head" style="border-bottom-color:#fecaca; background:#fef2f2;">
                <h3 style="color:var(--danger); display:flex; align-items:center; gap:8px;">
                    <div class="confirm-icon-badge danger" style="width:32px; height:32px; font-size:18px;">
                        <i class="ph ph-warning-circle"></i>
                    </div>
                    Confirm Delete
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('deleteConfirmModal')">&times;</button>
            </div>
            <form id="singleDeleteForm" method="POST">
                <input type="hidden" name="action" id="del_action" value="">
                <input type="hidden" name="news_id" id="del_news_id" value="">
                <input type="hidden" name="reel_id" id="del_reel_id" value="">
                <input type="hidden" name="comment_id" id="del_comment_id" value="">
                <input type="hidden" name="comment_type" id="del_comment_type" value="">
                <input type="hidden" name="parent_id" id="del_parent_id" value="">

                <div class="modal-body" style="font-size: 0.9rem; color: var(--text-secondary); line-height: 1.5;">
                    <p>Are you sure you want to permanently delete this item?</p>
                    <div id="deleteItemTitle" style="font-weight: 700; color: var(--text-primary); margin: 10px 0; padding: 10px 14px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border);"></div>
                    <p style="font-size: 0.78rem; color: #dc2626; margin-top: 8px; display: flex; align-items: center; gap: 4px;">
                        <i class="ph ph-warning"></i> This operation cannot be reversed.
                    </p>
                </div>
                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('deleteConfirmModal')">Cancel</button>
                    <button type="submit" class="btn btn-danger">Yes, Permanently Delete</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: UNIVERSAL APP CONFIRMATION (REPLACES BROWSER CONFIRM) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="appConfirmModal">
        <div class="modal-card confirm-dialog-card" style="max-width: 440px; text-align: center; padding: 24px;">
            <div id="appConfirmIconBubble" class="confirm-icon-bubble confirm-warning">
                <i id="appConfirmIcon" class="ph ph-warning-circle"></i>
            </div>
            <h3 id="appConfirmTitle" style="font-size: 1.15rem; font-weight: 700; color: var(--text-primary); margin-bottom: 8px;">Confirm Action</h3>
            <p id="appConfirmMessage" style="font-size: 0.92rem; color: var(--text-secondary); line-height: 1.5; margin-bottom: 8px; word-break: break-word;"></p>
            <p id="appConfirmSubtext" style="font-size: 0.78rem; color: var(--text-muted); margin-bottom: 20px; line-height: 1.4; display: none;"></p>
            
            <div style="display: flex; gap: 12px; justify-content: center; width: 100%; margin-top: 14px;">
                <button type="button" class="btn btn-secondary" style="flex: 1; padding: 9px 16px;" onclick="closeModal('appConfirmModal')">Cancel</button>
                <button type="button" id="appConfirmBtn" class="btn btn-primary" style="flex: 1; padding: 9px 16px;" onclick="executeAppConfirm()">Confirm</button>
            </div>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: REJECT / SUSPEND CREATOR -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="rejectCreatorModal">
        <div class="modal-card confirm-dialog-card">
            <div class="modal-head" style="border-bottom-color:#fecaca; background:#fef2f2;">
                <h3 id="rejectCreatorTitle" style="color:var(--danger); display:flex; align-items:center; gap:8px;">
                    <div class="confirm-icon-badge danger" style="width:32px; height:32px; font-size:18px;">
                        <i class="ph ph-user-minus"></i>
                    </div>
                    Reject Creator Application
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('rejectCreatorModal')">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="admin_approve_creator">
                <input type="hidden" name="creator_id" id="reject_creator_id" value="">
                <input type="hidden" name="approval_action" id="reject_approval_action" value="reject">

                <div class="modal-body">
                    <div style="margin-bottom: 12px; padding: 10px 14px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border);">
                        <span style="font-size: 0.75rem; color: var(--text-muted); display: block;">Creator Name:</span>
                        <strong id="rejectCreatorName" style="color: var(--text-primary); font-size: 0.95rem;"></strong>
                    </div>
                    <div class="form-row">
                        <label for="reject_reason">Reason for Rejection / Suspension *</label>
                        <textarea name="reason" id="reject_reason" class="form-input" rows="3" placeholder="Please state the reason (e.g., Ineligible agricultural niche, duplicate identity, policy violation)..." required></textarea>
                    </div>
                    <p style="font-size: 0.75rem; color: var(--text-muted); margin-top: 4px;">
                        This decision will be immutably recorded in the system audit log.
                    </p>
                </div>
                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('rejectCreatorModal')">Cancel</button>
                    <button type="submit" class="btn btn-danger" id="rejectCreatorSubmitBtn">Confirm Rejection</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: ADD PERFORMANCE BONUS -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="bonusModal">
        <div class="modal-card confirm-dialog-card">
            <div class="modal-head" style="border-bottom-color:#bae6fd; background:#f0f9ff;">
                <h3 style="color:#0284c7; display:flex; align-items:center; gap:8px;">
                    <div class="confirm-icon-badge primary" style="width:32px; height:32px; font-size:18px;">
                        <i class="ph ph-gift"></i>
                    </div>
                    Add Performance Bonus
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('bonusModal')">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="add_payout_bonus">
                <input type="hidden" name="payout_id" id="bonus_payout_id" value="">
                <input type="hidden" name="month" id="bonus_month" value="">

                <div class="modal-body">
                    <div style="margin-bottom: 14px; padding: 10px 14px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border);">
                        <span style="font-size: 0.75rem; color: var(--text-muted); display: block;">Creator:</span>
                        <strong id="bonusCreatorName" style="color: var(--text-primary); font-size: 0.95rem;"></strong>
                    </div>
                    <div class="form-row">
                        <label for="bonus_amount">Bonus Amount (₹) *</label>
                        <input type="number" step="0.01" min="1" name="amount" id="bonus_amount" class="form-input" placeholder="e.g. 100" required>
                    </div>
                    <div class="form-row">
                        <label for="bonus_explanation">Explanation / Milestone *</label>
                        <input type="text" name="explanation" id="bonus_explanation" class="form-input" placeholder="e.g. Exceptional reel engagement, High quality crop advisory" required>
                    </div>
                </div>
                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('bonusModal')">Cancel</button>
                    <button type="submit" class="btn btn-primary">Add Bonus</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: RECORD PAYOUT DISBURSEMENT (MARK PAID) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="markPaidModal">
        <div class="modal-card confirm-dialog-card">
            <div class="modal-head" style="border-bottom-color:#bbf7d0; background:#f0fdf4;">
                <h3 style="color:#16a34a; display:flex; align-items:center; gap:8px;">
                    <div class="confirm-icon-badge success" style="width:32px; height:32px; font-size:18px;">
                        <i class="ph ph-check-circle"></i>
                    </div>
                    Record Payout Disbursement
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('markPaidModal')">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="mark_payout_paid">
                <input type="hidden" name="payout_id" id="paid_payout_id" value="">
                <input type="hidden" name="month" id="paid_month" value="">

                <div class="modal-body">
                    <div style="margin-bottom: 14px; padding: 12px 14px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border);">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                            <span style="font-size: 0.75rem; color: var(--text-muted);">Creator</span>
                            <strong id="paidCreatorName" style="color: var(--text-primary); font-size: 0.9rem;"></strong>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                            <span style="font-size: 0.75rem; color: var(--text-muted);">Disbursement Amount</span>
                            <strong id="paidAmount" style="color: #15803d; font-size: 1.1rem; font-weight: 800;"></strong>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <span style="font-size: 0.75rem; color: var(--text-muted);">Creator UPI ID</span>
                            <code id="paidUpiId" style="font-size: 0.8rem; background: #e2e8f0; padding: 2px 6px; border-radius: 4px; color: #1e293b;"></code>
                        </div>
                    </div>
                    <div class="form-row">
                        <label for="paid_ref">Bank UTR / Transaction Reference *</label>
                        <input type="text" name="payment_reference" id="paid_ref" class="form-input" placeholder="e.g. UTR1234567890 or IMPS987654" required>
                    </div>
                    <p style="font-size: 0.75rem; color: var(--text-muted); margin-top: 4px;">
                        Entering the UTR marks this creator payout as Settled and records the timestamp.
                    </p>
                </div>
                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('markPaidModal')">Cancel</button>
                    <button type="submit" class="btn btn-primary" style="background: #15803d; border-color: #15803d;">Mark as Paid</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: REEL MODERATION / REVIEW -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="reelModerationModal">
        <div class="modal-card confirm-dialog-card" style="max-width: 540px;">
            <div class="modal-head" style="background: #f8fafc; border-bottom: 1px solid var(--border);">
                <h3 id="modReelTitle" style="display: flex; align-items: center; gap: 8px; font-size: 1.05rem;">
                    <div class="confirm-icon-badge primary" style="width:32px; height:32px; font-size:18px;">
                        <i class="ph ph-shield-check"></i>
                    </div>
                    Reel Moderation Review
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('reelModerationModal')">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="admin_review_reel">
                <input type="hidden" name="reel_id" id="mod_reel_id" value="">

                <div class="modal-body">
                    <div id="modReelSlaNotice" style="display: none; padding: 10px 14px; background: #ede9fe; border: 1px solid #ddd6fe; border-radius: 8px; color: #6d28d9; font-size: 0.8rem; margin-bottom: 14px; line-height: 1.4;">
                    </div>

                    <div style="margin-bottom: 14px; padding: 12px 14px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border);">
                        <div style="font-size: 0.75rem; color: var(--text-muted); margin-bottom: 4px;">Creator: <strong id="modReelCreator" style="color: var(--text-primary);"></strong></div>
                        <div style="font-size: 0.84rem; color: var(--text-secondary); font-style: italic; line-height: 1.3;" id="modReelCaption"></div>
                    </div>

                    <div class="form-row">
                        <label style="font-weight: 600;">Moderation Decision *</label>
                        <div style="display: flex; gap: 14px; margin-top: 8px;">
                            <label style="display: flex; align-items: center; gap: 6px; font-size: 0.84rem; cursor: pointer;">
                                <input type="radio" name="decision" value="approved" id="decisionApprove" checked onchange="toggleReasonCodeRequired(this.value)">
                                <span style="font-weight: 700; color: #15803d;">Approve & Publish</span>
                            </label>
                            <label style="display: flex; align-items: center; gap: 6px; font-size: 0.84rem; cursor: pointer;">
                                <input type="radio" name="decision" value="changes_requested" id="decisionChanges" onchange="toggleReasonCodeRequired(this.value)">
                                <span style="font-weight: 700; color: #d97706;">Request Changes</span>
                            </label>
                            <label style="display: flex; align-items: center; gap: 6px; font-size: 0.84rem; cursor: pointer;">
                                <input type="radio" name="decision" value="rejected" id="decisionReject" onchange="toggleReasonCodeRequired(this.value)">
                                <span style="font-weight: 700; color: #dc2626;">Reject</span>
                            </label>
                        </div>
                    </div>

                    <div class="form-row" id="reasonCodeRow">
                        <label for="mod_reason_code" style="font-weight: 600;">Review Reason Code *</label>
                        <select name="reason_code" id="mod_reason_code" class="form-input">
                            <option value="manual_approval">Manual Approval (Verified Agricultural Content)</option>
                            <option value="duplicate_content">Duplicate Content / Source URL</option>
                            <option value="copyright_infringement">Copyright Infringement / Not Original</option>
                            <option value="misleading_agri_info">Misleading / Inaccurate Agricultural Advice</option>
                            <option value="low_quality_video">Low Quality Video / Distorted Audio</option>
                            <option value="community_policy_violation">Community Policy / Guideline Violation</option>
                            <option value="other">Other / General Reason</option>
                        </select>
                    </div>

                    <div class="form-row">
                        <label for="mod_comments" style="font-weight: 600;">Moderator Feedback / Notes</label>
                        <textarea name="comments" id="mod_comments" class="form-input" rows="3" placeholder="Provide actionable feedback or instructions for the creator..."></textarea>
                        <p style="font-size: 0.72rem; color: var(--text-muted); margin-top: 4px;">
                            This feedback will be visible to the creator in the mobile app when changes are requested or rejected.
                        </p>
                    </div>
                </div>
                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('reelModerationModal')">Cancel</button>
                    <button type="submit" class="btn btn-primary" id="modSubmitBtn" style="background: #15803d; border-color: #15803d;">Approve & Publish Reel</button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: REEL PLAYER PREVIEW -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="reelPlayerModal" onclick="if(event.target===this) closeReelPlayer();">
        <div style="position: relative;">
            <button onclick="closeReelPlayer()" style="position:absolute; right:-32px; top:-8px; background:none; border:none; color:#fff; font-size:24px; cursor:pointer;">&times;</button>
            <div class="reel-mockup">
                <video id="playerReelVideo" src="" autoplay loop playsinline controls></video>
                <div class="reel-info-overlay">
                    <div id="playerReelAuthor" style="font-weight: 700;"></div>
                    <div id="playerReelCaption"></div>
                </div>
            </div>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: ARTICLE PREVIEW -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="articlePreviewModal">
        <div class="modal-card">
            <div class="modal-head">
                <h3 id="prevTitle">Article Preview</h3>
                <button type="button" class="close-btn" onclick="closeModal('articlePreviewModal')">&times;</button>
            </div>
            <div class="modal-body">
                <img id="prevImg" src="" style="width:100%; max-height:220px; object-fit:cover; border-radius:4px; margin-bottom:12px;">
                <div style="font-size: 0.76rem; color: var(--text-muted); margin-bottom: 6px;">
                    <span id="prevCat" style="background:var(--surface-subtle); padding:2px 6px; border-radius:3px; border:1px solid var(--border);"></span>
                    &bull; By <strong id="prevAuthor"></strong>
                </div>
                <h2 id="prevHeadline" style="font-size:1.1rem; line-height:1.35; margin-bottom:8px;"></h2>
                <p id="prevSummary" style="font-size:0.86rem; color:var(--text-secondary); margin-bottom:12px; font-weight:500;"></p>
                <div id="prevContent" style="font-size:0.84rem; color:var(--text-secondary); line-height:1.6; white-space:pre-wrap;"></div>
            </div>
            <div class="modal-foot">
                <button type="button" class="btn btn-secondary" onclick="closeModal('articlePreviewModal')">Close</button>
            </div>
        </div>
    </div>

    <!-- JAVASCRIPT LOGIC -->
    <script>
        function closeModal(id) {
            const el = document.getElementById(id);
            if (el) el.classList.remove('open');
        }

        function openModal(id) {
            const el = document.getElementById(id);
            if (el) el.classList.add('open');
        }

        function applySearch(tab, query) {
            location.href = '?tab=' + encodeURIComponent(tab) + '&q=' + encodeURIComponent(query);
        }

        // --- News Modals ---
        function openNewsModal() {
            document.getElementById('news_id').value = '0';
            document.getElementById('newsModalTitle').innerText = 'New Krishi Article';
            document.getElementById('newsSubmitBtn').innerText = 'Publish Article';
            document.getElementById('news_title').value = '';
            document.getElementById('news_summary').value = '';
            document.getElementById('news_content').value = '';
            document.getElementById('news_title_te').value = '';
            document.getElementById('news_summary_te').value = '';
            document.getElementById('news_content_te').value = '';
            document.getElementById('news_title_hi').value = '';
            document.getElementById('news_summary_hi').value = '';
            document.getElementById('news_content_hi').value = '';
            document.getElementById('news_author').value = 'CropSync Desk';
            document.getElementById('news_source_name').value = 'Krishi Jagran';
            document.getElementById('news_image_url').value = '';
            document.getElementById('news_is_featured').checked = false;

            // Sync Alpine state if initialized
            const modalEl = document.getElementById('newsModal');
            if (modalEl && modalEl.__x) {
                modalEl.__x.$data.category = 'Govt Schemes';
                modalEl.__x.$data.status = 'published';
                modalEl.__x.$data.langTab = 'en';
                modalEl.__x.$data.targetLang = 'all';
                modalEl.__x.$data.imageUrl = '';
                modalEl.__x.$data.statusText = '';
            }

            openModal('newsModal');
        }

        function editNews(art) {
            document.getElementById('news_id').value = art.id;
            document.getElementById('newsModalTitle').innerText = 'Edit Article #' + art.id;
            document.getElementById('newsSubmitBtn').innerText = 'Save Changes';
            document.getElementById('news_title').value = art.title || '';
            document.getElementById('news_summary').value = art.summary || '';
            document.getElementById('news_content').value = art.content || '';
            document.getElementById('news_title_te').value = art.title_te || '';
            document.getElementById('news_summary_te').value = art.summary_te || '';
            document.getElementById('news_content_te').value = art.content_te || '';
            document.getElementById('news_title_hi').value = art.title_hi || '';
            document.getElementById('news_summary_hi').value = art.summary_hi || '';
            document.getElementById('news_content_hi').value = art.content_hi || '';
            document.getElementById('news_author').value = art.author || 'CropSync Desk';
            document.getElementById('news_source_name').value = art.source_name || '';
            document.getElementById('news_image_url').value = art.image_url || '';
            document.getElementById('news_is_featured').checked = !!parseInt(art.is_featured);

            const modalEl = document.getElementById('newsModal');
            if (modalEl && modalEl.__x) {
                modalEl.__x.$data.category = art.category || 'Govt Schemes';
                modalEl.__x.$data.status = art.status || 'published';
                modalEl.__x.$data.langTab = 'en';
                modalEl.__x.$data.targetLang = art.language || 'all';
                modalEl.__x.$data.imageUrl = art.image_url || '';
                modalEl.__x.$data.statusText = '';
            }

            openModal('newsModal');
        }

        function previewArticle(art) {
            document.getElementById('prevTitle').innerText = 'Article #' + art.id;
            document.getElementById('prevHeadline').innerText = art.title || '';
            document.getElementById('prevCat').innerText = art.category || '';
            document.getElementById('prevAuthor').innerText = art.author || 'CropSync';
            document.getElementById('prevSummary').innerText = art.summary || '';
            document.getElementById('prevContent').innerText = art.content || '';
            document.getElementById('prevImg').src = art.image_url || 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=600&q=80';
            openModal('articlePreviewModal');
        }

        // --- Reel Modals ---
        function openReelModal() {
            document.getElementById('reel_id').value = '0';
            document.getElementById('reelModalTitle').innerText = 'Upload Agri Reel';
            document.getElementById('reelSubmitBtn').innerText = 'Publish Reel';
            document.getElementById('reel_caption').value = '';
            document.getElementById('reel_creator_name').value = 'CropSync Creator';
            document.getElementById('reel_phone_number').value = '9182867655';
            document.getElementById('reel_music_title').value = 'Original Audio';
            document.getElementById('reel_tags').value = '#Paddy #AgriTips';
            document.getElementById('reel_video_url').value = '';

            const modalEl = document.getElementById('reelModal');
            if (modalEl && modalEl.__x) {
                modalEl.__x.$data.isActive = 1;
                modalEl.__x.$data.videoUrl = '';
                modalEl.__x.$data.statusText = '';
            }

            openModal('reelModal');
        }

        function editReel(rel) {
            document.getElementById('reel_id').value = rel.id;
            document.getElementById('reelModalTitle').innerText = 'Edit Reel #' + rel.id;
            document.getElementById('reelSubmitBtn').innerText = 'Update Reel';
            document.getElementById('reel_caption').value = rel.caption || '';
            document.getElementById('reel_creator_name').value = rel.creator_name || 'CropSync Creator';
            document.getElementById('reel_phone_number').value = rel.phone_number || '';
            document.getElementById('reel_music_title').value = rel.music_title || 'Original Audio';
            document.getElementById('reel_tags').value = rel.tags || '';
            document.getElementById('reel_video_url').value = rel.video_url || '';

            const modalEl = document.getElementById('reelModal');
            if (modalEl && modalEl.__x) {
                modalEl.__x.$data.isActive = parseInt(rel.is_active) === 1 ? 1 : 0;
                modalEl.__x.$data.videoUrl = rel.video_url || '';
                modalEl.__x.$data.statusText = '';
            }

            openModal('reelModal');
        }

        function previewReelVideo(url, caption, author) {
            const player = document.getElementById('playerReelVideo');
            player.src = url;
            document.getElementById('playerReelCaption').innerText = caption;
            document.getElementById('playerReelAuthor').innerText = '@' + author;
            openModal('reelPlayerModal');
            player.play().catch(() => {});
        }

        function closeReelPlayer() {
            const player = document.getElementById('playerReelVideo');
            player.pause();
            player.src = '';
            closeModal('reelPlayerModal');
        }

        // --- Single Item Delete Modal ---
        function promptDelete(type, id, title) {
            document.getElementById('deleteItemTitle').innerText = (type === 'news' ? 'Article: ' : 'Reel: ') + title;
            document.getElementById('del_comment_id').value = '';
            document.getElementById('del_comment_type').value = '';
            document.getElementById('del_parent_id').value = '';

            if (type === 'news') {
                document.getElementById('del_action').value = 'delete_news';
                document.getElementById('del_news_id').value = id;
                document.getElementById('del_reel_id').value = '';
            } else if (type === 'reel') {
                document.getElementById('del_action').value = 'delete_reel';
                document.getElementById('del_reel_id').value = id;
                document.getElementById('del_news_id').value = '';
            }
            openModal('deleteConfirmModal');
        }

        function promptCommentDelete(type, commentId, parentId) {
            document.getElementById('deleteItemTitle').innerText = 'Comment #' + commentId + ' on ' + type + ' #' + parentId;
            document.getElementById('del_action').value = 'delete_comment';
            document.getElementById('del_comment_id').value = commentId;
            document.getElementById('del_comment_type').value = type;
            document.getElementById('del_parent_id').value = parentId;
            document.getElementById('del_news_id').value = '';
            document.getElementById('del_reel_id').value = '';
            openModal('deleteConfirmModal');
        }

        // --- Bulk Selection ---
        function toggleSelectAll(master, childClass, barId, countId) {
            const checkboxes = document.querySelectorAll('.' + childClass);
            checkboxes.forEach(cb => cb.checked = master.checked);
            updateBulkBar(childClass, barId, countId);
        }

        function updateBulkBar(childClass, barId, countId) {
            const checked = document.querySelectorAll('.' + childClass + ':checked');
            const bar = document.getElementById(barId);
            const countLabel = document.getElementById(countId);
            if (checked.length > 0) {
                bar.classList.add('active');
                countLabel.innerText = checked.length + ' selected';
            } else {
                bar.classList.remove('active');
            }
        }

        function clearSelection(childClass, barId, masterId) {
            document.querySelectorAll('.' + childClass).forEach(cb => cb.checked = false);
            const master = document.getElementById(masterId);
            if (master) master.checked = false;
            document.getElementById(barId).classList.remove('active');
        }

        // --- App Universal Confirmation & Action Modals (Zero Browser Popups) ---
        let confirmCallback = null;

        function showAppConfirm(opts) {
            document.getElementById('appConfirmTitle').innerText = opts.title || 'Confirm Action';
            document.getElementById('appConfirmMessage').innerText = opts.message || 'Are you sure you want to proceed?';
            
            const subtextEl = document.getElementById('appConfirmSubtext');
            if (opts.subtext) {
                subtextEl.innerText = opts.subtext;
                subtextEl.style.display = 'block';
            } else {
                subtextEl.style.display = 'none';
            }

            const iconBadge = document.getElementById('appConfirmIconBubble');
            iconBadge.className = 'confirm-icon-bubble ' + (opts.iconColor ? 'confirm-' + opts.iconColor : 'confirm-warning');
            
            const iconEl = document.getElementById('appConfirmIcon');
            iconEl.className = 'ph ' + (opts.icon || 'ph-warning-circle');

            const confirmBtn = document.getElementById('appConfirmBtn');
            confirmBtn.className = 'btn ' + (opts.confirmClass || 'btn-primary');
            if (opts.confirmStyle) {
                confirmBtn.setAttribute('style', opts.confirmStyle);
            } else {
                confirmBtn.removeAttribute('style');
                confirmBtn.style.flex = '1';
                confirmBtn.style.padding = '9px 16px';
            }
            confirmBtn.innerText = opts.confirmText || 'Confirm';

            confirmCallback = opts.onConfirm || null;
            openModal('appConfirmModal');
        }

        function executeAppConfirm() {
            closeModal('appConfirmModal');
            if (typeof confirmCallback === 'function') {
                confirmCallback();
            }
        }

        function promptLockBatch() {
            showAppConfirm({
                title: 'Lock Payout Batch',
                message: 'Lock the payout batch for <?= htmlspecialchars($payoutMonth) ?> for finance review?',
                subtext: 'Once locked, base payouts and calculations are frozen pending Finance Admin approval.',
                icon: 'ph-lock',
                iconColor: 'warning',
                confirmText: 'Yes, Lock Batch',
                confirmClass: 'btn-secondary',
                onConfirm: () => {
                    document.getElementById('lockBatchForm').submit();
                }
            });
        }

        function promptApproveBatch() {
            showAppConfirm({
                title: 'Finance Batch Approval',
                message: 'Approve this monthly payout batch as Finance Admin?',
                subtext: 'Authorizes payouts for all eligible creators in this batch for disbursement.',
                icon: 'ph-check-circle',
                iconColor: 'success',
                confirmText: 'Approve Batch',
                confirmClass: 'btn-primary',
                confirmStyle: 'flex: 1; padding: 9px 16px; background: #15803d; border-color: #15803d; color: white;',
                onConfirm: () => {
                    document.getElementById('approveBatchForm').submit();
                }
            });
        }

        function openRejectCreatorModal(creatorId, creatorName, isSuspend) {
            document.getElementById('reject_creator_id').value = creatorId;
            document.getElementById('reject_approval_action').value = isSuspend ? 'suspend' : 'reject';
            document.getElementById('rejectCreatorTitle').innerHTML = '<div class="confirm-icon-badge danger" style="width:32px; height:32px; font-size:18px;"><i class="ph ph-user-minus"></i></div>' + (isSuspend ? 'Suspend Active Creator' : 'Reject Creator Application');
            document.getElementById('rejectCreatorSubmitBtn').innerText = isSuspend ? 'Confirm Suspension' : 'Confirm Rejection';
            document.getElementById('rejectCreatorName').innerText = creatorName;
            document.getElementById('reject_reason').value = '';
            openModal('rejectCreatorModal');
        }

        function openAddBonusModal(payoutId, creatorName, month) {
            document.getElementById('bonus_payout_id').value = payoutId;
            document.getElementById('bonus_month').value = month;
            document.getElementById('bonusCreatorName').innerText = creatorName + ' (' + month + ')';
            document.getElementById('bonus_amount').value = '';
            document.getElementById('bonus_explanation').value = '';
            openModal('bonusModal');
        }

        function openMarkPaidModal(payoutId, creatorName, upiId, grossAmount, month) {
            document.getElementById('paid_payout_id').value = payoutId;
            document.getElementById('paid_month').value = month;
            document.getElementById('paidCreatorName').innerText = creatorName;
            document.getElementById('paidAmount').innerText = '₹' + parseFloat(grossAmount).toFixed(2);
            document.getElementById('paidUpiId').innerText = upiId ? upiId : 'Not Provided';
            document.getElementById('paid_ref').value = '';
            openModal('markPaidModal');
        }

        function confirmBulkDelete(formId, itemLabel) {
            showAppConfirm({
                title: 'Confirm Bulk Deletion',
                message: 'Are you sure you want to permanently delete all ' + itemLabel + '?',
                subtext: 'This operation cannot be reversed. Selected records will be permanently removed.',
                icon: 'ph-trash',
                iconColor: 'danger',
                confirmText: 'Yes, Delete All',
                confirmClass: 'btn-danger',
                confirmStyle: 'flex: 1; padding: 9px 16px; background: #dc2626; border-color: #dc2626; color: white;',
                onConfirm: () => {
                    document.getElementById(formId).submit();
                }
            });
        }

        // --- Reel Moderation SLA & Review Helpers ---
        function toggleReasonCodeRequired(decision) {
            const submitBtn = document.getElementById('modSubmitBtn');
            const reasonSelect = document.getElementById('mod_reason_code');
            if (decision === 'approved') {
                submitBtn.style.background = '#15803d';
                submitBtn.style.borderColor = '#15803d';
                submitBtn.innerText = 'Approve & Publish Reel';
                if (!reasonSelect.value || reasonSelect.value !== 'manual_approval') {
                    reasonSelect.value = 'manual_approval';
                }
            } else if (decision === 'changes_requested') {
                submitBtn.style.background = '#d97706';
                submitBtn.style.borderColor = '#d97706';
                submitBtn.innerText = 'Send Change Request';
            } else {
                submitBtn.style.background = '#dc2626';
                submitBtn.style.borderColor = '#dc2626';
                submitBtn.innerText = 'Confirm Rejection';
            }
        }

        function quickApproveReel(reelId, caption) {
            showAppConfirm({
                title: 'Approve Agri Reel #' + reelId,
                message: 'Approve "' + caption + '" and make it publicly visible to users?',
                subtext: 'This will set the reel status to Approved, mark it as active, and make it eligible for creator payouts.',
                icon: 'ph-check-circle',
                iconColor: 'success',
                confirmText: 'Approve & Publish',
                confirmClass: 'btn-primary',
                confirmStyle: 'flex: 1; padding: 9px 16px; background: #15803d; border-color: #15803d; color: white;',
                onConfirm: () => {
                    const form = document.createElement('form');
                    form.method = 'POST';
                    form.innerHTML = `
                        <input type="hidden" name="action" value="admin_review_reel">
                        <input type="hidden" name="reel_id" value="${reelId}">
                        <input type="hidden" name="decision" value="approved">
                        <input type="hidden" name="reason_code" value="manual_approval">
                        <input type="hidden" name="comments" value="Manual approval by moderator from dashboard.">
                    `;
                    document.body.appendChild(form);
                    form.submit();
                }
            });
        }

        function openReelModerationModal(reel) {
            document.getElementById('mod_reel_id').value = reel.id;
            document.getElementById('modReelTitle').innerHTML = '<div class="confirm-icon-badge primary" style="width:32px; height:32px; font-size:18px;"><i class="ph ph-shield-check"></i></div> Moderation Review: Reel #' + reel.id;
            document.getElementById('modReelCaption').innerText = reel.caption || '(No caption provided)';
            document.getElementById('modReelCreator').innerText = reel.creator || 'CropSync Creator';
            
            const slaNotice = document.getElementById('modReelSlaNotice');
            if (reel.is_night) {
                slaNotice.style.display = 'block';
                slaNotice.innerHTML = '<i class="ph ph-moon"></i> <strong>Night Upload:</strong> Uploaded between 9:00 PM and 6:00 AM IST. Auto-approval is permanently disabled for night submissions; manual verification is required before going live.';
            } else {
                slaNotice.style.display = 'none';
            }

            const decisionRadios = document.getElementsByName('decision');
            let matchedDecision = 'approved';
            if (reel.status === 'changes_requested') {
                matchedDecision = 'changes_requested';
            } else if (reel.status === 'rejected') {
                matchedDecision = 'rejected';
            }
            for (let r of decisionRadios) {
                r.checked = (r.value === matchedDecision);
            }

            toggleReasonCodeRequired(matchedDecision);
            if (reel.reason_code) {
                document.getElementById('mod_reason_code').value = reel.reason_code;
            }
            document.getElementById('mod_comments').value = reel.feedback || '';
            
            openModal('reelModerationModal');
        }
    </script>
</body>
</html>
