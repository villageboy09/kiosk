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

$action = isset($_GET['action']) ? $_GET['action'] : '';
$farmer_username = isset($_GET['username']) ? $_GET['username'] : '';

// --- API Router ---

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // 1. Fetch All Reels with Creator details, Comments, and total interaction counts
    try {
        $stmt = $pdo->prepare("
            SELECT r.*, c.username AS creator_username, c.display_name, c.profile_image_url 
            FROM reels r
            JOIN creators c ON r.creator_id = c.id
            ORDER BY r.id DESC
        ");
        $stmt->execute();
        $reels = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $response = [];
        foreach ($reels as $reel) {
            $reelId = $reel['id'];

            // Fetch comments
            $commentStmt = $pdo->prepare("SELECT farmer_username, comment_text, created_at FROM reel_comments WHERE reel_id = :reel_id ORDER BY id ASC");
            $commentStmt->bindParam(':reel_id', $reelId, PDO::PARAM_INT);
            $commentStmt->execute();
            $comments = $commentStmt->fetchAll(PDO::FETCH_ASSOC);

            // Count total likes
            $likesStmt = $pdo->prepare("SELECT COUNT(*) as count FROM reel_likes WHERE reel_id = :reel_id");
            $likesStmt->bindParam(':reel_id', $reelId, PDO::PARAM_INT);
            $likesStmt->execute();
            $likesCount = intval($likesStmt->fetch(PDO::FETCH_ASSOC)['count']);

            // Check if the current user has liked it
            $hasLiked = false;
            if (!empty($farmer_username)) {
                $checkLiked = $pdo->prepare("SELECT COUNT(*) as count FROM reel_likes WHERE reel_id = :reel_id AND farmer_username = :farmer_username");
                $checkLiked->bindParam(':reel_id', $reelId, PDO::PARAM_INT);
                $checkLiked->bindParam(':farmer_username', $farmer_username, PDO::PARAM_STR);
                $checkLiked->execute();
                $hasLiked = intval($checkLiked->fetch(PDO::FETCH_ASSOC)['count']) > 0;
            }

            // Count total saves
            $savesStmt = $pdo->prepare("SELECT COUNT(*) as count FROM reel_actions WHERE reel_id = :reel_id AND action_type = 'save'");
            $savesStmt->bindParam(':reel_id', $reelId, PDO::PARAM_INT);
            $savesStmt->execute();
            $savesCount = intval($savesStmt->fetch(PDO::FETCH_ASSOC)['count']);

            // Format counts
            $likesDisplay = $likesCount >= 1000 ? number_format($likesCount / 1000, 1) . 'K' : strval($likesCount);
            $savesDisplay = $savesCount >= 1000 ? number_format($savesCount / 1000, 1) . 'K' : strval($savesCount);

            $response[] = [
                "id" => $reelId,
                "videoUrl" => rewriteToCDN($reel['video_url']),
                "creator" => [
                    "username" => $reel['creator_username'],
                    "displayName" => $reel['display_name'],
                    "profileImageUrl" => rewriteToCDN($reel['profile_image_url'])
                ],
                "caption" => $reel['caption'],
                "likes" => $likesDisplay,
                "likesRaw" => $likesCount,
                "hasLiked" => $hasLiked,
                "saves" => $savesDisplay,
                "savesRaw" => $savesCount,
                "commentsCount" => count($comments),
                "comments" => $comments,
                "createdAt" => $reel['created_at']
            ];
        }

        http_response_code(200);
        echo json_encode($response);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["error" => $e->getMessage()]);
    }
} 

elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Read JSON payload
    $data = json_decode(file_get_contents("php://input"), true);
    
    // 2. Action: Like/Unlike Reel
    if ($action === 'like') {
        if (!isset($data['reel_id']) || !isset($data['farmer_username'])) {
            http_response_code(400);
            echo json_encode(["error" => "Missing reel_id or farmer_username"]);
            exit();
        }

        try {
            // Check if already liked (toggle behavior)
            $check = $pdo->prepare("SELECT COUNT(*) as count FROM reel_likes WHERE reel_id = :reel_id AND farmer_username = :farmer_username");
            $check->bindParam(':reel_id', $data['reel_id'], PDO::PARAM_INT);
            $check->bindParam(':farmer_username', $data['farmer_username'], PDO::PARAM_STR);
            $check->execute();
            $liked = intval($check->fetch(PDO::FETCH_ASSOC)['count']) > 0;

            if ($liked) {
                // Unlike
                $stmt = $pdo->prepare("DELETE FROM reel_likes WHERE reel_id = :reel_id AND farmer_username = :farmer_username");
                $message = "Unliked successfully";
            } else {
                // Like
                $stmt = $pdo->prepare("INSERT INTO reel_likes (reel_id, farmer_username) VALUES (:reel_id, :farmer_username)");
                $message = "Liked successfully";
            }
            
            $stmt->bindParam(':reel_id', $data['reel_id'], PDO::PARAM_INT);
            $stmt->bindParam(':farmer_username', $data['farmer_username'], PDO::PARAM_STR);
            $stmt->execute();

            // Count new likes
            $likesStmt = $pdo->prepare("SELECT COUNT(*) as count FROM reel_likes WHERE reel_id = :reel_id");
            $likesStmt->bindParam(':reel_id', $data['reel_id'], PDO::PARAM_INT);
            $likesStmt->execute();
            $likesCount = intval($likesStmt->fetch(PDO::FETCH_ASSOC)['count']);

            http_response_code(200);
            echo json_encode([
                "message" => $message, 
                "likes" => $likesCount >= 1000 ? number_format($likesCount / 1000, 1) . 'K' : strval($likesCount),
                "likesRaw" => $likesCount
            ]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    } 
    
    // 3. Action: Add Comment
    elseif ($action === 'comment') {
        if (!isset($data['reel_id']) || !isset($data['farmer_username']) || !isset($data['comment_text'])) {
            http_response_code(400);
            echo json_encode(["error" => "Missing required parameters (reel_id, farmer_username, comment_text)"]);
            exit();
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO reel_comments (reel_id, farmer_username, comment_text) VALUES (:reel_id, :farmer_username, :comment_text)");
            $stmt->bindParam(':reel_id', $data['reel_id'], PDO::PARAM_INT);
            $stmt->bindParam(':farmer_username', $data['farmer_username'], PDO::PARAM_STR);
            $stmt->bindParam(':comment_text', $data['comment_text'], PDO::PARAM_STR);
            $stmt->execute();

            http_response_code(201);
            echo json_encode(["message" => "Comment added successfully"]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    } 

    // 4. Action: Log Action (Save, Call, Share)
    elseif ($action === 'action') {
        if (!isset($data['reel_id']) || !isset($data['farmer_username']) || !isset($data['action_type'])) {
            http_response_code(400);
            echo json_encode(["error" => "Missing required parameters (reel_id, farmer_username, action_type)"]);
            exit();
        }

        if (!in_array($data['action_type'], ['save', 'call', 'share'])) {
            http_response_code(400);
            echo json_encode(["error" => "Invalid action_type. Must be save, call, or share."]);
            exit();
        }

        try {
            $stmt = $pdo->prepare("INSERT INTO reel_actions (reel_id, farmer_username, action_type) VALUES (:reel_id, :farmer_username, :action_type)");
            $stmt->bindParam(':reel_id', $data['reel_id'], PDO::PARAM_INT);
            $stmt->bindParam(':farmer_username', $data['farmer_username'], PDO::PARAM_STR);
            $stmt->bindParam(':action_type', $data['action_type'], PDO::PARAM_STR);
            $stmt->execute();

            http_response_code(201);
            echo json_encode(["message" => "Action logged successfully"]);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(["error" => $e->getMessage()]);
        }
    }

    // 5. Action: Log Watch Analytics
    elseif ($action === 'watch') {
        if (!isset($data['reel_id']) || !isset($data['farmer_username']) || !isset($data['duration'])) {
            http_response_code(400);
            echo json_encode(["error" => "Missing required parameters (reel_id, farmer_username, duration)"]);
            exit();
        }

        $isCompleted = isset($data['completed']) ? intval($data['completed']) : 0;

        try {
            $stmt = $pdo->prepare("INSERT INTO reel_watch_analytics (reel_id, farmer_username, watch_duration_seconds, is_completed) VALUES (:reel_id, :farmer_username, :duration, :completed)");
            $stmt->bindParam(':reel_id', $data['reel_id'], PDO::PARAM_INT);
            $stmt->bindParam(':farmer_username', $data['farmer_username'], PDO::PARAM_STR);
            $stmt->bindParam(':duration', $data['duration'], PDO::PARAM_INT);
            $stmt->bindParam(':completed', $isCompleted, PDO::PARAM_INT);
            $stmt->execute();

            http_response_code(201);
            echo json_encode(["message" => "Watch analytics logged successfully"]);
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
