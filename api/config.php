<?php
// --- Database Credentials ---
$servername = "127.0.0.1";
$username = "u893187665_arjun";
$password = "CropSync@2024";
$dbname   = "u893187665_kiosk";

// --- Global Application Constant Definitions ---
define('GEMINI_API_KEY', 'AIzaSyBp38fONs2aJ0LCuEtDJJ1POrTG7UkafLI');
define('CDN_URL', 'https://kiosk.cropsync.in/');

// --- Razorpay Live Configuration (Keep Live Key Secret strictly on the server) ---
if (!defined('RAZORPAY_KEY_ID')) {
    define('RAZORPAY_KEY_ID', 'rzp_live_your_key_id_here');
}
if (!defined('RAZORPAY_KEY_SECRET')) {
    define('RAZORPAY_KEY_SECRET', 'your_live_key_secret_here');
}

/*
=====================================================
 MySQLi Connection (App / Kiosk / APIs)
=====================================================
*/
$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die("MySQLi connection failed: " . $conn->connect_error);
}

// Force Indian Standard Time for this session
$conn->query("SET time_zone = '+05:30'");

/*
=====================================================
 PDO Connection (Admin / Backend)
=====================================================
*/
try {
    $dsn = "mysql:host=$servername;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]);

    // Force Indian Standard Time for PDO session
    $pdo->exec("SET time_zone = '+05:30'");

} catch (PDOException $e) {
    die("PDO connection failed: " . $e->getMessage());
}
?>
