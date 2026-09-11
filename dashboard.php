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
            'created_at' => "ALTER TABLE `reels` ADD COLUMN `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
        ];
        foreach ($reelsCols as $cCol => $cSql) {
            try {
                $chk = $pdo->query("SHOW COLUMNS FROM `reels` LIKE '$cCol'");
                if (!$chk || !$chk->fetch()) {
                    $pdo->exec($cSql);
                }
            } catch (Throwable $e) {}
        }

        // Migrate any missing columns in news_articles
        $newsCols = [
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
            } catch (Throwable $e) {}
        }
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
}

// -------------------------------------------------------------
// 5. Data Fetching
// -------------------------------------------------------------
$activeTab = $_GET['tab'] ?? 'news';
$searchQuery = trim($_GET['q'] ?? '');
$categoryFilter = trim($_GET['category'] ?? 'all');
$flash = getFlash();

$totalNews = 0;
$publishedNews = 0;
$totalReels = 0;
$activeReels = 0;

$articlesList = [];
$reelsList = [];
$commentsList = [];

if (isset($pdo) && $pdo instanceof PDO) {
    try {
        $nStats = $pdo->query("SELECT COUNT(*) as total, SUM(CASE WHEN status = 'published' THEN 1 ELSE 0 END) as published FROM news_articles")->fetch();
        if ($nStats) {
            $totalNews = intval($nStats['total']);
            $publishedNews = intval($nStats['published']);
        }

        $rStats = $pdo->query("SELECT COUNT(*) as total, SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active FROM reels")->fetch();
        if ($rStats) {
            $totalReels = intval($rStats['total']);
            $activeReels = intval($rStats['active']);
        }

        // News fetch
        $newsSql = "SELECT * FROM news_articles WHERE 1=1";
        $newsParams = [];
        if (!empty($searchQuery) && $activeTab === 'news') {
            $newsSql .= " AND (title LIKE ? OR summary LIKE ? OR author LIKE ?)";
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

        // Reels fetch
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
        $reelSql .= " ORDER BY r.id DESC LIMIT 100";
        $rStmt = $pdo->prepare($reelSql);
        $rStmt->execute($reelParams);
        $reelsList = $rStmt->fetchAll();

        // Comments fetch
        $commSql = "
            (SELECT id, article_id as parent_id, 'news' as type, user_name as author_name, phone_number, comment_text, created_at 
             FROM news_article_comments ORDER BY id DESC LIMIT 25)
            UNION ALL
            (SELECT id, reel_id as parent_id, 'reel' as type, farmer_username as author_name, phone_number, comment_text, created_at 
             FROM reel_comments ORDER BY id DESC LIMIT 25)
            ORDER BY created_at DESC LIMIT 50";
        $cStmt = $pdo->query($commSql);
        $commentsList = $cStmt ? $cStmt->fetchAll() : [];

    } catch (Throwable $e) {
        $dbError = $e->getMessage();
    }
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

        /* MODAL */
        .modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.45);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 1000;
            padding: 16px;
        }
        .modal-overlay.open {
            display: flex;
        }

        .modal-card {
            background: var(--surface);
            border-radius: var(--radius);
            width: 100%;
            max-width: 580px;
            max-height: 90vh;
            overflow-y: auto;
            border: 1px solid var(--border);
        }

        .modal-head {
            padding: 14px 18px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .modal-head h3 {
            font-size: 0.95rem;
            font-weight: 700;
        }
        .close-btn {
            background: transparent;
            border: none;
            font-size: 18px;
            cursor: pointer;
            color: var(--text-muted);
        }
        .close-btn:hover {
            color: var(--text-primary);
        }

        .modal-body {
            padding: 18px;
        }

        .modal-foot {
            padding: 12px 18px;
            border-top: 1px solid var(--border);
            display: flex;
            justify-content: flex-end;
            gap: 8px;
            background: #fafafa;
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
            <!-- Catalog Dashboard Link -->
            <a href="shop_seeds_dashboard.php" class="btn btn-secondary" title="Agri Shop & Seeds Catalog Master" style="text-decoration: none;">
                <i class="ph-bold ph-storefront"></i> Seeds & Shop Catalog
            </a>

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
                    <a href="shop_seeds_dashboard.php" class="dropdown-option" style="text-decoration:none;">
                        <span><i class="ph ph-storefront"></i> Seeds & Shop Catalog</span>
                    </a>
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
            <i class="ph ph-film-strip"></i> Agri Reels
            <span class="tab-counter"><?= $totalReels ?></span>
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
                                    <th>Visibility</th>
                                    <th>Engagement</th>
                                    <th>Date</th>
                                    <th style="text-align: right;">Delete / Edit</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($reelsList)): ?>
                                    <tr>
                                        <td colspan="10" style="text-align: center; color: var(--text-muted); padding: 36px;">
                                            No reels found. Click "+ Upload Reel" to upload a short video.
                                        </td>
                                    </tr>
                                <?php else: foreach ($reelsList as $rel): ?>
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
                                            <span class="status-tag <?= intval($rel['is_active']) === 1 ? 'active' : 'hidden' ?>">
                                                <?= intval($rel['is_active']) === 1 ? 'Active' : 'Hidden' ?>
                                            </span>
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-secondary); white-space: nowrap;">
                                            <?= number_format($rel['views_count']) ?> views &bull; <?= number_format($rel['likes_count']) ?> likes
                                        </td>
                                        <td style="font-size: 0.78rem; color: var(--text-muted); white-space: nowrap;">
                                            <?= date('M d, Y', strtotime($rel['created_at'])) ?>
                                        </td>
                                        <td style="text-align: right; white-space: nowrap;">
                                            <button type="button" class="btn btn-secondary btn-sm" onclick='editReel(<?= json_encode($rel) ?>)' title="Edit">
                                                <i class="ph ph-pencil"></i>
                                            </button>
                                            <button type="button" class="btn btn-secondary btn-sm" onclick="previewReelVideo('<?= htmlspecialchars($rel['video_url']) ?>', '<?= htmlspecialchars(addslashes($rel['caption'])) ?>', '<?= htmlspecialchars(addslashes($rel['creator_name'] ?? 'Creator')) ?>')" title="Play Reel">
                                                <i class="ph ph-play"></i>
                                            </button>
                                            <button type="button" class="btn btn-danger-outline btn-sm" onclick="promptDelete('reel', <?= $rel['id'] ?>, '<?= htmlspecialchars(addslashes(mb_strimwidth($rel['caption'], 0, 40, '...'))) ?>')" title="Delete Reel">
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
        <div class="modal-card delete-dialog">
            <div class="modal-head" style="border-bottom-color:#fecaca; background:#fef2f2;">
                <h3 style="color:var(--danger); display:flex; align-items:center; gap:6px;">
                    <i class="ph ph-warning-circle"></i> Confirm Delete
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

                <div class="modal-body" style="font-size: 0.88rem; color: var(--text-secondary);">
                    <p>Are you sure you want to permanently delete this item?</p>
                    <p id="deleteItemTitle" style="font-weight: 700; color: var(--text-primary); margin-top: 6px;"></p>
                    <p style="font-size: 0.78rem; color: var(--text-muted); margin-top: 8px;">
                        This operation cannot be reversed.
                    </p>
                </div>
                <div class="modal-foot">
                    <button type="button" class="btn btn-secondary" onclick="closeModal('deleteConfirmModal')">Cancel</button>
                    <button type="submit" class="btn btn-danger">Yes, Delete</button>
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

        function confirmBulkDelete(formId, itemLabel) {
            if (confirm('Are you sure you want to permanently delete all ' + itemLabel + '?')) {
                document.getElementById(formId).submit();
            }
        }
    </script>
</body>
</html>
