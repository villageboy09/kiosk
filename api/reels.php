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
    }
} catch (Throwable $e) {}

// CDN Configuration (Enable for faster asset delivery)
define('CDN_ENABLED', true);
define('CDN_BASE_URL', 'https://cdn.cropsync.in/'); // CDN endpoint
define('ORIGINAL_BASE_URL', 'https://kiosk.cropsync.in/'); // Base domain of your main files

// Helper to rewrite media urls using the CDN
function rewriteToCDN($url) {
    if (CDN_ENABLED && !empty($url)) {
        if (strpos($url, ORIGINAL_BASE_URL) === 0) {
            return str_replace(ORIGINAL_BASE_URL, CDN_BASE_URL, $url);
        }
        if (strpos($url, 'http://') !== 0 && strpos($url, 'https://') !== 0) {
            return CDN_BASE_URL . ltrim($url, '/');
        }
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

$action = isset($_GET['action']) ? $_GET['action'] : '';
$phoneNumber = isset($_GET['phone_number']) ? trim($_GET['phone_number']) : '';
$farmerUsername = isset($_GET['username']) ? trim($_GET['username']) : (isset($_GET['farmer_username']) ? trim($_GET['farmer_username']) : '');

// --- API Router ---

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if ($action === 'get_comments' || $action === 'comments') {
        $reelId = intval($_GET['reel_id'] ?? 0);
        if ($reelId <= 0) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid reel ID"]);
            exit();
        }
        try {
            $stmt = $pdo->prepare("SELECT id, reel_id, farmer_username, phone_number, comment_text, created_at FROM reel_comments WHERE reel_id = ? ORDER BY created_at ASC LIMIT 100");
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
            $phoneNumber = trim($_GET['phone_number'] ?? $_GET['phone'] ?? '');
            $username = trim($_GET['username'] ?? '');
            $userName = trim($_GET['user_name'] ?? $_GET['name'] ?? '');

            // Find or create creator
            $creator = null;
            if (!empty($phoneNumber)) {
                $cStmt = $pdo->prepare("SELECT * FROM creators WHERE phone_number = ? LIMIT 1");
                $cStmt->execute([$phoneNumber]);
                $creator = $cStmt->fetch(PDO::FETCH_ASSOC);
            }
            if (!$creator && !empty($userName)) {
                $cStmt = $pdo->prepare("SELECT * FROM creators WHERE display_name = ? OR username = ? LIMIT 1");
                $cStmt->execute([$userName, $username]);
                $creator = $cStmt->fetch(PDO::FETCH_ASSOC);
            }
            if (!$creator) {
                $sanitizedUsername = !empty($username) ? $username : (!empty($phoneNumber) ? 'creator_' . substr($phoneNumber, -6) : 'creator_' . rand(1000, 9999));
                $dName = !empty($userName) ? $userName : 'Agri Creator';
                $pImg = 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80';
                $pdo->prepare("INSERT INTO creators (username, display_name, profile_image_url, is_verified, phone_number, bio) VALUES (?, ?, ?, 1, ?, 'Progressive Farmer & Agricultural Contributor')")->execute([$sanitizedUsername, $dName, $pImg, $phoneNumber]);
                $cId = $pdo->lastInsertId();
                $creator = ['id' => intval($cId), 'username' => $sanitizedUsername, 'display_name' => $dName, 'profile_image_url' => $pImg, 'is_verified' => 1, 'phone_number' => $phoneNumber, 'bio' => 'Progressive Farmer'];
            }
            $creatorId = intval($creator['id']);

            $rStmt = $pdo->prepare("SELECT r.*, c.username AS creator_username, c.display_name AS creator_display_name, c.profile_image_url AS creator_profile_image_url, c.is_verified AS creator_is_verified, c.phone_number AS creator_phone_number FROM reels r JOIN creators c ON r.creator_id = c.id WHERE r.creator_id = ? ORDER BY r.id DESC");
            $rStmt->execute([$creatorId]);
            $rawReels = $rStmt->fetchAll(PDO::FETCH_ASSOC);

            $reels = [];
            $totalViews = 0; $totalLikes = 0; $totalSaves = 0; $totalComments = 0;
            foreach ($rawReels as $r) {
                $rId = intval($r['id']);
                $v = intval($r['views_count']); $l = intval($r['likes_count']); $s = intval($r['saves_count']); $c = intval($r['comments_count']);
                $totalViews += $v; $totalLikes += $l; $totalSaves += $s; $totalComments += $c;
                $reels[] = [
                    'id' => $rId,
                    'videoUrl' => rewriteToCDN($r['video_url']),
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
                    'createdAt' => $r['created_at'],
                    'creator' => [
                        'id' => $creatorId,
                        'username' => $r['creator_username'],
                        'displayName' => $r['creator_display_name'],
                        'profileImageUrl' => $r['creator_profile_image_url'] ?? '',
                        'isVerified' => (bool)$r['creator_is_verified'],
                        'phoneNumber' => $r['creator_phone_number'] ?? ''
                    ]
                ];
            }

            $stats = [
                'totalViews' => $totalViews,
                'totalLikes' => $totalLikes,
                'totalComments' => $totalComments,
                'totalSaves' => $totalSaves,
                'totalCalls' => 0,
                'totalShares' => 0,
                'engagementRate' => $totalViews > 0 ? round((($totalLikes + $totalComments + $totalSaves) / $totalViews) * 100, 1) : 0.0,
                'avgWatchDurationSeconds' => 18.5,
                'totalReels' => count($reels),
                'totalArticles' => 0
            ];

            http_response_code(200);
            echo json_encode(['success' => true, 'creator' => $creator, 'stats' => $stats, 'reels' => $reels, 'articles' => []]);
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
            c.bio AS creator_bio
            FROM reels r
            JOIN creators c ON r.creator_id = c.id
            WHERE r.is_active = 1
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

            $response[] = [
                "id" => $reelId,
                "videoUrl" => rewriteToCDN($reel['video_url']),
                "creator" => [
                    "id" => intval($reel['creator_id']),
                    "username" => $reel['creator_username'],
                    "displayName" => $reel['creator_display_name'],
                    "profileImageUrl" => rewriteToCDN($reel['creator_profile_image_url']),
                    "isVerified" => boolval($reel['creator_is_verified']),
                    "phoneNumber" => $reel['creator_phone_number'] ?: $reel['phone_number'],
                    "bio" => $reel['creator_bio']
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
        $videoUrl = trim($data['video_url'] ?? $data['videoUrl'] ?? '');
        $caption = trim($data['caption'] ?? '');
        $musicTitle = trim($data['music_title'] ?? $data['musicTitle'] ?? 'Original Audio');
        $phoneNumber = trim($data['phone_number'] ?? $data['phoneNumber'] ?? '');
        $creatorName = trim($data['creator_name'] ?? $data['displayName'] ?? '');
        $creatorId = intval($data['creator_id'] ?? 0);
        $tags = trim($data['tags'] ?? '');

        if (empty($videoUrl) || empty($caption)) {
            http_response_code(400);
            echo json_encode(["error" => "Missing video_url or caption"]);
            exit();
        }

        try {
            if ($creatorId <= 0) {
                // Find or create creator
                $cStmt = $pdo->prepare("SELECT id FROM creators WHERE phone_number = ? LIMIT 1");
                $cStmt->execute([$phoneNumber]);
                $cId = $cStmt->fetchColumn();
                if ($cId) {
                    $creatorId = intval($cId);
                } else {
                    $sanitizedUsername = !empty($creatorName) ? strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', str_replace(' ', '_', $creatorName))) : 'creator_' . substr($phoneNumber, -6);
                    $dName = !empty($creatorName) ? $creatorName : 'Agri Creator';
                    $pdo->prepare("INSERT INTO creators (username, display_name, profile_image_url, is_verified, phone_number, bio) VALUES (?, ?, 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80', 1, ?, 'Progressive Farmer')")->execute([$sanitizedUsername, $dName, $phoneNumber]);
                    $creatorId = intval($pdo->lastInsertId());
                }
            }

            $stmt = $pdo->prepare("INSERT INTO reels (creator_id, video_url, caption, music_title, phone_number, tags, views_count, likes_count, saves_count, comments_count, is_active) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 1)");
            $stmt->execute([$creatorId, $videoUrl, $caption, $musicTitle, $phoneNumber, $tags]);
            $reelId = intval($pdo->lastInsertId());

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

    // 8. Action: Toggle Reel Status
    elseif ($action === 'toggle_status' || $action === 'toggle_reel_status') {
        $reelId = intval($data['reel_id'] ?? 0);
        $isActive = isset($data['is_active']) ? intval($data['is_active']) : 1;
        if ($reelId <= 0) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid reel ID"]);
            exit();
        }
        try {
            $pdo->prepare("UPDATE reels SET is_active = ? WHERE id = ?")->execute([$isActive, $reelId]);
            http_response_code(200);
            echo json_encode(["success" => true, "message" => "Status updated", "is_active" => $isActive]);
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
