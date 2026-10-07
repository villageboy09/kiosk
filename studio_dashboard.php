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
            'user_id' => "ALTER TABLE `creators` ADD COLUMN `user_id` INT NULL",
            'email' => "ALTER TABLE `creators` ADD COLUMN `email` VARCHAR(150) NULL",
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

        // Shop Banners Table (Agri Shop home carousel)
        $pdo->exec("CREATE TABLE IF NOT EXISTS `shop_banners` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `tag_en` VARCHAR(40) NULL,
            `tag_hi` VARCHAR(40) NULL,
            `tag_te` VARCHAR(40) NULL,
            `title_en` VARCHAR(120) NOT NULL,
            `title_hi` VARCHAR(120) NULL,
            `title_te` VARCHAR(120) NULL,
            `subtitle_en` VARCHAR(200) NULL,
            `subtitle_hi` VARCHAR(200) NULL,
            `subtitle_te` VARCHAR(200) NULL,
            `cta_text_en` VARCHAR(40) NULL,
            `cta_text_hi` VARCHAR(40) NULL,
            `cta_text_te` VARCHAR(40) NULL,
            `badge_en` VARCHAR(30) NULL,
            `badge_hi` VARCHAR(30) NULL,
            `badge_te` VARCHAR(30) NULL,
            `target_type` ENUM('none','product','category','url') NOT NULL DEFAULT 'none',
            `target_value` VARCHAR(500) NULL,
            `bg_color_1` CHAR(7) DEFAULT '#064E3B',
            `bg_color_2` CHAR(7) DEFAULT '#047857',
            `icon_key` VARCHAR(40) NULL,
            `image_url` VARCHAR(500) NULL,
            `is_active` TINYINT(1) NOT NULL DEFAULT 1,
            `sort_order` INT NOT NULL DEFAULT 0,
            `start_at` DATETIME NULL,
            `end_at` DATETIME NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_active_sort` (`is_active`, `sort_order`)
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

// ---- Shop Banner helpers -------------------------------------------------
const SHOP_BANNER_W = 1250;
const SHOP_BANNER_H = 500;
const SHOP_BANNER_MAX_BYTES = 1572864; // 1.5 MB
const SHOP_BANNER_ICONS = ['eco', 'verified', 'local_shipping', 'bolt', 'star', 'agriculture', 'shield', 'percent'];

function shopBannerDir() {
    return __DIR__ . '/shop_banners/';
}

function shopBannerPublicBase() {
    $base = defined('CDN_URL') ? rtrim((string)CDN_URL, '/') : 'https://kiosk.cropsync.in';
    if (stripos($base, 'https://') !== 0) {
        $base = 'https://kiosk.cropsync.in';
    }
    return $base . '/shop_banners/';
}

/**
 * Delete a previously stored banner image. Only files directly inside /shop_banners/
 * with a generated filename are ever removed (no path traversal possible).
 */
function shopBannerDeleteFile($url) {
    $url = trim((string)$url);
    if ($url === '') return;
    $path = parse_url($url, PHP_URL_PATH);
    if (!is_string($path) || strpos($path, '/shop_banners/') === false) return;
    $name = basename($path);
    if (!preg_match('/^[A-Za-z0-9_-]{8,64}\.(jpg|png|webp)$/', $name)) return;
    $dir = realpath(shopBannerDir());
    if ($dir === false) return;
    $full = realpath($dir . DIRECTORY_SEPARATOR . $name);
    if ($full === false || dirname($full) !== $dir || !is_file($full)) return;
    @unlink($full);
}

/**
 * Validate + store an uploaded banner image from a local file path.
 * Returns ['url' => string|null, 'error' => string|null].
 */
/** memory_limit in bytes; 0 when unlimited (-1) or unreadable. */
function shopBannerMemoryLimitBytes() {
    $raw = trim((string)ini_get('memory_limit'));
    if ($raw === '' || $raw === '-1') return 0;
    $num = (float)$raw;
    $unit = strtolower(substr($raw, -1));
    if ($unit === 'g') $num *= 1073741824;
    elseif ($unit === 'm') $num *= 1048576;
    elseif ($unit === 'k') $num *= 1024;
    return $num > 0 ? (int)$num : 0;
}

function shopBannerStoreImage($tmpPath, $size) {
    if ($size <= 0 || $size > SHOP_BANNER_MAX_BYTES) {
        return ['url' => null, 'error' => 'Banner image must be 1.5 MB or smaller.'];
    }
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($tmpPath);
    $allowed = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    if (!isset($allowed[$mime])) {
        return ['url' => null, 'error' => 'Banner image must be a JPEG, PNG or WEBP file.'];
    }
    $info = @getimagesize($tmpPath);
    if (!$info || $info[0] < 1 || $info[1] < 1) {
        return ['url' => null, 'error' => 'Could not read the uploaded image.'];
    }
    $w = (int)$info[0];
    $h = (int)$info[1];
    if (abs(($w / $h) - 2.5) > 2.5 * 0.02) { // must be within 2% of 5:2
        return ['url' => null, 'error' => "Banner image must have a 5:2 ratio (1250x500 px). Uploaded image is {$w}x{$h}."];
    }

    $dir = shopBannerDir();
    if (!is_dir($dir)) @mkdir($dir, 0755, true);
    if (!is_dir($dir) || !is_writable($dir)) {
        return ['url' => null, 'error' => 'Server cannot write to the /shop_banners/ directory.'];
    }
    $rand = bin2hex(random_bytes(12));

    if (function_exists('imagecreatetruecolor')) {
        if ($w * $h > 16000000) {
            return ['url' => null, 'error' => "Image dimensions are too large ({$w}x{$h}). Please upload an image under 16 megapixels."];
        }
        $memLimit = shopBannerMemoryLimitBytes();
        if ($memLimit > 0 && (5 * $w * $h + memory_get_usage(true)) >= $memLimit) {
            return ['url' => null, 'error' => "Image ({$w}x{$h}) is too large for the server's memory limit. Please upload a smaller image (1250x500 px recommended)."];
        }
        $src = null;
        if ($mime === 'image/jpeg' && function_exists('imagecreatefromjpeg')) $src = @imagecreatefromjpeg($tmpPath);
        elseif ($mime === 'image/png' && function_exists('imagecreatefrompng')) $src = @imagecreatefrompng($tmpPath);
        elseif ($mime === 'image/webp' && function_exists('imagecreatefromwebp')) $src = @imagecreatefromwebp($tmpPath);
        if (!$src) {
            return ['url' => null, 'error' => 'Server could not decode this image format. Please upload a JPEG.'];
        }
        // Apply EXIF orientation (JPEG only) so phone photos are cropped the right way up
        if ($mime === 'image/jpeg' && function_exists('exif_read_data') && function_exists('imagerotate')) {
            $exif = @exif_read_data($tmpPath);
            $orient = (is_array($exif) && isset($exif['Orientation'])) ? (int)$exif['Orientation'] : 1;
            $angle = [3 => 180, 6 => -90, 8 => 90][$orient] ?? 0;
            if ($angle !== 0) {
                $rot = @imagerotate($src, $angle, 0);
                if ($rot) {
                    imagedestroy($src);
                    $src = $rot;
                    $w = imagesx($src);
                    $h = imagesy($src);
                }
            }
        }
        // Centre-crop to 5:2, then resample to exactly 1250x500
        $targetRatio = SHOP_BANNER_W / SHOP_BANNER_H;
        if (($w / $h) > $targetRatio) {
            $sh = $h;
            $sw = (int)round($h * $targetRatio);
        } else {
            $sw = $w;
            $sh = (int)round($w / $targetRatio);
        }
        $sx = (int)floor(($w - $sw) / 2);
        $sy = (int)floor(($h - $sh) / 2);
        $dst = imagecreatetruecolor(SHOP_BANNER_W, SHOP_BANNER_H);
        imagefill($dst, 0, 0, imagecolorallocate($dst, 255, 255, 255));
        imagecopyresampled($dst, $src, 0, 0, $sx, $sy, SHOP_BANNER_W, SHOP_BANNER_H, $sw, $sh);
        $fileName = 'banner_' . $rand . '.jpg';
        $ok = imagejpeg($dst, $dir . $fileName, 82);
        imagedestroy($src);
        imagedestroy($dst);
        if (!$ok) {
            return ['url' => null, 'error' => 'Failed to save the banner image.'];
        }
        return ['url' => shopBannerPublicBase() . $fileName, 'error' => null];
    }

    // No GD: only accept images that are already exactly 1250x500
    if ($w !== SHOP_BANNER_W || $h !== SHOP_BANNER_H) {
        return ['url' => null, 'error' => "The server cannot resize images (GD missing). Upload an image that is exactly 1250x500 px (got {$w}x{$h})."];
    }
    $fileName = 'banner_' . $rand . '.' . $allowed[$mime];
    $moved = is_uploaded_file($tmpPath) ? move_uploaded_file($tmpPath, $dir . $fileName) : rename($tmpPath, $dir . $fileName);
    if (!$moved) {
        return ['url' => null, 'error' => 'Failed to save the banner image.'];
    }
    return ['url' => shopBannerPublicBase() . $fileName, 'error' => null];
}

function shopBannerParseDate($raw) {
    $raw = trim((string)$raw);
    if ($raw === '') return [null, true];
    foreach (['Y-m-d\TH:i', 'Y-m-d\TH:i:s', 'Y-m-d H:i:s', 'Y-m-d H:i'] as $fmt) {
        $d = DateTime::createFromFormat($fmt, $raw);
        $errs = DateTime::getLastErrors();
        if ($d && (!$errs || ($errs['warning_count'] == 0 && $errs['error_count'] == 0))) {
            return [$d->format('Y-m-d H:i:s'), true];
        }
    }
    return [null, false];
}

/** Compute the display status of a banner row. */
function shopBannerStatus($b, $now) {
    if (empty($b['is_active'])) return 'Inactive';
    if (!empty($b['start_at']) && strtotime($now) < strtotime($b['start_at'])) return 'Scheduled';
    if (!empty($b['end_at']) && strtotime($now) > strtotime($b['end_at'])) return 'Expired';
    return 'Live';
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
// AJAX: Fetch Reel Comments (For Inline Reel Moderation Drawer)
// -------------------------------------------------------------
if (isset($_GET['ajax_get_reel_comments']) && isset($pdo) && $pdo instanceof PDO) {
    header('Content-Type: application/json');
    $reelId = intval($_GET['reel_id'] ?? 0);
    if ($reelId <= 0) {
        echo json_encode(['success' => false, 'error' => 'Invalid Reel ID']);
        exit();
    }
    try {
        $cStmt = $pdo->prepare("
            SELECT id, reel_id, farmer_username, phone_number, user_id, comment_text, created_at 
            FROM reel_comments 
            WHERE reel_id = ? 
            ORDER BY created_at DESC 
            LIMIT 150
        ");
        $cStmt->execute([$reelId]);
        $comments = $cStmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode(['success' => true, 'comments' => $comments]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit();
}

// -------------------------------------------------------------
// AJAX: Fetch Reel Watch & Audience Dropoff Analytics
// -------------------------------------------------------------
if (isset($_GET['ajax_get_reel_analytics']) && isset($pdo) && $pdo instanceof PDO) {
    header('Content-Type: application/json');
    $reelId = intval($_GET['reel_id'] ?? 0);
    if ($reelId <= 0) {
        echo json_encode(['success' => false, 'error' => 'Invalid Reel ID']);
        exit();
    }
    try {
        // 1. Reel metadata
        $rStmt = $pdo->prepare("
            SELECT r.*, c.display_name AS creator_name, c.username AS creator_username 
            FROM reels r 
            LEFT JOIN creators c ON r.creator_id = c.id 
            WHERE r.id = ?
        ");
        $rStmt->execute([$reelId]);
        $reel = $rStmt->fetch(PDO::FETCH_ASSOC);

        // 2. Watch metrics from reel_watch_analytics
        $wStmt = $pdo->prepare("
            SELECT 
                COUNT(*) AS total_watches,
                COUNT(DISTINCT COALESCE(NULLIF(phone_number, ''), NULLIF(farmer_username, ''), user_id)) AS unique_viewers,
                SUM(CASE WHEN is_completed = 1 THEN 1 ELSE 0 END) AS completed_watches,
                COALESCE(AVG(watch_duration_seconds), 0) AS avg_watch_seconds,
                COALESCE(SUM(watch_duration_seconds), 0) AS total_watch_seconds
            FROM reel_watch_analytics 
            WHERE reel_id = ?
        ");
        $wStmt->execute([$reelId]);
        $watchStats = $wStmt->fetch(PDO::FETCH_ASSOC) ?: [];

        // 3. User actions breakdown from reel_actions
        $aStmt = $pdo->prepare("
            SELECT action_type, COUNT(*) AS cnt 
            FROM reel_actions 
            WHERE reel_id = ? 
            GROUP BY action_type
        ");
        $aStmt->execute([$reelId]);
        $actionRows = $aStmt->fetchAll(PDO::FETCH_ASSOC);
        $actionMap = [];
        foreach ($actionRows as $ar) {
            $actionMap[$ar['action_type']] = intval($ar['cnt']);
        }

        // 4. Past review history from reel_reviews
        $revStmt = $pdo->prepare("
            SELECT * FROM reel_reviews 
            WHERE reel_id = ? 
            ORDER BY id DESC 
            LIMIT 10
        ");
        $revStmt->execute([$reelId]);
        $reviews = $revStmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode([
            'success' => true,
            'reel' => $reel,
            'watch_stats' => $watchStats,
            'actions' => $actionMap,
            'reviews' => $reviews
        ]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit();
}

// -------------------------------------------------------------
// AJAX: Live Sync Reel Statuses, Moderation State & Global Counters
// -------------------------------------------------------------
if (isset($_GET['ajax_reels_live_sync']) && isset($pdo) && $pdo instanceof PDO) {
    header('Content-Type: application/json');
    try {
        $rStmt = $pdo->query("
            SELECT r.id, r.is_active, r.status, r.payout_eligible, r.is_duplicate, 
                   r.views_count, r.likes_count, r.comments_count,
                   c.id AS creator_id, c.display_name AS creator_name, c.status AS creator_status
            FROM reels r
            LEFT JOIN creators c ON r.creator_id = c.id
            ORDER BY r.id DESC
            LIMIT 100
        ");
        $reels = $rStmt->fetchAll(PDO::FETCH_ASSOC);

        $totalAll = intval($pdo->query("SELECT COUNT(*) FROM reels")->fetchColumn() ?: 0);
        $totalActive = intval($pdo->query("SELECT COUNT(*) FROM reels WHERE is_active = 1")->fetchColumn() ?: 0);
        $totalSuspendedCreators = intval($pdo->query("
            SELECT COUNT(*) FROM reels r 
            INNER JOIN creators c ON r.creator_id = c.id 
            WHERE c.status = 'suspended'
        ")->fetchColumn() ?: 0);

        $pendingCnt = 0; $approvedCnt = 0; $changesCnt = 0; $rejectedCnt = 0;
        $chkRStatus = $pdo->query("SHOW COLUMNS FROM `reels` LIKE 'status'");
        if ($chkRStatus && $chkRStatus->fetch()) {
            $rmStats = $pdo->query("SELECT 
                SUM(CASE WHEN (r.status IN ('under_review', 'submitted') OR (r.is_active = 0 AND (r.status IS NULL OR r.status = ''))) AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as pending_cnt,
                SUM(CASE WHEN (r.status = 'approved' OR (r.is_active = 1 AND (r.status IS NULL OR r.status = 'approved'))) AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as approved_cnt,
                SUM(CASE WHEN r.status = 'changes_requested' AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as changes_cnt,
                SUM(CASE WHEN r.status = 'rejected' AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as rejected_cnt
            FROM reels r LEFT JOIN creators c ON r.creator_id = c.id")->fetch();
            if ($rmStats) {
                $pendingCnt = intval($rmStats['pending_cnt'] ?? 0);
                $approvedCnt = intval($rmStats['approved_cnt'] ?? 0);
                $changesCnt = intval($rmStats['changes_cnt'] ?? 0);
                $rejectedCnt = intval($rmStats['rejected_cnt'] ?? 0);
            }
        }

        echo json_encode([
            'success' => true,
            'timestamp' => time(),
            'counts' => [
                'total' => $totalAll,
                'pending' => $pendingCnt,
                'approved' => $approvedCnt,
                'changes_requested' => $changesCnt,
                'rejected' => $rejectedCnt,
                'suspended_creator_reels' => $totalSuspendedCreators
            ],
            'reels' => $reels
        ]);
    } catch (Throwable $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
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

    // D2. SHOP BANNERS: SAVE / EDIT
    if ($action === 'save_shop_banner') {
        $id = intval($_POST['banner_id'] ?? 0);
        $errors = [];
        $langs = ['en', 'hi', 'te'];
        $limits = ['tag' => 40, 'title' => 120, 'subtitle' => 200, 'cta_text' => 40, 'badge' => 30];
        $text = [];
        foreach ($limits as $field => $max) {
            foreach ($langs as $l) {
                $key = $field . '_' . $l;
                $val = trim((string)($_POST[$key] ?? ''));
                if (mb_strlen($val) > $max) {
                    $errors[] = strtoupper($l) . " " . str_replace('_', ' ', $field) . " must be at most $max characters.";
                }
                $text[$key] = $val;
            }
        }
        if ($text['title_en'] === '') $errors[] = 'English title is required.';

        $target_type = $_POST['target_type'] ?? 'none';
        if (!in_array($target_type, ['none', 'product', 'category', 'url'], true)) $target_type = 'none';
        $target_value = trim((string)($_POST['target_value'] ?? ''));
        if ($target_type === 'none') {
            $target_value = null;
        } elseif ($target_type === 'product') {
            if (!ctype_digit($target_value) || (int)$target_value < 1) {
                $errors[] = 'Product target needs a valid numeric product ID.';
            } else {
                $target_value = (string)(int)$target_value;
            }
        } elseif ($target_type === 'category') {
            if ($target_value === '' || mb_strlen($target_value) > 100) {
                $errors[] = 'Category target needs a category name (max 100 characters).';
            }
        } else { // url
            if (stripos($target_value, 'https://') !== 0 || !filter_var($target_value, FILTER_VALIDATE_URL) || strlen($target_value) > 500) {
                $errors[] = 'URL target must be a valid https:// link (max 500 characters).';
            }
        }

        $bg1 = strtoupper(trim((string)($_POST['bg_color_1'] ?? '#064E3B')));
        $bg2 = strtoupper(trim((string)($_POST['bg_color_2'] ?? '#047857')));
        if (!preg_match('/^#[0-9A-F]{6}$/', $bg1) || !preg_match('/^#[0-9A-F]{6}$/', $bg2)) {
            $errors[] = 'Colours must be in #RRGGBB format.';
        }

        $icon_key = trim((string)($_POST['icon_key'] ?? ''));
        if ($icon_key === '') {
            $icon_key = null;
        } elseif (!in_array($icon_key, SHOP_BANNER_ICONS, true)) {
            $errors[] = 'Unknown icon selected.';
        }

        [$start_at, $startOk] = shopBannerParseDate($_POST['start_at'] ?? '');
        [$end_at, $endOk] = shopBannerParseDate($_POST['end_at'] ?? '');
        if (!$startOk || !$endOk) {
            $errors[] = 'Invalid start/end date.';
        } elseif ($start_at && $end_at && strtotime($end_at) <= strtotime($start_at)) {
            $errors[] = 'End date must be after the start date.';
        }

        $is_active = isset($_POST['is_active']) ? 1 : 0;
        $sortRaw = trim((string)($_POST['sort_order'] ?? ''));
        $sort_order = null;
        if ($sortRaw !== '') {
            if (filter_var($sortRaw, FILTER_VALIDATE_INT) === false || abs((int)$sortRaw) > 100000) {
                $errors[] = 'Sort order must be a whole number.';
            } else {
                $sort_order = (int)$sortRaw;
            }
        }

        $oldImage = '';
        $existing = null;
        if ($id > 0) {
            $st = $pdo->prepare("SELECT * FROM shop_banners WHERE id = ?");
            $st->execute([$id]);
            $existing = $st->fetch();
            if (!$existing) {
                $errors[] = "Banner #$id was not found.";
            } else {
                $oldImage = (string)($existing['image_url'] ?? '');
            }
        }

        // Image intake (file upload from the cropper, or base64 fallback)
        $imgTmp = null;
        $imgSize = 0;
        $imgTmpIsTemp = false;
        if (empty($errors)) {
            if (isset($_FILES['image_file']) && $_FILES['image_file']['error'] === UPLOAD_ERR_OK) {
                $imgTmp = $_FILES['image_file']['tmp_name'];
                $imgSize = (int)$_FILES['image_file']['size'];
            } elseif (isset($_FILES['image_file']) && in_array($_FILES['image_file']['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
                $errors[] = 'Banner image must be 1.5 MB or smaller.';
            } elseif (!empty($_POST['image_data']) && preg_match('#^data:image/(jpeg|png|webp);base64,#', (string)$_POST['image_data'], $mm)) {
                $b64 = substr((string)$_POST['image_data'], strlen($mm[0]));
                if (strlen($b64) > SHOP_BANNER_MAX_BYTES * 1.4) {
                    $errors[] = 'Banner image must be 1.5 MB or smaller.';
                } else {
                    $bin = base64_decode($b64, true);
                    if ($bin === false) {
                        $errors[] = 'Invalid image data.';
                    } else {
                        $tmpName = tempnam(sys_get_temp_dir(), 'sbn');
                        if ($tmpName !== false && file_put_contents($tmpName, $bin) !== false) {
                            $imgTmp = $tmpName;
                            $imgSize = strlen($bin);
                            $imgTmpIsTemp = true;
                        } else {
                            $errors[] = 'Could not process image data.';
                        }
                    }
                }
            }
        }

        $newImageUrl = null;
        if (empty($errors) && $imgTmp !== null) {
            $res = shopBannerStoreImage($imgTmp, $imgSize);
            if ($res['error']) {
                $errors[] = $res['error'];
            } else {
                $newImageUrl = $res['url'];
            }
            if ($imgTmpIsTemp && is_file($imgTmp)) @unlink($imgTmp);
        }

        if (!empty($errors)) {
            setFlash(implode(' ', $errors), 'danger');
        } else {
            $image_url = $oldImage !== '' ? $oldImage : null;
            if ($newImageUrl !== null) {
                $image_url = $newImageUrl;
            } elseif (!empty($_POST['remove_image'])) {
                $image_url = null;
            }
            try {
                if ($sort_order === null) {
                    $sort_order = $id > 0 ? (int)$existing['sort_order'] : ((int)$pdo->query("SELECT COALESCE(MAX(sort_order), 0) FROM shop_banners")->fetchColumn() + 1);
                }
                $vals = [
                    $text['tag_en'] ?: null, $text['tag_hi'] ?: null, $text['tag_te'] ?: null,
                    $text['title_en'], $text['title_hi'] ?: null, $text['title_te'] ?: null,
                    $text['subtitle_en'] ?: null, $text['subtitle_hi'] ?: null, $text['subtitle_te'] ?: null,
                    $text['cta_text_en'] ?: null, $text['cta_text_hi'] ?: null, $text['cta_text_te'] ?: null,
                    $text['badge_en'] ?: null, $text['badge_hi'] ?: null, $text['badge_te'] ?: null,
                    $target_type, $target_value, $bg1, $bg2, $icon_key, $image_url,
                    $is_active, $sort_order, $start_at, $end_at
                ];
                if ($id > 0) {
                    $stmt = $pdo->prepare("UPDATE shop_banners SET tag_en = ?, tag_hi = ?, tag_te = ?, title_en = ?, title_hi = ?, title_te = ?, subtitle_en = ?, subtitle_hi = ?, subtitle_te = ?, cta_text_en = ?, cta_text_hi = ?, cta_text_te = ?, badge_en = ?, badge_hi = ?, badge_te = ?, target_type = ?, target_value = ?, bg_color_1 = ?, bg_color_2 = ?, icon_key = ?, image_url = ?, is_active = ?, sort_order = ?, start_at = ?, end_at = ? WHERE id = ?");
                    $stmt->execute(array_merge($vals, [$id]));
                    setFlash("Shop banner #$id updated successfully.");
                } else {
                    $stmt = $pdo->prepare("INSERT INTO shop_banners (tag_en, tag_hi, tag_te, title_en, title_hi, title_te, subtitle_en, subtitle_hi, subtitle_te, cta_text_en, cta_text_hi, cta_text_te, badge_en, badge_hi, badge_te, target_type, target_value, bg_color_1, bg_color_2, icon_key, image_url, is_active, sort_order, start_at, end_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
                    $stmt->execute($vals);
                    setFlash("New shop banner created.");
                }
                // Remove the replaced / cleared image file once the DB write succeeded
                if ($oldImage !== '' && $oldImage !== (string)$image_url) {
                    shopBannerDeleteFile($oldImage);
                }
            } catch (Throwable $e) {
                if ($newImageUrl !== null) shopBannerDeleteFile($newImageUrl);
                setFlash("Database error: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=shop_banners");
        exit();
    }

    // D3. SHOP BANNERS: DELETE
    if ($action === 'delete_shop_banner') {
        $id = intval($_POST['banner_id'] ?? 0);
        if ($id > 0) {
            try {
                $st = $pdo->prepare("SELECT image_url FROM shop_banners WHERE id = ?");
                $st->execute([$id]);
                $img = $st->fetchColumn();
                $pdo->prepare("DELETE FROM shop_banners WHERE id = ?")->execute([$id]);
                if ($img) shopBannerDeleteFile($img);
                setFlash("Shop banner #$id deleted successfully.");
            } catch (Throwable $e) {
                setFlash("Error deleting banner: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=shop_banners");
        exit();
    }

    // D4. SHOP BANNERS: TOGGLE ACTIVE
    if ($action === 'toggle_shop_banner') {
        $id = intval($_POST['banner_id'] ?? 0);
        if ($id > 0) {
            try {
                $pdo->prepare("UPDATE shop_banners SET is_active = 1 - is_active WHERE id = ?")->execute([$id]);
                setFlash("Shop banner #$id visibility updated.");
            } catch (Throwable $e) {
                setFlash("Error updating banner: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=shop_banners");
        exit();
    }

    // D5. SHOP BANNERS: REORDER (swap with neighbour)
    if ($action === 'reorder_shop_banners') {
        $id = intval($_POST['banner_id'] ?? 0);
        $dir = ($_POST['direction'] ?? '') === 'up' ? 'up' : 'down';
        if ($id > 0) {
            try {
                $pdo->beginTransaction();
                // Normalise to a clean 1..n sequence first so swaps always work even with duplicate sort values
                $ids = $pdo->query("SELECT id FROM shop_banners ORDER BY sort_order ASC, id ASC FOR UPDATE")->fetchAll(PDO::FETCH_COLUMN);
                $pos = array_search($id, array_map('intval', $ids), true);
                if ($pos !== false) {
                    $swapWith = $dir === 'up' ? $pos - 1 : $pos + 1;
                    if ($swapWith >= 0 && $swapWith < count($ids)) {
                        $tmp = $ids[$pos];
                        $ids[$pos] = $ids[$swapWith];
                        $ids[$swapWith] = $tmp;
                    }
                    $upd = $pdo->prepare("UPDATE shop_banners SET sort_order = ? WHERE id = ?");
                    foreach ($ids as $i => $bid) {
                        $upd->execute([$i + 1, (int)$bid]);
                    }
                }
                $pdo->commit();
                setFlash("Shop banner order updated.");
            } catch (Throwable $e) {
                if ($pdo->inTransaction()) $pdo->rollBack();
                setFlash("Error reordering banners: " . $e->getMessage(), 'danger');
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=shop_banners");
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
        $is_active = isset($_POST['is_active']) ? intval($_POST['is_active']) : 1;
        $video_url = trim($_POST['video_url'] ?? '');

        $crop = trim($_POST['crop'] ?? 'General');
        $category = trim($_POST['category'] ?? 'Crop Care');
        $language = trim($_POST['language'] ?? 'te');
        $source_url = trim($_POST['source_url'] ?? '');
        $payout_eligible = isset($_POST['payout_eligible']) ? intval($_POST['payout_eligible']) : 1;
        $is_duplicate = isset($_POST['is_duplicate']) ? intval($_POST['is_duplicate']) : 0;
        $rights_declared = isset($_POST['rights_declared']) ? intval($_POST['rights_declared']) : 1;
        $creator_id = intval($_POST['creator_id'] ?? 0);

        $uploadedVideo = uploadReelVideo('video_file');
        if (!empty($uploadedVideo)) {
            $video_url = $uploadedVideo;
        }

        if (empty($caption) || empty($video_url)) {
            setFlash('Caption and Video URL or upload are required.', 'danger');
        } else {
            try {
                if ($creator_id > 0) {
                    $cStmt = $pdo->prepare("SELECT id, display_name, phone_number FROM creators WHERE id = ? LIMIT 1");
                    $cStmt->execute([$creator_id]);
                    $cRow = $cStmt->fetch(PDO::FETCH_ASSOC);
                    if ($cRow) {
                        $creator_name = $cRow['display_name'];
                        if (!empty($cRow['phone_number'])) {
                            $phone_number = $cRow['phone_number'];
                        }
                    }
                } else {
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
                }

                if ($id > 0) {
                    $stmt = $pdo->prepare("UPDATE reels SET caption = ?, video_url = ?, music_title = ?, tags = ?, phone_number = ?, is_active = ?, creator_id = ?, crop = ?, category = ?, language = ?, source_url = ?, payout_eligible = ?, is_duplicate = ?, rights_declared = ? WHERE id = ?");
                    $stmt->execute([$caption, $video_url, $music_title, $tags, $phone_number, $is_active, $creator_id, $crop, $category, $language, $source_url, $payout_eligible, $is_duplicate, $rights_declared, $id]);
                    setFlash("Reel #$id updated successfully.");
                } else {
                    $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active, crop, category, language, source_url, payout_eligible, is_duplicate, rights_declared, status, created_at) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, ?, ?, ?, ?, ?, ?, ?, ?, 'approved', NOW())");
                    $stmt->execute([$creator_id, $video_url, $caption, $music_title, $phone_number, $tags, $is_active, $crop, $category, $language, $source_url, $payout_eligible, $is_duplicate, $rights_declared]);
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

    // G.1 BULK APPROVE REELS
    if ($action === 'bulk_approve_reels') {
        $ids = $_POST['selected_reels'] ?? [];
        if (!empty($ids) && is_array($ids)) {
            $sanitizedIds = array_map('intval', $ids);
            $sanitizedIds = array_filter($sanitizedIds, function($v) { return $v > 0; });
            if (!empty($sanitizedIds)) {
                $placeholders = implode(',', array_fill(0, count($sanitizedIds), '?'));
                try {
                    $pdo->prepare("UPDATE reels SET status = 'approved', is_active = 1, reviewed_at = NOW(), reviewed_by = 'Admin' WHERE id IN ($placeholders)")->execute($sanitizedIds);
                    setFlash(count($sanitizedIds) . " reels approved and made live successfully.");
                } catch (Throwable $e) {
                    setFlash("Bulk approval error: " . $e->getMessage(), 'danger');
                }
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // H. TOGGLE REEL STATUS
    if ($action === 'toggle_reel_status') {
        $id = intval($_POST['reel_id'] ?? 0);
        $new_status = intval($_POST['is_active'] ?? 0) === 1 ? 0 : 1;
        $isAjax = (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') || isset($_POST['ajax']) || isset($_GET['ajax']);

        if ($id > 0) {
            $chk = $pdo->prepare("SELECT r.status, c.status AS creator_status, c.display_name AS creator_name FROM reels r LEFT JOIN creators c ON r.creator_id = c.id WHERE r.id = ?");
            $chk->execute([$id]);
            $rRow = $chk->fetch(PDO::FETCH_ASSOC);

            if ($new_status === 1) {
                if ($rRow && ($rRow['creator_status'] ?? '') === 'suspended') {
                    $cName = $rRow['creator_name'] ?: 'Creator';
                    if ($isAjax) {
                        header('Content-Type: application/json');
                        echo json_encode(['success' => false, 'error' => "Cannot activate reel: Creator ($cName) is suspended. Unsuspend creator first."]);
                        exit();
                    }
                    setFlash("Cannot activate reel: Creator ($cName) is suspended.", "danger");
                    header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
                    exit();
                }

                $rStatus = $rRow['status'] ?? '';
                if ($rStatus !== 'approved') {
                    if ($isAjax) {
                        header('Content-Type: application/json');
                        echo json_encode(['success' => false, 'error' => "Reel cannot be activated until approved by a moderator."]);
                        exit();
                    }
                    setFlash("Reel cannot be activated until approved by a moderator.", "danger");
                    header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
                    exit();
                }
            }
            $pdo->prepare("UPDATE reels SET is_active = ? WHERE id = ?")->execute([$new_status, $id]);
            if ($isAjax) {
                header('Content-Type: application/json');
                echo json_encode([
                    'success' => true,
                    'reel_id' => $id,
                    'is_active' => $new_status,
                    'message' => "Reel #$id visibility updated to " . ($new_status === 1 ? 'Visible' : 'Hidden') . "."
                ]);
                exit();
            }
            setFlash("Reel visibility updated.");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // H.1 TOGGLE REEL PAYOUT ELIGIBILITY
    if ($action === 'toggle_reel_payout_eligible') {
        $id = intval($_POST['reel_id'] ?? 0);
        $newEligible = intval($_POST['payout_eligible'] ?? 0) === 1 ? 0 : 1;
        $isAjax = (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') || isset($_POST['ajax']) || isset($_GET['ajax']);

        if ($id > 0) {
            $chk = $pdo->prepare("SELECT c.status AS creator_status FROM reels r LEFT JOIN creators c ON r.creator_id = c.id WHERE r.id = ?");
            $chk->execute([$id]);
            $cStatus = $chk->fetchColumn();
            if ($newEligible === 1 && $cStatus === 'suspended') {
                if ($isAjax) {
                    header('Content-Type: application/json');
                    echo json_encode(['success' => false, 'error' => "Cannot make reel payout eligible: Creator is currently suspended."]);
                    exit();
                }
                setFlash("Cannot make reel payout eligible: Creator is suspended.", "danger");
                header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
                exit();
            }

            $pdo->prepare("UPDATE reels SET payout_eligible = ? WHERE id = ?")->execute([$newEligible, $id]);
            if ($isAjax) {
                header('Content-Type: application/json');
                echo json_encode([
                    'success' => true,
                    'reel_id' => $id,
                    'payout_eligible' => $newEligible,
                    'message' => "Reel #$id payout status set to " . ($newEligible === 1 ? 'Eligible' : 'Ineligible') . "."
                ]);
                exit();
            }
            setFlash("Reel #$id payout status set to " . ($newEligible === 1 ? 'Eligible' : 'Ineligible') . ".");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // H.2 TOGGLE REEL DUPLICATE FLAG
    if ($action === 'toggle_reel_duplicate') {
        $id = intval($_POST['reel_id'] ?? 0);
        $newDuplicate = intval($_POST['is_duplicate'] ?? 0) === 1 ? 0 : 1;
        $isAjax = (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') || isset($_POST['ajax']) || isset($_GET['ajax']);

        if ($id > 0) {
            $payoutVal = $newDuplicate === 1 ? 0 : 1; // Duplicates automatically forfeit payout
            $pdo->prepare("UPDATE reels SET is_duplicate = ?, payout_eligible = ? WHERE id = ?")->execute([$newDuplicate, $payoutVal, $id]);
            if ($isAjax) {
                header('Content-Type: application/json');
                echo json_encode([
                    'success' => true,
                    'reel_id' => $id,
                    'is_duplicate' => $newDuplicate,
                    'payout_eligible' => $payoutVal,
                    'message' => "Reel #$id duplicate flag updated to " . ($newDuplicate === 1 ? 'Duplicate' : 'Original') . "."
                ]);
                exit();
            }
            setFlash("Reel #$id duplicate flag updated.");
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
        exit();
    }

    // I. DELETE COMMENT
    if ($action === 'delete_comment') {
        $type = $_POST['comment_type'] ?? '';
        $cid = intval($_POST['comment_id'] ?? 0);
        $parent_id = intval($_POST['parent_id'] ?? 0);
        $redirectTab = $_POST['redirect_tab'] ?? 'comments';

        if ($type === 'news' && $cid > 0) {
            $pdo->prepare("DELETE FROM news_article_comments WHERE id = ?")->execute([$cid]);
            $pdo->prepare("UPDATE news_articles SET comments_count = GREATEST(0, comments_count - 1) WHERE id = ?")->execute([$parent_id]);
            setFlash("Comment deleted.");
            header("Location: " . $_SERVER['PHP_SELF'] . "?tab=" . urlencode($redirectTab));
            exit();
        } elseif ($type === 'reel' && $cid > 0) {
            $pdo->prepare("DELETE FROM reel_comments WHERE id = ?")->execute([$cid]);
            $pdo->prepare("UPDATE reels SET comments_count = GREATEST(0, comments_count - 1) WHERE id = ?")->execute([$parent_id]);
            if (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') {
                header('Content-Type: application/json');
                echo json_encode(['success' => true]);
                exit();
            }
            setFlash("Comment deleted.");
            header("Location: " . $_SERVER['PHP_SELF'] . "?tab=" . urlencode($redirectTab));
            exit();
        }
    }

    // =========================================================
    // J. AGRI CREATOR PARTNER PROGRAM ACTIONS
    // =========================================================

    // 1. SAVE CREATOR (CREATE / EDIT WITH VALIDATION & USER SYNC)
    if ($action === 'save_creator') {
        $creatorId = intval($_POST['creator_id'] ?? 0);
        $displayName = trim($_POST['display_name'] ?? '');
        $username = trim($_POST['username'] ?? '');
        $phoneNumber = trim($_POST['phone_number'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $bio = trim($_POST['bio'] ?? '');
        $profileImageUrl = trim($_POST['profile_image_url'] ?? '');
        $niches = trim($_POST['agriculture_niches'] ?? '');
        $languages = trim($_POST['languages'] ?? 'te');
        $socialHandles = trim($_POST['social_handles'] ?? '');
        $upiId = trim($_POST['upi_id'] ?? '');
        $partnershipTier = trim($_POST['partnership_tier'] ?? 'trial');
        $status = trim($_POST['status'] ?? 'active');
        $isVerified = (isset($_POST['is_verified']) && ($_POST['is_verified'] === '1' || $_POST['is_verified'] === 'on')) ? 1 : 0;
        $termsAccepted = (isset($_POST['terms_accepted']) && ($_POST['terms_accepted'] === '1' || $_POST['terms_accepted'] === 'on')) ? 1 : 0;

        if (empty($displayName)) {
            setFlash("Creator display name is required.", "danger");
        } else {
            try {
                // Auto-generate or sanitize username
                if (empty($username)) {
                    $username = strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', str_replace(' ', '_', $displayName)));
                    if (empty($username)) {
                        $username = 'creator_' . (!empty($phoneNumber) ? substr($phoneNumber, -4) : rand(1000, 9999));
                    }
                } else {
                    $username = strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', $username));
                }

                // Check username uniqueness
                $uStmt = $pdo->prepare("SELECT id FROM creators WHERE username = ? AND id != ? LIMIT 1");
                $uStmt->execute([$username, $creatorId]);
                if ($uStmt->fetchColumn()) {
                    $username = $username . '_' . rand(10, 99);
                }

                if (empty($profileImageUrl)) {
                    $profileImageUrl = 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80';
                }

                // Check pilot cap if activating
                if ($status === 'active') {
                    $capStmt = $pdo->prepare("SELECT COUNT(*) FROM creators WHERE status = 'active' AND id != ?");
                    $capStmt->execute([$creatorId]);
                    $activeCount = intval($capStmt->fetchColumn() ?: 0);
                    if ($activeCount >= 25) {
                        setFlash("Pilot cap of 25 active creators is currently full. Saved with 'pending_review' status instead.", "warning");
                        $status = 'pending_review';
                    }
                }

                // Sync with existing user account if phone matches
                $userId = null;
                if (!empty($phoneNumber)) {
                    try {
                        $usrStmt = $pdo->prepare("SELECT user_id FROM users WHERE phone_number = ? LIMIT 1");
                        $usrStmt->execute([$phoneNumber]);
                        $foundUserId = $usrStmt->fetchColumn();
                        if ($foundUserId) {
                            $userId = $foundUserId;
                            if ($status === 'active') {
                                $pdo->prepare("UPDATE users SET role = 'creator' WHERE user_id = ?")->execute([$foundUserId]);
                            }
                        }
                    } catch (Throwable $e) {}
                }

                if ($creatorId > 0) {
                    $stmt = $pdo->prepare("
                        UPDATE creators 
                        SET display_name = ?, username = ?, phone_number = ?, email = ?, bio = ?, 
                            profile_image_url = ?, agriculture_niches = ?, languages = ?, social_handles = ?, 
                            upi_id = ?, partnership_tier = ?, status = ?, is_verified = ?, terms_accepted = ?,
                            user_id = COALESCE(?, user_id)
                        WHERE id = ?
                    ");
                    $stmt->execute([
                        $displayName, $username, $phoneNumber, $email, $bio, 
                        $profileImageUrl, $niches, $languages, $socialHandles, 
                        $upiId, $partnershipTier, $status, $isVerified, $termsAccepted,
                        $userId, $creatorId
                    ]);
                    // Cascade reel status if creator is suspended or activated
                    if ($status === 'suspended') {
                        $pdo->prepare("UPDATE reels SET is_active = 0, payout_eligible = 0 WHERE creator_id = ?")->execute([$creatorId]);
                    } elseif ($status === 'active') {
                        $pdo->prepare("UPDATE reels SET is_active = 1, payout_eligible = 1 WHERE creator_id = ? AND status = 'approved' AND (is_duplicate IS NULL OR is_duplicate = 0)")->execute([$creatorId]);
                    }
                    setFlash("Creator partner #$creatorId ($displayName) updated successfully.", "success");
                } else {
                    $stmt = $pdo->prepare("
                        INSERT INTO creators 
                        (display_name, username, phone_number, email, bio, profile_image_url, agriculture_niches, languages, social_handles, upi_id, partnership_tier, status, is_verified, terms_accepted, user_id, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                    ");
                    $stmt->execute([
                        $displayName, $username, $phoneNumber, $email, $bio, 
                        $profileImageUrl, $niches, $languages, $socialHandles, 
                        $upiId, $partnershipTier, $status, $isVerified, $termsAccepted, $userId
                    ]);
                    $creatorId = $pdo->lastInsertId();
                    setFlash("New creator partner $displayName (#$creatorId) enrolled successfully.", "success");
                }
            } catch (Throwable $e) {
                setFlash("Error saving creator: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=creators");
        exit();
    }

    // 2. DELETE CREATOR WITH FULL INTEGRITY CLEANUP
    if ($action === 'delete_creator') {
        $creatorId = intval($_POST['creator_id'] ?? 0);
        $deleteReels = intval($_POST['delete_reels'] ?? 1);

        if ($creatorId > 0) {
            try {
                // Fetch info
                $cStmt = $pdo->prepare("SELECT display_name, user_id, phone_number FROM creators WHERE id = ?");
                $cStmt->execute([$creatorId]);
                $cData = $cStmt->fetch(PDO::FETCH_ASSOC);
                $displayName = $cData['display_name'] ?? "ID #$creatorId";
                $userId = $cData['user_id'] ?? null;
                $phone = $cData['phone_number'] ?? null;

                // 1. Delete associated reels & interactions if requested
                $rStmt = $pdo->prepare("SELECT id FROM reels WHERE creator_id = ?");
                $rStmt->execute([$creatorId]);
                $reelIds = $rStmt->fetchAll(PDO::FETCH_COLUMN);

                if (!empty($reelIds) && $deleteReels === 1) {
                    $placeholders = implode(',', array_fill(0, count($reelIds), '?'));
                    try { $pdo->prepare("DELETE FROM reel_likes WHERE reel_id IN ($placeholders)")->execute($reelIds); } catch (Throwable $e) {}
                    try { $pdo->prepare("DELETE FROM reel_comments WHERE reel_id IN ($placeholders)")->execute($reelIds); } catch (Throwable $e) {}
                    try { $pdo->prepare("DELETE FROM reel_actions WHERE reel_id IN ($placeholders)")->execute($reelIds); } catch (Throwable $e) {}
                    try { $pdo->prepare("DELETE FROM reel_watch_analytics WHERE reel_id IN ($placeholders)")->execute($reelIds); } catch (Throwable $e) {}
                    try { $pdo->prepare("DELETE FROM reel_reviews WHERE reel_id IN ($placeholders)")->execute($reelIds); } catch (Throwable $e) {}
                    try { $pdo->prepare("DELETE FROM reel_events WHERE reel_id IN ($placeholders)")->execute($reelIds); } catch (Throwable $e) {}
                    $pdo->prepare("DELETE FROM reels WHERE creator_id = ?")->execute([$creatorId]);
                }

                // 2. Delete campaign deliverables & assignments
                try { $pdo->prepare("DELETE FROM campaign_creator_assignments WHERE creator_id = ?")->execute([$creatorId]); } catch (Throwable $e) {}

                // 3. Delete payout line items & payouts
                try {
                    $poStmt = $pdo->prepare("SELECT id FROM monthly_creator_payouts WHERE creator_id = ?");
                    $poStmt->execute([$creatorId]);
                    $payoutIds = $poStmt->fetchAll(PDO::FETCH_COLUMN);
                    if (!empty($payoutIds)) {
                        $pPlaceholders = implode(',', array_fill(0, count($payoutIds), '?'));
                        $pdo->prepare("DELETE FROM payout_line_items WHERE payout_id IN ($pPlaceholders)")->execute($payoutIds);
                    }
                    $pdo->prepare("DELETE FROM monthly_creator_payouts WHERE creator_id = ?")->execute([$creatorId]);
                } catch (Throwable $e) {}

                // 4. Delete payment profiles & terms
                try { $pdo->prepare("DELETE FROM creator_payment_profiles WHERE creator_id = ?")->execute([$creatorId]); } catch (Throwable $e) {}
                try { $pdo->prepare("DELETE FROM creator_terms WHERE creator_id = ?")->execute([$creatorId]); } catch (Throwable $e) {}

                // 5. Restore user account role back to farmer if no other creator profiles
                if (!empty($userId)) {
                    try {
                        $chkOther = $pdo->prepare("SELECT COUNT(*) FROM creators WHERE user_id = ? AND id != ?");
                        $chkOther->execute([$userId, $creatorId]);
                        if (intval($chkOther->fetchColumn() ?: 0) === 0) {
                            $pdo->prepare("UPDATE users SET role = 'farmer' WHERE user_id = ? AND role = 'creator'")->execute([$userId]);
                        }
                    } catch (Throwable $e) {}
                } elseif (!empty($phone)) {
                    try {
                        $pdo->prepare("UPDATE users SET role = 'farmer' WHERE phone_number = ? AND role = 'creator'")->execute([$phone]);
                    } catch (Throwable $e) {}
                }

                // 6. Delete creator record
                $pdo->prepare("DELETE FROM creators WHERE id = ?")->execute([$creatorId]);

                setFlash("Creator partner $displayName (#$creatorId) and all associated assets have been permanently removed.", "success");
            } catch (Throwable $e) {
                setFlash("Error deleting creator: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=creators");
        exit();
    }

    // 3. TOGGLE CREATOR VERIFIED STATUS
    if ($action === 'toggle_creator_verified') {
        $creatorId = intval($_POST['creator_id'] ?? 0);
        if ($creatorId > 0) {
            try {
                $pdo->prepare("UPDATE creators SET is_verified = IF(is_verified = 1, 0, 1) WHERE id = ?")->execute([$creatorId]);
                setFlash("Verification badge for Creator #$creatorId updated.", "success");
            } catch (Throwable $e) {
                setFlash("Error: " . $e->getMessage(), "danger");
            }
        }
        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=creators");
        exit();
    }

    // 4. APPROVE / REJECT / SUSPEND CREATOR WITH 25-CAP ENFORCEMENT & REEL CASCADE
    if ($action === 'admin_approve_creator') {
        $creatorId = intval($_POST['creator_id'] ?? 0);
        $approvalAction = trim($_POST['approval_action'] ?? 'approve');
        $tier = trim($_POST['tier'] ?? 'trial');
        $reason = trim($_POST['reason'] ?? '');
        $isAjax = (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') || isset($_POST['ajax']) || isset($_GET['ajax']);

        if ($creatorId > 0) {
            try {
                if ($approvalAction === 'approve') {
                    $capStmt = $pdo->query("SELECT COUNT(*) FROM creators WHERE status = 'active'");
                    $activeCount = intval($capStmt->fetchColumn() ?: 0);
                    if ($activeCount >= 25) {
                        $msg = "Cannot approve creator: 25-creator pilot cap reached (Active: $activeCount / 25).";
                        if ($isAjax) {
                            header('Content-Type: application/json');
                            echo json_encode(['success' => false, 'error' => $msg]);
                            exit();
                        }
                        setFlash($msg, "danger");
                    } else {
                        $pdo->prepare("UPDATE creators SET status = 'active', partnership_tier = ?, is_verified = 1, reviewed_by = 'Admin', reviewed_at = NOW(), approved_at = NOW() WHERE id = ?")
                            ->execute([$tier, $creatorId]);
                        // Reactivate approved non-duplicate reels
                        $pdo->prepare("UPDATE reels SET is_active = 1, payout_eligible = 1 WHERE creator_id = ? AND status = 'approved' AND (is_duplicate IS NULL OR is_duplicate = 0)")
                            ->execute([$creatorId]);
                        $msg = "Creator #$creatorId approved as $tier partner ($activeCount / 25 active). Approved reels restored to live feed.";
                        if ($isAjax) {
                            header('Content-Type: application/json');
                            echo json_encode(['success' => true, 'creator_id' => $creatorId, 'status' => 'active', 'message' => $msg]);
                            exit();
                        }
                        setFlash($msg, "success");
                    }
                } elseif ($approvalAction === 'reject') {
                    $pdo->prepare("UPDATE creators SET status = 'rejected', rejection_reason = ?, reviewed_by = 'Admin', reviewed_at = NOW() WHERE id = ?")
                        ->execute([$reason, $creatorId]);
                    $pdo->prepare("UPDATE reels SET is_active = 0, payout_eligible = 0 WHERE creator_id = ?")->execute([$creatorId]);
                    $msg = "Creator #$creatorId application rejected. All reels suppressed.";
                    if ($isAjax) {
                        header('Content-Type: application/json');
                        echo json_encode(['success' => true, 'creator_id' => $creatorId, 'status' => 'rejected', 'message' => $msg]);
                        exit();
                    }
                    setFlash($msg, "warning");
                } elseif ($approvalAction === 'suspend') {
                    $pdo->prepare("UPDATE creators SET status = 'suspended', rejection_reason = ?, reviewed_by = 'Admin', reviewed_at = NOW() WHERE id = ?")
                        ->execute([$reason, $creatorId]);
                    // CASCADE REEL DEACTIVATION: All reels immediately deactivated & payout eligibility revoked
                    $pdo->prepare("UPDATE reels SET is_active = 0, payout_eligible = 0 WHERE creator_id = ?")->execute([$creatorId]);
                    $msg = "Creator #$creatorId suspended. All associated videos are suppressed and deactivated from public feeds.";
                    if ($isAjax) {
                        header('Content-Type: application/json');
                        echo json_encode(['success' => true, 'creator_id' => $creatorId, 'status' => 'suspended', 'message' => $msg]);
                        exit();
                    }
                    setFlash($msg, "danger");
                }
            } catch (Throwable $e) {
                if ($isAjax) {
                    header('Content-Type: application/json');
                    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
                    exit();
                }
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
        $isAjax = (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest') || isset($_POST['ajax']) || isset($_GET['ajax']);

        if ($reelId > 0) {
            try {
                if ($decision === 'approved') {
                    $cChk = $pdo->prepare("SELECT c.status AS creator_status, c.display_name FROM reels r LEFT JOIN creators c ON r.creator_id = c.id WHERE r.id = ?");
                    $cChk->execute([$reelId]);
                    $cRow = $cChk->fetch(PDO::FETCH_ASSOC);
                    if ($cRow && ($cRow['creator_status'] ?? '') === 'suspended') {
                        $err = "Cannot approve reel: Creator " . ($cRow['display_name'] ?: '') . " is currently suspended.";
                        if ($isAjax) {
                            header('Content-Type: application/json');
                            echo json_encode(['success' => false, 'error' => $err]);
                            exit();
                        }
                        setFlash($err, 'danger');
                        header("Location: " . $_SERVER['PHP_SELF'] . "?tab=reels");
                        exit();
                    }
                }

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

                $msg = "Reel #$reelId marked as $decision.";
                if ($isAjax) {
                    header('Content-Type: application/json');
                    echo json_encode([
                        'success' => true,
                        'reel_id' => $reelId,
                        'status' => $decision,
                        'is_active' => $isActive,
                        'payout_eligible' => $payoutEligible,
                        'message' => $msg
                    ]);
                    exit();
                }
                setFlash($msg);
            } catch (Throwable $e) {
                if ($isAjax) {
                    header('Content-Type: application/json');
                    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
                    exit();
                }
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
$suspendedCreatorReelsCount = 0;
$totalCreators = 0;
$totalCreatorsCount = 0;
$verifiedCreatorsCount = 0;
$totalCreatorReels = 0;
$totalCreatorViews = 0;

$creatorStatusFilter = trim($_GET['creator_status'] ?? 'all');
$creatorTierFilter = trim($_GET['creator_tier'] ?? 'all');
$creatorVerifiedFilter = trim($_GET['creator_verified'] ?? 'all');
$creatorSort = trim($_GET['creator_sort'] ?? 'newest');

$articlesList = [];
$reelsList = [];
$commentsList = [];
$creatorsList = [];
$allCreators = [];
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

        $suspendedCreatorReelsCount = 0;
        try {
            $scStmt = $pdo->query("SELECT COUNT(*) FROM reels r INNER JOIN creators c ON r.creator_id = c.id WHERE c.status = 'suspended'");
            $suspendedCreatorReelsCount = intval($scStmt->fetchColumn() ?: 0);
        } catch (Throwable $e) {}

        $chkRStatus = $pdo->query("SHOW COLUMNS FROM `reels` LIKE 'status'");
        if ($chkRStatus && $chkRStatus->fetch()) {
            $rmStats = $pdo->query("SELECT 
                SUM(CASE WHEN (r.status IN ('under_review', 'submitted') OR (r.is_active = 0 AND (r.status IS NULL OR r.status = ''))) AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as pending_cnt,
                SUM(CASE WHEN (r.status = 'approved' OR (r.is_active = 1 AND (r.status IS NULL OR r.status = 'approved'))) AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as approved_cnt,
                SUM(CASE WHEN r.status = 'changes_requested' AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as changes_cnt,
                SUM(CASE WHEN r.status = 'rejected' AND (c.status IS NULL OR c.status != 'suspended') THEN 1 ELSE 0 END) as rejected_cnt
            FROM reels r LEFT JOIN creators c ON r.creator_id = c.id")->fetch();
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

        $reelSql = "SELECT r.*, c.display_name AS creator_name, c.username AS creator_username, c.status AS creator_status 
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
            if ($moderationFilter === 'suspended_creator') {
                $reelSql .= " AND c.status = 'suspended'";
            } elseif ($hasReelStatus) {
                if ($moderationFilter === 'pending' || $moderationFilter === 'under_review') {
                    $reelSql .= " AND (r.status IN ('under_review', 'submitted') OR (r.is_active = 0 AND (r.status IS NULL OR r.status = ''))) AND (c.status IS NULL OR c.status != 'suspended')";
                } elseif ($moderationFilter === 'approved') {
                    $reelSql .= " AND (r.status = 'approved' OR (r.is_active = 1 AND (r.status IS NULL OR r.status = 'approved'))) AND (c.status IS NULL OR c.status != 'suspended')";
                } else {
                    $reelSql .= " AND r.status = ? AND (c.status IS NULL OR c.status != 'suspended')";
                    $reelParams[] = $moderationFilter;
                }
            } elseif ($moderationFilter === 'approved') {
                $reelSql .= " AND r.is_active = 1 AND (c.status IS NULL OR c.status != 'suspended')";
            } elseif ($moderationFilter === 'pending' || $moderationFilter === 'under_review') {
                $reelSql .= " AND r.is_active = 0 AND (c.status IS NULL OR c.status != 'suspended')";
            }
        }
        $reelSql .= " ORDER BY r.id DESC LIMIT 100";
        $rStmt = $pdo->prepare($reelSql);
        $rStmt->execute($reelParams);
        $reelsList = $rStmt->fetchAll();
    } catch (Throwable $e) {}

    // 6. Creators fetch & partner analytics
    try {
        $hasReelStatus = false;
        try {
            $chkRStatus = $pdo->query("SHOW COLUMNS FROM `reels` LIKE 'status'");
            $hasReelStatus = ($chkRStatus && $chkRStatus->fetch());
        } catch (Throwable $e) {}

        $approvedExpr = $hasReelStatus 
            ? "SUM(CASE WHEN r.status = 'approved' THEN 1 ELSE 0 END)" 
            : "SUM(CASE WHEN r.is_active = 1 THEN 1 ELSE 0 END)";

        // Summary KPI statistics
        try {
            $cStatsStmt = $pdo->query("
                SELECT 
                    COUNT(*) as total_c,
                    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_c,
                    SUM(CASE WHEN status IN ('applied', 'pending_review') THEN 1 ELSE 0 END) as pending_c,
                    SUM(CASE WHEN is_verified = 1 THEN 1 ELSE 0 END) as verified_c
                FROM creators
            ");
            if ($cStatsStmt && ($cs = $cStatsStmt->fetch(PDO::FETCH_ASSOC))) {
                $totalCreatorsCount = intval($cs['total_c'] ?? 0);
                $totalCreators = $totalCreatorsCount;
                $activeCreatorsCount = intval($cs['active_c'] ?? 0);
                $pendingCreatorsCount = intval($cs['pending_c'] ?? 0);
                $verifiedCreatorsCount = intval($cs['verified_c'] ?? 0);
            }

            $crTotStmt = $pdo->query("SELECT COUNT(*) as r_count, COALESCE(SUM(views_count), 0) as r_views FROM reels");
            if ($crTotStmt && ($crs = $crTotStmt->fetch(PDO::FETCH_ASSOC))) {
                $totalCreatorReels = intval($crs['r_count'] ?? 0);
                $totalCreatorViews = intval($crs['r_views'] ?? 0);
            }
        } catch (Throwable $e) {}

        // Full creators list for modal/campaign dropdowns
        $acStmt = $pdo->query("SELECT id, display_name, username, phone_number, partnership_tier, status FROM creators ORDER BY display_name ASC");
        $allCreators = $acStmt ? $acStmt->fetchAll(PDO::FETCH_ASSOC) : [];

        // Filter-aware query for Creators Directory
        $crWhere = [];
        $crParams = [];

        if ($activeTab === 'creators' && !empty($searchQuery)) {
            $crWhere[] = "(c.display_name LIKE ? OR c.username LIKE ? OR c.phone_number LIKE ? OR c.email LIKE ? OR c.agriculture_niches LIKE ?)";
            $sqTerm = "%$searchQuery%";
            $crParams[] = $sqTerm;
            $crParams[] = $sqTerm;
            $crParams[] = $sqTerm;
            $crParams[] = $sqTerm;
            $crParams[] = $sqTerm;
        }

        if ($activeTab === 'creators' && $creatorStatusFilter !== 'all') {
            $crWhere[] = "c.status = ?";
            $crParams[] = $creatorStatusFilter;
        }

        if ($activeTab === 'creators' && $creatorTierFilter !== 'all') {
            $crWhere[] = "c.partnership_tier = ?";
            $crParams[] = $creatorTierFilter;
        }

        if ($activeTab === 'creators' && $creatorVerifiedFilter === 'verified') {
            $crWhere[] = "c.is_verified = 1";
        } elseif ($activeTab === 'creators' && $creatorVerifiedFilter === 'unverified') {
            $crWhere[] = "c.is_verified = 0";
        }

        $crWhereSql = !empty($crWhere) ? "WHERE " . implode(" AND ", $crWhere) : "";

        // Sort order
        $crOrderSql = "ORDER BY c.id DESC";
        if ($creatorSort === 'most_views') {
            $crOrderSql = "ORDER BY total_views DESC, c.id DESC";
        } elseif ($creatorSort === 'most_reels') {
            $crOrderSql = "ORDER BY total_reels DESC, c.id DESC";
        } elseif ($creatorSort === 'name_asc') {
            $crOrderSql = "ORDER BY c.display_name ASC";
        } elseif ($creatorSort === 'oldest') {
            $crOrderSql = "ORDER BY c.id ASC";
        }

        $crSql = "
            SELECT c.*, 
                   COUNT(r.id) AS total_reels,
                   $approvedExpr AS approved_reels,
                   COALESCE(SUM(r.views_count), 0) AS total_views
            FROM creators c
            LEFT JOIN reels r ON c.id = r.creator_id
            $crWhereSql
            GROUP BY c.id
            $crOrderSql
        ";
        $crStmt = $pdo->prepare($crSql);
        $crStmt->execute($crParams);
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
            background: radial-gradient(at 10% 10%, rgba(16, 185, 129, 0.035) 0px, transparent 50%), radial-gradient(at 90% 0%, rgba(14, 165, 233, 0.035) 0px, transparent 50%), #f8fafc;
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
            gap: 22px;
            overflow-x: auto;
            position: relative;
        }

        .tab-link {
            padding: 13px 2px;
            font-size: 0.88rem;
            font-weight: 500;
            color: var(--text-secondary);
            text-decoration: none;
            border-bottom: 2px solid transparent;
            display: inline-flex;
            align-items: center;
            gap: 7px;
            white-space: nowrap;
            transition: all 0.18s cubic-bezier(0.16, 1, 0.3, 1);
            position: relative;
        }

        .tab-link:hover {
            color: var(--text-primary);
            transform: translateY(-1px);
        }

        .tab-link.active {
            color: var(--text-primary);
            font-weight: 700;
            border-bottom-color: var(--accent);
        }

        .tab-counter {
            font-size: 0.73rem;
            padding: 2px 7px;
            background: var(--surface-subtle);
            border-radius: var(--radius-pill);
            color: var(--text-muted);
            font-weight: 600;
            transition: transform 0.15s ease;
        }

        .tab-link:hover .tab-counter {
            transform: scale(1.05);
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

        /* ALPINE CUSTOM DROPDOWN & SELECT SYSTEM (ZERO NATIVE SELECTS) */
        .alpine-dropdown, .alpine-select-wrapper {
            position: relative;
            display: inline-block;
        }

        .alpine-select-wrapper.full-width {
            width: 100%;
        }

        .dropdown-trigger, .alpine-select-trigger {
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
            user-select: none;
            transition: border-color 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
        }

        .alpine-select-trigger.sm {
            padding: 4px 8px;
            font-size: 0.76rem;
            min-width: 110px;
            border-radius: 4px;
        }

        .alpine-select-wrapper.full-width .alpine-select-trigger {
            width: 100%;
        }

        .dropdown-trigger:hover, .dropdown-trigger:focus,
        .alpine-select-trigger:hover {
            border-color: #94a3b8;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
        }

        .dropdown-trigger.active,
        .alpine-select-trigger.active {
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(21, 128, 61, 0.15);
        }

        .alpine-select-trigger i.ph-caret-down,
        .dropdown-trigger i.ph-caret-down {
            font-size: 0.85rem;
            color: var(--text-muted);
            transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1);
        }

        .alpine-select-trigger.active i.ph-caret-down,
        .dropdown-trigger.active i.ph-caret-down {
            transform: rotate(180deg);
        }

        .dropdown-panel, .alpine-select-menu {
            position: absolute;
            top: calc(100% + 5px);
            left: 0;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 10px;
            box-shadow: 0 16px 36px -4px rgba(15, 23, 42, 0.16), 0 6px 14px -3px rgba(15, 23, 42, 0.08);
            z-index: 250 !important;
            min-width: 100%;
            max-height: 270px;
            overflow-y: auto;
            padding: 5px;
            animation: dropdownSpring 0.18s cubic-bezier(0.16, 1, 0.3, 1);
            transform-origin: top left;
        }

        .dropdown-panel.right-align, .alpine-select-menu.right-align {
            left: auto;
            right: 0;
            transform-origin: top right;
        }

        /* Smart Viewport-Aware Dropup Position */
        .dropdown-panel.dropup-menu, .alpine-select-menu.dropup-menu {
            top: auto !important;
            bottom: calc(100% + 5px) !important;
            transform-origin: bottom right !important;
            box-shadow: 0 -14px 34px -4px rgba(15, 23, 42, 0.16), 0 -6px 14px -3px rgba(15, 23, 42, 0.08) !important;
            animation: dropdownSpringUp 0.18s cubic-bezier(0.16, 1, 0.3, 1) !important;
        }

        @keyframes dropdownSpring {
            from { opacity: 0; transform: translateY(-5px) scale(0.97); }
            to { opacity: 1; transform: translateY(0) scale(1); }
        }

        @keyframes dropdownSpringUp {
            from { opacity: 0; transform: translateY(5px) scale(0.97); }
            to { opacity: 1; transform: translateY(0) scale(1); }
        }

        .dropdown-option, .alpine-select-option {
            padding: 8px 11px;
            font-size: 0.83rem;
            color: var(--text-secondary);
            border-radius: 6px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 10px;
            transition: all 0.12s ease;
            white-space: nowrap;
        }

        .dropdown-option:hover, .alpine-select-option:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
            transform: translateX(2px);
        }

        .dropdown-option.selected, .alpine-select-option.selected {
            background: #dcfce7;
            color: #15803d;
            font-weight: 600;
        }

        .alpine-select-option i.check-icon {
            font-size: 0.85rem;
            color: #15803d;
        }

        /* CREATOR MANAGEMENT STATS & STYLING */
        .creator-stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(235px, 1fr));
            gap: 16px;
            margin-bottom: 22px;
        }

        .creator-stat-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 18px 20px;
            display: flex;
            flex-direction: column;
            gap: 8px;
            position: relative;
            box-shadow: 0 1px 3px rgba(0,0,0,0.03);
            transition: transform 0.22s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.22s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.2s ease;
            overflow: hidden;
        }
        .creator-stat-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 12px 28px -6px rgba(15, 23, 42, 0.09), 0 4px 10px -2px rgba(15, 23, 42, 0.04);
            border-color: #cbd5e1;
        }

        /* Distinct Contextual Color Themes for Stat Cards */
        .creator-stat-card.card-pilot {
            background: linear-gradient(135deg, rgba(16, 185, 129, 0.05) 0%, #ffffff 100%);
            border-top: 3px solid #10b981;
        }
        .creator-stat-card.card-queue {
            background: linear-gradient(135deg, rgba(245, 158, 11, 0.05) 0%, #ffffff 100%);
            border-top: 3px solid #f59e0b;
        }
        .creator-stat-card.card-verified {
            background: linear-gradient(135deg, rgba(2, 132, 199, 0.05) 0%, #ffffff 100%);
            border-top: 3px solid #0284c7;
        }
        .creator-stat-card.card-impact {
            background: linear-gradient(135deg, rgba(139, 92, 246, 0.05) 0%, #ffffff 100%);
            border-top: 3px solid #8b5cf6;
        }

        .stat-icon-circle {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 1.05rem;
            flex-shrink: 0;
            transition: transform 0.2s ease;
        }
        .creator-stat-card:hover .stat-icon-circle {
            transform: scale(1.1);
        }
        .stat-icon-circle.emerald { background: rgba(16, 185, 129, 0.12); color: #059669; }
        .stat-icon-circle.amber { background: rgba(245, 158, 11, 0.12); color: #d97706; }
        .stat-icon-circle.sky { background: rgba(2, 132, 199, 0.12); color: #0284c7; }
        .stat-icon-circle.violet { background: rgba(139, 92, 246, 0.12); color: #7c3aed; }

        .pulse-dot {
            width: 7px;
            height: 7px;
            border-radius: 50%;
            display: inline-block;
            background: #10b981;
            box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
            animation: pulseRing 1.8s infinite;
        }
        @keyframes pulseRing {
            0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.6); }
            70% { box-shadow: 0 0 0 6px rgba(16, 185, 129, 0); }
            100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
        }

        .pulse-dot.warning {
            background: #f59e0b;
            box-shadow: 0 0 0 0 rgba(245, 158, 11, 0.7);
            animation: pulseRingWarn 1.8s infinite;
        }
        @keyframes pulseRingWarn {
            0% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0.6); }
            70% { box-shadow: 0 0 0 6px rgba(245, 158, 11, 0); }
            100% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0); }
        }

        .stat-card-label {
            font-size: 0.74rem;
            font-weight: 700;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.04em;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .stat-card-value {
            font-size: 1.5rem;
            font-weight: 800;
            color: var(--text-primary);
            line-height: 1.2;
            letter-spacing: -0.02em;
        }

        .stat-card-meta {
            font-size: 0.78rem;
            color: var(--text-secondary);
        }

        .pilot-bar-track {
            height: 7px;
            background: #e2e8f0;
            border-radius: 999px;
            overflow: hidden;
            margin-top: 6px;
            box-shadow: inset 0 1px 2px rgba(0,0,0,0.06);
        }

        .pilot-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #10b981, #059669);
            border-radius: 999px;
            transition: width 0.4s cubic-bezier(0.16, 1, 0.3, 1);
            position: relative;
            overflow: hidden;
        }
        .pilot-bar-fill::after {
            content: '';
            position: absolute;
            top: 0; left: -100%; width: 100%; height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.45), transparent);
            animation: barShimmer 2.4s infinite;
        }
        @keyframes barShimmer {
            0% { left: -100%; }
            50%, 100% { left: 100%; }
        }
        .pilot-bar-fill.warning { background: linear-gradient(90deg, #f59e0b, #d97706); }
        .pilot-bar-fill.danger { background: linear-gradient(90deg, #ef4444, #dc2626); }

        .tier-pill {
            font-size: 0.70rem;
            font-weight: 700;
            padding: 3px 8px;
            border-radius: 6px;
            text-transform: uppercase;
            letter-spacing: 0.03em;
            display: inline-flex;
            align-items: center;
            gap: 4px;
            transition: transform 0.15s ease;
        }
        .tier-pill:hover {
            transform: scale(1.04);
        }
        .tier-pill.tier-trial { background: #ede9fe; color: #5b21b6; border: 1px solid #ddd6fe; }
        .tier-pill.tier-active_partner { background: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; }
        .tier-pill.tier-verified { background: #e0f2fe; color: #0284c7; border: 1px solid #bae6fd; }
        .tier-pill.tier-strategic { background: #fef3c7; color: #b45309; border: 1px solid #fde68a; }

        .creator-avatar-wrap {
            width: 38px;
            height: 38px;
            border-radius: 50%;
            overflow: hidden;
            background: linear-gradient(135deg, #e2e8f0 0%, #cbd5e1 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            color: #334155;
            flex-shrink: 0;
            border: 2px solid #ffffff;
            box-shadow: 0 2px 6px rgba(0,0,0,0.08);
            position: relative;
            transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s ease;
        }
        .creator-avatar-wrap:hover {
            transform: scale(1.08);
            box-shadow: 0 4px 12px rgba(0,0,0,0.14);
        }
        .creator-avatar-wrap img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }

        /* BUTTONS WITH MICRO-INTERACTIONS */
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
            transition: all 0.18s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.07);
        }
        .btn:active {
            transform: translateY(0) scale(0.98);
        }

        .btn-primary {
            background: linear-gradient(135deg, #18181b 0%, #27272a 100%);
            color: #fff;
            border-color: #27272a;
        }
        .btn-primary:hover {
            background: linear-gradient(135deg, #27272a 0%, #3f3f46 100%);
            box-shadow: 0 4px 14px rgba(24, 24, 27, 0.25);
        }

        .btn-secondary {
            background: var(--surface);
            border-color: var(--border);
            color: var(--text-secondary);
        }
        .btn-secondary:hover {
            background: var(--surface-subtle);
            color: var(--text-primary);
            border-color: #cbd5e1;
        }

        .btn-danger {
            background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
            color: #fff;
        }
        .btn-danger:hover {
            background: linear-gradient(135deg, #b91c1c 0%, #991b1b 100%);
            box-shadow: 0 4px 12px rgba(220, 38, 38, 0.25);
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

        /* DATA TABLE (OVERFLOW & Z-INDEX CLIPPING SAFEGUARD) */
        .table-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            overflow: visible; /* Safeguard: ensures action dropdowns never get clipped */
            box-shadow: 0 1px 3px rgba(0,0,0,0.03);
            transition: box-shadow 0.2s ease;
        }
        .table-card:hover {
            box-shadow: 0 4px 16px rgba(0,0,0,0.05);
        }

        .table-responsive {
            width: 100%;
            overflow-x: auto;
            min-height: 250px; /* Ample vertical space for single-row tables so menus never get clipped */
            padding-bottom: 70px;
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
            position: relative;
        }

        table.data-table tr:last-child td {
            border-bottom: none;
        }

        table.data-table tbody tr {
            transition: background 0.15s ease;
        }

        table.data-table tbody tr:hover td {
            background: #f8fafc;
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

        /* REELS AGRONOMY BADGES & ENGAGEMENT METRIC TOKENS */
        .reel-crop-badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: 0.68rem;
            font-weight: 700;
            padding: 2px 7px;
            border-radius: 4px;
            background: #ecfdf5;
            color: #047857;
            border: 1px solid #a7f3d0;
            white-space: nowrap;
        }
        .reel-cat-badge {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: 0.68rem;
            font-weight: 600;
            padding: 2px 7px;
            border-radius: 4px;
            background: #eff6ff;
            color: #1d4ed8;
            border: 1px solid #bfdbfe;
            white-space: nowrap;
        }
        .reel-lang-badge {
            display: inline-flex;
            align-items: center;
            font-size: 0.65rem;
            font-weight: 800;
            padding: 1px 5px;
            border-radius: 3px;
            background: #f5f3ff;
            color: #6d28d9;
            border: 1px solid #ddd6fe;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }
        .reel-source-link {
            display: inline-flex;
            align-items: center;
            gap: 3px;
            font-size: 0.68rem;
            color: var(--text-muted);
            text-decoration: none;
            padding: 1px 5px;
            border-radius: 3px;
            background: var(--surface-subtle);
            border: 1px solid var(--border);
            transition: all 0.15s ease;
        }
        .reel-source-link:hover {
            color: var(--primary);
            border-color: var(--primary);
        }
        .stat-metric-pill {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: 0.72rem;
            font-weight: 600;
            padding: 3px 8px;
            border-radius: 6px;
            background: #f8fafc;
            border: 1px solid var(--border);
            color: var(--text-secondary);
            white-space: nowrap;
            transition: all 0.15s ease;
        }
        .stat-metric-pill.clickable {
            cursor: pointer;
            background: #ffffff;
        }
        .stat-metric-pill.clickable:hover {
            border-color: #3b82f6;
            color: #1d4ed8;
            background: #eff6ff;
            transform: translateY(-1px);
            box-shadow: 0 2px 6px rgba(59, 130, 246, 0.12);
        }
        .payout-status-btn {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: 0.70rem;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 4px;
            border: 1px solid transparent;
            cursor: pointer;
            transition: all 0.15s ease;
            background: none;
        }
        .payout-status-btn.eligible {
            background: #dcfce7;
            color: #15803d;
            border-color: #bbf7d0;
        }
        .payout-status-btn.ineligible {
            background: #f1f5f9;
            color: #64748b;
            border-color: #cbd5e1;
        }
        .payout-status-btn:hover {
            transform: scale(1.03);
        }
        .dup-badge {
            display: inline-flex;
            align-items: center;
            gap: 3px;
            font-size: 0.68rem;
            font-weight: 700;
            padding: 2px 6px;
            border-radius: 4px;
            background: #fef2f2;
            color: #b91c1c;
            border: 1px solid #fecaca;
        }
        .analytics-kpi-card {
            background: #ffffff;
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 14px 16px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.03);
            display: flex;
            flex-direction: column;
            gap: 4px;
            position: relative;
            overflow: hidden;
        }
        .analytics-kpi-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #10b981, #06b6d4);
        }
        .comment-item-card {
            padding: 12px 14px;
            background: #ffffff;
            border: 1px solid var(--border);
            border-radius: 8px;
            margin-bottom: 8px;
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 12px;
            transition: border-color 0.15s ease;
        }
        .comment-item-card:hover {
            border-color: #cbd5e1;
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
        @keyframes livePulse {
            0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
            70% { transform: scale(1); box-shadow: 0 0 0 6px rgba(16, 185, 129, 0); }
            100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
        }
        .pulse-dot {
            animation: livePulse 2s infinite ease-in-out;
        }
        .toast-item {
            background: rgba(255, 255, 255, 0.98);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(228, 228, 231, 0.9);
            border-radius: 10px;
            padding: 12px 16px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.12), 0 8px 10px -6px rgba(0, 0, 0, 0.06);
            display: flex;
            align-items: center;
            gap: 12px;
            min-width: 290px;
            max-width: 440px;
            pointer-events: auto;
            font-size: 0.84rem;
            color: var(--text-primary);
            transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
            transform: translateX(110%);
            opacity: 0;
        }
        .toast-item.show {
            transform: translateX(0);
            opacity: 1;
        }
        .toast-item.hide {
            transform: translateX(110%);
            opacity: 0;
        }
        .toast-item.success { border-left: 4px solid #16a34a; }
        .toast-item.danger { border-left: 4px solid #dc2626; }
        .toast-item.warning { border-left: 4px solid #f59e0b; }
        .toast-item.info { border-left: 4px solid #0284c7; }
        .toast-icon { font-size: 1.2rem; flex-shrink: 0; }
        .toast-item.success .toast-icon { color: #16a34a; }
        .toast-item.danger .toast-icon { color: #dc2626; }
        .toast-item.warning .toast-icon { color: #f59e0b; }
        .toast-item.info .toast-icon { color: #0284c7; }
        .toast-content { flex: 1; line-height: 1.4; }
        .toast-close { border: none; background: transparent; cursor: pointer; color: #a1a1aa; font-size: 1rem; line-height: 1; }
        .toast-close:hover { color: #18181b; }
        .row-suppressed { background: rgba(254, 242, 242, 0.45) !important; }
    </style>
</head>
<body>
    <!-- Real-time Toast Notification Container -->
    <div id="toastContainer" style="position: fixed; top: 24px; right: 24px; z-index: 99999; display: flex; flex-direction: column; gap: 10px; pointer-events: none;"></div>

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
            <?php elseif ($activeTab === 'creators'): ?>
                <button class="btn btn-primary" onclick="openCreateCreatorModal()">
                    <i class="ph ph-user-plus"></i> New Creator
                </button>
            <?php elseif ($activeTab === 'shop_banners'): ?>
                <button class="btn btn-primary" onclick="openShopBannerModal()">
                    <i class="ph ph-plus"></i> New Banner
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
                    <div class="dropdown-option" @click="openCreateCreatorModal(); open = false;">
                        <span><i class="ph ph-user-plus"></i> + Add Creator Partner</span>
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
        <a href="?tab=shop_banners" class="tab-link <?= $activeTab === 'shop_banners' ? 'active' : '' ?>">
            <i class="ph ph-image-square"></i> Shop Banners
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
        <!-- TAB: SHOP BANNERS (Agri Shop home carousel) -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'shop_banners'):
            $shopBanners = [];
            $sbNow = date('Y-m-d H:i:s');
            if (isset($pdo) && $pdo instanceof PDO) {
                try {
                    $sbNow = (string)$pdo->query("SELECT NOW()")->fetchColumn();
                    $shopBanners = $pdo->query("SELECT * FROM shop_banners ORDER BY sort_order ASC, id ASC")->fetchAll();
                } catch (Throwable $e) {
                    $shopBanners = [];
                }
            }
            $sbIcons = ['eco' => 'ph-leaf', 'verified' => 'ph-seal-check', 'local_shipping' => 'ph-truck', 'bolt' => 'ph-lightning', 'star' => 'ph-star', 'agriculture' => 'ph-plant', 'shield' => 'ph-shield-check', 'percent' => 'ph-percent'];
            $sbStatusStyle = [
                'Live' => 'background:#dcfce7; color:#166534;',
                'Scheduled' => 'background:#dbeafe; color:#1e40af;',
                'Expired' => 'background:#fee2e2; color:#991b1b;',
                'Inactive' => 'background:#f1f5f9; color:#475569;',
            ];
            $sbCount = count($shopBanners);
            $sbSafeColor = function ($c, $fallback) {
                return preg_match('/^#[0-9A-Fa-f]{6}$/', (string)$c) ? $c : $fallback;
            };
        ?>
            <style>
                .sb-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 16px; }
                .sb-card { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; display: flex; flex-direction: column; }
                .sb-preview { position: relative; width: 100%; aspect-ratio: 5 / 2; overflow: hidden; color: #fff; }
                .sb-preview img { width: 100%; height: 100%; object-fit: cover; display: block; }
                .sb-preview .sb-text { position: absolute; inset: 0; padding: 4% 5%; display: flex; flex-direction: column; justify-content: center; gap: 4px; }
                .sb-preview .sb-tag { font-size: 0.62rem; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; opacity: 0.85; }
                .sb-preview .sb-title { font-size: 1.05rem; font-weight: 800; line-height: 1.15; max-width: 70%; }
                .sb-preview .sb-sub { font-size: 0.72rem; opacity: 0.9; max-width: 65%; line-height: 1.3; }
                .sb-preview .sb-cta { margin-top: 4px; align-self: flex-start; background: #fff; color: #064E3B; font-size: 0.68rem; font-weight: 700; padding: 3px 10px; border-radius: 999px; }
                .sb-preview .sb-badge { position: absolute; top: 8px; right: 8px; background: rgba(255,255,255,0.22); font-size: 0.64rem; font-weight: 700; padding: 2px 8px; border-radius: 999px; }
                .sb-preview .sb-icon { position: absolute; right: 6%; bottom: 10%; font-size: 3.2rem; opacity: 0.28; }
                .sb-meta { padding: 12px 14px; display: flex; flex-direction: column; gap: 8px; }
                .sb-actions { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
                .sb-pill { font-size: 0.68rem; font-weight: 700; padding: 2px 8px; border-radius: 999px; }
            </style>

            <div class="section-toolbar">
                <div style="font-size: 0.82rem; color: var(--text-muted);">
                    <?= $sbCount ?> banner<?= $sbCount === 1 ? '' : 's' ?> &bull; shown in the Agri Shop carousel in the order below.
                    Status and schedule times use server time (now: <?= htmlspecialchars($sbNow) ?>).
                    Banner image: 1250x500 px (5:2). It will be cropped/resized automatically.
                </div>
            </div>

            <?php if (empty($shopBanners)): ?>
                <div class="table-card" style="padding: 36px; text-align: center; color: var(--text-muted);">
                    No shop banners yet. Click "+ New Banner" to create one.
                </div>
            <?php else: ?>
                <div class="sb-grid">
                    <?php foreach ($shopBanners as $i => $b):
                        $st = shopBannerStatus($b, $sbNow);
                        $c1 = $sbSafeColor($b['bg_color_1'], '#064E3B');
                        $c2 = $sbSafeColor($b['bg_color_2'], '#047857');
                        $icoClass = $sbIcons[$b['icon_key'] ?? ''] ?? '';
                        $targetLabel = $b['target_type'] === 'none' ? 'No link' : ucfirst($b['target_type']) . ': ' . mb_strimwidth((string)$b['target_value'], 0, 40, '...');
                    ?>
                        <div class="sb-card">
                            <?php if (!empty($b['image_url'])): ?>
                                <div class="sb-preview" style="background:#e2e8f0;">
                                    <img src="<?= htmlspecialchars($b['image_url']) ?>" alt="Banner #<?= (int)$b['id'] ?>" loading="lazy">
                                </div>
                            <?php else: ?>
                                <div class="sb-preview" style="background: linear-gradient(135deg, <?= htmlspecialchars($c1) ?>, <?= htmlspecialchars($c2) ?>);">
                                    <?php if ($icoClass): ?><i class="ph <?= $icoClass ?> sb-icon"></i><?php endif; ?>
                                    <?php if (!empty($b['badge_en'])): ?><span class="sb-badge"><?= htmlspecialchars($b['badge_en']) ?></span><?php endif; ?>
                                    <div class="sb-text">
                                        <?php if (!empty($b['tag_en'])): ?><div class="sb-tag"><?= htmlspecialchars($b['tag_en']) ?></div><?php endif; ?>
                                        <div class="sb-title"><?= htmlspecialchars($b['title_en']) ?></div>
                                        <?php if (!empty($b['subtitle_en'])): ?><div class="sb-sub"><?= htmlspecialchars($b['subtitle_en']) ?></div><?php endif; ?>
                                        <?php if (!empty($b['cta_text_en'])): ?><div class="sb-cta"><?= htmlspecialchars($b['cta_text_en']) ?></div><?php endif; ?>
                                    </div>
                                </div>
                            <?php endif; ?>

                            <div class="sb-meta">
                                <div style="display:flex; align-items:center; justify-content:space-between; gap:8px; flex-wrap:wrap;">
                                    <div style="font-weight:600; color:var(--text-primary); font-size:0.88rem;">
                                        #<?= (int)$b['id'] ?> &middot; <?= htmlspecialchars(mb_strimwidth($b['title_en'], 0, 40, '...')) ?>
                                    </div>
                                    <span class="sb-pill" style="<?= $sbStatusStyle[$st] ?>"><?= htmlspecialchars($st) ?></span>
                                </div>
                                <div style="font-size:0.76rem; color:var(--text-muted); line-height:1.5;">
                                    Order: <strong><?= (int)$b['sort_order'] ?></strong> &bull;
                                    <?= !empty($b['image_url']) ? 'Image banner' : 'Gradient banner' ?> &bull;
                                    <?= htmlspecialchars($targetLabel) ?>
                                    <?php if (!empty($b['start_at']) || !empty($b['end_at'])): ?>
                                        <br><?= !empty($b['start_at']) ? 'From ' . htmlspecialchars(date('M d, Y H:i', strtotime($b['start_at']))) : '' ?>
                                        <?= !empty($b['end_at']) ? 'until ' . htmlspecialchars(date('M d, Y H:i', strtotime($b['end_at']))) : '' ?>
                                    <?php endif; ?>
                                </div>
                                <div class="sb-actions">
                                    <form method="POST" style="margin:0;">
                                        <input type="hidden" name="action" value="reorder_shop_banners">
                                        <input type="hidden" name="banner_id" value="<?= (int)$b['id'] ?>">
                                        <input type="hidden" name="direction" value="up">
                                        <button type="submit" class="btn btn-secondary btn-sm" title="Move up" <?= $i === 0 ? 'disabled' : '' ?>><i class="ph ph-arrow-up"></i></button>
                                    </form>
                                    <form method="POST" style="margin:0;">
                                        <input type="hidden" name="action" value="reorder_shop_banners">
                                        <input type="hidden" name="banner_id" value="<?= (int)$b['id'] ?>">
                                        <input type="hidden" name="direction" value="down">
                                        <button type="submit" class="btn btn-secondary btn-sm" title="Move down" <?= $i === $sbCount - 1 ? 'disabled' : '' ?>><i class="ph ph-arrow-down"></i></button>
                                    </form>
                                    <button type="button" class="btn btn-secondary btn-sm" onclick='openShopBannerModal(<?= json_encode($b, JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP | JSON_HEX_TAG | JSON_INVALID_UTF8_SUBSTITUTE) ?: '{}' ?>)' title="Edit">
                                        <i class="ph ph-pencil"></i> Edit
                                    </button>
                                    <form method="POST" style="margin:0;">
                                        <input type="hidden" name="action" value="toggle_shop_banner">
                                        <input type="hidden" name="banner_id" value="<?= (int)$b['id'] ?>">
                                        <button type="submit" class="btn btn-secondary btn-sm" title="<?= !empty($b['is_active']) ? 'Deactivate' : 'Activate' ?>">
                                            <i class="ph <?= !empty($b['is_active']) ? 'ph-eye-slash' : 'ph-eye' ?>"></i> <?= !empty($b['is_active']) ? 'Deactivate' : 'Activate' ?>
                                        </button>
                                    </form>
                                    <button type="button" class="btn btn-danger-outline btn-sm" style="margin-left:auto;" onclick='promptShopBannerDelete(<?= (int)$b['id'] ?>, <?= json_encode($b['title_en'], JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP | JSON_HEX_TAG) ?>)' title="Delete banner">
                                        <i class="ph ph-trash"></i> Delete
                                    </button>
                                </div>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
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

            <!-- Moderation Filter Tabs & Real-Time Sync Indicator -->
            <div style="display: flex; gap: 8px; margin-bottom: 16px; overflow-x: auto; padding-bottom: 4px; align-items: center;">
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
                <a href="?tab=reels&moderation_status=suspended_creator<?= !empty($searchQuery) ? '&q='.urlencode($searchQuery) : '' ?>" 
                   class="btn btn-sm <?= $moderationFilter === 'suspended_creator' ? 'btn-primary' : 'btn-secondary' ?>" style="text-decoration: none; border-radius: 20px; font-size: 0.78rem; <?= $suspendedCreatorReelsCount > 0 ? 'border-color: #ef4444; color: #b91c1c; background: #fef2f2;' : '' ?>" title="Reels automatically deactivated because their creator is suspended">
                   🚫 Suspended Creator Reels (<?= $suspendedCreatorReelsCount ?>)
                </a>

                <div id="reelsRealtimeIndicator" style="margin-left: auto; display: inline-flex; align-items: center; gap: 6px; font-size: 0.75rem; color: #10b981; font-weight: 500; background: rgba(16, 185, 129, 0.08); padding: 5px 12px; border-radius: 9999px; border: 1px solid rgba(16, 185, 129, 0.25); white-space: nowrap;">
                    <span class="pulse-dot" style="width: 8px; height: 8px; border-radius: 50%; background: #10b981; display: inline-block;"></span>
                    <span id="reelsRealtimeText">Real-Time Sync Active</span>
                </div>
            </div>

            <form id="bulkReelsForm" method="POST">
                <input type="hidden" name="action" id="bulkReelsAction" value="bulk_delete_reels">

                <div class="bulk-bar" id="reelsBulkBar">
                    <span id="reelsSelectedCount">0 reels selected</span>
                    <button type="submit" class="btn btn-sm" style="background:#15803d; color:#fff; border-color:#15803d;" onclick="document.getElementById('bulkReelsAction').value='bulk_approve_reels';">
                        <i class="ph ph-check-circle"></i> Approve Selected
                    </button>
                    <button type="button" class="btn btn-danger btn-sm" onclick="document.getElementById('bulkReelsAction').value='bulk_delete_reels'; confirmBulkDelete('bulkReelsForm', 'selected reels')">
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
                                    <th>Caption & Taxonomy</th>
                                    <th>Creator</th>
                                    <th>Audio</th>
                                    <th>Status & Eligibility</th>
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
                                        $cropVal = $rel['crop'] ?: 'General';
                                        $catVal = $rel['category'] ?: 'Crop Care';
                                        $langVal = $rel['language'] ?: 'te';
                                        $isDup = intval($rel['is_duplicate'] ?? 0);
                                        $isPayout = intval($rel['payout_eligible'] ?? 1);
                                        $rightsVal = intval($rel['rights_declared'] ?? 1);
                                        $isCreatorSuspended = (($rel['creator_status'] ?? '') === 'suspended');
                                ?>
                                    <tr id="reel-row-<?= $rel['id'] ?>" data-reel-id="<?= $rel['id'] ?>" data-creator-id="<?= $rel['creator_id'] ?? '' ?>" data-creator-status="<?= htmlspecialchars($rel['creator_status'] ?? '') ?>" class="<?= $isCreatorSuspended ? 'row-suppressed' : '' ?>">
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
                                        <td style="max-width: 320px;">
                                            <div style="font-weight: 600; color: var(--text-primary); line-height: 1.35; margin-bottom: 4px;">
                                                <?= htmlspecialchars($rel['caption']) ?>
                                            </div>
                                            <div style="display: flex; gap: 4px; flex-wrap: wrap; align-items: center; margin-bottom: 4px;">
                                                <span class="reel-crop-badge"><i class="ph ph-plant"></i> <?= htmlspecialchars($cropVal) ?></span>
                                                <span class="reel-cat-badge"><i class="ph ph-tag"></i> <?= htmlspecialchars($catVal) ?></span>
                                                <span class="reel-lang-badge"><?= strtoupper(htmlspecialchars($langVal)) ?></span>
                                                <?php if (!empty($rel['source_url'])): ?>
                                                    <a href="<?= htmlspecialchars($rel['source_url']) ?>" target="_blank" class="reel-source-link" title="<?= htmlspecialchars($rel['source_url']) ?>">
                                                        <i class="ph ph-arrow-square-out"></i> Source
                                                    </a>
                                                <?php endif; ?>
                                                <?php if ($rightsVal === 1): ?>
                                                    <span style="font-size: 0.65rem; color: #16a34a; font-weight: 600; display: inline-flex; align-items: center; gap: 2px;" title="Original rights declared by creator">
                                                        <i class="ph ph-shield-check"></i> Rights OK
                                                    </span>
                                                <?php endif; ?>
                                                <span id="reel-dup-badge-<?= $rel['id'] ?>" class="dup-badge" style="<?= $isDup === 1 ? '' : 'display: none;' ?>" title="Flagged as duplicate content">
                                                    <i class="ph ph-warning"></i> Duplicate
                                                </span>
                                            </div>
                                            <?php if (!empty($rel['tags'])): ?>
                                                <div style="font-size: 0.72rem; color: var(--text-muted);">
                                                    <?= htmlspecialchars($rel['tags']) ?>
                                                </div>
                                            <?php endif; ?>
                                        </td>
                                        <td id="reel-creator-cell-<?= $rel['id'] ?>">
                                            <div style="font-size: 0.82rem; font-weight: 600; display: flex; align-items: center; gap: 5px; flex-wrap: wrap;">
                                                <span><?= htmlspecialchars($rel['creator_name'] ?: 'CropSync Creator') ?></span>
                                                <?php if ($isCreatorSuspended): ?>
                                                    <span class="badge" style="background:#fee2e2; color:#b91c1c; font-size:0.65rem; padding:1px 6px; border-radius:4px; font-weight:700; display:inline-flex; align-items:center; gap:3px;" title="Creator account is currently suspended">
                                                        <i class="ph ph-prohibit"></i> Suspended
                                                    </span>
                                                <?php endif; ?>
                                            </div>
                                            <div style="font-size: 0.72rem; color: var(--text-muted);"><?= htmlspecialchars($rel['phone_number'] ?: '') ?></div>
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                            <i class="ph ph-music-note"></i> <?= htmlspecialchars($rel['music_title'] ?: 'Original Audio') ?>
                                        </td>
                                        <td id="reel-status-cell-<?= $rel['id'] ?>">
                                            <?php if ($isCreatorSuspended): ?>
                                                <span class="status-tag hidden" style="background:#fef2f2; color:#991b1b; border: 1px solid #fecaca; font-weight:700; display:inline-flex; align-items:center; gap:4px;" title="Creator account is suspended. This reel is forcibly deactivated and hidden from all public feeds.">
                                                    <i class="ph ph-prohibit"></i> Suppressed (Creator Suspended)
                                                </span>
                                                <div style="font-size:0.7rem; color:#b91c1c; margin-top:2px; font-weight:500;">Feed Hidden & Ineligible</div>
                                            <?php elseif ($rStatus === 'approved'): ?>
                                                <span class="status-tag active" style="background:#dcfce7; color:#15803d; font-weight:600; display:inline-flex; align-items:center; gap:4px;">
                                                    <i class="ph ph-check-circle"></i> Live & Approved
                                                </span>
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

                                            <!-- Controls Cluster: Realtime Live Visibility, Payout Eligibility & Duplicate -->
                                            <div style="display: flex; gap: 4px; flex-wrap: wrap; margin-top: 6px; align-items: center;">
                                                <button type="button" 
                                                        class="btn btn-sm reel-visibility-btn" 
                                                        id="reel-vis-btn-<?= $rel['id'] ?>"
                                                        data-reel-id="<?= $rel['id'] ?>" 
                                                        data-active="<?= intval($rel['is_active']) ?>"
                                                        data-creator-status="<?= htmlspecialchars($rel['creator_status'] ?? '') ?>"
                                                        onclick="realtimeToggleReelVisibility(<?= $rel['id'] ?>, this)"
                                                        style="padding: 1px 6px; font-size: 0.68rem; border-radius: 4px; <?= intval($rel['is_active']) === 1 ? 'background: #f0fdf4; color: #166534; border: 1px solid #bbf7d0;' : 'background: #f1f5f9; color: #64748b; border: 1px solid #cbd5e1;' ?>" 
                                                        title="Toggle Feed Visibility (Instant Realtime)">
                                                    <?= intval($rel['is_active']) === 1 ? '🟢 Visible' : '⚫ Hidden' ?>
                                                </button>

                                                <button type="button" 
                                                        class="payout-status-btn <?= $isPayout === 1 ? 'eligible' : 'ineligible' ?>" 
                                                        id="reel-payout-btn-<?= $rel['id'] ?>"
                                                        data-reel-id="<?= $rel['id'] ?>" 
                                                        data-eligible="<?= $isPayout ?>"
                                                        data-creator-status="<?= htmlspecialchars($rel['creator_status'] ?? '') ?>"
                                                        onclick="realtimeToggleReelPayout(<?= $rel['id'] ?>, this)"
                                                        title="Toggle Partner Program Payout Eligibility (Instant Realtime)">
                                                    <i class="ph ph-currency-inr"></i> <?= $isPayout === 1 ? 'Payout OK' : 'No Payout' ?>
                                                </button>

                                                <button type="button" 
                                                        class="btn btn-sm reel-dup-btn" 
                                                        id="reel-dup-btn-<?= $rel['id'] ?>"
                                                        data-reel-id="<?= $rel['id'] ?>" 
                                                        data-duplicate="<?= $isDup ?>"
                                                        onclick="realtimeToggleReelDuplicate(<?= $rel['id'] ?>, this)"
                                                        style="padding: 1px 6px; font-size: 0.68rem; border-radius: 4px; <?= $isDup === 1 ? 'background: #fee2e2; color: #b91c1c; border: 1px solid #fecaca;' : 'background: #f8fafc; color: #94a3b8; border: 1px solid #e2e8f0;' ?>" 
                                                        title="Toggle Duplicate Flag (Instant Realtime)">
                                                    <?= $isDup === 1 ? '⚠️ Dup Flag' : 'Mark Dup' ?>
                                                </button>
                                            </div>
                                        </td>
                                        <td>
                                            <div style="display: flex; flex-direction: column; gap: 4px;">
                                                <div style="display: flex; gap: 4px; flex-wrap: wrap;">
                                                    <span class="stat-metric-pill" title="Total Views"><i class="ph ph-eye"></i> <span id="reel-views-<?= $rel['id'] ?>"><?= number_format($rel['views_count']) ?></span></span>
                                                    <span class="stat-metric-pill" title="Likes"><i class="ph ph-heart" style="color:#ef4444;"></i> <span id="reel-likes-<?= $rel['id'] ?>"><?= number_format($rel['likes_count']) ?></span></span>
                                                </div>
                                                <div style="display: flex; gap: 4px; flex-wrap: wrap;">
                                                    <span class="stat-metric-pill" title="Saves / Bookmarks"><i class="ph ph-bookmark" style="color:#0284c7;"></i> <span id="reel-saves-<?= $rel['id'] ?>"><?= number_format($rel['saves_count'] ?? 0) ?></span></span>
                                                    <span class="stat-metric-pill clickable" onclick="openReelCommentsModal(<?= $rel['id'] ?>, '<?= htmlspecialchars(addslashes(mb_strimwidth($rel['caption'], 0, 30, '...'))) ?>')" title="View and moderate <?= number_format($rel['comments_count'] ?? 0) ?> comments">
                                                        <i class="ph ph-chat-circle" style="color:#10b981;"></i> <span id="reel-comments-<?= $rel['id'] ?>"><?= number_format($rel['comments_count'] ?? 0) ?></span>
                                                    </span>
                                                </div>
                                            </div>
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                            <?= date('M d, Y', strtotime($rel['created_at'])) ?>
                                        </td>
                                        <td style="text-align: right; white-space: nowrap;">
                                            <?php if ($rStatus !== 'approved' && !$isCreatorSuspended): ?>
                                                <button type="button" class="btn btn-sm" id="quick-approve-btn-<?= $rel['id'] ?>" style="background:#15803d; color:white; border-color:#15803d; padding:4px 9px; font-size:0.75rem;" onclick="quickApproveReel(<?= $rel['id'] ?>, '<?= htmlspecialchars(addslashes(mb_strimwidth($rel['caption'], 0, 30, '...'))) ?>', '<?= htmlspecialchars($rel['creator_status'] ?? '') ?>')" title="Quick Approve & Make Live">
                                                    <i class="ph ph-check"></i> Approve
                                                </button>
                                            <?php elseif ($isCreatorSuspended): ?>
                                                <button type="button" class="btn btn-sm" style="background:#fee2e2; color:#b91c1c; border-color:#fecaca; padding:4px 9px; font-size:0.75rem; cursor:not-allowed;" title="Cannot approve reel while creator is suspended" disabled>
                                                    <i class="ph ph-prohibit"></i> Blocked
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
                                            <button type="button" class="btn btn-secondary btn-sm" onclick="openReelAnalyticsModal(<?= $rel['id'] ?>, '<?= htmlspecialchars(addslashes(mb_strimwidth($rel['caption'], 0, 30, '...'))) ?>')" title="Watch time, completion rate & audience actions">
                                                <i class="ph ph-chart-line-up"></i>
                                            </button>
                                            <button type="button" class="btn btn-secondary btn-sm" onclick="openReelCommentsModal(<?= $rel['id'] ?>, '<?= htmlspecialchars(addslashes(mb_strimwidth($rel['caption'], 0, 30, '...'))) ?>')" title="Comments moderation">
                                                <i class="ph ph-chat-circle-dots"></i>
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
        <!-- ============================================================== -->
        <!-- TAB: CREATOR PARTNER MANAGEMENT & ROSTER -->
        <!-- ============================================================== -->
        <?php if ($activeTab === 'creators'): ?>
            <!-- Header Bar -->
            <div class="filter-header-bar" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; flex-wrap: wrap; gap: 14px;">
                <div>
                    <h2 style="font-size: 1.25rem; font-weight: 700; color: var(--text-primary); margin-bottom: 4px; display: flex; align-items: center; gap: 8px;">
                        <i class="ph ph-users-three" style="color: var(--accent);"></i> Agri Creator Partner Network
                    </h2>
                    <p style="font-size: 0.85rem; color: var(--text-muted); margin: 0;">
                        Manage verified agricultural creators, review applications, configure tiers, and monitor reels reach.
                    </p>
                </div>
                <div style="display: flex; gap: 10px; align-items: center;">
                    <button type="button" class="btn btn-primary" onclick="openCreateCreatorModal()">
                        <i class="ph ph-user-plus"></i> Enroll Creator
                    </button>
                </div>
            </div>

            <!-- Stats & Capacity Grid -->
            <div class="creator-stats-grid">
                <!-- Pilot Capacity Card -->
                <?php 
                    $capPct = min(100, round(($activeCreatorsCount / 25) * 100));
                    $capBarClass = $activeCreatorsCount >= 25 ? 'danger' : ($activeCreatorsCount >= 20 ? 'warning' : '');
                ?>
                <div class="creator-stat-card card-pilot">
                    <div class="stat-card-label">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span class="stat-icon-circle emerald"><i class="ph ph-shield-check"></i></span>
                            <span>Pilot Partner Cap</span>
                        </div>
                        <span class="status-tag <?= $activeCreatorsCount >= 25 ? 'danger' : 'active' ?>" style="font-size: 0.68rem;">
                            <span class="pulse-dot <?= $activeCreatorsCount >= 25 ? 'warning' : '' ?>" style="margin-right: 4px;"></span>
                            <?= $activeCreatorsCount >= 25 ? 'Capacity Full' : 'Enrolling' ?>
                        </span>
                    </div>
                    <div class="stat-card-value" style="color: <?= $activeCreatorsCount >= 25 ? 'var(--danger)' : '#0f172a' ?>;">
                        <?= $activeCreatorsCount ?> <span style="font-size: 1rem; font-weight: 500; color: var(--text-muted);">/ 25 Active</span>
                    </div>
                    <div class="pilot-bar-track">
                        <div class="pilot-bar-fill <?= $capBarClass ?>" style="width: <?= $capPct ?>%;"></div>
                    </div>
                    <div class="stat-card-meta" style="margin-top: 4px;">
                        <?= max(0, 25 - $activeCreatorsCount) ?> active partner slot<?= max(0, 25 - $activeCreatorsCount) === 1 ? '' : 's' ?> remaining
                    </div>
                </div>

                <!-- Review Queue Card -->
                <div class="creator-stat-card card-queue">
                    <div class="stat-card-label">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span class="stat-icon-circle amber"><i class="ph ph-clock-countdown"></i></span>
                            <span>Review Queue</span>
                        </div>
                        <?php if ($pendingCreatorsCount > 0): ?>
                            <span class="status-tag warning" style="font-size: 0.68rem;">
                                <span class="pulse-dot warning" style="margin-right: 4px;"></span>
                                <?= $pendingCreatorsCount ?> Pending
                            </span>
                        <?php endif; ?>
                    </div>
                    <div class="stat-card-value" style="color: <?= $pendingCreatorsCount > 0 ? '#b45309' : '#0f172a' ?>;">
                        <?= $pendingCreatorsCount ?>
                    </div>
                    <div class="stat-card-meta">
                        <a href="?tab=creators&creator_status=pending_review" style="color: #b45309; text-decoration: none; font-weight: 600;">
                            View pending applications &rarr;
                        </a>
                    </div>
                </div>

                <!-- Verified Roster Card -->
                <div class="creator-stat-card card-verified">
                    <div class="stat-card-label">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span class="stat-icon-circle sky"><i class="ph-fill ph-check-circle"></i></span>
                            <span>Verified Partners</span>
                        </div>
                    </div>
                    <div class="stat-card-value" style="color: #0369a1;">
                        <?= $verifiedCreatorsCount ?>
                    </div>
                    <div class="stat-card-meta">
                        Out of <?= $totalCreatorsCount ?> total creator accounts
                    </div>
                </div>

                <!-- Engagement Reach Card -->
                <div class="creator-stat-card card-impact">
                    <div class="stat-card-label">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span class="stat-icon-circle violet"><i class="ph ph-eye"></i></span>
                            <span>Content Impact</span>
                        </div>
                    </div>
                    <div class="stat-card-value" style="color: #6d28d9;">
                        <?= number_format($totalCreatorViews) ?>
                    </div>
                    <div class="stat-card-meta">
                        Generated by <?= number_format($totalCreatorReels) ?> published agri reels
                    </div>
                </div>
            </div>

            <?php if ($activeCreatorsCount >= 25): ?>
                <div class="alert-banner warning" style="margin-bottom: 20px;">
                    <i class="ph ph-warning-circle" style="font-size: 1.2rem;"></i>
                    <span><strong>Pilot Capacity Reached:</strong> 25 active creators are currently enrolled. New approvals are blocked until existing partners are suspended or the pilot cap is expanded.</span>
                </div>
            <?php endif; ?>

            <!-- Filter Toolbar (100% Alpine.js Custom Dropdowns) -->
            <div class="section-toolbar">
                <div class="filter-group">
                    <!-- Search Input -->
                    <div class="search-wrapper">
                        <i class="ph ph-magnifying-glass"></i>
                        <input type="text" class="search-input" id="creatorSearch" placeholder="Search name, phone, niches..." value="<?= htmlspecialchars($searchQuery) ?>" onkeydown="if(event.key==='Enter'){ applyCreatorFilter('q', this.value); }">
                    </div>

                    <!-- Alpine Dropdown: Status Filter -->
                    <?php
                        $statusMap = [
                            'all' => 'All Statuses',
                            'active' => 'Active Partners',
                            'pending_review' => 'Pending Review',
                            'applied' => 'New Applications',
                            'suspended' => 'Suspended',
                            'rejected' => 'Rejected'
                        ];
                        $curStatusLabel = $statusMap[$creatorStatusFilter] ?? 'All Statuses';
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($curStatusLabel)) ?>', val: '<?= htmlspecialchars($creatorStatusFilter) ?>' }" @click.outside="open = false">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <?php foreach ($statusMap as $sKey => $sName): ?>
                                <div class="alpine-select-option" :class="{ 'selected': val === '<?= $sKey ?>' }" @click="label = '<?= htmlspecialchars(addslashes($sName)) ?>'; val = '<?= $sKey ?>'; open = false; applyCreatorFilter('creator_status', '<?= $sKey ?>');">
                                    <span><?= htmlspecialchars($sName) ?></span>
                                    <i class="ph ph-check check-icon" x-show="val === '<?= $sKey ?>'"></i>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <!-- Alpine Dropdown: Tier Filter -->
                    <?php
                        $tierMap = [
                            'all' => 'All Tiers',
                            'trial' => 'Trial (M1)',
                            'active_partner' => 'Active Partner (M2-3)',
                            'verified' => 'Verified Partner',
                            'strategic' => 'Strategic Partner'
                        ];
                        $curTierLabel = $tierMap[$creatorTierFilter] ?? 'All Tiers';
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($curTierLabel)) ?>', val: '<?= htmlspecialchars($creatorTierFilter) ?>' }" @click.outside="open = false">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <?php foreach ($tierMap as $tKey => $tName): ?>
                                <div class="alpine-select-option" :class="{ 'selected': val === '<?= $tKey ?>' }" @click="label = '<?= htmlspecialchars(addslashes($tName)) ?>'; val = '<?= $tKey ?>'; open = false; applyCreatorFilter('creator_tier', '<?= $tKey ?>');">
                                    <span><?= htmlspecialchars($tName) ?></span>
                                    <i class="ph ph-check check-icon" x-show="val === '<?= $tKey ?>'"></i>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <!-- Alpine Dropdown: Verification Filter -->
                    <?php
                        $verifMap = [
                            'all' => 'All Verification',
                            'verified' => 'Verified Only',
                            'unverified' => 'Unverified'
                        ];
                        $curVerifLabel = $verifMap[$creatorVerifiedFilter] ?? 'All Verification';
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($curVerifLabel)) ?>', val: '<?= htmlspecialchars($creatorVerifiedFilter) ?>' }" @click.outside="open = false">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <?php foreach ($verifMap as $vKey => $vName): ?>
                                <div class="alpine-select-option" :class="{ 'selected': val === '<?= $vKey ?>' }" @click="label = '<?= htmlspecialchars(addslashes($vName)) ?>'; val = '<?= $vKey ?>'; open = false; applyCreatorFilter('creator_verified', '<?= $vKey ?>');">
                                    <span><?= htmlspecialchars($vName) ?></span>
                                    <i class="ph ph-check check-icon" x-show="val === '<?= $vKey ?>'"></i>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <!-- Alpine Dropdown: Sort Order -->
                    <?php
                        $sortMap = [
                            'newest' => 'Newest First',
                            'most_views' => 'Most Views',
                            'most_reels' => 'Most Reels',
                            'name_asc' => 'Name (A-Z)',
                            'oldest' => 'Oldest First'
                        ];
                        $curSortLabel = $sortMap[$creatorSort] ?? 'Newest First';
                    ?>
                    <div class="alpine-select-wrapper" x-data="{ open: false, label: '<?= htmlspecialchars(addslashes($curSortLabel)) ?>', val: '<?= htmlspecialchars($creatorSort) ?>' }" @click.outside="open = false">
                        <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                            <span x-text="label"></span>
                            <i class="ph ph-caret-down"></i>
                        </div>
                        <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                            <?php foreach ($sortMap as $soKey => $soName): ?>
                                <div class="alpine-select-option" :class="{ 'selected': val === '<?= $soKey ?>' }" @click="label = '<?= htmlspecialchars(addslashes($soName)) ?>'; val = '<?= $soKey ?>'; open = false; applyCreatorFilter('creator_sort', '<?= $soKey ?>');">
                                    <span><?= htmlspecialchars($soName) ?></span>
                                    <i class="ph ph-check check-icon" x-show="val === '<?= $soKey ?>'"></i>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <!-- Reset Filters Button -->
                    <?php if ($creatorStatusFilter !== 'all' || $creatorTierFilter !== 'all' || $creatorVerifiedFilter !== 'all' || $creatorSort !== 'newest' || !empty($searchQuery)): ?>
                        <a href="?tab=creators" class="btn btn-secondary btn-sm" style="color: var(--danger); border-color: #fca5a5;">
                            <i class="ph ph-x"></i> Clear Filters
                        </a>
                    <?php endif; ?>
                </div>

                <div style="font-size: 0.82rem; color: var(--text-muted);">
                    Showing <?= count($creatorsList) ?> of <?= $totalCreatorsCount ?> creators
                </div>
            </div>

            <!-- Creators Directory Table Card -->
            <div class="table-card">
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Creator Partner</th>
                                <th>Contact & UPI</th>
                                <th>Specialty & Languages</th>
                                <th>Tier</th>
                                <th>Status</th>
                                <th>Content Reach</th>
                                <th style="text-align: right;">Manage & Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($creatorsList)): ?>
                                <tr>
                                    <td colspan="7" style="text-align: center; color: var(--text-muted); padding: 48px;">
                                        <div style="font-size: 2.2rem; margin-bottom: 8px; color: #94a3b8;">
                                            <i class="ph ph-user-focus"></i>
                                        </div>
                                        <div style="font-weight: 600; font-size: 0.95rem; color: var(--text-primary); margin-bottom: 4px;">
                                            No Creator Partners Found
                                        </div>
                                        <div style="font-size: 0.82rem; margin-bottom: 16px;">
                                            No creators matched the active filters. Try adjusting your search or enroll a new creator.
                                        </div>
                                        <button type="button" class="btn btn-primary btn-sm" onclick="openCreateCreatorModal()">
                                            <i class="ph ph-user-plus"></i> Enroll Creator Partner
                                        </button>
                                    </td>
                                </tr>
                            <?php else: foreach ($creatorsList as $cr): ?>
                                <tr>
                                    <!-- Creator Partner Identity -->
                                    <td>
                                        <div style="display: flex; align-items: center; gap: 12px;">
                                            <div class="creator-avatar-wrap">
                                                <?php if (!empty($cr['profile_image_url'])): ?>
                                                    <img src="<?= htmlspecialchars($cr['profile_image_url']) ?>" alt="Avatar" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
                                                    <span style="display: none; width:100%; height:100%; align-items:center; justify-content:center;"><?= strtoupper(substr($cr['display_name'] ?: 'C', 0, 1)) ?></span>
                                                <?php else: ?>
                                                    <span><?= strtoupper(substr($cr['display_name'] ?: 'C', 0, 1)) ?></span>
                                                <?php endif; ?>
                                            </div>
                                            <div>
                                                <div style="font-weight: 700; font-size: 0.88rem; color: var(--text-primary); display: flex; align-items: center; gap: 4px;">
                                                    <?= htmlspecialchars($cr['display_name']) ?>
                                                    <?php if (!empty($cr['is_verified'])): ?>
                                                        <i class="ph-fill ph-check-circle" style="color: #0284c7; font-size: 1rem;" title="Verified Creator Partner"></i>
                                                    <?php endif; ?>
                                                </div>
                                                <div style="font-size: 0.74rem; color: var(--text-muted); display: flex; align-items: center; gap: 6px;">
                                                    <span>@<?= htmlspecialchars($cr['username']) ?></span>
                                                    <span>&bull;</span>
                                                    <span>ID #<?= $cr['id'] ?></span>
                                                </div>
                                                <?php if (!empty($cr['bio'])): ?>
                                                    <div style="font-size: 0.72rem; color: var(--text-secondary); max-width: 240px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 2px;" title="<?= htmlspecialchars($cr['bio']) ?>">
                                                        <?= htmlspecialchars($cr['bio']) ?>
                                                    </div>
                                                <?php endif; ?>
                                            </div>
                                        </div>
                                    </td>

                                    <!-- Contact & UPI Payment -->
                                    <td>
                                        <div style="font-size: 0.82rem; font-weight: 600; color: var(--text-primary); display: flex; align-items: center; gap: 4px;">
                                            <i class="ph ph-phone" style="font-size: 0.8rem; color: var(--text-muted);"></i>
                                            <?= htmlspecialchars($cr['phone_number'] ?: 'No phone') ?>
                                        </div>
                                        <?php if (!empty($cr['email'])): ?>
                                            <div style="font-size: 0.72rem; color: var(--text-muted); max-width: 170px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                                                <?= htmlspecialchars($cr['email']) ?>
                                            </div>
                                        <?php endif; ?>
                                        <div style="margin-top: 3px;">
                                            <?php if (!empty($cr['upi_id'])): ?>
                                                <span style="font-size: 0.70rem; font-family: monospace; background: #f0fdf4; color: #166534; padding: 2px 6px; border-radius: 4px; border: 1px solid #bbf7d0;">
                                                    UPI: <?= htmlspecialchars($cr['upi_id']) ?>
                                                </span>
                                            <?php else: ?>
                                                <span style="font-size: 0.70rem; color: var(--text-muted);">No UPI set</span>
                                            <?php endif; ?>
                                        </div>
                                    </td>

                                    <!-- Specialty & Languages -->
                                    <td>
                                        <div style="font-size: 0.78rem; font-weight: 500; color: var(--text-primary);">
                                            <?= htmlspecialchars($cr['agriculture_niches'] ?: 'General Farming') ?>
                                        </div>
                                        <div style="font-size: 0.72rem; color: var(--text-muted); margin-top: 2px;">
                                            Lang: <strong><?= strtoupper(htmlspecialchars($cr['languages'] ?: 'te')) ?></strong>
                                        </div>
                                    </td>

                                    <!-- Partnership Tier -->
                                    <td>
                                        <?php 
                                            $tier = $cr['partnership_tier'] ?? 'trial';
                                            $tierClass = 'tier-' . $tier;
                                            $tierTitle = str_replace('_', ' ', $tier);
                                        ?>
                                        <span class="tier-pill <?= $tierClass ?>">
                                            <i class="ph ph-medal"></i> <?= htmlspecialchars($tierTitle) ?>
                                        </span>
                                    </td>

                                    <!-- Status -->
                                    <td>
                                        <?php 
                                            $st = $cr['status'] ?? 'active';
                                            $badgeColor = '#dcfce7'; $textColor = '#166534';
                                            if ($st === 'pending_review' || $st === 'applied') { $badgeColor = '#fef3c7'; $textColor = '#92400e'; }
                                            elseif ($st === 'rejected' || $st === 'suspended') { $badgeColor = '#fee2e2'; $textColor = '#991b1b'; }
                                        ?>
                                        <span class="status-tag" style="background: <?= $badgeColor ?>; color: <?= $textColor ?>; text-transform: capitalize; font-weight: 600;">
                                            <?= str_replace('_', ' ', $st) ?>
                                        </span>
                                        <div style="font-size: 0.70rem; color: var(--text-muted); margin-top: 3px;">
                                            <?= !empty($cr['terms_accepted']) ? 'Terms v1.0 ✓' : 'Terms Pending' ?>
                                        </div>
                                    </td>

                                    <!-- Content Reach -->
                                    <td style="font-size: 0.80rem; white-space: nowrap;">
                                        <div>
                                            <strong><?= intval($cr['approved_reels']) ?></strong> / <?= intval($cr['total_reels']) ?> approved
                                        </div>
                                        <div style="font-size: 0.73rem; color: var(--text-muted); margin-top: 2px;">
                                            <i class="ph ph-eye"></i> <?= number_format(intval($cr['total_views'])) ?> views
                                        </div>
                                    </td>

                                    <!-- Manage & Actions (100% Alpine.js Custom Dropdowns & Modals) -->
                                    <td style="text-align: right; white-space: nowrap;">
                                        <!-- Edit Profile Button -->
                                        <button type="button" class="btn btn-secondary btn-sm" onclick='openEditCreatorModal(<?= json_encode($cr, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>)' title="Edit Creator Profile">
                                            <i class="ph ph-pencil"></i> Edit
                                        </button>

                                        <!-- View Reels Filter -->
                                        <a href="?tab=reels&q=<?= urlencode($cr['username']) ?>" class="btn btn-secondary btn-sm" title="View Reels by this Creator">
                                            <i class="ph ph-film-strip"></i> Reels
                                        </a>

                                        <!-- Alpine Dropdown for Additional Actions (Zero Native Selects & Viewport-Aware) -->
                                        <div class="alpine-select-wrapper" style="vertical-align: middle; margin-left: 2px;" x-data="{ open: false, dropUp: false }" :style="open ? 'z-index: 250; position: relative;' : ''" @click.outside="open = false">
                                            <button type="button" class="btn btn-secondary btn-sm" @click="dropUp = ($el.getBoundingClientRect().bottom + 210 > window.innerHeight); open = !open" title="More Creator Options">
                                                <i class="ph ph-dots-three-vertical"></i>
                                            </button>
                                            <div class="alpine-select-menu right-align" :class="{ 'dropup-menu': dropUp }" style="min-width: 185px; z-index: 250;" x-show="open" x-cloak x-transition>
                                                <!-- Toggle Verified -->
                                                <form method="POST" style="margin: 0;">
                                                    <input type="hidden" name="action" value="toggle_creator_verified">
                                                    <input type="hidden" name="creator_id" value="<?= $cr['id'] ?>">
                                                    <div class="alpine-select-option" onclick="this.closest('form').submit()">
                                                        <i class="ph ph-shield-check" style="color: #0284c7;"></i>
                                                        <span><?= !empty($cr['is_verified']) ? 'Revoke Verified Badge' : 'Grant Verified Badge' ?></span>
                                                    </div>
                                                </form>

                                                <!-- Quick Approve / Tier Promote -->
                                                <?php if ($cr['status'] !== 'active'): ?>
                                                    <form method="POST" style="margin: 0;">
                                                        <input type="hidden" name="action" value="admin_approve_creator">
                                                        <input type="hidden" name="creator_id" value="<?= $cr['id'] ?>">
                                                        <input type="hidden" name="approval_action" value="approve">
                                                        <input type="hidden" name="tier" value="active_partner">
                                                        <div class="alpine-select-option" style="color: #15803d;" onclick="this.closest('form').submit()">
                                                            <i class="ph ph-check-circle" style="color: #15803d;"></i>
                                                            <span>Approve Partner</span>
                                                        </div>
                                                    </form>
                                                <?php endif; ?>

                                                <!-- Suspend / Reject -->
                                                <div class="alpine-select-option" style="color: #b45309;" @click="open = false; openRejectCreatorModal(<?= $cr['id'] ?>, '<?= htmlspecialchars(addslashes($cr['display_name'])) ?>', <?= $cr['status'] === 'active' ? 'true' : 'false' ?>)">
                                                    <i class="ph ph-prohibit" style="color: #b45309;"></i>
                                                    <span><?= $cr['status'] === 'active' ? 'Suspend Creator' : 'Reject Application' ?></span>
                                                </div>

                                                <div style="height: 1px; background: var(--border); margin: 4px 0;"></div>

                                                <!-- Delete Creator -->
                                                <div class="alpine-select-option" style="color: #dc2626;" @click="open = false; openDeleteCreatorModal(<?= $cr['id'] ?>, '<?= htmlspecialchars(addslashes($cr['display_name'])) ?>', '<?= htmlspecialchars(addslashes($cr['username'])) ?>', <?= intval($cr['total_reels']) ?>)">
                                                    <i class="ph ph-trash" style="color: #dc2626;"></i>
                                                    <span>Delete Creator</span>
                                                </div>
                                            </div>
                                        </div>
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
                                            <!-- Alpine Custom Creator Selector -->
                                            <div class="alpine-select-wrapper" style="vertical-align: middle; margin-right: 4px;" x-data="{ open: false, label: 'Select Creator', val: '' }" @click.outside="open = false">
                                                <input type="hidden" name="creator_id" :value="val" required>
                                                <div class="alpine-select-trigger sm" :class="{ 'active': open }" @click="open = !open" style="min-width: 135px; font-size: 0.76rem;">
                                                    <span x-text="label" style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 105px;"></span>
                                                    <i class="ph ph-caret-down"></i>
                                                </div>
                                                <div class="alpine-select-menu right-align" style="max-height: 190px; z-index: 130;" x-show="open" x-cloak x-transition>
                                                    <div class="alpine-select-option" :class="{ 'selected': val === '' }" @click="label = 'Select Creator'; val = ''; open = false;">
                                                        <span>Select Creator</span>
                                                    </div>
                                                    <?php foreach ($allCreators as $cOpt): ?>
                                                        <div class="alpine-select-option" :class="{ 'selected': val == <?= $cOpt['id'] ?> }" @click="label = '<?= htmlspecialchars(addslashes($cOpt['display_name'])) ?>'; val = <?= $cOpt['id'] ?>; open = false;">
                                                            <span><?= htmlspecialchars($cOpt['display_name']) ?></span>
                                                            <i class="ph ph-check check-icon" x-show="val == <?= $cOpt['id'] ?>"></i>
                                                        </div>
                                                    <?php endforeach; ?>
                                                </div>
                                            </div>
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
    <!-- MODAL: CREATE / EDIT CREATOR PARTNER (WITH ALPINE DROPDOWNS & REAL-TIME PREVIEW) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="creatorModal" x-data="{
        isEdit: false,
        creatorId: 0,
        displayName: '',
        username: '',
        phoneNumber: '',
        email: '',
        bio: '',
        profileImageUrl: '',
        niches: '',
        languages: 'te',
        upiId: '',
        socialHandles: '',
        tier: 'trial',
        tierLabel: 'Trial (M1)',
        tierOpen: false,
        status: 'active',
        statusLabel: 'Active Partner',
        statusOpen: false,
        isVerified: 0,
        termsAccepted: 1,
        
        tierOptions: [
            { val: 'trial', label: 'Trial (M1)' },
            { val: 'active_partner', label: 'Active Partner (M2-3)' },
            { val: 'verified', label: 'Verified Partner' },
            { val: 'strategic', label: 'Strategic Partner' }
        ],
        statusOptions: [
            { val: 'active', label: 'Active Partner' },
            { val: 'pending_review', label: 'Pending Review' },
            { val: 'applied', label: 'New Application' },
            { val: 'suspended', label: 'Suspended' },
            { val: 'rejected', label: 'Rejected' }
        ],
        setTier(opt) {
            this.tier = opt.val;
            this.tierLabel = opt.label;
            this.tierOpen = false;
        },
        setStatus(opt) {
            this.status = opt.val;
            this.statusLabel = opt.label;
            this.statusOpen = false;
        },
        populate(data) {
            this.isEdit = true;
            this.creatorId = parseInt(data.id) || 0;
            this.displayName = data.display_name || '';
            this.username = data.username || '';
            this.phoneNumber = data.phone_number || '';
            this.email = data.email || '';
            this.bio = data.bio || '';
            this.profileImageUrl = data.profile_image_url || '';
            this.niches = data.agriculture_niches || '';
            this.languages = data.languages || 'te';
            this.upiId = data.upi_id || '';
            this.socialHandles = data.social_handles || '';
            
            const curTier = data.partnership_tier || 'trial';
            this.tier = curTier;
            const topt = this.tierOptions.find(o => o.val === curTier);
            this.tierLabel = topt ? topt.label : curTier;

            const curStatus = data.status || 'active';
            this.status = curStatus;
            const sopt = this.statusOptions.find(o => o.val === curStatus);
            this.statusLabel = sopt ? sopt.label : curStatus;

            this.isVerified = (parseInt(data.is_verified) === 1 || data.is_verified === true || data.is_verified === '1') ? 1 : 0;
            this.termsAccepted = (parseInt(data.terms_accepted) === 1 || data.terms_accepted === true || data.terms_accepted === '1') ? 1 : 0;
            this.tierOpen = false;
            this.statusOpen = false;
        },
        reset() {
            this.isEdit = false;
            this.creatorId = 0;
            this.displayName = '';
            this.username = '';
            this.phoneNumber = '';
            this.email = '';
            this.bio = '';
            this.profileImageUrl = '';
            this.niches = '';
            this.languages = 'te';
            this.upiId = '';
            this.socialHandles = '';
            this.tier = 'trial';
            this.tierLabel = 'Trial (M1)';
            this.status = 'active';
            this.statusLabel = 'Active Partner';
            this.isVerified = 0;
            this.termsAccepted = 1;
            this.tierOpen = false;
            this.statusOpen = false;
        }
    }"
    @populate-creator.window="populate($event.detail)"
    @reset-creator.window="reset()"
    >
        <div class="modal-card" style="max-width: 680px;">
            <div class="modal-head">
                <h3 id="creatorModalHeading">
                    <i class="ph ph-user-circle" style="color: var(--accent);"></i>
                    <span x-text="isEdit ? 'Edit Creator Partner #' + creatorId : 'Enroll New Creator Partner'"></span>
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('creatorModal')">&times;</button>
            </div>
            <form method="POST" id="creatorForm">
                <input type="hidden" name="action" value="save_creator">
                <input type="hidden" name="creator_id" id="form_creator_id" :value="creatorId" value="0">
                <input type="hidden" name="partnership_tier" id="form_partnership_tier" :value="tier" value="trial">
                <input type="hidden" name="status" id="form_status" :value="status" value="active">

                <div class="modal-body">
                    <!-- Avatar Preview Banner -->
                    <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 20px; padding: 12px 16px; background: var(--surface-subtle); border-radius: 10px; border: 1px solid var(--border);">
                        <div class="creator-avatar-wrap" style="width: 52px; height: 52px; font-size: 1.2rem;">
                            <template x-if="profileImageUrl">
                                <img :src="profileImageUrl" alt="Preview" @error="$el.style.display='none'">
                            </template>
                            <template x-if="!profileImageUrl">
                                <span x-text="displayName ? displayName.charAt(0).toUpperCase() : 'C'"></span>
                            </template>
                        </div>
                        <div style="flex-grow: 1;">
                            <div style="font-weight: 700; font-size: 0.95rem; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
                                <span x-text="displayName || 'Creator Name'"></span>
                                <i class="ph-fill ph-check-circle" style="color: #0284c7;" x-show="isVerified == 1"></i>
                            </div>
                            <div style="font-size: 0.78rem; color: var(--text-muted);">
                                <span x-text="username ? '@' + username : '@username'"></span> &bull; 
                                <span x-text="tierLabel"></span> &bull; 
                                <span x-text="statusLabel" style="text-transform: capitalize;"></span>
                            </div>
                        </div>
                    </div>

                    <!-- Row 1: Display Name & Username -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Display Name *</label>
                            <input type="text" name="display_name" id="form_display_name" x-model="displayName" class="form-input" placeholder="e.g. Ramesh Kumar Patel" required>
                        </div>
                        <div class="form-row">
                            <label>Username / Handle (@)</label>
                            <input type="text" name="username" id="form_username" x-model="username" class="form-input" placeholder="e.g. ramesh_agri (auto-generated if empty)">
                        </div>
                    </div>

                    <!-- Row 2: Phone & Email -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Phone Number (Mobile App Sync) *</label>
                            <input type="text" name="phone_number" id="form_phone_number" x-model="phoneNumber" class="form-input" placeholder="e.g. 9182867655" required>
                        </div>
                        <div class="form-row">
                            <label>Email Address</label>
                            <input type="email" name="email" id="form_email" x-model="email" class="form-input" placeholder="e.g. creator@example.com">
                        </div>
                    </div>

                    <!-- Row 3: Profile Image URL -->
                    <div class="form-row">
                        <label>Profile Image URL</label>
                        <input type="url" name="profile_image_url" id="form_profile_image_url" x-model="profileImageUrl" class="form-input" placeholder="https://images.unsplash.com/... or direct image link">
                    </div>

                    <!-- Row 4: Niches & Languages -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Agricultural Niches & Specialization</label>
                            <input type="text" name="agriculture_niches" id="form_agriculture_niches" x-model="niches" class="form-input" placeholder="e.g. Paddy, Cotton, Organic Farming">
                        </div>
                        <div class="form-row">
                            <label>Languages (comma-separated)</label>
                            <input type="text" name="languages" id="form_languages" x-model="languages" class="form-input" placeholder="e.g. te, hi, en">
                        </div>
                    </div>

                    <!-- Row 5: UPI ID & Social Handles -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>UPI ID (Direct Payout Settlement)</label>
                            <input type="text" name="upi_id" id="form_upi_id" x-model="upiId" class="form-input" placeholder="e.g. 9182867655@ybl or ramesh@okaxis">
                        </div>
                        <div class="form-row">
                            <label>Social Handles / Links</label>
                            <input type="text" name="social_handles" id="form_social_handles" x-model="socialHandles" class="form-input" placeholder="e.g. YouTube: @KrishiTips, Instagram: @agri">
                        </div>
                    </div>

                    <!-- Row 6: Tier & Status Dropdowns (100% Alpine.js Custom Dropdowns) -->
                    <div class="grid-2">
                        <!-- Partnership Tier Alpine Dropdown -->
                        <div class="form-row">
                            <label>Partnership Tier</label>
                            <div class="alpine-select-wrapper full-width" @click.outside="tierOpen = false">
                                <div class="alpine-select-trigger" :class="{ 'active': tierOpen }" @click="tierOpen = !tierOpen">
                                    <span x-text="tierLabel"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="tierOpen" x-cloak x-transition>
                                    <template x-for="opt in tierOptions" :key="opt.val">
                                        <div class="alpine-select-option" :class="{ 'selected': tier === opt.val }" @click="setTier(opt)">
                                            <span x-text="opt.label"></span>
                                            <i class="ph ph-check check-icon" x-show="tier === opt.val"></i>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>

                        <!-- Account Status Alpine Dropdown -->
                        <div class="form-row">
                            <label>Account Status</label>
                            <div class="alpine-select-wrapper full-width" @click.outside="statusOpen = false">
                                <div class="alpine-select-trigger" :class="{ 'active': statusOpen }" @click="statusOpen = !statusOpen">
                                    <span x-text="statusLabel"></span>
                                    <i class="ph ph-caret-down"></i>
                                </div>
                                <div class="alpine-select-menu" x-show="statusOpen" x-cloak x-transition>
                                    <template x-for="opt in statusOptions" :key="opt.val">
                                        <div class="alpine-select-option" :class="{ 'selected': status === opt.val }" @click="setStatus(opt)">
                                            <span x-text="opt.label"></span>
                                            <i class="ph ph-check check-icon" x-show="status === opt.val"></i>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Row 7: Bio -->
                    <div class="form-row">
                        <label>Bio / Agricultural Background</label>
                        <textarea name="bio" id="form_bio" x-model="bio" class="form-input" rows="2" placeholder="Brief creator background, farming experience, region, expertise..."></textarea>
                    </div>

                    <!-- Row 8: Toggles -->
                    <div style="display: flex; gap: 24px; padding: 10px 14px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border); flex-wrap: wrap;">
                        <label style="display: flex; align-items: center; gap: 8px; font-size: 0.82rem; font-weight: 600; cursor: pointer;">
                            <input type="checkbox" name="is_verified" id="form_is_verified" value="1" :checked="isVerified == 1" @change="isVerified = $event.target.checked ? 1 : 0">
                            <span><i class="ph-fill ph-check-circle" style="color: #0284c7;"></i> Verified Partner Badge</span>
                        </label>
                        <label style="display: flex; align-items: center; gap: 8px; font-size: 0.82rem; font-weight: 600; cursor: pointer;">
                            <input type="checkbox" name="terms_accepted" id="form_terms_accepted" value="1" :checked="termsAccepted == 1" @change="termsAccepted = $event.target.checked ? 1 : 0">
                            <span>Terms of Service v1.0 Accepted</span>
                        </label>
                    </div>
                </div>

                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('creatorModal')">Cancel</button>
                    <button type="submit" class="btn btn-primary" id="creatorSubmitBtn">
                        <i class="ph ph-check"></i> <span x-text="isEdit ? 'Save Changes' : 'Enroll Creator'"></span>
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: DELETE CREATOR PARTNER (WITH REELS CASCADE WARNING) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="deleteCreatorModal">
        <div class="modal-card confirm-dialog-card">
            <div class="modal-head" style="border-bottom-color: #fecaca; background: #fef2f2;">
                <h3 style="color: var(--danger); display: flex; align-items: center; gap: 8px;">
                    <div class="confirm-icon-badge danger" style="width: 32px; height: 32px; font-size: 18px;">
                        <i class="ph ph-trash"></i>
                    </div>
                    Delete Creator Partner
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('deleteCreatorModal')">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="delete_creator">
                <input type="hidden" name="creator_id" id="delete_creator_id" value="0">

                <div class="modal-body">
                    <div style="margin-bottom: 14px; padding: 12px 16px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border);">
                        <span style="font-size: 0.72rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700; display: block; margin-bottom: 2px;">Creator Partner</span>
                        <div style="font-weight: 700; font-size: 1rem; color: var(--text-primary);" id="delete_creator_name"></div>
                        <div style="font-size: 0.76rem; color: var(--text-muted);" id="delete_creator_meta"></div>
                    </div>

                    <div style="background: #fff1f2; border: 1px solid #fecdd3; border-radius: 8px; padding: 12px 14px; margin-bottom: 14px;">
                        <div style="color: #9f1239; font-weight: 700; font-size: 0.84rem; display: flex; align-items: center; gap: 6px; margin-bottom: 4px;">
                            <i class="ph ph-warning"></i> Permanent Deletion Warning
                        </div>
                        <p style="font-size: 0.78rem; color: #881337; margin: 0; line-height: 1.45;">
                            This action cannot be undone. All agreements, payment profiles, and partner records for this creator will be erased.
                        </p>
                    </div>

                    <div class="form-row" style="margin-bottom: 10px;">
                        <label style="display: flex; align-items: flex-start; gap: 10px; font-size: 0.84rem; font-weight: 600; cursor: pointer; color: var(--text-primary);">
                            <input type="checkbox" name="delete_reels" value="1" checked style="margin-top: 3px;">
                            <span>Also permanently delete all (<span id="delete_reels_count">0</span>) uploaded agri reels, reviews, analytics, and comments by this creator</span>
                        </label>
                    </div>

                    <p style="font-size: 0.74rem; color: var(--text-muted); margin: 0;">
                        * Note: If the creator has a linked app user profile, their role will safely revert back to "farmer".
                    </p>
                </div>

                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('deleteCreatorModal')">Cancel</button>
                    <button type="submit" class="btn btn-danger" style="background: #dc2626; border-color: #dc2626; color: white;">
                        <i class="ph ph-trash"></i> Permanently Delete Creator
                    </button>
                </div>
            </form>
        </div>
    </div>

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
    <!-- MODAL: UPLOAD / EDIT REEL (FULL BACKGROUND FEATURES INTEGRATION) -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="reelModal" x-data="{
        isActive: 1,
        activeOpen: false,
        videoUrl: '',
        isUploading: false,
        progress: 0,
        statusText: '',
        creatorId: 0,
        creatorName: 'CropSync Creator',
        creatorPhone: '9182867655',
        creatorOpen: false,
        cropVal: 'General',
        cropOpen: false,
        categoryVal: 'Crop Care',
        categoryOpen: false,
        languageVal: 'te',
        languageOpen: false,
        payoutEligible: 1,
        isDuplicate: 0,
        rightsDeclared: 1,
        sourceUrl: '',
        setActive(val) { this.isActive = val; this.activeOpen = false; },
        setCreator(id, name, phone) {
            this.creatorId = id;
            this.creatorName = name;
            this.creatorPhone = phone;
            document.getElementById('reel_creator_id').value = id;
            document.getElementById('reel_creator_name').value = name;
            document.getElementById('reel_phone_number').value = phone;
            this.creatorOpen = false;
        },
        setCrop(val) { this.cropVal = val; this.cropOpen = false; },
        setCategory(val) { this.categoryVal = val; this.categoryOpen = false; },
        setLanguage(val) { this.languageVal = val; this.languageOpen = false; },
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
        <div class="modal-card" style="max-width: 680px;">
            <div class="modal-head">
                <h3 id="reelModalTitle">Upload Agri Reel</h3>
                <button type="button" class="close-btn" onclick="closeModal('reelModal')">&times;</button>
            </div>
            <form method="POST" enctype="multipart/form-data">
                <input type="hidden" name="action" value="save_reel">
                <input type="hidden" name="reel_id" id="reel_id" value="0">
                <input type="hidden" name="creator_id" id="reel_creator_id" :value="creatorId">
                <input type="hidden" name="is_active" :value="isActive">
                <input type="hidden" name="crop" id="reel_crop" :value="cropVal">
                <input type="hidden" name="category" id="reel_category" :value="categoryVal">
                <input type="hidden" name="language" id="reel_language" :value="languageVal">
                <input type="hidden" name="payout_eligible" :value="payoutEligible">
                <input type="hidden" name="is_duplicate" :value="isDuplicate">
                <input type="hidden" name="rights_declared" :value="rightsDeclared">

                <div class="modal-body">
                    <!-- Caption -->
                    <div class="form-row">
                        <label>Reel Caption *</label>
                        <textarea name="caption" id="reel_caption" class="form-input" placeholder="Video description, farming technique, crop variety, organic inputs..." rows="3" required></textarea>
                    </div>

                    <!-- Enrolled Creator Selection (Alpine Dropdown) -->
                    <div class="form-row">
                        <label>Select Creator (Partner Program)</label>
                        <div class="alpine-dropdown" style="width:100%;" @click.outside="creatorOpen = false">
                            <button type="button" class="dropdown-trigger" style="width:100%;" @click="creatorOpen = !creatorOpen">
                                <span style="display:flex; align-items:center; gap:8px;">
                                    <i class="ph ph-user-circle" style="font-size:16px; color:#16a34a;"></i>
                                    <span x-text="creatorId > 0 ? (creatorName + ' (@' + creatorPhone + ')') : 'Custom / Unregistered Creator'"></span>
                                </span>
                                <i class="ph ph-caret-down" style="font-size:12px;"></i>
                            </button>
                            <div class="dropdown-panel" style="width:100%; max-height:220px; overflow-y:auto;" x-show="creatorOpen" x-cloak x-transition>
                                <div class="dropdown-option" :class="{ 'selected': creatorId == 0 }" @click="setCreator(0, 'CropSync Creator', '9182867655')">
                                    <em>Custom / Unregistered Creator</em>
                                </div>
                                <?php if (!empty($allCreators)): foreach ($allCreators as $ac): ?>
                                    <div class="dropdown-option" :class="{ 'selected': creatorId == <?= $ac['id'] ?> }" 
                                         @click="setCreator(<?= $ac['id'] ?>, '<?= htmlspecialchars(addslashes($ac['display_name'])) ?>', '<?= htmlspecialchars(addslashes($ac['phone_number'] ?? '')) ?>')">
                                        <div style="display:flex; align-items:center; justify-content:space-between; width:100%;">
                                            <span>
                                                <strong><?= htmlspecialchars($ac['display_name']) ?></strong> 
                                                <small style="color:var(--text-muted); font-size:0.75rem;">@<?= htmlspecialchars($ac['username']) ?></small>
                                            </span>
                                            <span style="font-size:0.7rem; background:#f1f5f9; padding:2px 6px; border-radius:4px;"><?= ucfirst(str_replace('_', ' ', $ac['partnership_tier'] ?? 'trial')) ?></span>
                                        </div>
                                    </div>
                                <?php endforeach; endif; ?>
                            </div>
                        </div>
                    </div>

                    <!-- Creator Details Inputs -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Creator Display Name *</label>
                            <input type="text" name="creator_name" id="reel_creator_name" x-model="creatorName" class="form-input" required>
                        </div>
                        <div class="form-row">
                            <label>Creator Phone Number</label>
                            <input type="text" name="phone_number" id="reel_phone_number" x-model="creatorPhone" class="form-input">
                        </div>
                    </div>

                    <!-- Agronomy Crop & Category Selectors (Alpine Custom Dropdowns) -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Agricultural Crop *</label>
                            <div class="alpine-dropdown" style="width:100%;" @click.outside="cropOpen = false">
                                <button type="button" class="dropdown-trigger" style="width:100%;" @click="cropOpen = !cropOpen">
                                    <span style="display:flex; align-items:center; gap:6px;">
                                        <i class="ph ph-plant" style="color:#10b981;"></i>
                                        <span x-text="cropVal"></span>
                                    </span>
                                    <i class="ph ph-caret-down" style="font-size:12px;"></i>
                                </button>
                                <div class="dropdown-panel" style="width:100%; max-height:200px; overflow-y:auto;" x-show="cropOpen" x-cloak x-transition>
                                    <template x-for="c in ['General', 'Paddy', 'Cotton', 'Chilli', 'Maize', 'Groundnut', 'Soybean', 'Sugarcane', 'Vegetables', 'Horticulture', 'Pulses']" :key="c">
                                        <div class="dropdown-option" :class="{ 'selected': cropVal === c }" @click="setCrop(c)">
                                            <span x-text="c"></span>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>

                        <div class="form-row">
                            <label>Advisory Category *</label>
                            <div class="alpine-dropdown" style="width:100%;" @click.outside="categoryOpen = false">
                                <button type="button" class="dropdown-trigger" style="width:100%;" @click="categoryOpen = !categoryOpen">
                                    <span style="display:flex; align-items:center; gap:6px;">
                                        <i class="ph ph-tag" style="color:#3b82f6;"></i>
                                        <span x-text="categoryVal"></span>
                                    </span>
                                    <i class="ph ph-caret-down" style="font-size:12px;"></i>
                                </button>
                                <div class="dropdown-panel" style="width:100%; max-height:200px; overflow-y:auto;" x-show="categoryOpen" x-cloak x-transition>
                                    <template x-for="cat in ['Crop Care', 'Pest Advisory', 'Fertilizer & Soil', 'Machinery & Tools', 'Govt Schemes', 'Market Prices', 'Organic Farming', 'Harvesting']" :key="cat">
                                        <div class="dropdown-option" :class="{ 'selected': categoryVal === cat }" @click="setCategory(cat)">
                                            <span x-text="cat"></span>
                                        </div>
                                    </template>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Language & Audio Title -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Language *</label>
                            <div class="alpine-dropdown" style="width:100%;" @click.outside="languageOpen = false">
                                <button type="button" class="dropdown-trigger" style="width:100%;" @click="languageOpen = !languageOpen">
                                    <span style="display:flex; align-items:center; gap:6px;">
                                        <i class="ph ph-translate" style="color:#8b5cf6;"></i>
                                        <span x-text="languageVal === 'te' ? 'Telugu (తెలుగు)' : (languageVal === 'en' ? 'English' : (languageVal === 'hi' ? 'Hindi (हिन्दी)' : (languageVal === 'kn' ? 'Kannada (ಕನ್ನಡ)' : 'Tamil (தமிழ்)')))"></span>
                                    </span>
                                    <i class="ph ph-caret-down" style="font-size:12px;"></i>
                                </button>
                                <div class="dropdown-panel" style="width:100%;" x-show="languageOpen" x-cloak x-transition>
                                    <div class="dropdown-option" :class="{ 'selected': languageVal === 'te' }" @click="setLanguage('te')">Telugu (తెలుగు)</div>
                                    <div class="dropdown-option" :class="{ 'selected': languageVal === 'en' }" @click="setLanguage('en')">English</div>
                                    <div class="dropdown-option" :class="{ 'selected': languageVal === 'hi' }" @click="setLanguage('hi')">Hindi (हिन्दी)</div>
                                    <div class="dropdown-option" :class="{ 'selected': languageVal === 'kn' }" @click="setLanguage('kn')">Kannada (ಕನ್ನಡ)</div>
                                    <div class="dropdown-option" :class="{ 'selected': languageVal === 'ta' }" @click="setLanguage('ta')">Tamil (தமிழ்)</div>
                                </div>
                            </div>
                        </div>

                        <div class="form-row">
                            <label>Audio Title</label>
                            <input type="text" name="music_title" id="reel_music_title" class="form-input" value="Original Audio">
                        </div>
                    </div>

                    <!-- Hashtags & Source Reference URL -->
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Hashtags</label>
                            <input type="text" name="tags" id="reel_tags" class="form-input" placeholder="#Paddy #Harvesting">
                        </div>
                        <div class="form-row">
                            <label>Source Video Link / Credit</label>
                            <input type="url" name="source_url" id="reel_source_url" x-model="sourceUrl" class="form-input" placeholder="https://youtube.com/shorts/... or external source">
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

                    <!-- Governance, Visibility & Partner Program Flags -->
                    <div style="background: #f8fafc; border: 1px solid var(--border); border-radius: 8px; padding: 14px; margin-top: 10px;">
                        <div style="font-weight: 700; font-size: 0.84rem; color: var(--text-primary); margin-bottom: 10px; display: flex; align-items: center; gap: 6px;">
                            <i class="ph ph-shield-check" style="color: #10b981;"></i> Distribution & Compliance Settings
                        </div>

                        <div class="grid-2" style="margin-bottom: 10px;">
                            <div class="form-row" style="margin: 0;">
                                <label style="font-size: 0.78rem;">Feed Visibility</label>
                                <div class="alpine-dropdown" style="width:100%;" @click.outside="activeOpen = false">
                                    <button type="button" class="dropdown-trigger" style="width:100%;" @click="activeOpen = !activeOpen">
                                        <span x-text="isActive == 1 ? '🟢 Active (Live in Reel Feed)' : '⚫ Hidden (Private)'"></span>
                                        <i class="ph ph-caret-down" style="font-size:12px;"></i>
                                    </button>
                                    <div class="dropdown-panel" style="width:100%;" x-show="activeOpen" x-cloak x-transition>
                                        <div class="dropdown-option" :class="{ 'selected': isActive == 1 }" @click="setActive(1)">🟢 Active (Live in Reel Feed)</div>
                                        <div class="dropdown-option" :class="{ 'selected': isActive == 0 }" @click="setActive(0)">⚫ Hidden (Private)</div>
                                    </div>
                                </div>
                            </div>

                            <div style="display: flex; flex-direction: column; justify-content: center; gap: 8px;">
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.82rem; cursor: pointer;">
                                    <input type="checkbox" :checked="payoutEligible == 1" @change="payoutEligible = $event.target.checked ? 1 : 0">
                                    <span style="font-weight: 600; color: #15803d;">💰 Creator Payout Eligible</span>
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.82rem; cursor: pointer;">
                                    <input type="checkbox" :checked="rightsDeclared == 1" @change="rightsDeclared = $event.target.checked ? 1 : 0">
                                    <span style="font-weight: 600; color: var(--text-secondary);">🛡️ Original Rights Declared</span>
                                </label>
                                <label style="display: flex; align-items: center; gap: 8px; font-size: 0.82rem; cursor: pointer;">
                                    <input type="checkbox" :checked="isDuplicate == 1" @change="isDuplicate = $event.target.checked ? 1 : 0; if (isDuplicate) payoutEligible = 0;">
                                    <span style="font-weight: 600; color: #dc2626;">⚠️ Mark as Duplicate</span>
                                </label>
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
    <!-- MODAL: CREATE / EDIT SHOP BANNER (LANG TABS + CLIENT-SIDE 5:2 CROP) -->
    <!-- ============================================================== -->
    <script>
        function shopBannerForm() {
            const blank = () => ({
                tag_en: '', tag_hi: '', tag_te: '',
                title_en: '', title_hi: '', title_te: '',
                subtitle_en: '', subtitle_hi: '', subtitle_te: '',
                cta_text_en: '', cta_text_hi: '', cta_text_te: '',
                badge_en: '', badge_hi: '', badge_te: '',
                target_type: 'none', target_value: '',
                bg_color_1: '#064e3b', bg_color_2: '#047857',
                icon_key: '', is_active: true, sort_order: '',
                start_at: '', end_at: ''
            });
            const icons = { eco: 'ph-leaf', verified: 'ph-seal-check', local_shipping: 'ph-truck', bolt: 'ph-lightning', star: 'ph-star', agriculture: 'ph-plant', shield: 'ph-shield-check', percent: 'ph-percent' };
            const dt = (v) => v ? String(v).replace(' ', 'T').slice(0, 16) : '';
            return {
                id: 0,
                langTab: 'en',
                f: blank(),
                existingImage: '',
                removeImage: false,
                newPreview: '',
                cropMsg: '',
                cropErr: '',
                formErr: '',
                load(b) {
                    this.clearNew();
                    this.f = blank();
                    this.id = 0;
                    this.existingImage = '';
                    this.removeImage = false;
                    this.langTab = 'en';
                    this.cropMsg = this.cropErr = this.formErr = '';
                    if (!b) return;
                    this.id = parseInt(b.id) || 0;
                    Object.keys(this.f).forEach(k => {
                        if (b[k] !== undefined && b[k] !== null) this.f[k] = b[k];
                    });
                    this.f.is_active = !!parseInt(b.is_active);
                    this.f.sort_order = b.sort_order;
                    this.f.start_at = dt(b.start_at);
                    this.f.end_at = dt(b.end_at);
                    this.f.bg_color_1 = (b.bg_color_1 || '#064E3B').toLowerCase();
                    this.f.bg_color_2 = (b.bg_color_2 || '#047857').toLowerCase();
                    this.f.target_type = b.target_type || 'none';
                    this.f.target_value = b.target_value || '';
                    this.f.icon_key = b.icon_key || '';
                    this.existingImage = b.image_url || '';
                },
                get previewImage() { return this.newPreview || (this.removeImage ? '' : this.existingImage); },
                get iconClass() { return icons[this.f.icon_key] || ''; },
                pv(field) { return this.f[field + '_' + this.langTab] || this.f[field + '_en'] || ''; },
                targetPlaceholder() {
                    return { product: 'Product ID, e.g. 42', category: 'Category name, e.g. Seeds', url: 'https://example.com/offer', none: '' }[this.f.target_type] || '';
                },
                clearNew() {
                    if (this.newPreview) { try { URL.revokeObjectURL(this.newPreview); } catch (e) {} }
                    this.newPreview = '';
                    ['sb_out', 'sb_data', 'sb_pick'].forEach(i => { const e = document.getElementById(i); if (e) e.value = ''; });
                },
                removeCurrent() {
                    this.clearNew();
                    this.removeImage = true;
                    this.cropMsg = '';
                },
                onPick(ev) {
                    const file = ev.target.files && ev.target.files[0];
                    this.cropErr = ''; this.cropMsg = '';
                    if (!file) return;
                    if (['image/jpeg', 'image/png', 'image/webp'].indexOf(file.type) === -1) {
                        this.cropErr = 'Please choose a JPEG, PNG or WEBP image.';
                        ev.target.value = '';
                        return;
                    }
                    if (file.size > 25 * 1024 * 1024) {
                        this.cropErr = 'Source image is too large (max 25 MB).';
                        ev.target.value = '';
                        return;
                    }
                    const url = URL.createObjectURL(file);
                    const img = new Image();
                    img.onload = () => {
                        const W = 1250, H = 500, ratio = W / H;
                        const iw = img.naturalWidth, ih = img.naturalHeight;
                        let sw, sh;
                        if (iw / ih > ratio) { sh = ih; sw = ih * ratio; } else { sw = iw; sh = iw / ratio; }
                        const sx = (iw - sw) / 2, sy = (ih - sh) / 2;
                        const canvas = document.createElement('canvas');
                        canvas.width = W; canvas.height = H;
                        const ctx = canvas.getContext('2d');
                        ctx.fillStyle = '#ffffff';
                        ctx.fillRect(0, 0, W, H);
                        ctx.imageSmoothingQuality = 'high';
                        ctx.drawImage(img, sx, sy, sw, sh, 0, 0, W, H);
                        URL.revokeObjectURL(url);
                        const attempt = (q) => canvas.toBlob((blob) => {
                            if (!blob) { this.cropErr = 'Could not process the image in this browser.'; return; }
                            if (blob.size > 1.5 * 1024 * 1024 && q > 0.5) { attempt(q - 0.1); return; }
                            if (blob.size > 1.5 * 1024 * 1024) { this.cropErr = 'Image is still above 1.5 MB after compression. Try a simpler image.'; return; }
                            this.useBlob(blob);
                            this.cropMsg = 'Cropped to 1250x500 (5:2), ' + Math.round(blob.size / 1024) + ' KB' + ((iw < W || ih < H) ? ' - note: source is smaller than 1250x500 and was enlarged.' : '.');
                        }, 'image/jpeg', q);
                        attempt(0.85);
                    };
                    img.onerror = () => { URL.revokeObjectURL(url); this.cropErr = 'Could not read this image.'; };
                    img.src = url;
                },
                useBlob(blob) {
                    if (this.newPreview) { try { URL.revokeObjectURL(this.newPreview); } catch (e) {} }
                    this.newPreview = URL.createObjectURL(blob);
                    this.removeImage = false;
                    document.getElementById('sb_data').value = '';
                    try {
                        const d = new DataTransfer();
                        d.items.add(new File([blob], 'banner.jpg', { type: 'image/jpeg' }));
                        document.getElementById('sb_out').files = d.files;
                    } catch (e) {
                        // Fallback: send as base64 in a hidden field
                        const fr = new FileReader();
                        fr.onload = () => { document.getElementById('sb_data').value = fr.result; };
                        fr.readAsDataURL(blob);
                    }
                },
                onSubmit(ev) {
                    this.formErr = '';
                    if (!this.f.title_en.trim()) {
                        ev.preventDefault();
                        this.langTab = 'en';
                        this.formErr = 'English title is required.';
                        return;
                    }
                    if (this.f.target_type === 'url' && !/^https:\/\//i.test(this.f.target_value.trim())) {
                        ev.preventDefault();
                        this.formErr = 'URL target must start with https://';
                        return;
                    }
                    if (this.f.start_at && this.f.end_at && this.f.end_at <= this.f.start_at) {
                        ev.preventDefault();
                        this.formErr = 'End date must be after the start date.';
                    }
                }
            };
        }

        function openShopBannerModal(b) {
            if (b && !(parseInt(b.id) > 0)) {
                showToast('Could not load this banner for editing. Please reload the page.', 'danger');
                return;
            }
            const el = document.getElementById('shopBannerModal');
            const data = getAlpineData(el);
            if (data) data.load(b || null);
            openModal('shopBannerModal');
        }

        function promptShopBannerDelete(id, title) {
            document.getElementById('sb_del_id').value = id;
            document.getElementById('sbDeleteTitle').innerText = 'Banner #' + id + ': ' + title;
            openModal('shopBannerDeleteModal');
        }
    </script>

    <div class="modal-overlay" id="shopBannerModal" x-data="shopBannerForm()">
        <div class="modal-card" style="max-width: 760px;">
            <div class="modal-head">
                <h3 x-text="id ? 'Edit Banner #' + id : 'New Shop Banner'">New Shop Banner</h3>
                <button type="button" class="close-btn" onclick="closeModal('shopBannerModal')">&times;</button>
            </div>
            <form method="POST" enctype="multipart/form-data" @submit="onSubmit($event)">
                <input type="hidden" name="action" value="save_shop_banner">
                <input type="hidden" name="banner_id" :value="id">
                <input type="hidden" name="remove_image" :value="removeImage ? '1' : ''">
                <input type="hidden" name="image_data" id="sb_data" value="">

                <div class="modal-body">
                    <div x-show="formErr" x-cloak style="background:#fef2f2; border:1px solid #fca5a5; color:#991b1b; font-size:0.78rem; font-weight:600; padding:8px 12px; border-radius:6px; margin-bottom:12px;" x-text="formErr"></div>

                    <!-- Live preview (fixed 5:2). Image banners show the image alone, like the app. -->
                    <div style="margin-bottom:14px;">
                        <label style="font-size:0.78rem; font-weight:600; color:var(--text-secondary); display:block; margin-bottom:6px;">Live Preview (5:2)</label>
                        <div class="sb-preview" style="border-radius:10px; border:1px solid var(--border); max-width:100%;"
                             :style="previewImage ? 'background:#e2e8f0;' : 'background: linear-gradient(135deg, ' + f.bg_color_1 + ', ' + f.bg_color_2 + ');'">
                            <template x-if="previewImage">
                                <img :src="previewImage" alt="Banner preview">
                            </template>
                            <template x-if="!previewImage">
                                <div style="position:absolute; inset:0;">
                                    <i class="ph sb-icon" :class="iconClass" x-show="iconClass"></i>
                                    <span class="sb-badge" x-show="pv('badge')" x-text="pv('badge')"></span>
                                    <div class="sb-text">
                                        <div class="sb-tag" x-show="pv('tag')" x-text="pv('tag')"></div>
                                        <div class="sb-title" x-text="pv('title') || 'Banner title'"></div>
                                        <div class="sb-sub" x-show="pv('subtitle')" x-text="pv('subtitle')"></div>
                                        <div class="sb-cta" x-show="pv('cta_text')" x-text="pv('cta_text')"></div>
                                    </div>
                                </div>
                            </template>
                        </div>
                    </div>

                    <!-- Language tabs -->
                    <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap; margin-bottom:12px; background:var(--surface-subtle); padding:10px 14px; border-radius:var(--radius-md); border:1px solid var(--border);">
                        <button type="button" class="btn btn-sm" :class="langTab === 'en' ? 'btn-primary' : 'btn-outline'" @click="langTab = 'en'" style="font-size:0.75rem; padding:4px 10px;">🇬🇧 English</button>
                        <button type="button" class="btn btn-sm" :class="langTab === 'hi' ? 'btn-primary' : 'btn-outline'" @click="langTab = 'hi'" style="font-size:0.75rem; padding:4px 10px;">🇮🇳 Hindi (हिंदी)</button>
                        <button type="button" class="btn btn-sm" :class="langTab === 'te' ? 'btn-primary' : 'btn-outline'" @click="langTab = 'te'" style="font-size:0.75rem; padding:4px 10px;">🇮🇳 Telugu (తెలుగు)</button>
                        <span style="font-size:0.72rem; color:var(--text-muted); margin-left:auto;">Only the English title is required; other languages fall back to English.</span>
                    </div>

                    <?php
                    $sbLangFields = [
                        'tag' => ['Tag', 40, false],
                        'title' => ['Title', 120, false],
                        'subtitle' => ['Subtitle', 200, true],
                        'cta_text' => ['Button text (CTA)', 40, false],
                        'badge' => ['Badge', 30, false],
                    ];
                    foreach (['en', 'hi', 'te'] as $sbL): ?>
                        <div x-show="langTab === '<?= $sbL ?>'" <?= $sbL === 'en' ? '' : 'x-cloak' ?>>
                            <?php foreach ($sbLangFields as $sbF => [$sbLabel, $sbMax, $sbArea]): ?>
                                <div class="form-row">
                                    <label><?= htmlspecialchars($sbLabel) ?> (<?= strtoupper($sbL) ?>)<?= ($sbF === 'title' && $sbL === 'en') ? ' *' : '' ?></label>
                                    <?php if ($sbArea): ?>
                                        <textarea name="<?= $sbF ?>_<?= $sbL ?>" class="form-input" rows="2" maxlength="<?= $sbMax ?>" x-model="f.<?= $sbF ?>_<?= $sbL ?>"></textarea>
                                    <?php else: ?>
                                        <input type="text" name="<?= $sbF ?>_<?= $sbL ?>" class="form-input" maxlength="<?= $sbMax ?>" x-model="f.<?= $sbF ?>_<?= $sbL ?>">
                                    <?php endif; ?>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    <?php endforeach; ?>

                    <div class="grid-2">
                        <div class="form-row">
                            <label>Link Type</label>
                            <select name="target_type" class="form-input" x-model="f.target_type" @change="if (f.target_type === 'none') f.target_value = ''">
                                <option value="none">None</option>
                                <option value="product">Product</option>
                                <option value="category">Category</option>
                                <option value="url">URL (https only)</option>
                            </select>
                        </div>
                        <div class="form-row">
                            <label>Link Value</label>
                            <input type="text" name="target_value" class="form-input" maxlength="500" x-model="f.target_value" :disabled="f.target_type === 'none'" :placeholder="targetPlaceholder()">
                        </div>
                    </div>

                    <div class="grid-2">
                        <div class="form-row">
                            <label>Background Colour 1</label>
                            <input type="color" name="bg_color_1" class="form-input" style="height:38px; padding:3px;" x-model="f.bg_color_1">
                        </div>
                        <div class="form-row">
                            <label>Background Colour 2</label>
                            <input type="color" name="bg_color_2" class="form-input" style="height:38px; padding:3px;" x-model="f.bg_color_2">
                        </div>
                    </div>

                    <div class="grid-2">
                        <div class="form-row">
                            <label>Icon</label>
                            <select name="icon_key" class="form-input" x-model="f.icon_key">
                                <option value="">None</option>
                                <?php foreach (SHOP_BANNER_ICONS as $sbIc): ?>
                                    <option value="<?= htmlspecialchars($sbIc) ?>"><?= htmlspecialchars($sbIc) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="form-row">
                            <label>Sort Order (lower = first)</label>
                            <input type="number" step="1" name="sort_order" class="form-input" x-model="f.sort_order" placeholder="Auto (last)">
                        </div>
                    </div>

                    <div style="font-size:0.74rem; color:var(--text-muted); margin-bottom:4px;">Start/end times are in server time, not your browser's time zone.</div>
                    <div class="grid-2">
                        <div class="form-row">
                            <label>Start (optional, server time)</label>
                            <input type="datetime-local" name="start_at" class="form-input" x-model="f.start_at">
                        </div>
                        <div class="form-row">
                            <label>End (optional, server time)</label>
                            <input type="datetime-local" name="end_at" class="form-input" x-model="f.end_at">
                        </div>
                    </div>

                    <!-- Optional image upload with client-side 5:2 crop -->
                    <div class="form-row">
                        <label>Banner Image (optional)</label>
                        <div style="font-size:0.76rem; color:var(--text-muted); margin-bottom:6px;">
                            Banner image: 1250x500 px (5:2). It will be cropped/resized automatically. When an image is set, the app shows the image alone.
                        </div>
                        <input type="file" id="sb_pick" accept="image/jpeg,image/png,image/webp" @change="onPick($event)">
                        <input type="file" name="image_file" id="sb_out" style="display:none;">
                        <div style="display:flex; gap:8px; align-items:center; margin-top:6px; flex-wrap:wrap;">
                            <button type="button" class="btn btn-secondary btn-sm" x-show="newPreview" x-cloak @click="clearNew(); cropMsg = ''">Discard new image</button>
                            <button type="button" class="btn btn-danger-outline btn-sm" x-show="existingImage && !removeImage && !newPreview" x-cloak @click="removeCurrent()">Remove current image</button>
                            <button type="button" class="btn btn-secondary btn-sm" x-show="removeImage" x-cloak @click="removeImage = false">Keep current image</button>
                        </div>
                        <div x-show="cropMsg" x-cloak style="font-size:0.76rem; color:#065f46; margin-top:6px;" x-text="cropMsg"></div>
                        <div x-show="cropErr" x-cloak style="font-size:0.76rem; color:#991b1b; margin-top:6px;" x-text="cropErr"></div>
                    </div>

                    <div class="form-row" style="display:flex; align-items:center; gap:8px; margin-top:8px;">
                        <input type="checkbox" name="is_active" id="sb_is_active" value="1" x-model="f.is_active">
                        <label for="sb_is_active" style="margin-bottom:0; cursor:pointer;">Active (visible in the app within its schedule)</label>
                    </div>
                </div>

                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('shopBannerModal')">Cancel</button>
                    <button type="submit" class="btn btn-primary" x-text="id ? 'Save Changes' : 'Create Banner'">Save Banner</button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL: CONFIRM DELETE SHOP BANNER -->
    <div class="modal-overlay" id="shopBannerDeleteModal">
        <div class="modal-card confirm-dialog-card">
            <div class="modal-head" style="border-bottom-color:#fecaca; background:#fef2f2;">
                <h3 style="color:var(--danger); display:flex; align-items:center; gap:8px;">
                    <div class="confirm-icon-badge danger" style="width:32px; height:32px; font-size:18px;">
                        <i class="ph ph-warning-circle"></i>
                    </div>
                    Confirm Delete
                </h3>
                <button type="button" class="close-btn" onclick="closeModal('shopBannerDeleteModal')">&times;</button>
            </div>
            <form method="POST">
                <input type="hidden" name="action" value="delete_shop_banner">
                <input type="hidden" name="banner_id" id="sb_del_id" value="">
                <div class="modal-body" style="font-size: 0.9rem; color: var(--text-secondary); line-height: 1.5;">
                    <p>Are you sure you want to permanently delete this banner (and its uploaded image)?</p>
                    <div id="sbDeleteTitle" style="font-weight: 700; color: var(--text-primary); margin: 10px 0; padding: 10px 14px; background: #f8fafc; border-radius: 8px; border: 1px solid var(--border);"></div>
                    <p style="font-size: 0.78rem; color: #dc2626; margin-top: 8px; display: flex; align-items: center; gap: 4px;">
                        <i class="ph ph-warning"></i> This operation cannot be reversed.
                    </p>
                </div>
                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('shopBannerDeleteModal')">Cancel</button>
                    <button type="submit" class="btn btn-danger">Yes, Permanently Delete</button>
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
                    <div id="suspendNotice" style="margin-bottom: 12px; padding: 10px 12px; background: #fff1f2; border: 1px solid #fecdd3; border-radius: 8px; font-size: 0.78rem; color: #9f1239; display: none;">
                        <i class="ph ph-warning-circle" style="font-weight: bold;"></i> <strong>Automatic Cascade:</strong> Suspending this creator will immediately deactivate all their published reels and suppress them from all public feeds.
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
                        <label style="font-weight: 600;">Review Reason Code *</label>
                        <div class="alpine-select-wrapper full-width" id="modReasonAlpine" x-data="{ 
                            open: false, 
                            val: 'manual_approval', 
                            label: 'Manual Approval (Verified Agricultural Content)',
                            options: [
                                { val: 'manual_approval', label: 'Manual Approval (Verified Agricultural Content)' },
                                { val: 'duplicate_content', label: 'Duplicate Content / Source URL' },
                                { val: 'copyright_infringement', label: 'Copyright Infringement / Not Original' },
                                { val: 'misleading_agri_info', label: 'Misleading / Inaccurate Agricultural Advice' },
                                { val: 'low_quality_video', label: 'Low Quality Video / Distorted Audio' },
                                { val: 'community_policy_violation', label: 'Community Policy / Guideline Violation' },
                                { val: 'other', label: 'Other / General Reason' }
                            ],
                            select(item) {
                                this.val = item.val;
                                this.label = item.label;
                                this.open = false;
                                document.getElementById('mod_reason_code').value = item.val;
                            }
                        }" @click.outside="open = false">
                            <input type="hidden" name="reason_code" id="mod_reason_code" :value="val">
                            <div class="alpine-select-trigger" :class="{ 'active': open }" @click="open = !open">
                                <span x-text="label"></span>
                                <i class="ph ph-caret-down"></i>
                            </div>
                            <div class="alpine-select-menu" x-show="open" x-cloak x-transition>
                                <template x-for="item in options" :key="item.val">
                                    <div class="alpine-select-option" :class="{ 'selected': val === item.val }" @click="select(item)">
                                        <span x-text="item.label"></span>
                                        <i class="ph ph-check check-icon" x-show="val === item.val"></i>
                                    </div>
                                </template>
                            </div>
                        </div>
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

    <!-- ============================================================== -->
    <!-- MODAL: REEL COMMENTS MODERATION -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="reelCommentsModal">
        <div class="modal-card" style="max-width: 620px; max-height: 85vh; display: flex; flex-direction: column;">
            <div class="modal-head" style="background: #f8fafc; border-bottom: 1px solid var(--border);">
                <div style="display: flex; align-items: center; gap: 10px;">
                    <div class="confirm-icon-badge primary" style="width:34px; height:34px; font-size:18px;">
                        <i class="ph ph-chat-circle-dots"></i>
                    </div>
                    <div>
                        <h3 style="font-size: 1.05rem; margin: 0;">Reel Comments & Moderation</h3>
                        <div id="reelCommentsSubtitle" style="font-size: 0.75rem; color: var(--text-muted); margin-top: 2px;"></div>
                    </div>
                </div>
                <button type="button" class="close-btn" onclick="closeModal('reelCommentsModal')">&times;</button>
            </div>
            <div class="modal-body" style="overflow-y: auto; flex: 1; padding: 16px;">
                <div id="reelCommentsLoading" style="text-align: center; padding: 30px; color: var(--text-muted);">
                    <i class="ph ph-spinner ph-spin" style="font-size: 28px; color: #3b82f6;"></i>
                    <div style="margin-top: 8px; font-size: 0.85rem;">Loading comments...</div>
                </div>
                <div id="reelCommentsEmpty" style="display: none; text-align: center; padding: 36px; color: var(--text-muted);">
                    <i class="ph ph-chat-slash" style="font-size: 36px; opacity: 0.4;"></i>
                    <div style="margin-top: 8px; font-size: 0.9rem; font-weight: 600;">No comments yet</div>
                    <div style="font-size: 0.78rem;">Farmers' comments and questions on this reel will appear here.</div>
                </div>
                <div id="reelCommentsList" style="display: none;"></div>
            </div>
            <div class="modal-foot" style="background: #f8fafc; border-top: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center;">
                <span id="reelCommentsTotalCount" style="font-size: 0.78rem; color: var(--text-muted); font-weight: 600;"></span>
                <button type="button" class="btn btn-secondary" onclick="closeModal('reelCommentsModal')">Close</button>
            </div>
        </div>
    </div>

    <!-- ============================================================== -->
    <!-- MODAL: REEL WATCH & AUDIENCE ANALYTICS -->
    <!-- ============================================================== -->
    <div class="modal-overlay" id="reelAnalyticsModal">
        <div class="modal-card" style="max-width: 740px; max-height: 90vh; display: flex; flex-direction: column;">
            <div class="modal-head" style="background: #f8fafc; border-bottom: 1px solid var(--border);">
                <div style="display: flex; align-items: center; gap: 10px;">
                    <div class="confirm-icon-badge primary" style="width:34px; height:34px; font-size:18px; background: #e0f2fe; color: #0284c7;">
                        <i class="ph ph-chart-line-up"></i>
                    </div>
                    <div>
                        <h3 style="font-size: 1.05rem; margin: 0;">Reel Performance & Watch Analytics</h3>
                        <div id="reelAnalyticsSubtitle" style="font-size: 0.75rem; color: var(--text-muted); margin-top: 2px;"></div>
                    </div>
                </div>
                <button type="button" class="close-btn" onclick="closeModal('reelAnalyticsModal')">&times;</button>
            </div>
            <div class="modal-body" style="overflow-y: auto; flex: 1; padding: 20px;">
                <div id="reelAnalyticsLoading" style="text-align: center; padding: 40px; color: var(--text-muted);">
                    <i class="ph ph-spinner ph-spin" style="font-size: 32px; color: #0284c7;"></i>
                    <div style="margin-top: 8px; font-size: 0.88rem;">Analyzing reel watch time and actions...</div>
                </div>
                <div id="reelAnalyticsContent" style="display: none;">
                    <!-- 4 KPI Cards -->
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 12px; margin-bottom: 20px;">
                        <div class="analytics-kpi-card">
                            <span style="font-size: 0.72rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700;">Total Watches</span>
                            <span id="anaTotalWatches" style="font-size: 1.4rem; font-weight: 800; color: var(--text-primary);">0</span>
                            <span id="anaUniqueViewers" style="font-size: 0.7rem; color: var(--text-secondary);">0 unique farmers</span>
                        </div>
                        <div class="analytics-kpi-card">
                            <span style="font-size: 0.72rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700;">Avg Watch Time</span>
                            <span id="anaAvgWatchTime" style="font-size: 1.4rem; font-weight: 800; color: #2563eb;">0s</span>
                            <span id="anaTotalWatchTime" style="font-size: 0.7rem; color: var(--text-secondary);">0s total watch time</span>
                        </div>
                        <div class="analytics-kpi-card">
                            <span style="font-size: 0.72rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700;">Completion Rate</span>
                            <span id="anaCompletionRate" style="font-size: 1.4rem; font-weight: 800; color: #16a34a;">0%</span>
                            <span id="anaCompletedWatches" style="font-size: 0.7rem; color: var(--text-secondary);">0 completed</span>
                        </div>
                        <div class="analytics-kpi-card">
                            <span style="font-size: 0.72rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700;">Audience Actions</span>
                            <span id="anaTotalActions" style="font-size: 1.4rem; font-weight: 800; color: #d97706;">0</span>
                            <span style="font-size: 0.7rem; color: var(--text-secondary);">Engagement touches</span>
                        </div>
                    </div>

                    <!-- Watch completion progress visual bar -->
                    <div style="background: #f8fafc; border: 1px solid var(--border); border-radius: 8px; padding: 14px; margin-bottom: 20px;">
                        <div style="display: flex; justify-content: space-between; font-size: 0.8rem; font-weight: 600; margin-bottom: 6px;">
                            <span>Audience Retention & Full Completion</span>
                            <span id="anaCompletionRateText" style="color: #16a34a; font-weight: 700;">0%</span>
                        </div>
                        <div style="width: 100%; height: 8px; background: #e2e8f0; border-radius: 4px; overflow: hidden;">
                            <div id="anaCompletionBar" style="width: 0%; height: 100%; background: linear-gradient(90deg, #10b981, #059669); transition: width 0.5s ease;"></div>
                        </div>
                    </div>

                    <!-- Actions Breakdown Grid -->
                    <div style="margin-bottom: 20px;">
                        <h4 style="font-size: 0.88rem; font-weight: 700; margin-bottom: 10px; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
                            <i class="ph ph-hand-pointing"></i> Audience Interaction Breakdown
                        </h4>
                        <div id="anaActionsGrid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 10px;"></div>
                    </div>

                    <!-- Moderation & Review Timeline -->
                    <div>
                        <h4 style="font-size: 0.88rem; font-weight: 700; margin-bottom: 10px; color: var(--text-primary); display: flex; align-items: center; gap: 6px;">
                            <i class="ph ph-clock-counter-clockwise"></i> Moderation Audit Trail
                        </h4>
                        <div id="anaReviewsList"></div>
                    </div>
                </div>
            </div>
            <div class="modal-foot" style="background: #f8fafc; border-top: 1px solid var(--border);">
                <button type="button" class="btn btn-secondary" onclick="closeModal('reelAnalyticsModal')">Close</button>
            </div>
        </div>
    </div>

    <!-- JAVASCRIPT LOGIC -->
    <script>
        function getAlpineData(el) {
            if (!el) return null;
            if (window.Alpine && typeof window.Alpine.$data === 'function') {
                try {
                    const data = window.Alpine.$data(el);
                    if (data) return data;
                } catch(e) {}
            }
            if (el._x_dataStack && el._x_dataStack[0]) {
                return el._x_dataStack[0];
            }
            if (el.__x && el.__x.$data) {
                return el.__x.$data;
            }
            return null;
        }

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
            const data = getAlpineData(modalEl);
            if (data) {
                data.category = 'Govt Schemes';
                data.status = 'published';
                data.langTab = 'en';
                data.targetLang = 'all';
                data.imageUrl = '';
                data.statusText = '';
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
            const data = getAlpineData(modalEl);
            if (data) {
                data.category = art.category || 'Govt Schemes';
                data.status = art.status || 'published';
                data.langTab = 'en';
                data.targetLang = art.language || 'all';
                data.imageUrl = art.image_url || '';
                data.statusText = '';
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
            document.getElementById('reel_creator_id').value = '0';
            document.getElementById('reel_creator_name').value = 'CropSync Creator';
            document.getElementById('reel_phone_number').value = '9182867655';
            document.getElementById('reel_music_title').value = 'Original Audio';
            document.getElementById('reel_tags').value = '#Paddy #AgriTips';
            document.getElementById('reel_video_url').value = '';
            if (document.getElementById('reel_source_url')) document.getElementById('reel_source_url').value = '';

            const modalEl = document.getElementById('reelModal');
            const data = getAlpineData(modalEl);
            if (data) {
                data.isActive = 1;
                data.videoUrl = '';
                data.statusText = '';
                data.creatorId = 0;
                data.creatorName = 'CropSync Creator';
                data.creatorPhone = '9182867655';
                data.cropVal = 'General';
                data.categoryVal = 'Crop Care';
                data.languageVal = 'te';
                data.sourceUrl = '';
                data.payoutEligible = 1;
                data.isDuplicate = 0;
                data.rightsDeclared = 1;
            }

            openModal('reelModal');
        }

        function editReel(rel) {
            document.getElementById('reel_id').value = rel.id;
            document.getElementById('reelModalTitle').innerText = 'Edit Reel #' + rel.id;
            document.getElementById('reelSubmitBtn').innerText = 'Update Reel';
            document.getElementById('reel_caption').value = rel.caption || '';
            document.getElementById('reel_creator_id').value = rel.creator_id || 0;
            document.getElementById('reel_creator_name').value = rel.creator_name || 'CropSync Creator';
            document.getElementById('reel_phone_number').value = rel.phone_number || '';
            document.getElementById('reel_music_title').value = rel.music_title || 'Original Audio';
            document.getElementById('reel_tags').value = rel.tags || '';
            document.getElementById('reel_video_url').value = rel.video_url || '';
            if (document.getElementById('reel_source_url')) document.getElementById('reel_source_url').value = rel.source_url || '';

            const modalEl = document.getElementById('reelModal');
            const data = getAlpineData(modalEl);
            if (data) {
                data.isActive = parseInt(rel.is_active) === 1 ? 1 : 0;
                data.videoUrl = rel.video_url || '';
                data.statusText = '';
                data.creatorId = parseInt(rel.creator_id) || 0;
                data.creatorName = rel.creator_name || 'CropSync Creator';
                data.creatorPhone = rel.phone_number || '';
                data.cropVal = rel.crop || 'General';
                data.categoryVal = rel.category || 'Crop Care';
                data.languageVal = rel.language || 'te';
                data.sourceUrl = rel.source_url || '';
                data.payoutEligible = (rel.payout_eligible !== undefined && rel.payout_eligible !== null) ? parseInt(rel.payout_eligible) : 1;
                data.isDuplicate = parseInt(rel.is_duplicate) || 0;
                data.rightsDeclared = (rel.rights_declared !== undefined && rel.rights_declared !== null) ? parseInt(rel.rights_declared) : 1;
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

        // --- Reel Comments Moderation Drawer ---
        function openReelCommentsModal(reelId, caption) {
            document.getElementById('reelCommentsSubtitle').innerText = 'Reel #' + reelId + ' • "' + (caption || '') + '"';
            document.getElementById('reelCommentsLoading').style.display = 'block';
            document.getElementById('reelCommentsEmpty').style.display = 'none';
            document.getElementById('reelCommentsList').style.display = 'none';
            document.getElementById('reelCommentsTotalCount').innerText = '';
            openModal('reelCommentsModal');

            fetch('?ajax_get_reel_comments=1&reel_id=' + encodeURIComponent(reelId))
                .then(res => res.json())
                .then(data => {
                    document.getElementById('reelCommentsLoading').style.display = 'none';
                    if (!data.success) {
                        document.getElementById('reelCommentsList').style.display = 'block';
                        document.getElementById('reelCommentsList').innerHTML = '<div style="color:#ef4444; padding:12px; background:#fef2f2; border-radius:6px;">Failed to load comments: ' + (data.error || 'Server error') + '</div>';
                        return;
                    }
                    const comments = data.comments || [];
                    document.getElementById('reelCommentsTotalCount').innerText = comments.length + ' comments on this reel';
                    if (comments.length === 0) {
                        document.getElementById('reelCommentsEmpty').style.display = 'block';
                        return;
                    }
                    let html = '';
                    comments.forEach(c => {
                        const commenter = c.farmer_username || c.phone_number || ('User #' + (c.user_id || 'Farmer'));
                        const dateStr = new Date(c.created_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
                        html += `
                            <div class="comment-item-card" id="commentCard_${c.id}">
                                <div style="display: flex; gap: 10px; align-items: flex-start; flex: 1;">
                                    <div style="width: 32px; height: 32px; border-radius: 50%; background: #e0f2fe; color: #0284c7; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 0.8rem; flex-shrink: 0;">
                                        <i class="ph ph-user"></i>
                                    </div>
                                    <div style="flex: 1;">
                                        <div style="display: flex; justify-content: space-between; align-items: baseline; gap: 8px;">
                                            <span style="font-weight: 700; font-size: 0.82rem; color: var(--text-primary);">${escapeHtml(commenter)}</span>
                                            <span style="font-size: 0.70rem; color: var(--text-muted);">${dateStr}</span>
                                        </div>
                                        <div style="font-size: 0.84rem; color: var(--text-secondary); margin-top: 3px; line-height: 1.4;">
                                            ${escapeHtml(c.comment_text)}
                                        </div>
                                    </div>
                                </div>
                                <button type="button" class="btn btn-danger-outline btn-sm" style="padding: 2px 7px; font-size: 0.72rem;" onclick="deleteReelComment(${c.id}, ${reelId}, this)" title="Delete Comment">
                                    <i class="ph ph-trash"></i>
                                </button>
                            </div>
                        `;
                    });
                    const listEl = document.getElementById('reelCommentsList');
                    listEl.innerHTML = html;
                    listEl.style.display = 'block';
                })
                .catch(err => {
                    document.getElementById('reelCommentsLoading').style.display = 'none';
                    document.getElementById('reelCommentsList').style.display = 'block';
                    document.getElementById('reelCommentsList').innerHTML = '<div style="color:#ef4444; padding:12px; background:#fef2f2; border-radius:6px;">Network error while fetching comments.</div>';
                });
        }

        function deleteReelComment(commentId, reelId, btnEl) {
            showAppConfirm({
                title: 'Delete Comment #' + commentId,
                message: 'Are you sure you want to delete this farmer comment permanently?',
                subtext: 'This will remove the comment and update the reel comment count.',
                icon: 'ph-trash',
                iconColor: 'danger',
                confirmText: 'Delete Comment',
                confirmClass: 'btn-danger',
                onConfirm: () => {
                    const fd = new FormData();
                    fd.append('action', 'delete_comment');
                    fd.append('comment_id', commentId);
                    fd.append('comment_type', 'reel');
                    fd.append('parent_id', reelId);
                    fd.append('redirect_tab', 'reels');

                    fetch(window.location.href, {
                        method: 'POST',
                        body: fd,
                        headers: { 'X-Requested-With': 'XMLHttpRequest' }
                    })
                    .then(res => res.json())
                    .then(data => {
                        const card = document.getElementById('commentCard_' + commentId);
                        if (card) {
                            card.style.opacity = '0.4';
                            card.style.transform = 'scale(0.95)';
                            setTimeout(() => card.remove(), 200);
                        }
                    })
                    .catch(() => {
                        location.reload();
                    });
                }
            });
        }

        // --- Reel Watch & Dropoff Analytics Modal ---
        function openReelAnalyticsModal(reelId, caption) {
            document.getElementById('reelAnalyticsSubtitle').innerText = 'Reel #' + reelId + ' • "' + (caption || '') + '"';
            document.getElementById('reelAnalyticsLoading').style.display = 'block';
            document.getElementById('reelAnalyticsContent').style.display = 'none';
            openModal('reelAnalyticsModal');

            fetch('?ajax_get_reel_analytics=1&reel_id=' + encodeURIComponent(reelId))
                .then(res => res.json())
                .then(data => {
                    document.getElementById('reelAnalyticsLoading').style.display = 'none';
                    if (!data.success) {
                        alert('Could not load analytics: ' + (data.error || 'Server error'));
                        return;
                    }
                    const reel = data.reel || {};
                    const stats = data.watch_stats || {};
                    const actions = data.actions || {};
                    const reviews = data.reviews || [];

                    const totalWatches = parseInt(stats.total_watches) || 0;
                    const completedWatches = parseInt(stats.completed_watches) || 0;
                    const uniqueViewers = parseInt(stats.unique_viewers) || 0;
                    const avgSec = Math.round(parseFloat(stats.avg_watch_seconds) || 0);
                    const totalSec = Math.round(parseFloat(stats.total_watch_seconds) || 0);
                    const completionRate = totalWatches > 0 ? Math.round((completedWatches / totalWatches) * 100) : 0;

                    let totalAudienceActions = 0;
                    for (let k in actions) {
                        totalAudienceActions += actions[k];
                    }

                    document.getElementById('anaTotalWatches').innerText = totalWatches.toLocaleString();
                    document.getElementById('anaUniqueViewers').innerText = uniqueViewers.toLocaleString() + ' unique farmers';
                    document.getElementById('anaAvgWatchTime').innerText = avgSec + 's';
                    document.getElementById('anaTotalWatchTime').innerText = Math.round(totalSec / 60) + ' mins total watch time';
                    document.getElementById('anaCompletionRate').innerText = completionRate + '%';
                    document.getElementById('anaCompletedWatches').innerText = completedWatches.toLocaleString() + ' completed';
                    document.getElementById('anaTotalActions').innerText = totalAudienceActions.toLocaleString();

                    document.getElementById('anaCompletionRateText').innerText = completionRate + '%';
                    document.getElementById('anaCompletionBar').style.width = Math.min(100, completionRate) + '%';

                    // Actions Grid
                    const actionLabels = {
                        'like': { label: 'Likes', icon: 'ph-heart', color: '#ef4444' },
                        'save': { label: 'Saves / Bookmarks', icon: 'ph-bookmark', color: '#0284c7' },
                        'share': { label: 'Shares', icon: 'ph-share-network', color: '#10b981' },
                        'profile_view': { label: 'Profile Taps', icon: 'ph-user', color: '#8b5cf6' },
                        'contact_creator': { label: 'Creator Inquiries', icon: 'ph-phone-call', color: '#f59e0b' }
                    };
                    let actHtml = '';
                    const defaultKeys = ['like', 'save', 'share', 'profile_view', 'contact_creator'];
                    defaultKeys.forEach(k => {
                        const meta = actionLabels[k];
                        const count = actions[k] || 0;
                        actHtml += `
                            <div style="background:#f8fafc; border:1px solid var(--border); border-radius:8px; padding:10px 12px; display:flex; align-items:center; gap:8px;">
                                <i class="ph ${meta.icon}" style="font-size:18px; color:${meta.color};"></i>
                                <div>
                                    <div style="font-size:1.05rem; font-weight:800; color:var(--text-primary);">${count.toLocaleString()}</div>
                                    <div style="font-size:0.68rem; color:var(--text-muted);">${meta.label}</div>
                                </div>
                            </div>
                        `;
                    });
                    document.getElementById('anaActionsGrid').innerHTML = actHtml;

                    // Reviews List
                    let revHtml = '';
                    if (reviews.length === 0) {
                        revHtml = '<div style="font-size:0.8rem; color:var(--text-muted); font-style:italic;">No formal review logs recorded yet.</div>';
                    } else {
                        reviews.forEach(r => {
                            const badgeColor = r.decision === 'approved' ? '#15803d' : (r.decision === 'rejected' ? '#dc2626' : '#d97706');
                            const dateStr = new Date(r.reviewed_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
                            revHtml += `
                                <div style="padding:10px 12px; background:#f8fafc; border:1px solid var(--border); border-radius:6px; margin-bottom:6px; font-size:0.8rem;">
                                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
                                        <span style="font-weight:700; color:${badgeColor}; text-transform:uppercase; font-size:0.75rem;">${escapeHtml(r.decision)}</span>
                                        <span style="color:var(--text-muted); font-size:0.7rem;">${dateStr} &bull; ${escapeHtml(r.reviewer_id || 'Admin')}</span>
                                    </div>
                                    ${r.reason_code ? '<div style="color:var(--text-secondary); font-size:0.74rem;"><strong>Reason:</strong> ' + escapeHtml(r.reason_code) + '</div>' : ''}
                                    ${r.comments ? '<div style="color:var(--text-muted); font-style:italic; margin-top:2px;">"' + escapeHtml(r.comments) + '"</div>' : ''}
                                </div>
                            `;
                        });
                    }
                    document.getElementById('anaReviewsList').innerHTML = revHtml;

                    document.getElementById('reelAnalyticsContent').style.display = 'block';
                })
                .catch(err => {
                    document.getElementById('reelAnalyticsLoading').style.display = 'none';
                    alert('Network error while fetching reel analytics.');
                });
        }

        function escapeHtml(str) {
            if (!str) return '';
            return String(str)
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
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
            const sNotice = document.getElementById('suspendNotice');
            if (sNotice) sNotice.style.display = isSuspend ? 'block' : 'none';
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

        // --- Creator Management Helpers & Modals ---
        function applyCreatorFilter(key, val) {
            const url = new URL(window.location.href);
            url.searchParams.set('tab', 'creators');
            if (val && val !== 'all') {
                url.searchParams.set(key, val);
            } else {
                url.searchParams.delete(key);
            }
            window.location.href = url.toString();
        }

        function openCreateCreatorModal() {
            const modalEl = document.getElementById('creatorModal');
            const data = getAlpineData(modalEl);
            if (data) {
                if (typeof data.reset === 'function') {
                    data.reset();
                } else {
                    data.isEdit = false;
                    data.creatorId = 0;
                    data.displayName = '';
                    data.username = '';
                    data.phoneNumber = '';
                    data.email = '';
                    data.bio = '';
                    data.profileImageUrl = '';
                    data.niches = '';
                    data.languages = 'te';
                    data.upiId = '';
                    data.socialHandles = '';
                    data.tier = 'trial';
                    data.tierLabel = 'Trial (M1)';
                    data.status = 'active';
                    data.statusLabel = 'Active Partner';
                    data.isVerified = 0;
                    data.termsAccepted = 1;
                    data.tierOpen = false;
                    data.statusOpen = false;
                }
            }
            window.dispatchEvent(new CustomEvent('reset-creator'));
            const form = document.getElementById('creatorForm');
            if (form) form.reset();
            openModal('creatorModal');
        }

        function openEditCreatorModal(cr) {
            if (typeof cr === 'string') {
                try { cr = JSON.parse(cr); } catch(e) {}
            }
            if (!cr) return;

            // 1. Dispatch custom event for Alpine component listener
            window.dispatchEvent(new CustomEvent('populate-creator', { detail: cr }));

            // 2. Direct reactive Alpine state update via getAlpineData
            const modalEl = document.getElementById('creatorModal');
            const data = getAlpineData(modalEl);
            if (data) {
                if (typeof data.populate === 'function') {
                    data.populate(cr);
                } else {
                    data.isEdit = true;
                    data.creatorId = parseInt(cr.id) || 0;
                    data.displayName = cr.display_name || '';
                    data.username = cr.username || '';
                    data.phoneNumber = cr.phone_number || '';
                    data.email = cr.email || '';
                    data.bio = cr.bio || '';
                    data.profileImageUrl = cr.profile_image_url || '';
                    data.niches = cr.agriculture_niches || '';
                    data.languages = cr.languages || 'te';
                    data.upiId = cr.upi_id || '';
                    data.socialHandles = cr.social_handles || '';
                    
                    const curTier = cr.partnership_tier || 'trial';
                    data.tier = curTier;
                    const tierOpt = data.tierOptions ? data.tierOptions.find(o => o.val === curTier) : null;
                    data.tierLabel = tierOpt ? tierOpt.label : curTier;

                    const curStatus = cr.status || 'active';
                    data.status = curStatus;
                    const statusOpt = data.statusOptions ? data.statusOptions.find(o => o.val === curStatus) : null;
                    data.statusLabel = statusOpt ? statusOpt.label : curStatus;

                    data.isVerified = (parseInt(cr.is_verified) === 1 || cr.is_verified === true || cr.is_verified === '1') ? 1 : 0;
                    data.termsAccepted = (parseInt(cr.terms_accepted) === 1 || cr.terms_accepted === true || cr.terms_accepted === '1') ? 1 : 0;
                    data.tierOpen = false;
                    data.statusOpen = false;
                }
            }

            // 3. Fallback direct DOM value assignment and event dispatching (guarantees inputs autofill immediately)
            setTimeout(() => {
                const setVal = (id, val) => {
                    const el = document.getElementById(id);
                    if (el) {
                        el.value = val;
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                };
                setVal('form_creator_id', cr.id || 0);
                setVal('form_display_name', cr.display_name || '');
                setVal('form_username', cr.username || '');
                setVal('form_phone_number', cr.phone_number || '');
                setVal('form_email', cr.email || '');
                setVal('form_profile_image_url', cr.profile_image_url || '');
                setVal('form_agriculture_niches', cr.agriculture_niches || '');
                setVal('form_languages', cr.languages || 'te');
                setVal('form_upi_id', cr.upi_id || '');
                setVal('form_social_handles', cr.social_handles || '');
                setVal('form_bio', cr.bio || '');

                const vcb = document.getElementById('form_is_verified');
                if (vcb) {
                    vcb.checked = (parseInt(cr.is_verified) === 1);
                    vcb.dispatchEvent(new Event('change', { bubbles: true }));
                }
                const tcb = document.getElementById('form_terms_accepted');
                if (tcb) {
                    tcb.checked = (parseInt(cr.terms_accepted) === 1);
                    tcb.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }, 10);

            openModal('creatorModal');
        }

        function openDeleteCreatorModal(id, name, username, reelsCount) {
            document.getElementById('delete_creator_id').value = id;
            document.getElementById('delete_creator_name').innerText = name + (username ? ' (@' + username + ')' : '');
            document.getElementById('delete_creator_meta').innerText = 'Creator Partner ID #' + id;
            document.getElementById('delete_reels_count').innerText = reelsCount || 0;
            openModal('deleteCreatorModal');
        }

        // --- Reel Moderation SLA & Review Helpers ---
        function updateModReasonAlpine(val) {
            const el = document.getElementById('modReasonAlpine');
            const data = getAlpineData(el);
            if (data && data.options) {
                const opt = data.options.find(o => o.val === val);
                data.val = val;
                data.label = opt ? opt.label : val;
            }
        }

        function toggleReasonCodeRequired(decision) {
            const submitBtn = document.getElementById('modSubmitBtn');
            const reasonInput = document.getElementById('mod_reason_code');
            if (decision === 'approved') {
                submitBtn.style.background = '#15803d';
                submitBtn.style.borderColor = '#15803d';
                submitBtn.innerText = 'Approve & Publish Reel';
                if (!reasonInput.value || reasonInput.value !== 'manual_approval') {
                    reasonInput.value = 'manual_approval';
                    updateModReasonAlpine('manual_approval');
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

        function showToast(message, type = 'success') {
            const container = document.getElementById('toastContainer');
            if (!container) return;

            const toast = document.createElement('div');
            toast.className = `toast-item ${type}`;

            let iconClass = 'ph-check-circle';
            if (type === 'danger') iconClass = 'ph-x-circle';
            else if (type === 'warning') iconClass = 'ph-warning-circle';
            else if (type === 'info') iconClass = 'ph-info';

            toast.innerHTML = `
                <i class="ph-fill ${iconClass} toast-icon"></i>
                <div class="toast-content">${message}</div>
                <button type="button" class="toast-close" onclick="this.parentElement.classList.remove('show'); setTimeout(() => this.parentElement.remove(), 300);">&times;</button>
            `;

            container.appendChild(toast);
            requestAnimationFrame(() => {
                toast.classList.add('show');
            });

            setTimeout(() => {
                if (toast.parentElement) {
                    toast.classList.remove('show');
                    toast.classList.add('hide');
                    setTimeout(() => toast.remove(), 300);
                }
            }, 3800);
        }

        async function realtimeToggleReelVisibility(reelId, btn) {
            const creatorStatus = btn.dataset.creatorStatus || '';
            const curActive = parseInt(btn.dataset.active || '0');

            if (curActive === 0 && creatorStatus === 'suspended') {
                showToast('Cannot activate reel: Creator is currently suspended. Unsuspend the creator first.', 'danger');
                return;
            }

            const origContent = btn.innerHTML;
            btn.innerHTML = '<i class="ph ph-spinner ph-spin"></i>';
            btn.disabled = true;

            try {
                const formData = new FormData();
                formData.append('action', 'toggle_reel_status');
                formData.append('reel_id', reelId);
                formData.append('is_active', curActive);
                formData.append('ajax', '1');

                const resp = await fetch('studio_dashboard.php', {
                    method: 'POST',
                    headers: { 'X-Requested-With': 'XMLHttpRequest' },
                    body: formData
                });
                const data = await resp.json();

                if (data.success) {
                    const newActive = parseInt(data.is_active);
                    btn.dataset.active = newActive;
                    if (newActive === 1) {
                        btn.style.background = '#f0fdf4';
                        btn.style.color = '#166534';
                        btn.style.border = '1px solid #bbf7d0';
                        btn.innerHTML = '🟢 Visible';
                    } else {
                        btn.style.background = '#f1f5f9';
                        btn.style.color = '#64748b';
                        btn.style.border = '1px solid #cbd5e1';
                        btn.innerHTML = '⚫ Hidden';
                    }
                    showToast(data.message || 'Reel visibility updated', 'success');
                } else {
                    btn.innerHTML = origContent;
                    showToast(data.error || 'Failed to update visibility', 'danger');
                }
            } catch (err) {
                btn.innerHTML = origContent;
                showToast('Network error while updating visibility', 'danger');
            } finally {
                btn.disabled = false;
            }
        }

        async function realtimeToggleReelPayout(reelId, btn) {
            const creatorStatus = btn.dataset.creatorStatus || '';
            const curEligible = parseInt(btn.dataset.eligible || '0');

            if (curEligible === 0 && creatorStatus === 'suspended') {
                showToast('Cannot make payout eligible: Creator is suspended.', 'danger');
                return;
            }

            const origContent = btn.innerHTML;
            btn.innerHTML = '<i class="ph ph-spinner ph-spin"></i>';
            btn.disabled = true;

            try {
                const formData = new FormData();
                formData.append('action', 'toggle_reel_payout_eligible');
                formData.append('reel_id', reelId);
                formData.append('payout_eligible', curEligible);
                formData.append('ajax', '1');

                const resp = await fetch('studio_dashboard.php', {
                    method: 'POST',
                    headers: { 'X-Requested-With': 'XMLHttpRequest' },
                    body: formData
                });
                const data = await resp.json();

                if (data.success) {
                    const newEligible = parseInt(data.payout_eligible);
                    btn.dataset.eligible = newEligible;
                    if (newEligible === 1) {
                        btn.className = 'payout-status-btn eligible';
                        btn.innerHTML = '<i class="ph ph-currency-inr"></i> Payout OK';
                    } else {
                        btn.className = 'payout-status-btn ineligible';
                        btn.innerHTML = '<i class="ph ph-currency-inr"></i> No Payout';
                    }
                    showToast(data.message || 'Payout status updated', 'success');
                } else {
                    btn.innerHTML = origContent;
                    showToast(data.error || 'Failed to update payout status', 'danger');
                }
            } catch (err) {
                btn.innerHTML = origContent;
                showToast('Network error while updating payout status', 'danger');
            } finally {
                btn.disabled = false;
            }
        }

        async function realtimeToggleReelDuplicate(reelId, btn) {
            const curDup = parseInt(btn.dataset.duplicate || '0');
            const origContent = btn.innerHTML;
            btn.innerHTML = '<i class="ph ph-spinner ph-spin"></i>';
            btn.disabled = true;

            try {
                const formData = new FormData();
                formData.append('action', 'toggle_reel_duplicate');
                formData.append('reel_id', reelId);
                formData.append('is_duplicate', curDup);
                formData.append('ajax', '1');

                const resp = await fetch('studio_dashboard.php', {
                    method: 'POST',
                    headers: { 'X-Requested-With': 'XMLHttpRequest' },
                    body: formData
                });
                const data = await resp.json();

                if (data.success) {
                    const newDup = parseInt(data.is_duplicate);
                    btn.dataset.duplicate = newDup;
                    const dupBadge = document.getElementById('reel-dup-badge-' + reelId);
                    if (newDup === 1) {
                        btn.style.background = '#fee2e2';
                        btn.style.color = '#b91c1c';
                        btn.style.border = '1px solid #fecaca';
                        btn.innerHTML = '⚠️ Dup Flag';
                        if (dupBadge) dupBadge.style.display = 'inline-flex';

                        // Payout is automatically forfeited
                        const payoutBtn = document.getElementById('reel-payout-btn-' + reelId);
                        if (payoutBtn) {
                            payoutBtn.dataset.eligible = '0';
                            payoutBtn.className = 'payout-status-btn ineligible';
                            payoutBtn.innerHTML = '<i class="ph ph-currency-inr"></i> No Payout';
                        }
                    } else {
                        btn.style.background = '#f8fafc';
                        btn.style.color = '#94a3b8';
                        btn.style.border = '1px solid #e2e8f0';
                        btn.innerHTML = 'Mark Dup';
                        if (dupBadge) dupBadge.style.display = 'none';

                        const payoutBtn = document.getElementById('reel-payout-btn-' + reelId);
                        if (payoutBtn) {
                            payoutBtn.dataset.eligible = '1';
                            payoutBtn.className = 'payout-status-btn eligible';
                            payoutBtn.innerHTML = '<i class="ph ph-currency-inr"></i> Payout OK';
                        }
                    }
                    showToast(data.message || 'Duplicate flag updated', 'success');
                } else {
                    btn.innerHTML = origContent;
                    showToast(data.error || 'Failed to update duplicate flag', 'danger');
                }
            } catch (err) {
                btn.innerHTML = origContent;
                showToast('Network error while updating duplicate flag', 'danger');
            } finally {
                btn.disabled = false;
            }
        }

        async function triggerReelsLiveSync() {
            try {
                const resp = await fetch('studio_dashboard.php?ajax_reels_live_sync=1');
                if (!resp.ok) return;
                const data = await resp.json();
                if (!data.success || !Array.isArray(data.reels)) return;

                const indicatorText = document.getElementById('reelsRealtimeText');
                if (indicatorText) {
                    const now = new Date();
                    indicatorText.innerText = 'Live Sync ' + now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
                }

                // Process reels in the table
                data.reels.forEach(rel => {
                    const row = document.getElementById('reel-row-' + rel.id);
                    if (!row) return;

                    const isCreatorSuspended = (rel.creator_status === 'suspended');

                    // Update row suppressed appearance
                    if (isCreatorSuspended) {
                        row.classList.add('row-suppressed');
                        row.dataset.creatorStatus = 'suspended';

                        // Update creator cell badge if not present
                        const creatorCell = document.getElementById('reel-creator-cell-' + rel.id);
                        if (creatorCell && !creatorCell.querySelector('.badge')) {
                            const badge = document.createElement('span');
                            badge.className = 'badge';
                            badge.style.cssText = 'background:#fee2e2; color:#b91c1c; font-size:0.65rem; padding:1px 6px; border-radius:4px; font-weight:700; display:inline-flex; align-items:center; gap:3px;';
                            badge.title = 'Creator account is currently suspended';
                            badge.innerHTML = '<i class="ph ph-prohibit"></i> Suspended';
                            const titleSpan = creatorCell.querySelector('span');
                            if (titleSpan) titleSpan.parentElement.appendChild(badge);
                        }

                        // Update status cell to suppressed
                        const statusCell = document.getElementById('reel-status-cell-' + rel.id);
                        if (statusCell && !statusCell.innerHTML.includes('Suppressed')) {
                            statusCell.querySelector('.status-tag')?.remove();
                            const newTag = document.createElement('span');
                            newTag.className = 'status-tag hidden';
                            newTag.style.cssText = 'background:#fef2f2; color:#991b1b; border:1px solid #fecaca; font-weight:700; display:inline-flex; align-items:center; gap:4px;';
                            newTag.title = 'Creator account is suspended. This reel is forcibly deactivated.';
                            newTag.innerHTML = '<i class="ph ph-prohibit"></i> Suppressed (Creator Suspended)';
                            statusCell.prepend(newTag);
                        }

                        // Block quick approve button
                        const qBtn = document.getElementById('quick-approve-btn-' + rel.id);
                        if (qBtn) {
                            qBtn.className = 'btn btn-sm';
                            qBtn.style.cssText = 'background:#fee2e2; color:#b91c1c; border-color:#fecaca; padding:4px 9px; font-size:0.75rem; cursor:not-allowed;';
                            qBtn.disabled = true;
                            qBtn.innerHTML = '<i class="ph ph-prohibit"></i> Blocked';
                        }
                    } else {
                        row.classList.remove('row-suppressed');
                        row.dataset.creatorStatus = rel.creator_status || '';
                    }

                    // Update views & likes counters
                    const vEl = document.getElementById('reel-views-' + rel.id);
                    if (vEl) vEl.innerText = Number(rel.views_count || 0).toLocaleString();
                    const lEl = document.getElementById('reel-likes-' + rel.id);
                    if (lEl) lEl.innerText = Number(rel.likes_count || 0).toLocaleString();
                    const cEl = document.getElementById('reel-comments-' + rel.id);
                    if (cEl) cEl.innerText = Number(rel.comments_count || 0).toLocaleString();
                });
            } catch (e) {
                // Background sync silent fail
            }
        }

        // Run sync poller every 15 seconds
        setInterval(triggerReelsLiveSync, 15000);

        function quickApproveReel(reelId, caption, creatorStatus = '') {
            if (creatorStatus === 'suspended') {
                showToast('Cannot approve reel: Creator is currently suspended.', 'danger');
                return;
            }

            showAppConfirm({
                title: 'Approve Agri Reel #' + reelId,
                message: 'Approve "' + caption + '" and make it publicly visible to users?',
                subtext: 'This will set the reel status to Approved, mark it as active, and make it eligible for creator payouts.',
                icon: 'ph-check-circle',
                iconColor: 'success',
                confirmText: 'Approve & Publish',
                confirmClass: 'btn-primary',
                confirmStyle: 'flex: 1; padding: 9px 16px; background: #15803d; border-color: #15803d; color: white;',
                onConfirm: async () => {
                    try {
                        const formData = new FormData();
                        formData.append('action', 'admin_review_reel');
                        formData.append('reel_id', reelId);
                        formData.append('decision', 'approved');
                        formData.append('reason_code', 'manual_approval');
                        formData.append('comments', 'Manual approval by moderator from dashboard.');
                        formData.append('ajax', '1');

                        const resp = await fetch('studio_dashboard.php', {
                            method: 'POST',
                            headers: { 'X-Requested-With': 'XMLHttpRequest' },
                            body: formData
                        });
                        const data = await resp.json();

                        if (data.success) {
                            showToast(`Reel #${reelId} approved and published live!`, 'success');
                            
                            // Real-time DOM updates
                            const statusCell = document.getElementById('reel-status-cell-' + reelId);
                            if (statusCell) {
                                const oldTag = statusCell.querySelector('.status-tag');
                                if (oldTag) oldTag.remove();
                                const newTag = document.createElement('span');
                                newTag.className = 'status-tag active';
                                newTag.style.cssText = 'background:#dcfce7; color:#15803d; font-weight:600; display:inline-flex; align-items:center; gap:4px;';
                                newTag.innerHTML = '<i class="ph ph-check-circle"></i> Live & Approved';
                                statusCell.prepend(newTag);
                            }

                            const visBtn = document.getElementById('reel-vis-btn-' + reelId);
                            if (visBtn) {
                                visBtn.dataset.active = '1';
                                visBtn.style.background = '#f0fdf4';
                                visBtn.style.color = '#166534';
                                visBtn.style.border = '1px solid #bbf7d0';
                                visBtn.innerHTML = '🟢 Visible';
                            }

                            const payoutBtn = document.getElementById('reel-payout-btn-' + reelId);
                            if (payoutBtn) {
                                payoutBtn.dataset.eligible = '1';
                                payoutBtn.className = 'payout-status-btn eligible';
                                payoutBtn.innerHTML = '<i class="ph ph-currency-inr"></i> Payout OK';
                            }

                            const qBtn = document.getElementById('quick-approve-btn-' + reelId);
                            if (qBtn) qBtn.remove();
                        } else {
                            showToast(data.error || 'Failed to approve reel', 'danger');
                        }
                    } catch (e) {
                        showToast('Error approving reel: Network error', 'danger');
                    }
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
                updateModReasonAlpine(reel.reason_code);
            } else {
                updateModReasonAlpine('manual_approval');
            }
            document.getElementById('mod_comments').value = reel.feedback || '';
            
            openModal('reelModerationModal');
        }
    </script>
</body>
</html>
