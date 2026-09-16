<?php
/**
 * CropSync Kiosk - Reel Auto-Approval Cron Job
 * 
 * Moderation SLA Rules:
 *  - Daytime (06:00 to 21:00 IST): Automatically approves pending reels after 10 minutes of moderator inspection.
 *  - Night (After 21:00 IST to 06:00 IST): No auto-approvals. Submissions strictly require manual verification.
 * 
 * Usage:
 *  - CLI: php api/cron_reel_auto_approve.php
 *  - Web Cron / HTTP: GET https://kiosk.cropsync.in/api/cron_reel_auto_approve.php
 */

header('Content-Type: application/json');

if (file_exists(__DIR__ . '/config.php')) {
    require_once __DIR__ . '/config.php';
} elseif (file_exists(__DIR__ . '/../config.php')) {
    require_once __DIR__ . '/../config.php';
}

require_once __DIR__ . '/api.php';

if (!isset($pdo) || !$pdo instanceof PDO) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Database connection failed']);
    exit();
}

$tz = new DateTimeZone('Asia/Kolkata');
$now = new DateTime('now', $tz);
$currentHour = intval($now->format('G'));
$isNight = ($currentHour >= 21 || $currentHour < 6);

$approvedCount = processReelAutoApprovals($pdo);

echo json_encode([
    'success' => true,
    'timestamp' => $now->format('Y-m-d H:i:s T'),
    'current_hour' => $currentHour,
    'window' => $isNight ? 'Night Window (Auto-approval paused; manual verification required)' : 'Daytime Window (10-minute SLA active)',
    'auto_approved_count' => $approvedCount
]);
