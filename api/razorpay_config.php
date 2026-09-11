<?php
/**
 * CropSync Razorpay Server-Side Configuration
 *
 * IMPORTANT:
 * - Keep this file on your backend server.
 * - Do not commit your Live Key Secret to public repositories.
 */

// 1. Paste your Razorpay Live Key ID (starts with rzp_live_...)
if (!defined('RAZORPAY_KEY_ID')) {
    define('RAZORPAY_KEY_ID', 'rzp_live_your_key_id_here');
}

// 2. Paste your Razorpay Live Key Secret
if (!defined('RAZORPAY_KEY_SECRET')) {
    define('RAZORPAY_KEY_SECRET', 'your_live_key_secret_here');
}
?>
