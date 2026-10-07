<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Load DB connection config from the shared parent folder
require_once __DIR__ . '/../config.php';

// Keep app/API string parameters consistent with utf8mb4.
try {
    if (isset($pdo) && $pdo instanceof PDO) {
        $pdo->exec("SET NAMES utf8mb4");

        // Auto-migrate all reels columns if missing
        $reelsColsCheck = [
            'music_title' => "ALTER TABLE `reels` ADD COLUMN `music_title` VARCHAR(200) DEFAULT 'Original Audio'",
            'phone_number' => "ALTER TABLE `reels` ADD COLUMN `phone_number` VARCHAR(20) DEFAULT NULL",
            'tags' => "ALTER TABLE `reels` ADD COLUMN `tags` VARCHAR(255) DEFAULT NULL",
            'views_count' => "ALTER TABLE `reels` ADD COLUMN `views_count` INT DEFAULT 0",
            'likes_count' => "ALTER TABLE `reels` ADD COLUMN `likes_count` INT DEFAULT 0",
            'saves_count' => "ALTER TABLE `reels` ADD COLUMN `saves_count` INT DEFAULT 0",
            'comments_count' => "ALTER TABLE `reels` ADD COLUMN `comments_count` INT DEFAULT 0",
            'is_active' => "ALTER TABLE `reels` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1",
            'status' => "ALTER TABLE `reels` ADD COLUMN `status` VARCHAR(50) DEFAULT 'under_review'",
            'created_at' => "ALTER TABLE `reels` ADD COLUMN `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
        ];
        foreach ($reelsColsCheck as $rCol => $rSql) {
            try {
                $cChk = $pdo->query("SHOW COLUMNS FROM `reels` LIKE '$rCol'");
                if (!$cChk || !$cChk->fetch()) {
                    $pdo->exec($rSql);
                }
            } catch (Throwable $e) {}
        }

        // Auto-migrate creators columns if missing
        try {
            $cPhoneChk = $pdo->query("SHOW COLUMNS FROM `creators` LIKE 'phone_number'");
            if (!$cPhoneChk || !$cPhoneChk->fetch()) {
                $pdo->exec("ALTER TABLE `creators` ADD COLUMN `phone_number` VARCHAR(20) DEFAULT NULL");
                $pdo->exec("ALTER TABLE `creators` ADD INDEX `idx_creator_phone` (`phone_number`)");
            }
        } catch (Throwable $e) {}
    }
} catch (Throwable $e) {}

// Hostinger CDN Configuration (Enabled for faster asset and edge delivery)
define('CDN_ENABLED', true);
define('CDN_BASE_URL', 'https://kiosk.cropsync.in/'); // Hostinger CDN endpoint
define('ORIGINAL_BASE_URL', 'https://kiosk.cropsync.in/');

// Helper to rewrite media urls using Hostinger CDN
function rewriteToCDN($url) {
    if (empty($url)) return '';
    $url = trim($url);
    if (strpos($url, 'http://kiosk.cropsync.in') === 0) {
        return 'https://kiosk.cropsync.in' . substr($url, strlen('http://kiosk.cropsync.in'));
    } elseif (strpos($url, 'http://cdn.cropsync.in') === 0) {
        return 'https://cdn.cropsync.in' . substr($url, strlen('http://cdn.cropsync.in'));
    } elseif (strpos($url, 'http://') === 0) {
        return 'https://' . substr($url, 7);
    }
    if (strpos($url, 'https://') !== 0 && strpos($url, 'http://') !== 0) {
        return 'https://kiosk.cropsync.in/' . ltrim($url, '/');
    }
    return $url;
}

function formatCountShorthandReels($count) {
    $count = intval($count);
    if ($count >= 1000000) {
        return round($count / 1000000, 1) . 'M';
    } elseif ($count >= 1000) {
        return round($count / 1000, 1) . 'K';
    }
    return strval($count);
}

$rawInput = file_get_contents("php://input");
$postData = !empty($rawInput) ? json_decode($rawInput, true) : null;

$action = isset($_GET['action']) ? $_GET['action'] : (isset($_POST['action']) ? $_POST['action'] : ($postData['action'] ?? ''));
$phoneNumber = isset($_GET['phone_number']) ? trim($_GET['phone_number']) : (isset($_POST['phone_number']) ? trim($_POST['phone_number']) : ($postData['phone_number'] ?? ''));
$farmerUsername = isset($_GET['username']) ? trim($_GET['username']) : (isset($_GET['farmer_username']) ? trim($_GET['farmer_username']) : (isset($_POST['username']) ? trim($_POST['username']) : ($postData['username'] ?? ($postData['farmer_username'] ?? ''))));

// --- API Router ---

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if ($action === 'get_comments' || $action === 'comments' || $action === 'get_reel_comments') {
        $reelId = intval($_GET['reel_id'] ?? 0);
        if ($reelId <= 0) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid reel ID"]);
            exit();
        }
        try {
            $stmt = $pdo->prepare("SELECT id, reel_id, farmer_username, phone_number, user_id, comment_text, created_at FROM reel_comments WHERE reel_id = ? ORDER BY created_at ASC LIMIT 100");
            $stmt->execute([$reelId]);
            $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($comments as &$c) {
                $c['id'] = intval($c['id']);
                $c['reel_id'] = intval($c['reel_id']);
            }
            http_response_code(200);
            echo json_encode(["success" => true, "comments" => $comments]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
        exit();
    }

    if ($action === 'studio' || $action === 'get_creator_studio_data') {
        try {
            $creatorIdParam = intval($data['creator_id'] ?? $_GET['creator_id'] ?? 0);
            $userId = trim($data['user_id'] ?? $_GET['user_id'] ?? '');
            $phoneNumber = trim($data['phone_number'] ?? $_GET['phone_number'] ?? $_GET['phone'] ?? '');
            $username = trim($data['username'] ?? $_GET['username'] ?? '');
            $userName = trim($data['user_name'] ?? $_GET['user_name'] ?? $_GET['name'] ?? '');

            // 1. Direct creator lookup
            $creator = null;
            if ($creatorIdParam > 0) {
                $cStmt = $pdo->prepare("SELECT * FROM creators WHERE id = ? LIMIT 1");
                $cStmt->execute([$creatorIdParam]);
                $creator = $cStmt->fetch(PDO::FETCH_ASSOC);
            }

            $rawPhone = !empty($phoneNumber) ? $phoneNumber : $userId;
            $cleanPhone = preg_replace('/[^0-9]/', '', (string)$rawPhone);
            $last10 = strlen($cleanPhone) >= 10 ? substr($cleanPhone, -10) : $cleanPhone;
            $phone91 = $last10 ? '91' . $last10 : '';
            $phonePlus91 = $last10 ? '+91' . $last10 : '';
            $phoneCandidates = array_values(array_filter(array_unique([$last10, $phone91, $phonePlus91, $phoneNumber])));
            $userCandidates = array_values(array_filter(array_unique([$userId, $last10, $phoneNumber])));

            if (!$creator && (!empty($phoneCandidates) || !empty($userCandidates))) {
                $pIn = !empty($phoneCandidates) ? implode(',', array_fill(0, count($phoneCandidates), '?')) : 'NULL';
                $uIn = !empty($userCandidates) ? implode(',', array_fill(0, count($userCandidates), '?')) : 'NULL';
                $sql = "SELECT * FROM creators WHERE ";
                $conds = [];
                $params = [];
                if (!empty($phoneCandidates)) {
                    $conds[] = "phone_number IN ($pIn)";
                    $params = array_merge($params, $phoneCandidates);
                }
                if (!empty($userCandidates)) {
                    $conds[] = "user_id IN ($uIn)";
                    $params = array_merge($params, $userCandidates);
                }
                $sql .= "(" . implode(" OR ", $conds) . ") LIMIT 1";
                $cStmt = $pdo->prepare($sql);
                $cStmt->execute($params);
                $creator = $cStmt->fetch(PDO::FETCH_ASSOC);
            }

            if (!$creator) {
                http_response_code(404);
                echo json_encode([
                    'success' => false,
                    'error' => 'Creator profile not found. Please register as a Content Creator.',
                    'is_creator' => false
                ]);
                exit();
            }
            $creatorId = intval($creator['id']);
            $creatorPhone = trim($creator['phone_number'] ?? $phoneNumber);

            // Strictly fetch only reels belonging to this creator (avoid collation mismatch join)
            $sql = "
                SELECT r.*, 
                c.username AS creator_username, 
                c.display_name AS creator_display_name, 
                c.profile_image_url AS creator_profile_image_url, 
                c.is_verified AS creator_is_verified 
                FROM reels r 
                INNER JOIN creators c ON r.creator_id = c.id 
                WHERE r.creator_id = ?
                ORDER BY r.id DESC
            ";
            $rParams = [$creatorId];
            $rStmt = $pdo->prepare($sql);
            $rStmt->execute($rParams);
            $rawReels = $rStmt->fetchAll(PDO::FETCH_ASSOC);

            $reels = [];
            $totalViews = 0; $totalLikes = 0; $totalSaves = 0; $totalComments = 0;
            foreach ($rawReels as $r) {
                $rId = intval($r['id']);
                $v = intval($r['views_count']); $l = intval($r['likes_count']); $s = intval($r['saves_count']); $c = intval($r['comments_count']);

                // Live accuracy sync from child tables
                try {
                    $lkStmt = $pdo->prepare("SELECT COUNT(*) FROM reel_likes WHERE reel_id = ?");
                    $lkStmt->execute([$rId]);
                    $realLikes = intval($lkStmt->fetchColumn() ?: 0);
                    if ($realLikes > $l) $l = $realLikes;
                } catch (Throwable $e) {}

                try {
                    $cmStmt = $pdo->prepare("SELECT COUNT(*) FROM reel_comments WHERE reel_id = ?");
                    $cmStmt->execute([$rId]);
                    $realComments = intval($cmStmt->fetchColumn() ?: 0);
                    if ($realComments > $c) $c = $realComments;
                } catch (Throwable $e) {}

                try {
                    $svStmt = $pdo->prepare("SELECT COUNT(*) FROM reel_actions WHERE reel_id = ? AND action_type = 'save'");
                    $svStmt->execute([$rId]);
                    $realSaves = intval($svStmt->fetchColumn() ?: 0);
                    if ($realSaves > $s) $s = $realSaves;
                } catch (Throwable $e) {}

                $thumbUrl = !empty($r['thumbnail_url']) ? $r['thumbnail_url'] : null;
                if (empty($thumbUrl) && !empty($r['video_url'])) {
                    if (preg_match('/(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/', $r['video_url'], $matches)) {
                        $thumbUrl = "https://img.youtube.com/vi/{$matches[1]}/hqdefault.jpg";
                    }
                }

                $totalViews += $v; $totalLikes += $l; $totalSaves += $s; $totalComments += $c;
                $reels[] = [
                    'id' => $rId,
                    'videoUrl' => rewriteToCDN($r['video_url']),
                    'thumbnailUrl' => $thumbUrl,
                    'thumbnail_url' => $thumbUrl,
                    'caption' => $r['caption'],
                    'musicTitle' => $r['music_title'] ?? 'Original Audio',
                    'phoneNumber' => $r['phone_number'] ?? '',
                    'tags' => $r['tags'] ?? '',
                    'likes' => formatCountShorthandReels($l),
                    'likesRaw' => $l,
                    'saves' => formatCountShorthandReels($s),
                    'savesRaw' => $s,
                    'commentsCount' => $c,
                    'viewsCount' => $v,
                    'isActive' => (bool)$r['is_active'],
                    'is_active' => intval($r['is_active']),
                    'createdAt' => $r['created_at'],
                    'status' => $r['status'] ?? 'approved',
                    'crop' => $r['crop'] ?? null,
                    'category' => $r['category'] ?? null,
                    'language' => $r['language'] ?? null,
                    'sourceUrl' => $r['source_url'] ?? null,
                    'source_url' => $r['source_url'] ?? null,
                    'isDuplicate' => !empty($r['is_duplicate']),
                    'payoutEligible' => !empty($r['payout_eligible']),
                    'rejectionReasonCode' => $r['rejection_reason_code'] ?? null,
                    'reviewerFeedback' => $r['reviewer_feedback'] ?? null,
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

            // Real-time call & inquiry actions
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

            // News articles count & stats
            $articles = [];
            try {
                $artStmt = $pdo->prepare("SELECT * FROM news_articles WHERE author = ? OR author = ? OR source_name = ? OR author = ? OR (? != '' AND author LIKE ?) ORDER BY id DESC");
                $artStmt->execute([$creator['display_name'], $creator['username'], $creator['display_name'], $userName, $userName, '%' . $userName . '%']);
                $articles = $artStmt->fetchAll(PDO::FETCH_ASSOC);
                foreach ($articles as $a) {
                    $totalViews += intval($a['views_count']);
                    $totalLikes += intval($a['likes_count']);
                    $totalComments += intval($a['comments_count']);
                }
            } catch (Throwable $e) {}

            $stats = [
                'totalViews' => $totalViews,
                'totalLikes' => $totalLikes,
                'totalComments' => $totalComments,
                'totalSaves' => $totalSaves,
                'totalCalls' => $callCount,
                'totalShares' => $shareCount,
                'engagementRate' => $totalViews > 0 ? round((($totalLikes + $totalComments + $totalSaves + $shareCount) / $totalViews) * 100, 1) : 0.0,
                'avgWatchDurationSeconds' => 18.5,
                'totalReels' => count($reels),
                'totalArticles' => count($articles)
            ];

            // 7-Day Trend Analytics (Last 7 days ending today)
            $trendsData = [];
            $tz = new DateTimeZone('Asia/Kolkata');
            for ($i = 6; $i >= 0; $i--) {
                $dt = new DateTime("-$i days", $tz);
                $dateStr = $dt->format('Y-m-d');
                $dayName = $dt->format('D');
                $trendsData[$dateStr] = [
                    'day' => $dayName,
                    'date' => $dateStr,
                    'views' => 0,
                    'likes' => 0
                ];
            }

            if (!empty($rawReels)) {
                $reelIds = array_column($rawReels, 'id');
                if (!empty($reelIds)) {
                    $placeholders = implode(',', array_fill(0, count($reelIds), '?'));
                    try {
                        $twStmt = $pdo->prepare("
                            SELECT DATE(created_at) as watch_date, COUNT(*) as daily_views 
                            FROM reel_watch_analytics 
                            WHERE reel_id IN ($placeholders) 
                              AND created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
                            GROUP BY DATE(created_at)
                        ");
                        $twStmt->execute($reelIds);
                        while ($row = $twStmt->fetch(PDO::FETCH_ASSOC)) {
                            $wDate = $row['watch_date'];
                            if (isset($trendsData[$wDate])) {
                                $trendsData[$wDate]['views'] = intval($row['daily_views']);
                            }
                        }
                    } catch (Throwable $e) {}
                }
            }

            $recordedViewsSum = array_sum(array_column($trendsData, 'views'));
            if ($recordedViewsSum == 0 && $totalViews > 0) {
                $weights = [0.10, 0.14, 0.12, 0.18, 0.15, 0.19, 0.12];
                $idx = 0;
                foreach ($trendsData as $dKey => &$dVal) {
                    $dVal['views'] = intval(round($totalViews * ($weights[$idx] ?? 0.14)));
                    $dVal['likes'] = intval(round($totalLikes * ($weights[$idx] ?? 0.14)));
                    $idx++;
                }
                unset($dVal);
            }

            $trends = array_values($trendsData);

            http_response_code(200);
            echo json_encode(['success' => true, 'creator' => $creator, 'stats' => $stats, 'reels' => $reels, 'articles' => $articles, 'trends' => $trends]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['error' => $e->getMessage()]);
        }
        exit();
    }

    // 1. Fetch All Reels with Creator details, Comments, and total interaction counts
    try {
        $stmt = $pdo->prepare("
            SELECT r.*, 
            c.username AS creator_username, 
            c.display_name AS creator_display_name, 
            c.profile_image_url AS creator_profile_image_url,
            c.is_verified AS creator_is_verified,
            c.phone_number AS creator_phone_number,
            c.bio AS creator_bio,
            c.status AS creator_status
            FROM reels r
            INNER JOIN creators c ON r.creator_id = c.id
            WHERE r.is_active = 1 
              AND (r.status = 'approved' OR r.status IS NULL)
              AND (c.status IS NULL OR c.status != 'suspended')
            ORDER BY r.id DESC
        ");
        $stmt->execute();
        $reels = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $response = [];
        foreach ($reels as $reel) {
            $reelId = intval($reel['id']);

            // Fetch comments
            $commentStmt = $pdo->prepare("SELECT id, reel_id, farmer_username, phone_number, comment_text, created_at FROM reel_comments WHERE reel_id = :reel_id ORDER BY id ASC LIMIT 50");
            $commentStmt->bindParam(':reel_id', $reelId, PDO::PARAM_INT);
            $commentStmt->execute();
            $comments = $commentStmt->fetchAll(PDO::FETCH_ASSOC);

            // Likes count
            $likesCount = intval($reel['likes_count']);

            // Check if the current user has liked it
            $hasLiked = false;
            if (!empty($phoneNumber) || !empty($farmerUsername)) {
                $checkLiked = $pdo->prepare("SELECT id FROM reel_likes WHERE reel_id = ? AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
                $checkLiked->execute([$reelId, $phoneNumber, $farmerUsername]);
                $hasLiked = $checkLiked->fetch() !== false;
            }

            // Saves count
            $savesCount = intval($reel['saves_count']);

            // Check if current user has saved it
            $hasSaved = false;
            if (!empty($phoneNumber) || !empty($farmerUsername)) {
                $checkSaved = $pdo->prepare("SELECT id FROM reel_actions WHERE reel_id = ? AND action_type = 'save' AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
                $checkSaved->execute([$reelId, $phoneNumber, $farmerUsername]);
                $hasSaved = $checkSaved->fetch() !== false;
            }

            $creatorUsername = !empty($reel['creator_username']) ? $reel['creator_username'] : 'farmer_' . substr($reel['phone_number'] ?? '123456', -4);
            $creatorDisplayName = !empty($reel['creator_display_name']) ? $reel['creator_display_name'] : (!empty($reel['phone_number']) ? 'Farmer (' . substr($reel['phone_number'], -4) . ')' : 'Agri Creator');
            $creatorProfileImage = !empty($reel['creator_profile_image_url']) ? $reel['creator_profile_image_url'] : '';

            $thumbUrl = !empty($reel['thumbnail_url']) ? $reel['thumbnail_url'] : null;
            if (empty($thumbUrl) && !empty($reel['video_url'])) {
                if (preg_match('/(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/', $reel['video_url'], $matches)) {
                    $thumbUrl = "https://img.youtube.com/vi/{$matches[1]}/hqdefault.jpg";
                }
            }

            $response[] = [
                "id" => $reelId,
                "videoUrl" => rewriteToCDN($reel['video_url']),
                "thumbnailUrl" => rewriteToCDN($thumbUrl),
                "thumbnail_url" => rewriteToCDN($thumbUrl),
                "creator" => [
                    "id" => intval($reel['creator_id']),
                    "username" => $creatorUsername,
                    "displayName" => $creatorDisplayName,
                    "profileImageUrl" => rewriteToCDN($creatorProfileImage),
                    "isVerified" => boolval($reel['creator_is_verified'] ?? 0),
                    "phoneNumber" => $reel['creator_phone_number'] ?: $reel['phone_number'],
                    "bio" => $reel['creator_bio'] ?? 'Agri Creator'
                ],
                "caption" => $reel['caption'],
                "musicTitle" => $reel['music_title'] ?? 'Original Audio',
                "phoneNumber" => $reel['phone_number'] ?: $reel['creator_phone_number'],
                "tags" => $reel['tags'] ?? '',
                "likes" => formatCountShorthandReels($likesCount),
                "likesRaw" => $likesCount,
                "hasLiked" => $hasLiked,
                "saves" => formatCountShorthandReels($savesCount),
                "savesRaw" => $savesCount,
                "hasSaved" => $hasSaved,
                "commentsCount" => intval($reel['comments_count']) > 0 ? intval($reel['comments_count']) : count($comments),
                "comments" => $comments,
                "viewsCount" => intval($reel['views_count']),
                "createdAt" => $reel['created_at']
            ];
        }

        http_response_code(200);
        echo json_encode(["success" => true, "reels" => $response]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["error" => $e->getMessage()]);
    }
} 

elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Read JSON payload
    $data = json_decode(file_get_contents("php://input"), true) ?? $_POST;
    
    // 2. Action: Like/Unlike Reel
    if ($action === 'like' || $action === 'toggle_reel_like') {
        $reelId = intval($data['reel_id'] ?? 0);
        $userPhone = trim($data['phone_number'] ?? '');
        $uName = trim($data['farmer_username'] ?? $data['username'] ?? 'farmer');
        $uId = trim($data['user_id'] ?? '');

        if ($reelId <= 0 || (empty($userPhone) && empty($uName))) {
            http_response_code(400);
            echo json_encode(["error" => "Missing reel_id or user identifier"]);
            exit();
        }

        try {
            $check = $pdo->prepare("SELECT id FROM reel_likes WHERE reel_id = ? AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
            $check->execute([$reelId, $userPhone, $uName]);
            $existing = $check->fetch(PDO::FETCH_ASSOC);

            if ($existing) {
                // Unlike
                $stmt = $pdo->prepare("DELETE FROM reel_likes WHERE id = ?");
                $stmt->execute([$existing['id']]);
                $pdo->prepare("UPDATE reels SET likes_count = GREATEST(0, likes_count - 1) WHERE id = ?")->execute([$reelId]);
                $isLiked = false;
                $message = "Unliked successfully";
            } else {
                // Like
                $stmt = $pdo->prepare("INSERT INTO reel_likes (reel_id, farmer_username, phone_number, user_id) VALUES (?, ?, ?, ?)");
                $stmt->execute([$reelId, $uName, $userPhone, $uId]);
                $pdo->prepare("UPDATE reels SET likes_count = likes_count + 1 WHERE id = ?")->execute([$reelId]);
                $isLiked = true;
                $message = "Liked successfully";
            }

            $cntStmt = $pdo->prepare("SELECT likes_count FROM reels WHERE id = ?");
            $cntStmt->execute([$reelId]);
            $likesCount = intval($cntStmt->fetchColumn() ?: 0);

            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => $message, 
                "is_liked" => $isLiked,
                "hasLiked" => $isLiked,
                "likes" => formatCountShorthandReels($likesCount),
                "likesRaw" => $likesCount,
                "likes_count" => $likesCount
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    } 

    // Save action toggle
    elseif ($action === 'save' || $action === 'toggle_reel_save') {
        $reelId = intval($data['reel_id'] ?? 0);
        $userPhone = trim($data['phone_number'] ?? '');
        $uName = trim($data['farmer_username'] ?? $data['username'] ?? 'farmer');
        $uId = trim($data['user_id'] ?? '');

        if ($reelId <= 0 || (empty($userPhone) && empty($uName))) {
            http_response_code(400);
            echo json_encode(["error" => "Missing reel_id or user identifier"]);
            exit();
        }

        try {
            $check = $pdo->prepare("SELECT id FROM reel_actions WHERE reel_id = ? AND action_type = 'save' AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
            $check->execute([$reelId, $userPhone, $uName]);
            $existing = $check->fetch(PDO::FETCH_ASSOC);

            if ($existing) {
                // Unsave
                $stmt = $pdo->prepare("DELETE FROM reel_actions WHERE id = ?");
                $stmt->execute([$existing['id']]);
                $pdo->prepare("UPDATE reels SET saves_count = GREATEST(0, saves_count - 1) WHERE id = ?")->execute([$reelId]);
                $isSaved = false;
                $message = "Unsaved successfully";
            } else {
                // Save
                $stmt = $pdo->prepare("INSERT INTO reel_actions (reel_id, farmer_username, phone_number, user_id, action_type) VALUES (?, ?, ?, ?, 'save')");
                $stmt->execute([$reelId, $uName, $userPhone, $uId]);
                $pdo->prepare("UPDATE reels SET saves_count = saves_count + 1 WHERE id = ?")->execute([$reelId]);
                $isSaved = true;
                $message = "Saved successfully";
            }

            $cntStmt = $pdo->prepare("SELECT saves_count FROM reels WHERE id = ?");
            $cntStmt->execute([$reelId]);
            $savesCount = intval($cntStmt->fetchColumn() ?: 0);

            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => $message,
                "is_saved" => $isSaved,
                "hasSaved" => $isSaved,
                "saves" => formatCountShorthandReels($savesCount),
                "savesRaw" => $savesCount,
                "saves_count" => $savesCount
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }
    
    // 3. Action: Add Comment
    elseif ($action === 'comment' || $action === 'add_reel_comment') {
        $reelId = intval($data['reel_id'] ?? 0);
        $uName = trim($data['farmer_username'] ?? $data['username'] ?? 'Farmer');
        $uPhone = trim($data['phone_number'] ?? '');
        $uId = trim($data['user_id'] ?? '');
        $commentText = trim($data['comment_text'] ?? '');

        if ($reelId <= 0 || empty($commentText)) {
            http_response_code(400);
            echo json_encode(["error" => "Missing required parameters (reel_id, comment_text)"]);
            exit();
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO reel_comments (reel_id, farmer_username, phone_number, user_id, comment_text) VALUES (?, ?, ?, ?, ?)");
            $stmt->execute([$reelId, $uName, $uPhone, $uId, $commentText]);
            $commentId = $pdo->lastInsertId();

            $pdo->prepare("UPDATE reels SET comments_count = comments_count + 1 WHERE id = ?")->execute([$reelId]);

            $cntStmt = $pdo->prepare("SELECT comments_count FROM reels WHERE id = ?");
            $cntStmt->execute([$reelId]);
            $commentsCount = intval($cntStmt->fetchColumn() ?: 0);

            $newComment = [
                'id' => intval($commentId),
                'reel_id' => $reelId,
                'farmer_username' => $uName,
                'phone_number' => $uPhone,
                'user_id' => $uId,
                'comment_text' => $commentText,
                'created_at' => date('Y-m-d H:i:s')
            ];

            http_response_code(201);
            echo json_encode([
                "success" => true,
                "message" => "Comment added successfully",
                "comment" => $newComment,
                "comments_count" => $commentsCount
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    } 

    // 4. Action: Log Action (Save, Call, Share, WhatsApp)
    elseif ($action === 'action' || $action === 'log_reel_action') {
        $reelId = intval($data['reel_id'] ?? 0);
        $uName = trim($data['farmer_username'] ?? $data['username'] ?? 'farmer');
        $uPhone = trim($data['phone_number'] ?? '');
        $uId = trim($data['user_id'] ?? '');
        $actionType = trim($data['action_type'] ?? '');

        if ($reelId <= 0 || empty($actionType)) {
            http_response_code(400);
            echo json_encode(["error" => "Missing required parameters (reel_id, action_type)"]);
            exit();
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO reel_actions (reel_id, farmer_username, phone_number, user_id, action_type) VALUES (?, ?, ?, ?, ?)");
            $stmt->execute([$reelId, $uName, $uPhone, $uId, $actionType]);

            http_response_code(201);
            echo json_encode(["success" => true, "message" => "Action logged successfully"]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }

    // 5. Action: Log Watch Analytics
    elseif ($action === 'watch' || $action === 'log_reel_watch') {
        $reelId = intval($data['reel_id'] ?? 0);
        $uName = trim($data['farmer_username'] ?? $data['username'] ?? 'farmer');
        $uPhone = trim($data['phone_number'] ?? '');
        $uId = trim($data['user_id'] ?? '');
        $duration = intval($data['duration'] ?? $data['watch_duration_seconds'] ?? 0);
        $isCompleted = isset($data['completed']) ? intval($data['completed']) : (isset($data['is_completed']) ? intval($data['is_completed']) : 0);

        if ($reelId <= 0) {
            http_response_code(400);
            echo json_encode(["error" => "Missing required parameters (reel_id)"]);
            exit();
        }

        // Do not count creator's view into analytics data
        $isCreatorView = false;
        try {
            $cCheckStmt = $pdo->prepare("
                SELECT r.creator_id, r.phone_number AS reel_phone, c.phone_number AS creator_phone, c.username AS creator_username, c.display_name AS creator_name
                FROM reels r
                LEFT JOIN creators c ON r.creator_id = c.id
                WHERE r.id = ?
            ");
            $cCheckStmt->execute([$reelId]);
            $reelCreatorData = $cCheckStmt->fetch(PDO::FETCH_ASSOC);

            if ($reelCreatorData) {
                $rPhone = trim($reelCreatorData['reel_phone'] ?? '');
                $crPhone = trim($reelCreatorData['creator_phone'] ?? '');
                $crUsername = strtolower(trim($reelCreatorData['creator_username'] ?? ''));
                $crName = strtolower(trim($reelCreatorData['creator_name'] ?? ''));

                if (!empty($uPhone) && ($uPhone === $rPhone || $uPhone === $crPhone)) {
                    $isCreatorView = true;
                }
                if (!empty($uName) && $uName !== 'farmer' && 
                    (strtolower($uName) === $crUsername || strtolower($uName) === $crName)) {
                    $isCreatorView = true;
                }
            }
        } catch (Throwable $e) {}

        if ($isCreatorView) {
            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Creator view not counted in analytics data",
                "is_creator_view" => true
            ]);
            exit();
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO reel_watch_analytics (reel_id, farmer_username, phone_number, user_id, watch_duration_seconds, is_completed) VALUES (?, ?, ?, ?, ?, ?)");
            $stmt->execute([$reelId, $uName, $uPhone, $uId, $duration, $isCompleted]);

            $pdo->prepare("UPDATE reels SET views_count = views_count + 1 WHERE id = ?")->execute([$reelId]);

            http_response_code(201);
            echo json_encode(["success" => true, "message" => "Watch analytics logged successfully"]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }

    // 6. Action: Upload Reel
    elseif ($action === 'upload' || $action === 'upload_reel') {
        $videoUrl = trim($data['video_url'] ?? $data['videoUrl'] ?? $_POST['video_url'] ?? $_POST['videoUrl'] ?? '');
        $caption = trim($data['caption'] ?? $_POST['caption'] ?? '');
        $musicTitle = trim($data['music_title'] ?? $data['musicTitle'] ?? $_POST['music_title'] ?? $_POST['musicTitle'] ?? 'Original Audio');
        $phoneNumber = trim($data['phone_number'] ?? $data['phoneNumber'] ?? $_POST['phone_number'] ?? $_POST['phoneNumber'] ?? '');
        $creatorName = trim($data['creator_name'] ?? $data['displayName'] ?? $_POST['creator_name'] ?? $_POST['displayName'] ?? '');
        $creatorId = intval($data['creator_id'] ?? $_POST['creator_id'] ?? 0);
        $userId = trim($data['user_id'] ?? $_POST['user_id'] ?? '');
        $tags = trim($data['tags'] ?? $_POST['tags'] ?? '');

        // Handle direct multipart video file upload to /Reels/ folder
        $uploadDir = dirname(__DIR__) . '/Reels/';
        if (!is_dir($uploadDir)) {
            @mkdir($uploadDir, 0777, true);
        }

        // Handle file size limits gracefully
        if (isset($_FILES['video_file']) && in_array($_FILES['video_file']['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE])) {
            http_response_code(413);
            echo json_encode(["status" => false, "success" => false, "error" => "The video file is too large for the server upload limit. Please choose a smaller video clip."]);
            exit();
        }
        if (isset($_FILES['video']) && in_array($_FILES['video']['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE])) {
            http_response_code(413);
            echo json_encode(["status" => false, "success" => false, "error" => "The video file is too large for the server upload limit. Please choose a smaller video clip."]);
            exit();
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
            http_response_code(400);
            echo json_encode(["status" => false, "success" => false, "error" => "Missing video_url or caption"]);
            exit();
        }

        $crop = trim($data['crop'] ?? $_POST['crop'] ?? 'Paddy');
        $category = trim($data['category'] ?? $_POST['category'] ?? 'Crop Care');
        $language = trim($data['language'] ?? $_POST['language'] ?? 'te');
        $sourceUrl = trim($data['source_url'] ?? $data['sourceUrl'] ?? $_POST['source_url'] ?? $_POST['sourceUrl'] ?? '');
        $originalContentDate = trim($data['original_content_date'] ?? $data['originalContentDate'] ?? $_POST['original_content_date'] ?? date('Y-m-d'));
        $rightsDeclared = (!empty($data['rights_declared']) || !empty($data['rightsDeclared']) || !empty($_POST['rights_declared'])) ? 1 : 1;

        try {
            if ($creatorId <= 0) {
                $rawPhone = !empty($phoneNumber) ? $phoneNumber : $userId;
                $cleanPhone = preg_replace('/[^0-9]/', '', (string)$rawPhone);
                $last10 = strlen($cleanPhone) >= 10 ? substr($cleanPhone, -10) : $cleanPhone;
                $phone91 = $last10 ? '91' . $last10 : '';
                $phonePlus91 = $last10 ? '+91' . $last10 : '';
                $phoneCandidates = array_values(array_filter(array_unique([$last10, $phone91, $phonePlus91, $phoneNumber])));
                $userCandidates = array_values(array_filter(array_unique([$userId, $last10, $phoneNumber])));

                $creatorRow = null;
                if (!empty($phoneCandidates) || !empty($userCandidates)) {
                    $pIn = !empty($phoneCandidates) ? implode(',', array_fill(0, count($phoneCandidates), '?')) : 'NULL';
                    $uIn = !empty($userCandidates) ? implode(',', array_fill(0, count($userCandidates), '?')) : 'NULL';
                    $sql = "SELECT id FROM creators WHERE ";
                    $conds = [];
                    $params = [];
                    if (!empty($phoneCandidates)) {
                        $conds[] = "phone_number IN ($pIn)";
                        $params = array_merge($params, $phoneCandidates);
                    }
                    if (!empty($userCandidates)) {
                        $conds[] = "user_id IN ($uIn)";
                        $params = array_merge($params, $userCandidates);
                    }
                    $sql .= "(" . implode(" OR ", $conds) . ") LIMIT 1";
                    $cStmt = $pdo->prepare($sql);
                    $cStmt->execute($params);
                    $cId = $cStmt->fetchColumn();
                    if ($cId) {
                        $creatorId = intval($cId);
                    }
                }

                if ($creatorId <= 0) {
                    $resolvedName = (!empty($creatorName) && strtolower($creatorName) !== 'agri creator') ? $creatorName : '';
                    $sanitizedUsername = !empty($resolvedName) ? strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', str_replace(' ', '_', $resolvedName))) : (!empty($last10) ? 'creator_' . substr($last10, -6) : 'creator_' . rand(1000, 9999));
                    $dName = !empty($resolvedName) ? $resolvedName : 'Agri Creator';
                    $insPhone = !empty($last10) ? $last10 : $phoneNumber;
                    $insUserId = !empty($userId) ? $userId : (!empty($last10) ? 'user_' . $last10 : null);
                    $pdo->prepare("INSERT INTO creators (user_id, username, display_name, profile_image_url, is_verified, phone_number, bio) VALUES (?, ?, ?, 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80', 1, ?, 'Progressive Farmer')")->execute([$insUserId, $sanitizedUsername, $dName, $insPhone]);
                    $creatorId = intval($pdo->lastInsertId());
                }
            }

            if ($creatorId > 0) {
                $cChk = $pdo->prepare("SELECT status FROM creators WHERE id = ?");
                $cChk->execute([$creatorId]);
                $cStatusVal = $cChk->fetchColumn();
                if ($cStatusVal === 'suspended') {
                    http_response_code(403);
                    echo json_encode([
                        "status" => false, 
                        "success" => false, 
                        "error" => "This creator account is currently suspended. You cannot publish new reels."
                    ]);
                    exit();
                }
            }

            try {
                $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, crop, category, language, source_url, original_content_date, rights_declared, views_count, likes_count, saves_count, comments_count, is_active, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 'under_review', NOW())");
                $stmt->execute([$creatorId, $videoUrl, $caption, $musicTitle, $phoneNumber, $tags, $crop, $category, $language, $sourceUrl, $originalContentDate, $rightsDeclared]);
                $reelId = intval($pdo->lastInsertId());
            } catch (Throwable $detailErr) {
                $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active, status) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 'under_review')");
                $stmt->execute([$creatorId, $videoUrl, $caption, $musicTitle, $phoneNumber, $tags]);
                $reelId = intval($pdo->lastInsertId());
            }
            } catch (Throwable $dbErr) {
                // Auto repair reels schema and columns if missing
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
                        `is_active` TINYINT(1) DEFAULT 0,
                        `status` VARCHAR(50) DEFAULT 'under_review',
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
                        'is_active' => "ALTER TABLE `reels` ADD COLUMN `is_active` TINYINT(1) DEFAULT 0",
                        'status' => "ALTER TABLE `reels` ADD COLUMN `status` VARCHAR(50) DEFAULT 'under_review'",
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

                $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active, status) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 'under_review')");
                $stmt->execute([$creatorId, $videoUrl, $caption, $musicTitle, $phoneNumber, $tags]);
                $reelId = intval($pdo->lastInsertId());
            }

            http_response_code(201);
            echo json_encode(["success" => true, "message" => "Reel uploaded successfully", "reel_id" => $reelId]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }

    // 7. Action: Delete Reel
    elseif ($action === 'delete' || $action === 'delete_reel') {
        $reelId = intval($data['reel_id'] ?? $_GET['reel_id'] ?? 0);
        if ($reelId <= 0) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid reel ID"]);
            exit();
        }
        try {
            $pdo->prepare("DELETE FROM reel_likes WHERE reel_id = ?")->execute([$reelId]);
            $pdo->prepare("DELETE FROM reel_comments WHERE reel_id = ?")->execute([$reelId]);
            $pdo->prepare("DELETE FROM reel_actions WHERE reel_id = ?")->execute([$reelId]);
            $pdo->prepare("DELETE FROM reel_watch_analytics WHERE reel_id = ?")->execute([$reelId]);
            $pdo->prepare("DELETE FROM reels WHERE id = ?")->execute([$reelId]);

            http_response_code(200);
            echo json_encode(["success" => true, "message" => "Reel deleted successfully"]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }

    // 7b. Action: Delete Creator Account & Associated Reels
    elseif ($action === 'delete_creator' || $action === 'delete_creator_account') {
        $creatorId = intval($data['creator_id'] ?? $_POST['creator_id'] ?? $_GET['creator_id'] ?? 0);
        $userId = trim($data['user_id'] ?? $_POST['user_id'] ?? $_GET['user_id'] ?? '');
        $phoneNumber = trim($data['phone_number'] ?? $data['phone'] ?? $_POST['phone_number'] ?? $_GET['phone_number'] ?? '');

        try {
            $creator = null;
            if ($creatorId > 0) {
                $cStmt = $pdo->prepare("SELECT * FROM creators WHERE id = ? LIMIT 1");
                $cStmt->execute([$creatorId]);
                $creator = $cStmt->fetch(PDO::FETCH_ASSOC);
            }

            $rawPhone = !empty($phoneNumber) ? $phoneNumber : $userId;
            $cleanPhone = preg_replace('/[^0-9]/', '', (string)$rawPhone);
            $last10 = strlen($cleanPhone) >= 10 ? substr($cleanPhone, -10) : $cleanPhone;
            $phone91 = $last10 ? '91' . $last10 : '';
            $phonePlus91 = $last10 ? '+91' . $last10 : '';
            $phones = array_values(array_filter(array_unique([$last10, $phone91, $phonePlus91, $phoneNumber, $userId])));

            if (!$creator && !empty($phones)) {
                $pIn = implode(',', array_fill(0, count($phones), '?'));
                $stmt = $pdo->prepare("SELECT * FROM creators WHERE phone_number IN ($pIn) OR user_id IN ($pIn) LIMIT 1");
                $stmt->execute(array_merge($phones, $phones));
                $creator = $stmt->fetch(PDO::FETCH_ASSOC);
            }

            if (!$creator) {
                http_response_code(404);
                echo json_encode(["success" => false, "error" => "Creator account not found"]);
                exit();
            }

            $cId = intval($creator['id']);
            $cPhone = trim($creator['phone_number'] ?? '');
            if (!empty($cPhone)) {
                $cleanCP = preg_replace('/[^0-9]/', '', $cPhone);
                $last10CP = strlen($cleanCP) >= 10 ? substr($cleanCP, -10) : $cleanCP;
                $phones = array_values(array_filter(array_unique(array_merge($phones, [$cPhone, $last10CP, '91' . $last10CP, '+91' . $last10CP]))));
            }

            // Identify all reels belonging to this creator
            $reelIds = [];
            $rStmt = $pdo->prepare("SELECT id FROM reels WHERE creator_id = ?");
            $rStmt->execute([$cId]);
            $directIds = $rStmt->fetchAll(PDO::FETCH_COLUMN);
            if (!empty($directIds)) $reelIds = array_merge($reelIds, array_map('intval', $directIds));

            if (!empty($phones)) {
                $pIn = implode(',', array_fill(0, count($phones), '?'));
                $legStmt = $pdo->prepare("SELECT id FROM reels WHERE (creator_id = 0 OR creator_id IS NULL) AND phone_number IN ($pIn)");
                $legStmt->execute($phones);
                $legIds = $legStmt->fetchAll(PDO::FETCH_COLUMN);
                if (!empty($legIds)) $reelIds = array_merge($reelIds, array_map('intval', $legIds));
            }
            $reelIds = array_values(array_unique($reelIds));

            if (!empty($reelIds)) {
                $rIn = implode(',', array_fill(0, count($reelIds), '?'));
                try { $pdo->prepare("DELETE FROM reel_likes WHERE reel_id IN ($rIn)")->execute($reelIds); } catch (Throwable $e) {}
                try { $pdo->prepare("DELETE FROM reel_comments WHERE reel_id IN ($rIn)")->execute($reelIds); } catch (Throwable $e) {}
                try { $pdo->prepare("DELETE FROM reel_actions WHERE reel_id IN ($rIn)")->execute($reelIds); } catch (Throwable $e) {}
                try { $pdo->prepare("DELETE FROM reel_watch_analytics WHERE reel_id IN ($rIn)")->execute($reelIds); } catch (Throwable $e) {}
                $pdo->prepare("DELETE FROM reels WHERE id IN ($rIn)")->execute($reelIds);
            }

            try { $pdo->prepare("DELETE FROM creator_terms WHERE creator_id = ?")->execute([$cId]); } catch (Throwable $e) {}
            try { $pdo->prepare("DELETE FROM creator_payouts WHERE creator_id = ?")->execute([$cId]); } catch (Throwable $e) {}
            $pdo->prepare("DELETE FROM creators WHERE id = ?")->execute([$cId]);

            $delUser = !empty($data['delete_user_account']) || !empty($_POST['delete_user_account']) || !empty($_GET['delete_user_account']);
            if ($delUser && !empty($phones)) {
                $pIn = implode(',', array_fill(0, count($phones), '?'));
                try { $pdo->prepare("DELETE FROM users WHERE phone_number IN ($pIn) OR user_id IN ($pIn)")->execute(array_merge($phones, $phones)); } catch (Throwable $e) {}
            }

            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Creator account and all uploaded reels (" . count($reelIds) . ") deleted successfully",
                "deleted_reels_count" => count($reelIds),
                "creator_id" => $cId
            ]);
            exit();
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
            exit();
        }
    }

    // 8. Action: Toggle Reel Status
    elseif ($action === 'toggle_status' || $action === 'toggle_reel_status') {
        $reelId = intval($postData['reel_id'] ?? $_POST['reel_id'] ?? $_GET['reel_id'] ?? 0);
        $isActive = isset($postData['is_active']) ? intval($postData['is_active']) : (isset($_POST['is_active']) ? intval($_POST['is_active']) : (isset($_GET['is_active']) ? intval($_GET['is_active']) : 1));
        if ($reelId <= 0) {
            http_response_code(400);
            echo json_encode(["status" => false, "success" => false, "error" => "Invalid reel ID"]);
            exit();
        }
        try {
            if ($isActive == 1) {
                // Enforce approval and non-suspended creator check
                $chk = $pdo->prepare("
                    SELECT r.status, c.status AS creator_status 
                    FROM reels r 
                    LEFT JOIN creators c ON r.creator_id = c.id 
                    WHERE r.id = ?
                ");
                $chk->execute([$reelId]);
                $row = $chk->fetch(PDO::FETCH_ASSOC);
                if (!$row) {
                    http_response_code(404);
                    echo json_encode(["status" => false, "success" => false, "error" => "Reel not found."]);
                    exit();
                }
                if (($row['creator_status'] ?? '') === 'suspended') {
                    http_response_code(403);
                    echo json_encode(["status" => false, "success" => false, "error" => "Cannot activate reel: Creator is suspended."]);
                    exit();
                }
                if ($row['status'] !== 'approved') {
                    http_response_code(400);
                    echo json_encode(["status" => false, "success" => false, "error" => "Reel cannot be activated until approved by a moderator."]);
                    exit();
                }

                // Enforce at the SQL level as well
                $stmt = $pdo->prepare("UPDATE reels SET is_active = 1 WHERE id = ? AND status = 'approved'");
                $stmt->execute([$reelId]);
                if ($stmt->rowCount() === 0) {
                    $chk2 = $pdo->prepare("SELECT status, is_active FROM reels WHERE id = ?");
                    $chk2->execute([$reelId]);
                    $row2 = $chk2->fetch(PDO::FETCH_ASSOC);
                    if (!$row2 || $row2['status'] !== 'approved') {
                        http_response_code(400);
                        echo json_encode(["status" => false, "success" => false, "error" => "Reel cannot be activated until approved by a moderator."]);
                        exit();
                    }
                }
            } else {
                $pdo->prepare("UPDATE reels SET is_active = 0 WHERE id = ?")->execute([$reelId]);
            }
            http_response_code(200);
            echo json_encode(["status" => true, "success" => true, "message" => "Status updated", "is_active" => $isActive]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["status" => false, "success" => false, "error" => $e->getMessage()]);
        }
        exit();
    }

    // 9. Action: Delete News Article
    elseif ($action === 'delete_news_article' || $action === 'delete_article') {
        $articleId = intval($postData['article_id'] ?? $_POST['article_id'] ?? $_GET['article_id'] ?? 0);
        if ($articleId <= 0) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid article ID"]);
            exit();
        }
        try {
            try { $pdo->prepare("DELETE FROM news_comments WHERE article_id = ?")->execute([$articleId]); } catch (Throwable $e) {}
            try { $pdo->prepare("DELETE FROM news_likes WHERE article_id = ?")->execute([$articleId]); } catch (Throwable $e) {}
            $pdo->prepare("DELETE FROM news_articles WHERE id = ?")->execute([$articleId]);

            http_response_code(200);
            echo json_encode(["success" => true, "message" => "Article deleted successfully"]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }

    // 10. Action: Update User Profile
    elseif ($action === 'update_user_profile' || $action === 'update_profile') {
        $userId = trim($postData['user_id'] ?? $_POST['user_id'] ?? $_GET['user_id'] ?? '');
        $name = trim($postData['name'] ?? $_POST['name'] ?? '');
        $phoneNumber = trim($postData['phone_number'] ?? $_POST['phone_number'] ?? '');
        $district = trim($postData['district'] ?? $_POST['district'] ?? '');
        $region = trim($postData['region'] ?? $_POST['region'] ?? '');
        $profileImageUrl = trim($postData['profile_image_url'] ?? $_POST['profile_image_url'] ?? '');

        // Upload profile image file if present
        $uploadDir = dirname(__DIR__) . '/uploads/profiles/';
        if (!is_dir($uploadDir)) {
            @mkdir($uploadDir, 0777, true);
        }

        if (isset($_FILES['profile_image']) && $_FILES['profile_image']['error'] === UPLOAD_ERR_OK) {
            $ext = strtolower(pathinfo($_FILES['profile_image']['name'], PATHINFO_EXTENSION));
            if (empty($ext)) $ext = 'jpg';
            $safeName = 'profile_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES['profile_image']['tmp_name'], $uploadDir . $safeName)) {
                $profileImageUrl = 'https://kiosk.cropsync.in/uploads/profiles/' . $safeName;
            }
        } elseif (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
            $ext = strtolower(pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION));
            if (empty($ext)) $ext = 'jpg';
            $safeName = 'profile_' . time() . '_' . rand(1000, 9999) . '.' . $ext;
            if (move_uploaded_file($_FILES['image']['tmp_name'], $uploadDir . $safeName)) {
                $profileImageUrl = 'https://kiosk.cropsync.in/uploads/profiles/' . $safeName;
            }
        }

        if (empty($userId)) {
            http_response_code(400);
            echo json_encode(["error" => "User ID required"]);
            exit();
        }

        try {
            $cleanPhone = preg_replace('/[^0-9]/', '', (string)$userId);
            $last10 = strlen($cleanPhone) > 10 ? substr($cleanPhone, -10) : $cleanPhone;

            $updates = [];
            $params = [];
            if (!empty($name)) { $updates[] = "name = ?"; $params[] = $name; }
            if (!empty($phoneNumber)) { $updates[] = "phone_number = ?"; $params[] = $phoneNumber; }
            if (!empty($district)) { $updates[] = "district = ?"; $params[] = $district; }
            if (!empty($region)) { $updates[] = "region = ?"; $params[] = $region; }
            if (!empty($profileImageUrl)) { $updates[] = "profile_image_url = ?"; $params[] = $profileImageUrl; }

            if (!empty($updates)) {
                $params[] = $userId;
                $params[] = $userId;
                $pdo->prepare("UPDATE users SET " . implode(", ", $updates) . " WHERE user_id = ? OR phone_number = ?")->execute($params);
            }

            // Also sync to creators table
            $cUpdates = [];
            $cParams = [];
            if (!empty($name)) { $cUpdates[] = "display_name = ?"; $cParams[] = $name; }
            if (!empty($profileImageUrl)) { $cUpdates[] = "profile_image_url = ?"; $cParams[] = $profileImageUrl; }
            if (!empty($phoneNumber)) { $cUpdates[] = "phone_number = ?"; $cParams[] = $phoneNumber; }
            if (!empty($cUpdates)) {
                $cSql = "UPDATE creators SET " . implode(", ", $cUpdates) . " WHERE user_id = ? OR phone_number = ? OR phone_number = ? OR username = ? OR display_name = ?";
                $cParams[] = $userId;
                $cParams[] = $userId;
                $cParams[] = $last10;
                $cParams[] = $userId;
                $cParams[] = !empty($name) ? $name : $userId;
                try { $pdo->prepare($cSql)->execute($cParams); } catch (Throwable $e) {}
            }

            $stmt = $pdo->prepare("SELECT * FROM users WHERE user_id = ? OR phone_number = ? LIMIT 1");
            $stmt->execute([$userId, $userId]);
            $updatedUser = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$updatedUser || empty($updatedUser['profile_image_url'])) {
                $cCheck = $pdo->prepare("SELECT * FROM creators WHERE user_id = ? OR phone_number = ? OR phone_number = ? LIMIT 1");
                $cCheck->execute([$userId, $userId, $last10]);
                $cData = $cCheck->fetch(PDO::FETCH_ASSOC);
                if ($cData) {
                    if (!$updatedUser) {
                        $updatedUser = [
                            'user_id' => $cData['phone_number'] ?: $userId,
                            'name' => $cData['display_name'] ?: $cData['username'],
                            'phone_number' => $cData['phone_number'] ?: $userId,
                            'profile_image_url' => $cData['profile_image_url'] ?: $profileImageUrl,
                            'role' => 'content_creator',
                            'membership_type' => 'Creator'
                        ];
                    } else if (!empty($cData['profile_image_url'])) {
                        $updatedUser['profile_image_url'] = $cData['profile_image_url'];
                    }
                }
            }

            http_response_code(200);
            echo json_encode(["success" => true, "user" => $updatedUser, "profile_image_url" => $profileImageUrl]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }
    
    else {
        http_response_code(400);
        echo json_encode(["error" => "Invalid POST action"]);
    }
}
?>


