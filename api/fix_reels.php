<?php
/**
 * One-time fix script v2: Fixes ALL missing columns including 'id' primary keys
 * Visit: https://kiosk.cropsync.in/api/fix_reels.php
 * After running, delete this file from the server for security.
 */
header('Content-Type: text/html; charset=utf-8');
require_once __DIR__ . '/../config.php';

echo "<h2>CropSync Reels Database Fix v2</h2>";
echo "<pre>";

if (!isset($pdo) || !($pdo instanceof PDO)) {
    echo "ERROR: Database connection not available.\n";
    exit;
}

$pdo->exec("SET NAMES utf8mb4");

// Helper: show all columns of a table
function showTableColumns($pdo, $table) {
    try {
        $stmt = $pdo->query("DESCRIBE `$table`");
        $cols = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo "  Columns: ";
        $names = array_column($cols, 'Field');
        echo implode(', ', $names) . "\n";
        return $names;
    } catch (Throwable $e) {
        echo "  ⚠️ Cannot describe '$table': " . $e->getMessage() . "\n";
        return [];
    }
}

// Helper: add column if missing
function addColumnIfMissing($pdo, $table, $column, $definition) {
    try {
        $stmt = $pdo->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
        if (!$stmt || !$stmt->fetch()) {
            $pdo->exec("ALTER TABLE `$table` ADD COLUMN `$column` $definition");
            echo "  ✅ Added '$column' to '$table'\n";
        } else {
            echo "  ✔️  '$column' exists\n";
        }
    } catch (Throwable $e) {
        echo "  ⚠️  Error with '$table'.'$column': " . $e->getMessage() . "\n";
    }
}

echo "\n=== Step 1: Inspect current table structures ===\n\n";

$tables = ['reels', 'creators', 'reel_likes', 'reel_comments', 'reel_actions', 'reel_watch_analytics'];
foreach ($tables as $t) {
    echo "--- $t ---\n";
    showTableColumns($pdo, $t);
    echo "\n";
}

echo "\n=== Step 2: Fix reel_likes ===\n";
// Drop and recreate reel_likes if it's missing critical columns
try {
    $cols = $pdo->query("DESCRIBE `reel_likes`")->fetchAll(PDO::FETCH_COLUMN, 0);
    if (!in_array('id', $cols)) {
        echo "  🔧 'id' column missing! Adding AUTO_INCREMENT primary key...\n";
        try {
            $pdo->exec("ALTER TABLE `reel_likes` ADD COLUMN `id` INT AUTO_INCREMENT PRIMARY KEY FIRST");
            echo "  ✅ Added 'id' to reel_likes\n";
        } catch (Throwable $e) {
            echo "  ⚠️ Could not add id: " . $e->getMessage() . "\n";
            // Try dropping and recreating
            echo "  🔧 Recreating reel_likes table...\n";
            try {
                $pdo->exec("RENAME TABLE `reel_likes` TO `reel_likes_backup_" . time() . "`");
                $pdo->exec("CREATE TABLE `reel_likes` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `reel_id` INT NOT NULL,
                    `farmer_username` VARCHAR(100) DEFAULT '',
                    `phone_number` VARCHAR(20) DEFAULT NULL,
                    `user_id` VARCHAR(50) DEFAULT NULL,
                    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
                echo "  ✅ Recreated reel_likes with all columns\n";
            } catch (Throwable $e2) {
                echo "  ❌ Failed to recreate: " . $e2->getMessage() . "\n";
            }
        }
    } else {
        echo "  ✔️ 'id' exists\n";
    }
    addColumnIfMissing($pdo, 'reel_likes', 'phone_number', "VARCHAR(20) DEFAULT NULL");
    addColumnIfMissing($pdo, 'reel_likes', 'user_id', "VARCHAR(50) DEFAULT NULL");
    addColumnIfMissing($pdo, 'reel_likes', 'farmer_username', "VARCHAR(100) DEFAULT ''");
} catch (Throwable $e) {
    echo "  ⚠️ " . $e->getMessage() . "\n";
}

echo "\n=== Step 3: Fix reel_comments ===\n";
try {
    $cols = $pdo->query("DESCRIBE `reel_comments`")->fetchAll(PDO::FETCH_COLUMN, 0);
    if (!in_array('id', $cols)) {
        echo "  🔧 'id' column missing! Adding...\n";
        try {
            $pdo->exec("ALTER TABLE `reel_comments` ADD COLUMN `id` INT AUTO_INCREMENT PRIMARY KEY FIRST");
            echo "  ✅ Added 'id' to reel_comments\n";
        } catch (Throwable $e) {
            echo "  🔧 Recreating reel_comments table...\n";
            try {
                $pdo->exec("RENAME TABLE `reel_comments` TO `reel_comments_backup_" . time() . "`");
                $pdo->exec("CREATE TABLE `reel_comments` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `reel_id` INT NOT NULL,
                    `farmer_username` VARCHAR(100) DEFAULT '',
                    `phone_number` VARCHAR(20) DEFAULT NULL,
                    `user_id` VARCHAR(50) DEFAULT NULL,
                    `comment_text` TEXT NOT NULL,
                    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
                echo "  ✅ Recreated reel_comments with all columns\n";
            } catch (Throwable $e2) {
                echo "  ❌ Failed: " . $e2->getMessage() . "\n";
            }
        }
    } else {
        echo "  ✔️ 'id' exists\n";
    }
    addColumnIfMissing($pdo, 'reel_comments', 'phone_number', "VARCHAR(20) DEFAULT NULL");
    addColumnIfMissing($pdo, 'reel_comments', 'user_id', "VARCHAR(50) DEFAULT NULL");
} catch (Throwable $e) {
    echo "  ⚠️ " . $e->getMessage() . "\n";
}

echo "\n=== Step 4: Fix reel_actions ===\n";
try {
    $cols = $pdo->query("DESCRIBE `reel_actions`")->fetchAll(PDO::FETCH_COLUMN, 0);
    if (!in_array('id', $cols)) {
        echo "  🔧 'id' column missing! Adding...\n";
        try {
            $pdo->exec("ALTER TABLE `reel_actions` ADD COLUMN `id` INT AUTO_INCREMENT PRIMARY KEY FIRST");
            echo "  ✅ Added 'id' to reel_actions\n";
        } catch (Throwable $e) {
            echo "  🔧 Recreating reel_actions table...\n";
            try {
                $pdo->exec("RENAME TABLE `reel_actions` TO `reel_actions_backup_" . time() . "`");
                $pdo->exec("CREATE TABLE `reel_actions` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `reel_id` INT NOT NULL,
                    `farmer_username` VARCHAR(100) DEFAULT '',
                    `phone_number` VARCHAR(20) DEFAULT NULL,
                    `user_id` VARCHAR(50) DEFAULT NULL,
                    `action_type` VARCHAR(50) NOT NULL,
                    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
                echo "  ✅ Recreated reel_actions with all columns\n";
            } catch (Throwable $e2) {
                echo "  ❌ Failed: " . $e2->getMessage() . "\n";
            }
        }
    } else {
        echo "  ✔️ 'id' exists\n";
    }
    addColumnIfMissing($pdo, 'reel_actions', 'phone_number', "VARCHAR(20) DEFAULT NULL");
    addColumnIfMissing($pdo, 'reel_actions', 'user_id', "VARCHAR(50) DEFAULT NULL");
} catch (Throwable $e) {
    echo "  ⚠️ " . $e->getMessage() . "\n";
}

echo "\n=== Step 5: Fix reel_watch_analytics ===\n";
try {
    $cols = $pdo->query("DESCRIBE `reel_watch_analytics`")->fetchAll(PDO::FETCH_COLUMN, 0);
    if (!in_array('id', $cols)) {
        echo "  🔧 'id' column missing! Adding...\n";
        try {
            $pdo->exec("ALTER TABLE `reel_watch_analytics` ADD COLUMN `id` INT AUTO_INCREMENT PRIMARY KEY FIRST");
            echo "  ✅ Added 'id' to reel_watch_analytics\n";
        } catch (Throwable $e) {
            echo "  🔧 Recreating reel_watch_analytics table...\n";
            try {
                $pdo->exec("RENAME TABLE `reel_watch_analytics` TO `reel_watch_backup_" . time() . "`");
                $pdo->exec("CREATE TABLE `reel_watch_analytics` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `reel_id` INT NOT NULL,
                    `farmer_username` VARCHAR(100) DEFAULT '',
                    `phone_number` VARCHAR(20) DEFAULT NULL,
                    `user_id` VARCHAR(50) DEFAULT NULL,
                    `watch_duration_seconds` INT DEFAULT 0,
                    `is_completed` TINYINT(1) DEFAULT 0,
                    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
                echo "  ✅ Recreated reel_watch_analytics\n";
            } catch (Throwable $e2) {
                echo "  ❌ Failed: " . $e2->getMessage() . "\n";
            }
        }
    } else {
        echo "  ✔️ 'id' exists\n";
    }
    addColumnIfMissing($pdo, 'reel_watch_analytics', 'phone_number', "VARCHAR(20) DEFAULT NULL");
    addColumnIfMissing($pdo, 'reel_watch_analytics', 'user_id', "VARCHAR(50) DEFAULT NULL");
} catch (Throwable $e) {
    echo "  ⚠️ " . $e->getMessage() . "\n";
}

echo "\n=== Step 6: Final structures after fix ===\n\n";
foreach ($tables as $t) {
    echo "--- $t ---\n";
    showTableColumns($pdo, $t);
    echo "\n";
}

echo "\n=== Step 7: Test the full get_reels query chain ===\n";
try {
    // Test main query
    $stmt = $pdo->query("SELECT r.*, 
        c.username AS creator_username, 
        c.display_name AS creator_display_name, 
        c.profile_image_url AS creator_profile_image_url,
        c.is_verified AS creator_is_verified,
        c.phone_number AS creator_phone_number,
        c.bio AS creator_bio
        FROM reels r
        LEFT JOIN creators c ON r.creator_id = c.id
        WHERE r.is_active = 1
        ORDER BY r.id DESC
        LIMIT 5");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "✅ Main query works! Found " . count($rows) . " reels.\n";

    // Test comment query (same as in getReels)
    if (!empty($rows)) {
        $firstId = $rows[0]['id'];
        $cStmt = $pdo->prepare("SELECT id, reel_id, farmer_username, comment_text, phone_number, created_at FROM reel_comments WHERE reel_id = ? ORDER BY id ASC LIMIT 50");
        $cStmt->execute([$firstId]);
        echo "✅ reel_comments query works!\n";

        // Test likes check
        $lStmt = $pdo->prepare("SELECT id FROM reel_likes WHERE reel_id = ? AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
        $lStmt->execute([$firstId, '9182867655', 'farmer']);
        echo "✅ reel_likes query works!\n";

        // Test saves check
        $sStmt = $pdo->prepare("SELECT id FROM reel_actions WHERE reel_id = ? AND action_type = 'save' AND (phone_number = ? OR (farmer_username = ? AND farmer_username != ''))");
        $sStmt->execute([$firstId, '9182867655', 'farmer']);
        echo "✅ reel_actions query works!\n";
    }
} catch (Throwable $e) {
    echo "❌ Query failed: " . $e->getMessage() . "\n";
}

echo "\n=== DONE ===\n";
echo "All fixes applied. Upload the updated api.php and reels.php, then delete this file.\n";
echo "</pre>";
?>
