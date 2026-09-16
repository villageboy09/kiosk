<?php
/**
 * CropSync Universal Smart Share & Deep Link Endpoint
 * 
 * Handles rich social preview meta tags (WhatsApp, Telegram, etc.)
 * and redirects mobile users to the native app, or to Google Play Store if not installed.
 */

header('Content-Type: text/html; charset=utf-8');

$type = trim($_GET['type'] ?? 'app');
$id = trim($_GET['id'] ?? '');
$crop = trim($_GET['crop'] ?? '');
$commodity = trim($_GET['commodity'] ?? '');
$title = trim($_GET['title'] ?? '');
$desc = trim($_GET['desc'] ?? '');
$img = trim($_GET['img'] ?? '');
$price = trim($_GET['price'] ?? '');
$lang = trim($_GET['lang'] ?? 'te');

// Defaults if title or desc is empty
if (empty($title)) {
    switch ($type) {
        case 'shop':
            $title = 'CropSync Market - Agri Products';
            break;
        case 'advisory':
            $title = (!empty($crop) ? htmlspecialchars($crop) . ' - ' : '') . 'Crop Advisory & Diagnosis';
            break;
        case 'market':
            $title = (!empty($commodity) ? htmlspecialchars($commodity) . ' - ' : '') . 'Mandi Market Live Prices';
            break;
        case 'seed':
            $title = 'Certified Seed Varieties - CropSync';
            break;
        case 'news':
            $title = 'Agri News & Farming Updates - CropSync';
            break;
        case 'reel':
            $title = 'Agri Shorts & Farming Video - CropSync';
            break;
        default:
            $title = 'CropSync - Modern Agriculture Platform';
            break;
    }
}

if (empty($desc)) {
    $desc = 'Join thousands of farmers using CropSync for expert crop advisory, mandi prices, authentic agricultural shop, and farming reels.';
}

if (empty($img)) {
    $img = 'https://kiosk.cropsync.in/assets/images/logo_favicon.png';
}

$playStoreUrl = 'https://play.google.com/store/apps/details?id=com.cropsync.cropsync';
$queryString = http_build_query($_GET);
$appSchemeUrl = 'cropsync://share?' . $queryString;
$appIntentUrl = 'intent://share?' . $queryString . '#Intent;scheme=cropsync;package=com.cropsync.cropsync;S.browser_fallback_url=' . urlencode($playStoreUrl) . ';end';
$currentUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
?>
<!DOCTYPE html>
<html lang="<?= htmlspecialchars($lang) ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title><?= htmlspecialchars($title) ?></title>

    <!-- Open Graph / WhatsApp / Facebook -->
    <meta property="og:type" content="website">
    <meta property="og:url" content="<?= htmlspecialchars($currentUrl) ?>">
    <meta property="og:title" content="<?= htmlspecialchars($title) ?>">
    <meta property="og:description" content="<?= htmlspecialchars($desc) ?>">
    <meta property="og:image" content="<?= htmlspecialchars($img) ?>">
    <meta property="og:site_name" content="CropSync">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="<?= htmlspecialchars($title) ?>">
    <meta name="twitter:description" content="<?= htmlspecialchars($desc) ?>">
    <meta name="twitter:image" content="<?= htmlspecialchars($img) ?>">

    <link rel="icon" type="image/png" href="https://kiosk.cropsync.in/assets/images/logo_favicon.png">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;700;800;900&display=swap" rel="stylesheet">

    <style>
        :root {
            --primary: #16A34A;
            --primary-dark: #15803D;
            --primary-light: #DCFCE7;
            --text-dark: #0F172A;
            --text-muted: #64748B;
            --card-bg: #FFFFFF;
            --body-bg: #F8FAFC;
        }
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
        }
        body {
            background-color: var(--body-bg);
            color: var(--text-dark);
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 16px;
        }
        .container {
            max-width: 440px;
            width: 100%;
            background: var(--card-bg);
            border-radius: 24px;
            box-shadow: 0 20px 40px -15px rgba(0,0,0,0.07), 0 0 1px 1px rgba(0,0,0,0.04);
            overflow: hidden;
            border: 1px solid #E2E8F0;
            text-align: center;
        }
        .header {
            padding: 16px 20px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid #F1F5F9;
        }
        .logo-wrap {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .logo-img {
            width: 32px;
            height: 32px;
            border-radius: 8px;
        }
        .brand-name {
            font-size: 18px;
            font-weight: 900;
            color: var(--text-dark);
            letter-spacing: -0.5px;
        }
        .badge {
            background: var(--primary-light);
            color: var(--primary-dark);
            font-size: 11px;
            font-weight: 800;
            padding: 4px 10px;
            border-radius: 100px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .media-box {
            width: 100%;
            height: 220px;
            background: #F1F5F9;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            overflow: hidden;
        }
        .media-box img {
            width: 100%;
            height: 100%;
            object-fit: contain;
            padding: 12px;
        }
        .content {
            padding: 24px 20px;
            text-align: left;
        }
        .item-title {
            font-size: 20px;
            font-weight: 800;
            color: var(--text-dark);
            line-height: 1.3;
            margin-bottom: 8px;
        }
        .price-tag {
            display: inline-block;
            font-size: 18px;
            font-weight: 900;
            color: var(--primary);
            margin-bottom: 10px;
        }
        .item-desc {
            font-size: 14px;
            color: var(--text-muted);
            line-height: 1.5;
            margin-bottom: 24px;
        }
        .actions {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }
        .btn {
            display: block;
            width: 100%;
            padding: 14px 20px;
            border-radius: 100px;
            font-size: 15px;
            font-weight: 800;
            text-align: center;
            text-decoration: none;
            transition: all 0.2s ease;
            cursor: pointer;
            border: none;
        }
        .btn-primary {
            background: var(--primary);
            color: #FFFFFF;
            box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
        }
        .btn-primary:hover {
            background: var(--primary-dark);
        }
        .btn-secondary {
            background: #F1F5F9;
            color: var(--text-dark);
        }
        .btn-secondary:hover {
            background: #E2E8F0;
        }
        .footer-text {
            margin-top: 16px;
            font-size: 12px;
            color: #94A3B8;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo-wrap">
                <img src="https://kiosk.cropsync.in/assets/images/logo_favicon.png" alt="CropSync" class="logo-img">
                <span class="brand-name">CropSync</span>
            </div>
            <span class="badge"><?= htmlspecialchars(ucfirst($type)) ?></span>
        </div>

        <div class="media-box">
            <img src="<?= htmlspecialchars($img) ?>" alt="<?= htmlspecialchars($title) ?>" onerror="this.src='https://kiosk.cropsync.in/assets/images/logo_favicon.png';">
        </div>

        <div class="content">
            <h1 class="item-title"><?= htmlspecialchars($title) ?></h1>
            <?php if (!empty($price)): ?>
                <div class="price-tag"><?= htmlspecialchars($price) ?></div>
            <?php endif; ?>
            <p class="item-desc"><?= htmlspecialchars($desc) ?></p>

            <div class="actions">
                <a href="<?= htmlspecialchars($appSchemeUrl) ?>" id="openAppBtn" class="btn btn-primary">
                    Open in CropSync App
                </a>
                <a href="<?= htmlspecialchars($playStoreUrl) ?>" id="playStoreBtn" class="btn btn-secondary">
                    Get on Google Play Store
                </a>
            </div>
            <p class="footer-text">CropSync • Progressive Agriculture Platform</p>
        </div>
    </div>

    <script>
        (function() {
            var appScheme = <?= json_encode($appSchemeUrl) ?>;
            var appIntent = <?= json_encode($appIntentUrl) ?>;
            var playStore = <?= json_encode($playStoreUrl) ?>;
            var isAndroid = /Android/i.test(navigator.userAgent);
            var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);

            // Attempt redirect on mobile devices
            if (isAndroid || isIOS) {
                var start = Date.now();
                // Try opening custom scheme or Android Intent
                if (isAndroid) {
                    window.location.href = appScheme;
                } else if (isIOS) {
                    window.location.href = appScheme;
                }

                // If page is still active after 1500ms, user likely doesn't have the app installed
                setTimeout(function() {
                    if (Date.now() - start < 2200) {
                        window.location.href = playStore;
                    }
                }, 1500);
            }
        })();
    </script>
</body>
</html>
