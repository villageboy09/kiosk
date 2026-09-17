<?php
/**
 * CropSync Universal Smart Share & Deep Link Endpoint
 * 
 * Handles rich OpenGraph social preview cards (WhatsApp, Telegram, etc.)
 * with auto-database lookup, and provides zero-flick instant app launching
 * or fallback to Google Play Store if not installed.
 */

header('Content-Type: text/html; charset=utf-8');

// 1. Extract parameters (supports both short and long keys)
$type = strtolower(trim($_GET['t'] ?? $_GET['type'] ?? 'app'));
$id = trim($_GET['id'] ?? $_GET['i'] ?? '');
$crop = trim($_GET['c'] ?? $_GET['crop'] ?? '');
$commodity = trim($_GET['c'] ?? $_GET['commodity'] ?? $_GET['comm'] ?? '');
$title = trim($_GET['title'] ?? '');
$desc = trim($_GET['desc'] ?? '');
$img = trim($_GET['img'] ?? '');
$price = trim($_GET['price'] ?? '');
$lang = strtolower(trim($_GET['lang'] ?? $_GET['l'] ?? 'te'));

// 2. Database Lookup for Rich Preview metadata when not provided in URL
$pdo = null;
if (file_exists(__DIR__ . '/config.php')) {
    @require_once __DIR__ . '/config.php';
} elseif (file_exists(__DIR__ . '/../config.php')) {
    @require_once __DIR__ . '/../config.php';
}

if (isset($pdo) && $pdo instanceof PDO) {
    try {
        if ($type === 'shop' && !empty($id)) {
            $stmt = $pdo->prepare("SELECT product_name, product_description, price, image_url_1 FROM products WHERE product_id = :id OR id = :id LIMIT 1");
            $stmt->execute(['id' => $id]);
            if ($row = $stmt->fetch()) {
                if (empty($title)) $title = $row['product_name'] ?? '';
                if (empty($desc) && !empty($row['product_description'])) {
                    $desc = mb_substr(strip_tags($row['product_description']), 0, 150);
                }
                if (empty($img) && !empty($row['image_url_1'])) $img = $row['image_url_1'];
                if (empty($price) && !empty($row['price'])) $price = '₹' . $row['price'];
            }
        } elseif ($type === 'advisory' && !empty($id)) {
            $stmt = $pdo->prepare("SELECT name, category, image_url1 FROM crop_problems WHERE id = :id LIMIT 1");
            $stmt->execute(['id' => $id]);
            if ($row = $stmt->fetch()) {
                if (empty($title)) {
                    $title = $row['name'] . (!empty($crop) ? " ($crop)" : "");
                }
                if (empty($desc)) {
                    $desc = (!empty($row['category']) ? $row['category'] . ' • ' : '') . 'View complete symptoms, organic & chemical remedies on CropSync.';
                }
                if (empty($img) && !empty($row['image_url1'])) $img = $row['image_url1'];
            }
        } elseif (($type === 'seed' || $type === 'seeds') && !empty($id)) {
            $stmt = $pdo->prepare("SELECT variety_name, crop_name, details, price, price_unit, image_url FROM seed_varieties WHERE id = :id LIMIT 1");
            $stmt->execute(['id' => $id]);
            if ($row = $stmt->fetch()) {
                if (empty($title)) {
                    $title = $row['variety_name'] . (!empty($row['crop_name']) ? " ({$row['crop_name']})" : "");
                }
                if (empty($desc) && !empty($row['details'])) {
                    $desc = mb_substr(strip_tags($row['details']), 0, 150);
                }
                if (empty($img) && !empty($row['image_url'])) $img = $row['image_url'];
                if (empty($price) && !empty($row['price'])) {
                    $price = '₹' . $row['price'] . (!empty($row['price_unit']) ? ' / ' . $row['price_unit'] : '');
                }
            }
        } elseif ($type === 'news' && !empty($id)) {
            $stmt = $pdo->prepare("SELECT title, summary, content, image_url FROM news_articles WHERE id = :id LIMIT 1");
            $stmt->execute(['id' => $id]);
            if ($row = $stmt->fetch()) {
                if (empty($title)) $title = $row['title'] ?? '';
                if (empty($desc)) {
                    $desc = !empty($row['summary']) ? $row['summary'] : mb_substr(strip_tags($row['content'] ?? ''), 0, 150);
                }
                if (empty($img) && !empty($row['image_url'])) $img = $row['image_url'];
            }
        } elseif (($type === 'reel' || $type === 'reels') && !empty($id)) {
            $stmt = $pdo->prepare("SELECT caption, thumbnail_url, crop FROM reels WHERE id = :id LIMIT 1");
            $stmt->execute(['id' => $id]);
            if ($row = $stmt->fetch()) {
                if (empty($title)) {
                    $title = !empty($row['caption']) ? $row['caption'] : 'Agri Reel on CropSync';
                }
                if (empty($desc)) {
                    $desc = (!empty($row['crop']) ? $row['crop'] . ' • ' : '') . 'Watch helpful agricultural video shorts on CropSync.';
                }
                if (empty($img) && !empty($row['thumbnail_url'])) $img = $row['thumbnail_url'];
            }
        } elseif ($type === 'market' && (!empty($commodity) || !empty($id))) {
            $target = !empty($commodity) ? $commodity : $id;
            $stmt = $pdo->prepare("SELECT commodity, market, district, modal_price, image_url FROM market_prices WHERE commodity LIKE :comm ORDER BY arrival_date DESC LIMIT 1");
            $stmt->execute(['comm' => $target . '%']);
            if ($row = $stmt->fetch()) {
                if (empty($title)) $title = $row['commodity'] . " Mandi Prices";
                if (empty($desc)) {
                    $desc = "Latest price at {$row['market']} ({$row['district']}): ₹{$row['modal_price']} / quintal.";
                }
                if (empty($img) && !empty($row['image_url'])) $img = $row['image_url'];
                if (empty($price) && !empty($row['modal_price'])) $price = '₹' . $row['modal_price'] . ' / qtl';
            }
        }
    } catch (Throwable $e) {
        // Fallback silently if DB error occurs
    }
}

// 3. Fallbacks if still empty
if (empty($title)) {
    switch ($type) {
        case 'shop': $title = 'CropSync Market - Agri Products'; break;
        case 'advisory': $title = (!empty($crop) ? htmlspecialchars($crop) . ' - ' : '') . 'Crop Advisory & Diagnosis'; break;
        case 'market': $title = (!empty($commodity) ? htmlspecialchars($commodity) . ' - ' : '') . 'Mandi Market Live Prices'; break;
        case 'seed': case 'seeds': $title = 'Certified Seed Varieties - CropSync'; break;
        case 'news': $title = 'Agri News & Farming Updates - CropSync'; break;
        case 'reel': case 'reels': $title = 'Agri Shorts & Farming Video - CropSync'; break;
        default: $title = 'CropSync - Progressive Agriculture Platform'; break;
    }
}

if (empty($desc)) {
    $desc = 'Join progressive farmers on CropSync for expert crop diagnosis, mandi rates, authentic agri store & farming reels.';
}

if (empty($img)) {
    $img = 'https://kiosk.cropsync.in/assets/images/logo_favicon.png';
} elseif (!preg_match('/^https?:\/\//i', $img)) {
    $img = 'https://kiosk.cropsync.in/' . ltrim($img, '/');
}

// 4. Construct Minimal App Deep Link & Intent URLs
$playStoreUrl = 'https://play.google.com/store/apps/details?id=com.cropsync.cropsync';

$cleanParams = ['type' => $type];
if (!empty($id)) $cleanParams['id'] = $id;
if (!empty($crop)) $cleanParams['crop'] = $crop;
if (!empty($commodity) && empty($crop)) $cleanParams['commodity'] = $commodity;
if (!empty($lang)) $cleanParams['lang'] = $lang;

$appQuery = http_build_query($cleanParams);
$appSchemeUrl = 'cropsync://share?' . $appQuery;
$appIntentUrl = 'intent://share?' . $appQuery . '#Intent;scheme=cropsync;package=com.cropsync.cropsync;S.browser_fallback_url=' . urlencode($playStoreUrl) . ';end';

$currentUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
?>
<!DOCTYPE html>
<html lang="<?= htmlspecialchars($lang) ?>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title><?= htmlspecialchars($title) ?></title>

    <!-- Open Graph (WhatsApp, Telegram, Facebook) Preview Cards -->
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

    <!-- Zero-Flick Instant Redirection: Runs immediately in head before body render -->
    <script>
        (function() {
            var ua = navigator.userAgent || '';
            var isAndroid = /Android/i.test(ua);
            var isIOS = /iPhone|iPad|iPod/i.test(ua);
            var appIntent = <?= json_encode($appIntentUrl) ?>;
            var appScheme = <?= json_encode($appSchemeUrl) ?>;

            if (isAndroid) {
                // Official Android Chrome intent launch (no browser history push, seamless handover)
                window.location.replace(appIntent);
            } else if (isIOS) {
                window.location.replace(appScheme);
            }
        })();
    </script>

    <style>
        :root {
            --primary: #16A34A;
            --primary-dark: #15803D;
            --bg-neutral: #F9FAFB;
        }
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        }
        body {
            background-color: var(--bg-neutral);
            color: #111827;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 16px;
        }

        /* Seamless Branded Loading Screen (Matches Native App Splash) */
        #splashScreen {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            text-align: center;
        }
        .splash-logo {
            width: 84px;
            height: 84px;
            border-radius: 22px;
            box-shadow: 0 10px 30px -5px rgba(22, 163, 74, 0.25);
            animation: pulseLogo 1.6s ease-in-out infinite;
        }
        @keyframes pulseLogo {
            0%, 100% { transform: scale(1); opacity: 1; }
            50% { transform: scale(1.05); opacity: 0.9; }
        }
        .splash-title {
            margin-top: 18px;
            font-size: 18px;
            font-weight: 800;
            color: var(--primary-dark);
            letter-spacing: -0.3px;
        }
        .splash-desc {
            margin-top: 6px;
            font-size: 13.5px;
            color: #6B7280;
            font-weight: 500;
        }
        .splash-spinner {
            margin-top: 20px;
            width: 24px;
            height: 24px;
            border: 2.5px solid #E5E7EB;
            border-top-color: var(--primary);
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        /* Preview Card for Desktop or when App is not installed */
        #fallbackCard {
            display: none;
            max-width: 420px;
            width: 100%;
            background: #FFFFFF;
            border-radius: 24px;
            box-shadow: 0 20px 40px -15px rgba(0,0,0,0.07);
            border: 1px solid #E5E7EB;
            overflow: hidden;
            animation: fadeIn 0.3s ease;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(8px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .card-header {
            padding: 16px 20px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid #F3F4F6;
        }
        .card-logo {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .card-logo img {
            width: 32px;
            height: 32px;
            border-radius: 8px;
        }
        .card-logo span {
            font-weight: 800;
            font-size: 16px;
            color: #111827;
        }
        .badge {
            background: #DCFCE7;
            color: var(--primary-dark);
            padding: 4px 10px;
            border-radius: 100px;
            font-size: 11.5px;
            font-weight: 700;
            text-transform: capitalize;
        }
        .card-media {
            width: 100%;
            height: 210px;
            background: #F3F4F6;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }
        .card-media img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        .card-body {
            padding: 20px;
        }
        .card-title {
            font-size: 19px;
            font-weight: 800;
            color: #111827;
            line-height: 1.3;
        }
        .card-price {
            display: inline-block;
            margin-top: 6px;
            font-size: 17px;
            font-weight: 800;
            color: var(--primary);
        }
        .card-desc {
            margin-top: 10px;
            font-size: 13.5px;
            color: #4B5563;
            line-height: 1.5;
        }
        .card-actions {
            margin-top: 20px;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .btn {
            display: block;
            text-align: center;
            padding: 13px 18px;
            border-radius: 14px;
            font-size: 14.5px;
            font-weight: 700;
            text-decoration: none;
            transition: all 0.2s;
        }
        .btn-primary {
            background: var(--primary);
            color: #FFFFFF;
        }
        .btn-primary:hover {
            background: var(--primary-dark);
        }
        .btn-secondary {
            background: #F3F4F6;
            color: #1F2937;
            border: 1px solid #E5E7EB;
        }
    </style>
</head>
<body>
    <!-- 1. Smooth Splash State: Shown during app intent handover -->
    <div id="splashScreen">
        <img src="https://kiosk.cropsync.in/assets/images/logo_favicon.png" alt="CropSync" class="splash-logo">
        <h2 class="splash-title">Opening in CropSync...</h2>
        <p class="splash-desc">Loading <?= htmlspecialchars($title) ?></p>
        <div class="splash-spinner"></div>
    </div>

    <!-- 2. Fallback Card: Displayed gracefully if device remains in browser -->
    <div id="fallbackCard">
        <div class="card-header">
            <div class="card-logo">
                <img src="https://kiosk.cropsync.in/assets/images/logo_favicon.png" alt="CropSync">
                <span>CropSync</span>
            </div>
            <span class="badge"><?= htmlspecialchars($type) ?></span>
        </div>

        <div class="card-media">
            <img src="<?= htmlspecialchars($img) ?>" alt="<?= htmlspecialchars($title) ?>" onerror="this.src='https://kiosk.cropsync.in/assets/images/logo_favicon.png';">
        </div>

        <div class="card-body">
            <h1 class="card-title"><?= htmlspecialchars($title) ?></h1>
            <?php if (!empty($price)): ?>
                <div class="card-price"><?= htmlspecialchars($price) ?></div>
            <?php endif; ?>
            <p class="card-desc"><?= htmlspecialchars($desc) ?></p>

            <div class="card-actions">
                <a href="<?= htmlspecialchars($appSchemeUrl) ?>" class="btn btn-primary">
                    Open in CropSync App
                </a>
                <a href="<?= htmlspecialchars($playStoreUrl) ?>" class="btn btn-secondary">
                    Get on Google Play Store
                </a>
            </div>
        </div>
    </div>

    <script>
        // If the user remains in the browser after 1.6 seconds, smoothly show the fallback card
        setTimeout(function() {
            var splash = document.getElementById('splashScreen');
            var card = document.getElementById('fallbackCard');
            if (splash && card) {
                splash.style.display = 'none';
                card.style.display = 'block';
            }
        }, 1600);
    </script>
</body>
</html>
