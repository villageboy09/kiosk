<?php
session_start();
include '../config.php';

// --- Auth Check ---
if (!isset($_SESSION['advertiser_id'])) {
    header("Location: advertiser_login.php");
    exit();
}

$adv_id = $_SESSION['advertiser_id'];
$adv_name = $_SESSION['advertiser_name'];

// Initials for Avatar
$words = explode(" ", $adv_name);
$initials = "";
foreach ($words as $w) { $initials .= $w[0]; }
$initials = strtoupper(substr($initials, 0, 2));

// --- 0. HELPER FUNCTIONS ---
function redirectWithToast($msg, $isSuccess = true) {
    $_SESSION['toast'] = ['message' => $msg, 'type' => $isSuccess];
    header("Location: advertiser_dashboard.php");
    exit();
}

function time_elapsed_string($datetime, $full = false) {
    $now = new DateTime;
    $ago = new DateTime($datetime);
    $diff = $now->diff($ago);
    $weeks = floor($diff->d / 7);
    $days = $diff->d - ($weeks * 7);
    $string = array(
        'y' => 'year', 'm' => 'month', 'w' => 'week', 'd' => 'day',
        'h' => 'hour', 'i' => 'minute', 's' => 'second',
    );
    $values = [
        'y' => $diff->y, 'm' => $diff->m, 'w' => $weeks, 
        'd' => $days, 'h' => $diff->h, 'i' => $diff->i, 's' => $diff->s
    ];
    foreach ($string as $k => &$v) {
        if ($values[$k]) {
            $v = $values[$k] . ' ' . $v . ($values[$k] > 1 ? 's' : '');
        } else {
            unset($string[$k]);
        }
    }
    if (!$full) $string = array_slice($string, 0, 1);
    return $string ? implode(', ', $string) . ' ago' : 'just now';
}

function handleFileUpload($fileInputName, $existingUrl = null) {
    $targetDir = "../products/"; 
    $baseUrl = "https://kiosk.cropsync.in/products/"; 
    if (isset($_FILES[$fileInputName]) && $_FILES[$fileInputName]['error'] === 0) {
        if (!empty($existingUrl)) {
            $oldFilename = basename($existingUrl);
            $oldFilePath = $targetDir . $oldFilename;
            if (file_exists($oldFilePath) && is_file($oldFilePath)) unlink($oldFilePath); 
        }
        $fileExt = strtolower(pathinfo($_FILES[$fileInputName]['name'], PATHINFO_EXTENSION));
        $allowed = ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi'];
        if (in_array($fileExt, $allowed)) {
            $newFilename = time() . '_' . rand(1000, 9999) . '.' . $fileExt;
            $targetPath = $targetDir . $newFilename;
            if (move_uploaded_file($_FILES[$fileInputName]['tmp_name'], $targetPath)) {
                return $baseUrl . $newFilename;
            }
        }
    }
    return $existingUrl;
}

// --- 1. HANDLE POST ACTIONS ---
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    if (isset($_POST['ajax_action']) && $_POST['ajax_action'] == 'update_status') {
        $enq_id = $_POST['enquiry_id'];
        $new_status = $_POST['status'];
        $stmt = $conn->prepare("UPDATE enquiries SET status = ? WHERE enquiry_id = ? AND advertiser_id = ?");
        $stmt->bind_param("sii", $new_status, $enq_id, $adv_id);
        echo ($stmt->execute()) ? "success" : "error";
        exit; 
    }
    if (isset($_POST['action']) && ($_POST['action'] == 'add_product' || $_POST['action'] == 'edit_product')) {
        $p_name = $_POST['product_name'];
        $p_cat = $_POST['category'];
        $p_price = $_POST['price'];
        $p_mrp = !empty($_POST['mrp']) ? $_POST['mrp'] : NULL;
        $p_desc = $_POST['description'];
        $p_region = !empty($_POST['region_id']) ? $_POST['region_id'] : NULL;
        $p_stock = isset($_POST['in_stock']) ? 1 : 0;
        $p_active = isset($_POST['is_active']) ? 1 : 0;
        $old_img = $_POST['existing_image_1'] ?? null;
        $old_video = $_POST['existing_video'] ?? null;
        $p_img = handleFileUpload('image_file', $old_img);
        $p_video = handleFileUpload('video_file', $old_video);
        if ($_POST['action'] == 'add_product') {
            $p_code = 'TG' . rand(1000,9999) . 'P' . rand(10,99);
            $stmt = $conn->prepare("INSERT INTO products (product_code, category, advertiser_id, product_name, price, mrp, product_description, image_url_1, product_video_url, region_id, in_stock, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("ssisddsssiii", $p_code, $p_cat, $adv_id, $p_name, $p_price, $p_mrp, $p_desc, $p_img, $p_video, $p_region, $p_stock, $p_active);
            if ($stmt->execute()) redirectWithToast("Product listed successfully!");
            else redirectWithToast("Error: " . $conn->error, false);
        } else {
            $p_id = $_POST['product_id'];
            $check = $conn->prepare("SELECT product_id FROM products WHERE product_id = ? AND advertiser_id = ?");
            $check->bind_param("ii", $p_id, $adv_id);
            $check->execute();
            if ($check->get_result()->num_rows > 0) {
                $stmt = $conn->prepare("UPDATE products SET product_name=?, category=?, price=?, mrp=?, product_description=?, image_url_1=?, product_video_url=?, region_id=?, in_stock=?, is_active=? WHERE product_id=?");
                $stmt->bind_param("ssddsssiiii", $p_name, $p_cat, $p_price, $p_mrp, $p_desc, $p_img, $p_video, $p_region, $p_stock, $p_active, $p_id);
                if ($stmt->execute()) redirectWithToast("Product updated successfully!");
                else redirectWithToast("Update failed.", false);
            } else redirectWithToast("Unauthorized access.", false);
        }
    }
}

// --- 2. FILTERS SETUP ---
$filter_days = isset($_GET['days']) ? intval($_GET['days']) : 30;
$filter_region = isset($_GET['region']) ? $_GET['region'] : '';
$filter_product = isset($_GET['product']) ? $_GET['product'] : '';
$page = isset($_GET['page']) ? intval($_GET['page']) : 1;
$limit = 10; 
$offset = ($page - 1) * $limit;

$where_clauses = ["e.advertiser_id = ?"];
$params = [$adv_id];
$types = "i";
$date_condition = "AND stats_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)";
if ($filter_days == 3650) $date_condition = "AND 1=1";
if ($filter_days != 3650) {
    $where_clauses[] = "e.enquiry_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)";
    $params[] = $filter_days;
    $types .= "i";
}
if (!empty($filter_region)) {
    $where_clauses[] = "u.district = ?";
    $params[] = $filter_region;
    $types .= "s";
}
if (!empty($filter_product)) {
    $where_clauses[] = "e.product_id = ?";
    $params[] = $filter_product;
    $types .= "i";
}
$sql_condition = " WHERE " . implode(" AND ", $where_clauses);

// --- 3. ANALYTICS ---
$sql_traffic = "SELECT SUM(view_count) as views, SUM(click_count) as clicks FROM product_daily_stats WHERE advertiser_id = ? $date_condition";
$stmt = $conn->prepare($sql_traffic);
if ($filter_days != 3650) $stmt->bind_param("ii", $adv_id, $filter_days);
else $stmt->bind_param("i", $adv_id);
$stmt->execute();
$traffic = $stmt->get_result()->fetch_assoc();
$total_views = $traffic['views'] ?? 0;
$total_clicks = $traffic['clicks'] ?? 0;

$sql_kpi = "SELECT COUNT(*) as total, SUM(CASE WHEN e.status = 'Interested' THEN 1 ELSE 0 END) as pending, SUM(CASE WHEN e.status IN ('Contacted', 'Purchased') THEN 1 ELSE 0 END) as converted FROM enquiries e JOIN users u ON e.farmer_id = u.user_id $sql_condition";
$stmt = $conn->prepare($sql_kpi);
$stmt->bind_param($types, ...$params);
$stmt->execute();
$kpi = $stmt->get_result()->fetch_assoc();
$total_leads = $kpi['total'] ?? 0;
$pending_leads = $kpi['pending'] ?? 0;
$converted_leads = $kpi['converted'] ?? 0;

$action_rate = ($total_leads > 0) ? round(($converted_leads / $total_leads) * 100) : 0;
$ctr = ($total_views > 0) ? round(($total_clicks / $total_views) * 100, 1) : 0;
$conversion_rate = ($total_clicks > 0) ? round(($total_leads / $total_clicks) * 100, 1) : 0;

// Lead Trend Graph
$sql_graph = "SELECT DATE(e.enquiry_date) as date, COUNT(*) as count FROM enquiries e JOIN users u ON e.farmer_id = u.user_id $sql_condition GROUP BY DATE(e.enquiry_date) ORDER BY date ASC";
$stmt = $conn->prepare($sql_graph);
$stmt->bind_param($types, ...$params);
$stmt->execute();
$graph_res = $stmt->get_result();
$graph_data = [];
while($row = $graph_res->fetch_assoc()) { $graph_data[$row['date']] = $row['count']; }
$chart_labels = []; $chart_values = [];
for ($i = $filter_days - 1; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i days"));
    $chart_labels[] = date('M d', strtotime($d));
    $chart_values[] = isset($graph_data[$d]) ? $graph_data[$d] : 0;
}

// Product Breakdown (Pie Chart)
$sql_prod_pie = "SELECT p.product_name, COUNT(*) as count FROM enquiries e JOIN products p ON e.product_id = p.product_id JOIN users u ON e.farmer_id = u.user_id $sql_condition GROUP BY p.product_id ORDER BY count DESC LIMIT 5";
$stmt = $conn->prepare($sql_prod_pie);
$stmt->bind_param($types, ...$params);
$stmt->execute();
$pie_res = $stmt->get_result();
$pie_labels = []; $pie_data = [];
while($row = $pie_res->fetch_assoc()) {
    $pie_labels[] = $row['product_name'];
    $pie_data[] = $row['count'];
}

// --- 4. LISTS & DATA ---
$sql_live = "SELECT i.interaction_type, i.created_at, u.name as farmer_name, u.profile_image_url, u.village, p.product_name, p.image_url_1 FROM product_interactions i JOIN users u ON i.user_id = u.user_id JOIN products p ON i.product_id = p.product_id WHERE i.advertiser_id = ? ORDER BY i.created_at DESC LIMIT 5";
$stmt_live = $conn->prepare($sql_live);
$stmt_live->bind_param("i", $adv_id);
$stmt_live->execute();
$live_feed = $stmt_live->get_result();

$districts = $conn->query("SELECT DISTINCT u.district FROM enquiries e JOIN users u ON e.farmer_id = u.user_id WHERE e.advertiser_id = $adv_id AND u.district IS NOT NULL ORDER BY u.district");
$my_products_list = $conn->query("SELECT product_id, product_name FROM products WHERE advertiser_id = $adv_id ORDER BY product_name");

$sql_prods_table = "SELECT p.*, r.region_name, COALESCE(SUM(s.view_count), 0) as total_views, COALESCE(SUM(s.click_count), 0) as total_clicks FROM products p LEFT JOIN regions r ON p.region_id = r.id LEFT JOIN product_daily_stats s ON p.product_id = s.product_id WHERE p.advertiser_id = ? GROUP BY p.product_id ORDER BY p.created_at DESC";
$stmt = $conn->prepare($sql_prods_table);
$stmt->bind_param("i", $adv_id);
$stmt->execute();
$products_table = $stmt->get_result();

$regions = $conn->query("SELECT * FROM regions ORDER BY region_name ASC");

$sql_count = "SELECT COUNT(*) as total FROM enquiries e JOIN users u ON e.farmer_id = u.user_id $sql_condition";
$stmt = $conn->prepare($sql_count);
$stmt->bind_param($types, ...$params);
$stmt->execute();
$total_rows = $stmt->get_result()->fetch_assoc()['total'];
$total_pages = ceil($total_rows / $limit);

$sql_feed = "SELECT e.enquiry_id, e.status, e.enquiry_date, u.name as farmer_name, u.phone_number, u.village, u.district, u.profile_image_url, p.product_name, p.image_url_1 FROM enquiries e JOIN users u ON e.farmer_id = u.user_id JOIN products p ON e.product_id = p.product_id $sql_condition ORDER BY e.enquiry_date DESC LIMIT ? OFFSET ?";
$params_feed = $params; $params_feed[] = $limit; $params_feed[] = $offset;
$types_feed = $types . "ii";
$stmt = $conn->prepare($sql_feed);
$stmt->bind_param($types_feed, ...$params_feed);
$stmt->execute();
$leads = $stmt->get_result();

// Funnel data
$funnel_interested = $pending_leads;
$funnel_contacted = $kpi['converted'] ?? 0;
$sql_purchased = "SELECT COUNT(*) as cnt FROM enquiries e JOIN users u ON e.farmer_id = u.user_id $sql_condition AND e.status = 'Purchased'";
$stmt = $conn->prepare(str_replace($sql_condition . " AND", $sql_condition . " AND", $sql_purchased));
$stmt->bind_param($types, ...$params);
$stmt->execute();
$funnel_purchased = $stmt->get_result()->fetch_assoc()['cnt'] ?? 0;
?>
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard | <?= htmlspecialchars($adv_name) ?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/@phosphor-icons/web@2.1.1"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0"></script>
    <style>
        /* ===== DESIGN SYSTEM - FAANG LEVEL ===== */
        :root {
            /* Core Palette */
            --primary: #059669;
            --primary-light: #10b981;
            --primary-lighter: #d1fae5;
            --primary-gradient: linear-gradient(135deg, #059669 0%, #10b981 100%);
            
            /* Accent Colors */
            --blue: #3b82f6;
            --blue-light: #dbeafe;
            --purple: #8b5cf6;
            --purple-light: #ede9fe;
            --orange: #f97316;
            --orange-light: #ffedd5;
            --red: #ef4444;
            --red-light: #fee2e2;
            --amber: #f59e0b;
            --amber-light: #fef3c7;
            --cyan: #06b6d4;
            --cyan-light: #cffafe;
            
            /* Surfaces */
            --bg: #f8fafc;
            --bg-secondary: #f1f5f9;
            --surface: #ffffff;
            --surface-hover: #f8fafc;
            --surface-elevated: #ffffff;
            
            /* Text */
            --text-primary: #0f172a;
            --text-secondary: #475569;
            --text-tertiary: #94a3b8;
            --text-inverse: #ffffff;
            
            /* Borders & Shadows */
            --border: #e2e8f0;
            --border-light: #f1f5f9;
            --shadow-xs: 0 1px 2px rgba(0,0,0,0.04);
            --shadow-sm: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
            --shadow-md: 0 4px 6px -1px rgba(0,0,0,0.07), 0 2px 4px -2px rgba(0,0,0,0.05);
            --shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.08), 0 4px 6px -4px rgba(0,0,0,0.04);
            --shadow-xl: 0 20px 25px -5px rgba(0,0,0,0.08), 0 8px 10px -6px rgba(0,0,0,0.04);
            --shadow-glow: 0 0 20px rgba(5, 150, 105, 0.15);
            
            /* Layout */
            --sidebar-width: 280px;
            --header-height: 72px;
            --radius-sm: 8px;
            --radius-md: 12px;
            --radius-lg: 16px;
            --radius-xl: 20px;
            --radius-full: 9999px;
            
            /* Transitions */
            --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
            --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
            --duration-fast: 150ms;
            --duration-normal: 250ms;
            --duration-slow: 400ms;
        }

        /* Dark Theme */
        [data-theme="dark"] {
            --bg: #0f172a;
            --bg-secondary: #1e293b;
            --surface: #1e293b;
            --surface-hover: #334155;
            --surface-elevated: #334155;
            --text-primary: #f1f5f9;
            --text-secondary: #94a3b8;
            --text-tertiary: #64748b;
            --border: #334155;
            --border-light: #1e293b;
            --shadow-xs: 0 1px 2px rgba(0,0,0,0.2);
            --shadow-sm: 0 1px 3px rgba(0,0,0,0.3);
            --shadow-md: 0 4px 6px rgba(0,0,0,0.3);
            --shadow-lg: 0 10px 15px rgba(0,0,0,0.3);
            --shadow-xl: 0 20px 25px rgba(0,0,0,0.4);
        }

        /* ===== RESET & BASE ===== */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        
        html { scroll-behavior: smooth; -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; }
        
        body {
            font-family: 'Poppins', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: var(--bg);
            color: var(--text-primary);
            line-height: 1.6;
            overflow-x: hidden;
            min-height: 100vh;
        }

        /* ===== SIDEBAR ===== */
        .sidebar {
            position: fixed;
            left: 0;
            top: 0;
            bottom: 0;
            width: var(--sidebar-width);
            background: var(--surface);
            border-right: 1px solid var(--border);
            z-index: 200;
            display: flex;
            flex-direction: column;
            transition: transform var(--duration-slow) var(--ease-out);
        }

        .sidebar-header {
            padding: 24px 24px 20px;
            border-bottom: 1px solid var(--border);
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 14px;
        }

        .brand-logo {
            width: 44px;
            height: 44px;
            background: var(--primary-gradient);
            color: white;
            border-radius: var(--radius-md);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            font-size: 15px;
            letter-spacing: 0.5px;
            box-shadow: 0 4px 12px rgba(5, 150, 105, 0.3);
            flex-shrink: 0;
        }

        .brand-text {
            display: flex;
            flex-direction: column;
            min-width: 0;
        }

        .brand-name {
            font-weight: 700;
            font-size: 15px;
            color: var(--text-primary);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .brand-role {
            font-size: 11px;
            color: var(--primary);
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .sidebar-nav {
            flex: 1;
            padding: 16px 12px;
            overflow-y: auto;
        }

        .nav-section-label {
            font-size: 10px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1.2px;
            color: var(--text-tertiary);
            padding: 12px 16px 8px;
        }

        .nav-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 11px 16px;
            border-radius: var(--radius-md);
            color: var(--text-secondary);
            text-decoration: none;
            font-size: 13.5px;
            font-weight: 500;
            transition: all var(--duration-fast) ease;
            cursor: pointer;
            margin-bottom: 2px;
            position: relative;
        }

        .nav-item:hover {
            background: var(--surface-hover);
            color: var(--text-primary);
        }

        .nav-item.active {
            background: var(--primary-lighter);
            color: var(--primary);
            font-weight: 600;
        }

        .nav-item.active::before {
            content: '';
            position: absolute;
            left: 0;
            top: 50%;
            transform: translateY(-50%);
            width: 3px;
            height: 20px;
            background: var(--primary);
            border-radius: 0 4px 4px 0;
        }

        .nav-item i {
            font-size: 20px;
            width: 24px;
            text-align: center;
            flex-shrink: 0;
        }

        .nav-badge {
            margin-left: auto;
            background: var(--red);
            color: white;
            font-size: 10px;
            font-weight: 700;
            padding: 2px 7px;
            border-radius: var(--radius-full);
            min-width: 20px;
            text-align: center;
        }

        .sidebar-footer {
            padding: 16px 12px;
            border-top: 1px solid var(--border);
        }

        .theme-toggle {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 11px 16px;
            border-radius: var(--radius-md);
            color: var(--text-secondary);
            font-size: 13.5px;
            font-weight: 500;
            cursor: pointer;
            transition: all var(--duration-fast) ease;
            border: none;
            background: none;
            width: 100%;
            font-family: inherit;
        }

        .theme-toggle:hover {
            background: var(--surface-hover);
            color: var(--text-primary);
        }

        .theme-toggle i { font-size: 20px; width: 24px; text-align: center; }

        .logout-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 11px 16px;
            border-radius: var(--radius-md);
            color: var(--red);
            text-decoration: none;
            font-size: 13.5px;
            font-weight: 500;
            transition: all var(--duration-fast) ease;
            margin-top: 4px;
        }

        .logout-item:hover {
            background: var(--red-light);
        }

        .logout-item i { font-size: 20px; width: 24px; text-align: center; }

        /* ===== MAIN CONTENT ===== */
        .main-content {
            margin-left: var(--sidebar-width);
            min-height: 100vh;
            transition: margin-left var(--duration-slow) var(--ease-out);
        }

        /* ===== TOP HEADER ===== */
        .top-header {
            position: sticky;
            top: 0;
            z-index: 100;
            background: rgba(248, 250, 252, 0.85);
            backdrop-filter: blur(12px) saturate(180%);
            -webkit-backdrop-filter: blur(12px) saturate(180%);
            border-bottom: 1px solid var(--border);
            padding: 0 32px;
            height: var(--header-height);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        [data-theme="dark"] .top-header {
            background: rgba(15, 23, 42, 0.85);
        }

        .header-left {
            display: flex;
            align-items: center;
            gap: 16px;
        }

        .menu-toggle {
            display: none;
            background: none;
            border: none;
            color: var(--text-primary);
            font-size: 24px;
            cursor: pointer;
            padding: 8px;
            border-radius: var(--radius-sm);
            transition: background var(--duration-fast) ease;
        }

        .menu-toggle:hover { background: var(--surface-hover); }

        .page-title-section h1 {
            font-size: 20px;
            font-weight: 700;
            color: var(--text-primary);
            letter-spacing: -0.3px;
        }

        .page-title-section p {
            font-size: 12.5px;
            color: var(--text-tertiary);
            font-weight: 400;
            margin-top: 1px;
        }

        .header-actions {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .header-btn {
            width: 40px;
            height: 40px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            background: var(--surface);
            color: var(--text-secondary);
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all var(--duration-fast) ease;
            position: relative;
            font-size: 19px;
        }

        .header-btn:hover {
            background: var(--surface-hover);
            border-color: var(--primary-light);
            color: var(--primary);
            transform: translateY(-1px);
            box-shadow: var(--shadow-sm);
        }

        .notification-dot {
            position: absolute;
            top: 8px;
            right: 8px;
            width: 8px;
            height: 8px;
            background: var(--red);
            border-radius: 50%;
            border: 2px solid var(--surface);
        }

        .user-avatar-header {
            width: 38px;
            height: 38px;
            background: var(--primary-gradient);
            color: white;
            border-radius: var(--radius-md);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            font-size: 13px;
            cursor: pointer;
            transition: transform var(--duration-fast) var(--ease-spring);
        }

        .user-avatar-header:hover { transform: scale(1.05); }

        /* ===== CONTENT AREA ===== */
        .content-area {
            padding: 28px 32px 60px;
            max-width: 1400px;
        }

        /* ===== FILTER BAR ===== */
        .filter-bar {
            background: var(--surface);
            padding: 16px 20px;
            border-radius: var(--radius-lg);
            border: 1px solid var(--border);
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            align-items: center;
            margin-bottom: 28px;
            box-shadow: var(--shadow-xs);
        }

        .filter-group {
            position: relative;
            flex: 1;
            min-width: 150px;
        }

        .filter-icon {
            position: absolute;
            left: 14px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-tertiary);
            pointer-events: none;
            font-size: 16px;
            z-index: 1;
        }

        .filter-select {
            appearance: none;
            -webkit-appearance: none;
            width: 100%;
            padding: 10px 36px 10px 40px;
            border-radius: var(--radius-md);
            border: 1.5px solid var(--border);
            font-family: 'Poppins', sans-serif;
            font-size: 13px;
            background: var(--bg);
            cursor: pointer;
            outline: none;
            transition: all var(--duration-fast) ease;
            color: var(--text-primary);
            font-weight: 500;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 256 256'%3E%3Cpath fill='%2394a3b8' d='M213.66,101.66l-80,80a8,8,0,0,1-11.32,0l-80-80A8,8,0,0,1,53.66,90.34L128,164.69l74.34-74.35a8,8,0,0,1,11.32,11.32Z'%3E%3C/path%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: right 14px center;
        }

        .filter-select:hover { border-color: var(--primary-light); }
        .filter-select:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(5, 150, 105, 0.1); }

        .filter-apply {
            background: var(--text-primary);
            color: var(--text-inverse);
            border: none;
            padding: 10px 28px;
            border-radius: var(--radius-md);
            cursor: pointer;
            font-weight: 600;
            font-size: 13px;
            font-family: 'Poppins', sans-serif;
            transition: all var(--duration-normal) var(--ease-out);
            white-space: nowrap;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .filter-apply:hover {
            background: var(--primary);
            transform: translateY(-1px);
            box-shadow: var(--shadow-md);
        }

        .filter-apply i { font-size: 16px; }

        /* ===== STATS GRID ===== */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
            margin-bottom: 28px;
        }

        .stat-card {
            background: var(--surface);
            padding: 22px 24px;
            border-radius: var(--radius-lg);
            border: 1px solid var(--border);
            position: relative;
            overflow: hidden;
            transition: all var(--duration-normal) var(--ease-out);
            cursor: default;
        }

        .stat-card:hover {
            transform: translateY(-3px);
            box-shadow: var(--shadow-lg);
            border-color: transparent;
        }

        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            border-radius: 3px 3px 0 0;
        }

        .stat-card:nth-child(1)::before { background: linear-gradient(90deg, #3b82f6, #60a5fa); }
        .stat-card:nth-child(2)::before { background: linear-gradient(90deg, #059669, #10b981); }
        .stat-card:nth-child(3)::before { background: linear-gradient(90deg, #f97316, #fb923c); }
        .stat-card:nth-child(4)::before { background: linear-gradient(90deg, #8b5cf6, #a78bfa); }

        .stat-card:nth-child(1):hover { box-shadow: 0 8px 25px rgba(59, 130, 246, 0.15); }
        .stat-card:nth-child(2):hover { box-shadow: 0 8px 25px rgba(5, 150, 105, 0.15); }
        .stat-card:nth-child(3):hover { box-shadow: 0 8px 25px rgba(249, 115, 22, 0.15); }
        .stat-card:nth-child(4):hover { box-shadow: 0 8px 25px rgba(139, 92, 246, 0.15); }

        .stat-top {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            margin-bottom: 12px;
        }

        .stat-icon-box {
            width: 44px;
            height: 44px;
            border-radius: var(--radius-md);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        }

        .stat-card:nth-child(1) .stat-icon-box { background: var(--blue-light); color: var(--blue); }
        .stat-card:nth-child(2) .stat-icon-box { background: var(--primary-lighter); color: var(--primary); }
        .stat-card:nth-child(3) .stat-icon-box { background: var(--orange-light); color: var(--orange); }
        .stat-card:nth-child(4) .stat-icon-box { background: var(--purple-light); color: var(--purple); }

        .stat-trend {
            display: inline-flex;
            align-items: center;
            gap: 3px;
            font-size: 11px;
            font-weight: 600;
            padding: 3px 8px;
            border-radius: var(--radius-full);
        }

        .stat-trend.up { background: #dcfce7; color: #15803d; }
        .stat-trend.down { background: #fee2e2; color: #991b1b; }
        .stat-trend.neutral { background: #f1f5f9; color: #64748b; }

        .stat-value {
            font-size: 32px;
            font-weight: 800;
            color: var(--text-primary);
            line-height: 1.1;
            letter-spacing: -1px;
        }

        .stat-label {
            font-size: 12.5px;
            color: var(--text-tertiary);
            font-weight: 500;
            margin-top: 4px;
        }

        .stat-sub {
            font-size: 11.5px;
            color: var(--text-tertiary);
            font-weight: 400;
            margin-top: 2px;
        }

        /* ===== CHARTS ROW ===== */
        .charts-row {
            display: grid;
            grid-template-columns: 1.8fr 1fr;
            gap: 20px;
            margin-bottom: 28px;
        }

        .chart-card {
            background: var(--surface);
            border-radius: var(--radius-lg);
            border: 1px solid var(--border);
            overflow: hidden;
            transition: all var(--duration-normal) var(--ease-out);
        }

        .chart-card:hover {
            box-shadow: var(--shadow-md);
        }

        .chart-header {
            padding: 20px 24px 0;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .chart-title {
            font-size: 15px;
            font-weight: 700;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .chart-title-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--primary);
        }

        .chart-subtitle {
            font-size: 11.5px;
            color: var(--text-tertiary);
            font-weight: 400;
        }

        .chart-body {
            padding: 16px 20px 20px;
            height: 280px;
            position: relative;
        }

        /* ===== LIVE FEED ===== */
        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
            margin-top: 8px;
        }

        .section-title {
            font-size: 16px;
            font-weight: 700;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .section-title-icon {
            width: 32px;
            height: 32px;
            border-radius: var(--radius-sm);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
        }

        .live-dot {
            width: 8px;
            height: 8px;
            background: var(--red);
            border-radius: 50%;
            animation: livePulse 2s infinite;
            box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.4);
        }

        @keyframes livePulse {
            0% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.4); }
            70% { box-shadow: 0 0 0 8px rgba(239, 68, 68, 0); }
            100% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
        }

        .live-feed {
            display: flex;
            flex-direction: column;
            gap: 8px;
            margin-bottom: 32px;
        }

        .feed-item {
            background: var(--surface);
            padding: 14px 20px;
            border-radius: var(--radius-md);
            border: 1px solid var(--border);
            display: flex;
            align-items: center;
            gap: 14px;
            transition: all var(--duration-normal) var(--ease-out);
            animation: feedSlideIn 0.5s var(--ease-out) backwards;
        }

        .feed-item:nth-child(1) { animation-delay: 0ms; }
        .feed-item:nth-child(2) { animation-delay: 60ms; }
        .feed-item:nth-child(3) { animation-delay: 120ms; }
        .feed-item:nth-child(4) { animation-delay: 180ms; }
        .feed-item:nth-child(5) { animation-delay: 240ms; }

        @keyframes feedSlideIn {
            from { opacity: 0; transform: translateX(-12px); }
            to { opacity: 1; transform: translateX(0); }
        }

        .feed-item:hover {
            border-color: var(--primary-light);
            box-shadow: var(--shadow-sm);
            transform: translateX(4px);
        }

        .feed-item.click-type { border-left: 3px solid var(--blue); }
        .feed-item.view-type { border-left: 3px solid var(--text-tertiary); }

        .feed-avatar {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            object-fit: cover;
            border: 2px solid var(--surface);
            box-shadow: var(--shadow-xs);
            flex-shrink: 0;
        }

        .feed-content { flex: 1; min-width: 0; }

        .feed-text {
            font-size: 13.5px;
            color: var(--text-primary);
            line-height: 1.4;
        }

        .feed-text strong { font-weight: 600; }

        .feed-action-label {
            font-weight: 600;
            padding: 1px 6px;
            border-radius: 4px;
            font-size: 12px;
        }

        .feed-action-label.click { background: var(--blue-light); color: var(--blue); }
        .feed-action-label.view { background: var(--bg-secondary); color: var(--text-tertiary); }

        .feed-time {
            font-size: 11px;
            color: var(--text-tertiary);
            margin-top: 2px;
        }

        .feed-product-img {
            width: 40px;
            height: 40px;
            border-radius: var(--radius-sm);
            object-fit: cover;
            border: 1px solid var(--border);
            flex-shrink: 0;
        }

        /* ===== TABLE STYLES ===== */
        .table-card {
            background: var(--surface);
            border-radius: var(--radius-lg);
            border: 1px solid var(--border);
            overflow: hidden;
            margin-bottom: 32px;
            transition: box-shadow var(--duration-normal) var(--ease-out);
        }

        .table-card:hover { box-shadow: var(--shadow-sm); }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        thead th {
            background: var(--bg);
            text-align: left;
            padding: 14px 20px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: var(--text-tertiary);
            border-bottom: 1px solid var(--border);
            white-space: nowrap;
        }

        tbody td {
            padding: 14px 20px;
            border-bottom: 1px solid var(--border-light);
            vertical-align: middle;
            font-size: 13.5px;
            color: var(--text-primary);
        }

        tbody tr {
            transition: background var(--duration-fast) ease;
        }

        tbody tr:hover {
            background: var(--surface-hover);
        }

        tbody tr:last-child td {
            border-bottom: none;
        }

        .user-cell {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .user-avatar {
            width: 38px;
            height: 38px;
            border-radius: 50%;
            object-fit: cover;
            border: 2px solid var(--surface);
            box-shadow: var(--shadow-xs), 0 0 0 1px var(--border);
            flex-shrink: 0;
        }

        .user-info-name {
            font-weight: 600;
            font-size: 13.5px;
            color: var(--text-primary);
        }

        .user-info-sub {
            font-size: 11.5px;
            color: var(--text-tertiary);
            margin-top: 1px;
        }

        .product-cell {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .product-thumb {
            width: 36px;
            height: 36px;
            border-radius: var(--radius-sm);
            object-fit: cover;
            border: 1px solid var(--border);
        }

        .product-name-text {
            font-weight: 500;
            font-size: 13px;
        }

        /* Status Select */
        .status-select {
            padding: 7px 12px;
            border-radius: var(--radius-sm);
            border: 1.5px solid var(--border);
            background: var(--surface);
            font-size: 12.5px;
            font-weight: 600;
            cursor: pointer;
            font-family: 'Poppins', sans-serif;
            transition: all var(--duration-fast) ease;
            outline: none;
        }

        .status-select:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(5, 150, 105, 0.1);
        }

        .status-interested { color: #ea580c; border-color: #fed7aa; background: #fff7ed; }
        .status-contacted { color: #059669; border-color: #a7f3d0; background: #ecfdf5; }
        .status-purchased { color: #7c3aed; border-color: #c4b5fd; background: #f5f3ff; }

        /* Call Button */
        .call-btn {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 7px 16px;
            border-radius: var(--radius-sm);
            background: var(--bg);
            color: var(--text-primary);
            text-decoration: none;
            font-size: 12.5px;
            font-weight: 600;
            transition: all var(--duration-fast) ease;
            border: 1px solid var(--border);
        }

        .call-btn:hover {
            background: var(--primary-lighter);
            color: var(--primary);
            border-color: var(--primary-light);
            transform: translateY(-1px);
            box-shadow: var(--shadow-sm);
        }

        .call-btn i { font-size: 15px; }

        /* Date Cell */
        .date-cell {
            color: var(--text-secondary);
            font-size: 13px;
            font-weight: 500;
        }

        .date-cell-time {
            font-size: 11px;
            color: var(--text-tertiary);
            font-weight: 400;
            margin-top: 1px;
        }

        /* Badges */
        .badge {
            font-size: 10.5px;
            padding: 4px 10px;
            border-radius: var(--radius-full);
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.3px;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }

        .badge-stock { background: #dcfce7; color: #15803d; }
        .badge-stock::before { content: ''; width: 5px; height: 5px; border-radius: 50%; background: #15803d; }
        .badge-out { background: #fee2e2; color: #991b1b; }
        .badge-out::before { content: ''; width: 5px; height: 5px; border-radius: 50%; background: #991b1b; }
        .badge-hidden { background: #f1f5f9; color: #64748b; border: 1px solid #cbd5e1; }

        .prod-row.hidden-product { opacity: 0.5; }

        /* Product Table Specific */
        .product-views-col {
            font-weight: 700;
            font-size: 14px;
            color: var(--text-primary);
        }

        .product-clicks-col {
            font-weight: 500;
            color: var(--text-secondary);
        }

        .edit-btn {
            width: 34px;
            height: 34px;
            border-radius: var(--radius-sm);
            border: 1px solid var(--border);
            background: var(--surface);
            color: var(--text-tertiary);
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all var(--duration-fast) ease;
            font-size: 16px;
        }

        .edit-btn:hover {
            background: var(--blue-light);
            color: var(--blue);
            border-color: var(--blue);
            transform: scale(1.05);
        }

        /* ===== ADD BUTTON ===== */
        .add-product-btn {
            background: var(--primary-gradient);
            color: white;
            border: none;
            padding: 10px 22px;
            border-radius: var(--radius-md);
            font-weight: 600;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all var(--duration-normal) var(--ease-out);
            font-size: 13px;
            font-family: 'Poppins', sans-serif;
            box-shadow: 0 4px 12px rgba(5, 150, 105, 0.25);
        }

        .add-product-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(5, 150, 105, 0.35);
        }

        .add-product-btn:active { transform: translateY(0); }
        .add-product-btn i { font-size: 18px; }

        /* ===== PAGINATION ===== */
        .pagination {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 6px;
            margin-top: 24px;
            margin-bottom: 32px;
        }

        .page-btn {
            padding: 8px 14px;
            border: 1px solid var(--border);
            background: var(--surface);
            border-radius: var(--radius-sm);
            text-decoration: none;
            color: var(--text-secondary);
            font-size: 13px;
            font-weight: 600;
            transition: all var(--duration-fast) ease;
            font-family: 'Poppins', sans-serif;
        }

        .page-btn:hover {
            border-color: var(--primary-light);
            color: var(--primary);
            background: var(--primary-lighter);
        }

        .page-btn.active {
            background: var(--text-primary);
            color: var(--text-inverse);
            border-color: var(--text-primary);
        }

        .page-btn.nav-arrow {
            display: flex;
            align-items: center;
            gap: 4px;
        }

        /* ===== MODAL ===== */
        .modal-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.6);
            z-index: 1000;
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            align-items: center;
            justify-content: center;
            padding: 20px;
            opacity: 0;
            transition: opacity var(--duration-normal) ease;
        }

        .modal-overlay.active {
            display: flex;
            opacity: 1;
        }

        .modal-container {
            background: var(--surface);
            width: 100%;
            max-width: 520px;
            border-radius: var(--radius-xl);
            max-height: 90vh;
            overflow-y: auto;
            position: relative;
            box-shadow: var(--shadow-xl);
            transform: scale(0.95) translateY(10px);
            transition: transform var(--duration-normal) var(--ease-spring);
        }

        .modal-overlay.active .modal-container {
            transform: scale(1) translateY(0);
        }

        .modal-header {
            padding: 24px 28px 0;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .modal-title {
            font-size: 18px;
            font-weight: 700;
            color: var(--text-primary);
        }

        .modal-close {
            width: 36px;
            height: 36px;
            border-radius: 50%;
            border: none;
            background: var(--bg);
            color: var(--text-tertiary);
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: all var(--duration-fast) ease;
            font-size: 20px;
        }

        .modal-close:hover {
            background: var(--red-light);
            color: var(--red);
        }

        .modal-body {
            padding: 20px 28px 28px;
        }

        .form-group {
            margin-bottom: 18px;
        }

        .form-label {
            display: block;
            font-size: 12.5px;
            font-weight: 600;
            color: var(--text-secondary);
            margin-bottom: 6px;
            letter-spacing: 0.2px;
        }

        .form-input {
            width: 100%;
            padding: 10px 14px;
            border: 1.5px solid var(--border);
            border-radius: var(--radius-md);
            font-family: 'Poppins', sans-serif;
            font-size: 13.5px;
            color: var(--text-primary);
            background: var(--surface);
            transition: all var(--duration-fast) ease;
            outline: none;
        }

        .form-input:hover { border-color: var(--text-tertiary); }

        .form-input:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(5, 150, 105, 0.1);
        }

        .form-input::placeholder { color: var(--text-tertiary); }

        textarea.form-input { resize: vertical; min-height: 80px; }

        .form-row {
            display: flex;
            gap: 14px;
        }

        .form-row .form-group { flex: 1; }

        .toggle-bar {
            display: flex;
            gap: 0;
            background: var(--bg);
            padding: 14px 18px;
            border-radius: var(--radius-md);
            margin-bottom: 20px;
            border: 1px solid var(--border);
        }

        .toggle-item {
            flex: 1;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .toggle-item + .toggle-item {
            border-left: 1px solid var(--border);
            padding-left: 18px;
        }

        .toggle-label-text {
            font-size: 12.5px;
            font-weight: 600;
            color: var(--text-secondary);
        }

        /* Modern Toggle Switch */
        .switch {
            position: relative;
            display: inline-block;
            width: 42px;
            height: 24px;
        }

        .switch input { opacity: 0; width: 0; height: 0; }

        .slider {
            position: absolute;
            cursor: pointer;
            top: 0; left: 0; right: 0; bottom: 0;
            background-color: #cbd5e1;
            transition: all var(--duration-normal) var(--ease-out);
            border-radius: 34px;
        }

        .slider:before {
            position: absolute;
            content: "";
            height: 18px;
            width: 18px;
            left: 3px;
            bottom: 3px;
            background-color: white;
            transition: all var(--duration-normal) var(--ease-spring);
            border-radius: 50%;
            box-shadow: 0 1px 3px rgba(0,0,0,0.15);
        }

        input:checked + .slider { background-color: var(--primary); }
        input:checked + .slider:before { transform: translateX(18px); }

        /* File Upload */
        .file-upload-zone {
            border: 2px dashed var(--border);
            padding: 24px;
            text-align: center;
            border-radius: var(--radius-md);
            cursor: pointer;
            transition: all var(--duration-fast) ease;
            background: var(--bg);
        }

        .file-upload-zone:hover {
            border-color: var(--primary-light);
            background: var(--primary-lighter);
        }

        .file-upload-zone i {
            font-size: 28px;
            color: var(--primary);
            margin-bottom: 4px;
        }

        .file-upload-text {
            font-size: 12.5px;
            color: var(--text-tertiary);
            margin-top: 4px;
            font-weight: 500;
        }

        .submit-btn {
            width: 100%;
            padding: 13px;
            background: var(--primary-gradient);
            color: white;
            border: none;
            border-radius: var(--radius-md);
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            font-family: 'Poppins', sans-serif;
            transition: all var(--duration-normal) var(--ease-out);
            box-shadow: 0 4px 12px rgba(5, 150, 105, 0.25);
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }

        .submit-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(5, 150, 105, 0.35);
        }

        .submit-btn:active { transform: translateY(0); }

        /* ===== TOAST ===== */
        .toast-container {
            position: fixed;
            top: 24px;
            right: 24px;
            z-index: 2000;
        }

        .toast {
            background: var(--text-primary);
            color: white;
            padding: 14px 24px;
            border-radius: var(--radius-md);
            display: flex;
            align-items: center;
            gap: 10px;
            transform: translateX(120%);
            transition: transform var(--duration-slow) var(--ease-spring);
            box-shadow: var(--shadow-xl);
            font-size: 13.5px;
            font-weight: 500;
            max-width: 360px;
        }

        .toast.show { transform: translateX(0); }
        .toast-success { background: #064e3b; border: 1px solid rgba(16, 185, 129, 0.3); }
        .toast-error { background: #7f1d1d; border: 1px solid rgba(239, 68, 68, 0.3); }
        .toast i { font-size: 20px; flex-shrink: 0; }

        /* ===== EMPTY STATE ===== */
        .empty-state {
            text-align: center;
            padding: 48px 24px;
            color: var(--text-tertiary);
        }

        .empty-state i {
            font-size: 48px;
            margin-bottom: 12px;
            opacity: 0.3;
        }

        .empty-state-text {
            font-size: 14px;
            font-weight: 500;
        }

        .empty-state-sub {
            font-size: 12.5px;
            margin-top: 4px;
        }

        /* ===== FUNNEL CARD ===== */
        .funnel-card {
            background: var(--surface);
            border-radius: var(--radius-lg);
            border: 1px solid var(--border);
            padding: 24px;
            margin-bottom: 28px;
        }

        .funnel-stages {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0;
            margin-top: 16px;
        }

        .funnel-stage {
            flex: 1;
            text-align: center;
            position: relative;
            padding: 16px 12px;
        }

        .funnel-stage-value {
            font-size: 28px;
            font-weight: 800;
            letter-spacing: -0.5px;
        }

        .funnel-stage-label {
            font-size: 11.5px;
            color: var(--text-tertiary);
            font-weight: 500;
            margin-top: 4px;
        }

        .funnel-stage-bar {
            height: 6px;
            border-radius: 3px;
            margin-top: 10px;
        }

        .funnel-arrow {
            color: var(--text-tertiary);
            font-size: 20px;
            opacity: 0.4;
            flex-shrink: 0;
        }

        /* ===== SIDEBAR OVERLAY (Mobile) ===== */
        .sidebar-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.4);
            z-index: 199;
            opacity: 0;
            transition: opacity var(--duration-normal) ease;
        }

        .sidebar-overlay.active {
            display: block;
            opacity: 1;
        }

        /* ===== SCROLLBAR ===== */
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: var(--text-tertiary); }

        /* ===== RESPONSIVE ===== */
        @media (max-width: 1200px) {
            .stats-grid { grid-template-columns: repeat(2, 1fr); }
            .charts-row { grid-template-columns: 1fr; }
        }

        @media (max-width: 768px) {
            .sidebar { transform: translateX(-100%); }
            .sidebar.open { transform: translateX(0); }
            .main-content { margin-left: 0; }
            .menu-toggle { display: flex; }
            .content-area { padding: 20px 16px 60px; }
            .top-header { padding: 0 16px; }
            .stats-grid { grid-template-columns: 1fr 1fr; gap: 12px; }
            .stat-value { font-size: 24px; }
            .stat-card { padding: 16px 18px; }
            .filter-bar { padding: 12px 14px; gap: 10px; }
            .filter-group { min-width: 100%; }
            .charts-row { grid-template-columns: 1fr; }
            .page-title-section h1 { font-size: 17px; }
            .page-title-section p { display: none; }
            .funnel-stages { flex-direction: column; gap: 8px; }
            .funnel-arrow { transform: rotate(90deg); }
            
            /* Responsive table */
            .table-card { overflow-x: auto; }
            table { min-width: 600px; }
        }

        @media (max-width: 480px) {
            .stats-grid { grid-template-columns: 1fr; }
            .header-actions .header-btn:not(:last-child) { display: none; }
        }

        /* ===== ANIMATIONS ===== */
        @keyframes fadeInUp {
            from { opacity: 0; transform: translateY(16px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .animate-in {
            animation: fadeInUp 0.5s var(--ease-out) backwards;
        }

        .delay-1 { animation-delay: 50ms; }
        .delay-2 { animation-delay: 100ms; }
        .delay-3 { animation-delay: 150ms; }
        .delay-4 { animation-delay: 200ms; }
        .delay-5 { animation-delay: 250ms; }
        .delay-6 { animation-delay: 300ms; }

        /* Trend Pill */
        .trend-pill {
            font-size: 10px;
            padding: 2px 8px;
            border-radius: var(--radius-full);
            background: var(--bg-secondary);
            color: var(--text-tertiary);
            font-weight: 600;
            vertical-align: middle;
        }

        /* Category badge in product table */
        .category-badge {
            font-size: 11px;
            color: var(--text-tertiary);
            font-weight: 400;
            margin-top: 1px;
        }
    </style>
</head>
<body>

    <!-- Toast -->
    <div class="toast-container">
        <div id="toast" class="toast">
            <i class="ph ph-check-circle" style="color: #34d399;"></i>
            <span id="toastMsg">Action Successful</span>
        </div>
    </div>
    <?php if(isset($_SESSION['toast'])): ?>
    <script>
        document.getElementById('toastMsg').innerText = "<?= $_SESSION['toast']['message'] ?>";
        document.getElementById('toast').classList.add('show', '<?= $_SESSION['toast']['type'] ? 'toast-success' : 'toast-error' ?>');
        setTimeout(() => { document.getElementById('toast').classList.remove('show'); }, 3500);
    </script>
    <?php unset($_SESSION['toast']); endif; ?>

    <!-- Sidebar Overlay (Mobile) -->
    <div class="sidebar-overlay" id="sidebarOverlay" onclick="toggleSidebar()"></div>

    <!-- Sidebar -->
    <aside class="sidebar" id="sidebar">
        <div class="sidebar-header">
            <div class="brand">
                <div class="brand-logo"><?= $initials ?></div>
                <div class="brand-text">
                    <span class="brand-name"><?= htmlspecialchars($adv_name) ?></span>
                    <span class="brand-role">Partner Dashboard</span>
                </div>
            </div>
        </div>

        <nav class="sidebar-nav">
            <div class="nav-section-label">Main</div>
            <a href="#" class="nav-item active" onclick="scrollToSection('top')">
                <i class="ph ph-squares-four"></i>
                Overview
            </a>
            <a href="#" class="nav-item" onclick="scrollToSection('analytics')">
                <i class="ph ph-chart-line-up"></i>
                Analytics
            </a>
            <a href="#" class="nav-item" onclick="scrollToSection('live-feed')">
                <i class="ph ph-broadcast"></i>
                Live Feed
                <?php if($live_feed->num_rows > 0): ?>
                <span class="nav-badge"><?= $live_feed->num_rows ?></span>
                <?php endif; ?>
            </a>

            <div class="nav-section-label">Management</div>
            <a href="#" class="nav-item" onclick="scrollToSection('enquiries')">
                <i class="ph ph-address-book"></i>
                Enquiries
                <?php if($pending_leads > 0): ?>
                <span class="nav-badge"><?= $pending_leads ?></span>
                <?php endif; ?>
            </a>
            <a href="#" class="nav-item" onclick="scrollToSection('products')">
                <i class="ph ph-package"></i>
                Products
            </a>
        </nav>

        <div class="sidebar-footer">
            <button class="theme-toggle" onclick="toggleTheme()" id="themeBtn">
                <i class="ph ph-moon"></i>
                <span id="themeLabel">Dark Mode</span>
            </button>
            <a href="logout.php" class="logout-item">
                <i class="ph ph-sign-out"></i>
                Sign Out
            </a>
        </div>
    </aside>

    <!-- Main Content -->
    <main class="main-content">
        <!-- Top Header -->
        <header class="top-header">
            <div class="header-left">
                <button class="menu-toggle" onclick="toggleSidebar()">
                    <i class="ph ph-list"></i>
                </button>
                <div class="page-title-section">
                    <h1>Dashboard</h1>
                    <p>Welcome back, <?= htmlspecialchars(explode(' ', $adv_name)[0]) ?>. Here's your business overview.</p>
                </div>
            </div>
            <div class="header-actions">
                <button class="header-btn" title="Refresh" onclick="location.reload()">
                    <i class="ph ph-arrow-clockwise"></i>
                </button>
                <button class="header-btn" title="Notifications">
                    <i class="ph ph-bell"></i>
                    <?php if($pending_leads > 0): ?>
                    <span class="notification-dot"></span>
                    <?php endif; ?>
                </button>
                <div class="user-avatar-header" title="<?= htmlspecialchars($adv_name) ?>">
                    <?= $initials ?>
                </div>
            </div>
        </header>

        <!-- Content -->
        <div class="content-area" id="top">

            <!-- Filter Bar -->
            <form method="GET" class="filter-bar animate-in">
                <div class="filter-group">
                    <i class="ph ph-calendar-blank filter-icon"></i>
                    <select name="days" class="filter-select">
                        <option value="7" <?= $filter_days == 7 ? 'selected' : '' ?>>Last 7 Days</option>
                        <option value="30" <?= $filter_days == 30 ? 'selected' : '' ?>>Last 30 Days</option>
                        <option value="90" <?= $filter_days == 90 ? 'selected' : '' ?>>Last 3 Months</option>
                        <option value="3650" <?= $filter_days == 3650 ? 'selected' : '' ?>>All Time</option>
                    </select>
                </div>
                <div class="filter-group">
                    <i class="ph ph-map-pin filter-icon"></i>
                    <select name="region" class="filter-select">
                        <option value="">All Regions</option>
                        <?php while($d = $districts->fetch_assoc()): ?>
                            <option value="<?= htmlspecialchars($d['district']) ?>" <?= $filter_region == $d['district'] ? 'selected' : '' ?>>
                                <?= htmlspecialchars($d['district']) ?>
                            </option>
                        <?php endwhile; ?>
                    </select>
                </div>
                <div class="filter-group">
                    <i class="ph ph-package filter-icon"></i>
                    <select name="product" class="filter-select">
                        <option value="">All Products</option>
                        <?php while($p = $my_products_list->fetch_assoc()): ?>
                            <option value="<?= $p['product_id'] ?>" <?= $filter_product == $p['product_id'] ? 'selected' : '' ?>>
                                <?= htmlspecialchars($p['product_name']) ?>
                            </option>
                        <?php endwhile; ?>
                    </select>
                </div>
                <button type="submit" class="filter-apply">
                    <i class="ph ph-funnel"></i>
                    Apply
                </button>
            </form>

            <!-- Stats Grid -->
            <div class="stats-grid" id="analytics">
                <div class="stat-card animate-in delay-1">
                    <div class="stat-top">
                        <div class="stat-icon-box"><i class="ph-fill ph-eye"></i></div>
                        <span class="stat-trend neutral"><i class="ph ph-minus"></i> --</span>
                    </div>
                    <div class="stat-value"><?= number_format($total_views) ?></div>
                    <div class="stat-label">Total Views</div>
                    <div class="stat-sub">Product impressions</div>
                </div>
                <div class="stat-card animate-in delay-2">
                    <div class="stat-top">
                        <div class="stat-icon-box"><i class="ph-fill ph-users-three"></i></div>
                        <span class="stat-trend neutral"><i class="ph ph-minus"></i> --</span>
                    </div>
                    <div class="stat-value"><?= number_format($total_leads) ?></div>
                    <div class="stat-label">Total Leads</div>
                    <div class="stat-sub">Interested farmers</div>
                </div>
                <div class="stat-card animate-in delay-3">
                    <div class="stat-top">
                        <div class="stat-icon-box"><i class="ph-fill ph-cursor-click"></i></div>
                        <span class="stat-trend <?= $ctr > 5 ? 'up' : ($ctr > 0 ? 'neutral' : 'down') ?>">
                            <i class="ph ph-<?= $ctr > 5 ? 'arrow-up' : ($ctr > 0 ? 'minus' : 'arrow-down') ?>"></i>
                            <?= $ctr ?>%
                        </span>
                    </div>
                    <div class="stat-value"><?= $ctr ?>%</div>
                    <div class="stat-label">Click-Through Rate</div>
                    <div class="stat-sub">Views to clicks</div>
                </div>
                <div class="stat-card animate-in delay-4">
                    <div class="stat-top">
                        <div class="stat-icon-box"><i class="ph-fill ph-chart-pie-slice"></i></div>
                        <span class="stat-trend <?= $conversion_rate > 10 ? 'up' : ($conversion_rate > 0 ? 'neutral' : 'down') ?>">
                            <i class="ph ph-<?= $conversion_rate > 10 ? 'arrow-up' : ($conversion_rate > 0 ? 'minus' : 'arrow-down') ?>"></i>
                            <?= $conversion_rate ?>%
                        </span>
                    </div>
                    <div class="stat-value"><?= $conversion_rate ?>%</div>
                    <div class="stat-label">Conversion Rate</div>
                    <div class="stat-sub">Clicks to leads</div>
                </div>
            </div>

            <!-- Charts Row -->
            <div class="charts-row animate-in delay-5">
                <div class="chart-card">
                    <div class="chart-header">
                        <div>
                            <div class="chart-title">
                                <span class="chart-title-dot"></span>
                                Lead Trend
                            </div>
                            <div class="chart-subtitle">Daily enquiries over selected period</div>
                        </div>
                    </div>
                    <div class="chart-body">
                        <canvas id="trendChart"></canvas>
                    </div>
                </div>
                <div class="chart-card">
                    <div class="chart-header">
                        <div>
                            <div class="chart-title">
                                <span class="chart-title-dot" style="background: var(--blue);"></span>
                                Top Products
                            </div>
                            <div class="chart-subtitle">By enquiry volume</div>
                        </div>
                    </div>
                    <div class="chart-body" style="display:flex; align-items:center; justify-content:center;">
                        <canvas id="prodChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- Conversion Funnel -->
            <div class="funnel-card animate-in delay-6">
                <div class="chart-title" style="margin-bottom: 4px;">
                    <span class="chart-title-dot" style="background: var(--purple);"></span>
                    Conversion Funnel
                </div>
                <div class="chart-subtitle">Lead journey from interest to purchase</div>
                <div class="funnel-stages">
                    <div class="funnel-stage">
                        <div class="funnel-stage-value" style="color: var(--blue);"><?= number_format($total_views) ?></div>
                        <div class="funnel-stage-label">Views</div>
                        <div class="funnel-stage-bar" style="background: linear-gradient(90deg, #3b82f6, #60a5fa);"></div>
                    </div>
                    <div class="funnel-arrow"><i class="ph ph-caret-right"></i></div>
                    <div class="funnel-stage">
                        <div class="funnel-stage-value" style="color: var(--orange);"><?= number_format($total_clicks) ?></div>
                        <div class="funnel-stage-label">Clicks</div>
                        <div class="funnel-stage-bar" style="background: linear-gradient(90deg, #f97316, #fb923c);"></div>
                    </div>
                    <div class="funnel-arrow"><i class="ph ph-caret-right"></i></div>
                    <div class="funnel-stage">
                        <div class="funnel-stage-value" style="color: var(--primary);"><?= number_format($total_leads) ?></div>
                        <div class="funnel-stage-label">Leads</div>
                        <div class="funnel-stage-bar" style="background: linear-gradient(90deg, #059669, #10b981);"></div>
                    </div>
                    <div class="funnel-arrow"><i class="ph ph-caret-right"></i></div>
                    <div class="funnel-stage">
                        <div class="funnel-stage-value" style="color: var(--purple);"><?= number_format($converted_leads) ?></div>
                        <div class="funnel-stage-label">Converted</div>
                        <div class="funnel-stage-bar" style="background: linear-gradient(90deg, #8b5cf6, #a78bfa);"></div>
                    </div>
                </div>
            </div>

            <!-- Live Feed Section -->
            <div id="live-feed">
                <div class="section-header">
                    <div class="section-title">
                        <div class="live-dot"></div>
                        Live Visitor Feed
                    </div>
                </div>

                <div class="live-feed">
                    <?php if($live_feed->num_rows > 0): ?>
                        <?php while($feed = $live_feed->fetch_assoc()): 
                            $is_click = ($feed['interaction_type'] == 'click');
                            $action_text = $is_click ? "clicked on" : "viewed";
                            $icon = $is_click ? "ph-cursor-click" : "ph-eye";
                            $time_ago = time_elapsed_string($feed['created_at']);
                        ?>
                        <div class="feed-item <?= $is_click ? 'click-type' : 'view-type' ?>">
                            <img src="<?= $feed['profile_image_url'] ?: 'https://ui-avatars.com/api/?name='.urlencode($feed['farmer_name']).'&background=e2e8f0&color=475569&bold=true&size=80' ?>" 
                                 class="feed-avatar" alt="<?= htmlspecialchars($feed['farmer_name']) ?>">
                            <div class="feed-content">
                                <div class="feed-text">
                                    <strong><?= htmlspecialchars($feed['farmer_name']) ?></strong>
                                    <span style="color:var(--text-tertiary)">from <?= htmlspecialchars($feed['village']) ?></span>
                                    <span class="feed-action-label <?= $is_click ? 'click' : 'view' ?>">
                                        <i class="ph <?= $icon ?>"></i> <?= $action_text ?>
                                    </span>
                                    <strong><?= htmlspecialchars($feed['product_name']) ?></strong>
                                </div>
                                <div class="feed-time"><?= $time_ago ?></div>
                            </div>
                            <img src="<?= htmlspecialchars($feed['image_url_1']) ?>" class="feed-product-img" alt="Product">
                        </div>
                        <?php endwhile; ?>
                    <?php else: ?>
                        <div class="empty-state" style="background: var(--surface); border-radius: var(--radius-md); border: 1px solid var(--border);">
                            <i class="ph ph-broadcast"></i>
                            <div class="empty-state-text">No recent activity</div>
                            <div class="empty-state-sub">Visitor interactions will appear here in real-time</div>
                        </div>
                    <?php endif; ?>
                </div>
            </div>

            <!-- Enquiries Section -->
            <div id="enquiries">
                <div class="section-header">
                    <div class="section-title">
                        <div class="section-title-icon" style="background: var(--primary-lighter); color: var(--primary);">
                            <i class="ph-fill ph-address-book"></i>
                        </div>
                        Enquiries
                        <span class="trend-pill"><?= number_format($total_rows) ?> total</span>
                    </div>
                </div>

                <div class="table-card">
                    <table>
                        <thead>
                            <tr>
                                <th>Date</th>
                                <th>Farmer</th>
                                <th>Product</th>
                                <th>Status</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if($leads->num_rows > 0): ?>
                                <?php while($lead = $leads->fetch_assoc()): 
                                    $statusClass = 'status-' . strtolower($lead['status']);
                                ?>
                                <tr>
                                    <td>
                                        <div class="date-cell"><?= date('M d, Y', strtotime($lead['enquiry_date'])) ?></div>
                                        <div class="date-cell-time"><?= date('h:i A', strtotime($lead['enquiry_date'])) ?></div>
                                    </td>
                                    <td>
                                        <div class="user-cell">
                                            <img src="<?= $lead['profile_image_url'] ?: 'https://ui-avatars.com/api/?name='.urlencode($lead['farmer_name']).'&background=e2e8f0&color=475569&bold=true&size=80' ?>" class="user-avatar" alt="">
                                            <div>
                                                <div class="user-info-name"><?= htmlspecialchars($lead['farmer_name']) ?></div>
                                                <div class="user-info-sub"><?= htmlspecialchars($lead['village']) ?>, <?= htmlspecialchars($lead['district']) ?></div>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <div class="product-cell">
                                            <img src="<?= htmlspecialchars($lead['image_url_1']) ?>" class="product-thumb" alt="">
                                            <span class="product-name-text"><?= htmlspecialchars($lead['product_name']) ?></span>
                                        </div>
                                    </td>
                                    <td>
                                        <select class="status-select <?= $statusClass ?>" onchange="updateStatus(this, <?= $lead['enquiry_id'] ?>)">
                                            <option value="Interested" <?= $lead['status']=='Interested'?'selected':'' ?>>Interested</option>
                                            <option value="Contacted" <?= $lead['status']=='Contacted'?'selected':'' ?>>Contacted</option>
                                            <option value="Purchased" <?= $lead['status']=='Purchased'?'selected':'' ?>>Purchased</option>
                                        </select>
                                    </td>
                                    <td>
                                        <a href="tel:<?= $lead['phone_number'] ?>" class="call-btn">
                                            <i class="ph-fill ph-phone"></i> Call
                                        </a>
                                    </td>
                                </tr>
                                <?php endwhile; ?>
                            <?php else: ?>
                                <tr>
                                    <td colspan="5">
                                        <div class="empty-state">
                                            <i class="ph ph-address-book"></i>
                                            <div class="empty-state-text">No enquiries found</div>
                                            <div class="empty-state-sub">Try adjusting your filters to see more results</div>
                                        </div>
                                    </td>
                                </tr>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>

                <?php if($total_pages > 1): ?>
                <div class="pagination">
                    <?php $q = $_GET; ?>
                    <?php if($page > 1): $q['page'] = $page-1; ?>
                        <a href="?<?= http_build_query($q) ?>" class="page-btn nav-arrow">
                            <i class="ph ph-caret-left"></i> Prev
                        </a>
                    <?php endif; ?>
                    <?php for($i=1; $i<=$total_pages; $i++): $q['page'] = $i; ?>
                        <a href="?<?= http_build_query($q) ?>" class="page-btn <?= $i==$page ? 'active':'' ?>"><?= $i ?></a>
                    <?php endfor; ?>
                    <?php if($page < $total_pages): $q['page'] = $page+1; ?>
                        <a href="?<?= http_build_query($q) ?>" class="page-btn nav-arrow">
                            Next <i class="ph ph-caret-right"></i>
                        </a>
                    <?php endif; ?>
                </div>
                <?php endif; ?>
            </div>

            <!-- Products Section -->
            <div id="products">
                <div class="section-header">
                    <div class="section-title">
                        <div class="section-title-icon" style="background: var(--blue-light); color: var(--blue);">
                            <i class="ph-fill ph-package"></i>
                        </div>
                        Product Catalog
                    </div>
                    <button class="add-product-btn" onclick="openModal('add')">
                        <i class="ph ph-plus-circle"></i> Add Product
                    </button>
                </div>

                <div class="table-card">
                    <table>
                        <thead>
                            <tr>
                                <th>Product</th>
                                <th>Status</th>
                                <th>Views <span class="trend-pill">All Time</span></th>
                                <th>Clicks <span class="trend-pill">All Time</span></th>
                                <th style="text-align:center;">Edit</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php while($prod = $products_table->fetch_assoc()): ?>
                            <tr class="prod-row <?= ($prod['is_active'] == 0) ? 'hidden-product' : '' ?>">
                                <td>
                                    <div class="user-cell">
                                        <img src="<?= htmlspecialchars($prod['image_url_1']) ?>" class="product-thumb" style="width:42px;height:42px;border-radius:var(--radius-sm);" alt="">
                                        <div>
                                            <div class="user-info-name"><?= htmlspecialchars($prod['product_name']) ?></div>
                                            <div class="category-badge"><?= htmlspecialchars($prod['category']) ?></div>
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <?php if($prod['is_active'] == 0): ?>
                                        <span class="badge badge-hidden">Hidden</span>
                                    <?php elseif($prod['in_stock'] == 1): ?>
                                        <span class="badge badge-stock">In Stock</span>
                                    <?php else: ?>
                                        <span class="badge badge-out">Out of Stock</span>
                                    <?php endif; ?>
                                </td>
                                <td class="product-views-col"><?= number_format($prod['total_views']) ?></td>
                                <td class="product-clicks-col"><?= number_format($prod['total_clicks']) ?></td>
                                <td style="text-align:center;">
                                    <div class="edit-btn" onclick='openModal("edit", <?= json_encode($prod) ?>)' title="Edit product">
                                        <i class="ph ph-pencil-simple"></i>
                                    </div>
                                </td>
                            </tr>
                            <?php endwhile; ?>
                        </tbody>
                    </table>
                </div>
            </div>

        </div>
    </main>

    <!-- Product Modal -->
    <div id="productModal" class="modal-overlay">
        <div class="modal-container">
            <div class="modal-header">
                <h2 id="modalTitle" class="modal-title">List New Product</h2>
                <button class="modal-close" onclick="closeModal()">
                    <i class="ph ph-x"></i>
                </button>
            </div>
            <div class="modal-body">
                <form method="POST" enctype="multipart/form-data">
                    <input type="hidden" name="action" id="formAction" value="add_product">
                    <input type="hidden" name="product_id" id="prodId">
                    <input type="hidden" name="existing_image_1" id="existImg">
                    <input type="hidden" name="existing_video" id="existVid">

                    <!-- Toggle Bar -->
                    <div class="toggle-bar">
                        <div class="toggle-item">
                            <label class="switch">
                                <input type="checkbox" name="in_stock" id="pStock" checked>
                                <span class="slider"></span>
                            </label>
                            <span class="toggle-label-text">In Stock</span>
                        </div>
                        <div class="toggle-item">
                            <label class="switch">
                                <input type="checkbox" name="is_active" id="pActive" checked>
                                <span class="slider"></span>
                            </label>
                            <span class="toggle-label-text">Visible</span>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Product Name</label>
                        <input type="text" name="product_name" id="pName" class="form-input" placeholder="Enter product name" required>
                    </div>

                    <div class="form-row">
                        <div class="form-group">
                            <label class="form-label">Price (&#8377;)</label>
                            <input type="number" name="price" id="pPrice" class="form-input" placeholder="0.00" required>
                        </div>
                        <div class="form-group">
                            <label class="form-label">MRP (&#8377;)</label>
                            <input type="number" name="mrp" id="pMrp" class="form-input" placeholder="Optional">
                        </div>
                    </div>

                    <div class="form-row">
                        <div class="form-group">
                            <label class="form-label">Category</label>
                            <select name="category" id="pCat" class="form-input">
                                <option value="మెషీన్">Machinery</option>
                                <option value="పనిముట్లు">Tools</option>
                                <option value="విత్తనాలు/ఎరువులు">Inputs</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label class="form-label">Region</label>
                            <select name="region_id" id="pRegion" class="form-input">
                                <option value="">All India</option>
                                <?php 
                                $regions->data_seek(0); 
                                while($reg = $regions->fetch_assoc()): ?>
                                    <option value="<?= $reg['id'] ?>"><?= htmlspecialchars($reg['region_name']) ?></option>
                                <?php endwhile; ?>
                            </select>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Product Image</label>
                        <div class="file-upload-zone" onclick="document.getElementById('imgInput').click()">
                            <i class="ph ph-image"></i>
                            <div class="file-upload-text" id="imgPreviewText">Click to upload image</div>
                        </div>
                        <input type="file" name="image_file" id="imgInput" accept="image/*" style="display:none;" onchange="previewFile(this, 'imgPreviewText')">
                    </div>

                    <div class="form-group">
                        <label class="form-label">Product Video <span style="color:var(--text-tertiary);font-weight:400;">(Optional)</span></label>
                        <div class="file-upload-zone" onclick="document.getElementById('vidInput').click()">
                            <i class="ph ph-video-camera" style="color: var(--blue);"></i>
                            <div class="file-upload-text" id="vidPreviewText">Click to upload video</div>
                        </div>
                        <input type="file" name="video_file" id="vidInput" accept="video/*" style="display:none;" onchange="previewFile(this, 'vidPreviewText')">
                    </div>

                    <div class="form-group">
                        <label class="form-label">Description</label>
                        <textarea name="description" id="pDesc" class="form-input" rows="3" placeholder="Describe your product..." required></textarea>
                    </div>

                    <button type="submit" id="submitBtn" class="submit-btn">
                        <i class="ph ph-check-circle"></i>
                        <span id="submitBtnText">List Product</span>
                    </button>
                </form>
            </div>
        </div>
    </div>

    <script>
        // ===== CHART.JS CONFIG =====
        const fontConfig = { family: 'Poppins', size: 11, weight: '500' };
        const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        const gridColor = isDark ? 'rgba(148, 163, 184, 0.1)' : 'rgba(226, 232, 240, 0.8)';
        const tickColor = isDark ? '#94a3b8' : '#94a3b8';

        // Lead Trend Chart
        const trendCtx = document.getElementById('trendChart').getContext('2d');
        const trendGradient = trendCtx.createLinearGradient(0, 0, 0, 260);
        trendGradient.addColorStop(0, 'rgba(5, 150, 105, 0.15)');
        trendGradient.addColorStop(1, 'rgba(5, 150, 105, 0.0)');

        new Chart(trendCtx, {
            type: 'line',
            data: {
                labels: <?= json_encode($chart_labels) ?>,
                datasets: [{
                    label: 'Leads',
                    data: <?= json_encode($chart_values) ?>,
                    borderColor: '#059669',
                    backgroundColor: trendGradient,
                    tension: 0.4,
                    fill: true,
                    pointRadius: 0,
                    pointHoverRadius: 6,
                    pointHoverBackgroundColor: '#059669',
                    pointHoverBorderColor: '#ffffff',
                    pointHoverBorderWidth: 3,
                    borderWidth: 2.5
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        titleFont: { family: 'Poppins', size: 12, weight: '600' },
                        bodyFont: { family: 'Poppins', size: 11 },
                        padding: 12,
                        cornerRadius: 10,
                        displayColors: false,
                        callbacks: {
                            title: (items) => items[0].label,
                            label: (item) => `${item.raw} leads`
                        }
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { font: fontConfig, color: tickColor, maxRotation: 0, maxTicksLimit: 8 },
                        border: { display: false }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: gridColor, drawBorder: false },
                        ticks: { font: fontConfig, color: tickColor, padding: 8 },
                        border: { display: false }
                    }
                }
            }
        });

        // Product Doughnut Chart
        const pieColors = ['#3b82f6', '#059669', '#f97316', '#8b5cf6', '#ef4444'];
        new Chart(document.getElementById('prodChart'), {
            type: 'doughnut',
            data: {
                labels: <?= json_encode($pie_labels) ?>,
                datasets: [{
                    data: <?= json_encode($pie_data) ?>,
                    backgroundColor: pieColors,
                    borderWidth: 0,
                    hoverOffset: 6,
                    borderRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '72%',
                plugins: {
                    legend: {
                        position: 'right',
                        labels: {
                            font: { family: 'Poppins', size: 11, weight: '500' },
                            usePointStyle: true,
                            pointStyle: 'circle',
                            padding: 16,
                            color: tickColor
                        }
                    },
                    tooltip: {
                        backgroundColor: '#0f172a',
                        titleFont: { family: 'Poppins', size: 12, weight: '600' },
                        bodyFont: { family: 'Poppins', size: 11 },
                        padding: 12,
                        cornerRadius: 10
                    }
                }
            }
        });

        // ===== STATUS UPDATE =====
        function updateStatus(select, id) {
            const originalValue = select.dataset.original || select.value;
            select.style.opacity = '0.5';
            select.style.pointerEvents = 'none';
            
            const fd = new FormData();
            fd.append('ajax_action', 'update_status');
            fd.append('enquiry_id', id);
            fd.append('status', select.value);
            
            fetch('', { method: 'POST', body: fd })
                .then(r => r.text())
                .then(res => {
                    select.style.opacity = '1';
                    select.style.pointerEvents = 'auto';
                    
                    // Update styling
                    select.className = 'status-select status-' + select.value.toLowerCase();
                    
                    if (res === 'success') {
                        showToast('Status updated successfully', true);
                        select.dataset.original = select.value;
                    } else {
                        showToast('Failed to update status', false);
                        select.value = originalValue;
                    }
                })
                .catch(() => {
                    select.style.opacity = '1';
                    select.style.pointerEvents = 'auto';
                    showToast('Network error', false);
                    select.value = originalValue;
                });
        }

        // ===== TOAST =====
        function showToast(message, isSuccess) {
            const toast = document.getElementById('toast');
            const toastMsg = document.getElementById('toastMsg');
            toastMsg.innerText = message;
            toast.className = 'toast show ' + (isSuccess ? 'toast-success' : 'toast-error');
            toast.querySelector('i').className = isSuccess ? 'ph ph-check-circle' : 'ph ph-warning-circle';
            toast.querySelector('i').style.color = isSuccess ? '#34d399' : '#f87171';
            setTimeout(() => { toast.classList.remove('show'); }, 3500);
        }

        // ===== MODAL =====
        function openModal(mode, product = null) {
            const modal = document.getElementById('productModal');
            modal.classList.add('active');
            document.body.style.overflow = 'hidden';
            
            // Reset form
            const form = modal.querySelector('form');
            form.reset();
            
            const title = document.getElementById('modalTitle');
            const action = document.getElementById('formAction');
            const btnText = document.getElementById('submitBtnText');
            
            document.getElementById('pStock').checked = true;
            document.getElementById('pActive').checked = true;
            document.getElementById('imgPreviewText').innerText = 'Click to upload image';
            document.getElementById('vidPreviewText').innerText = 'Click to upload video';

            if (mode === 'edit' && product) {
                title.innerText = 'Edit Product';
                action.value = 'edit_product';
                btnText.innerText = 'Update Product';
                document.getElementById('prodId').value = product.product_id;
                document.getElementById('pName').value = product.product_name;
                document.getElementById('pPrice').value = product.price;
                document.getElementById('pMrp').value = product.mrp;
                document.getElementById('pCat').value = product.category;
                document.getElementById('pRegion').value = product.region_id || '';
                document.getElementById('pDesc').value = product.product_description;
                document.getElementById('existImg').value = product.image_url_1;
                document.getElementById('existVid').value = product.product_video_url;
                document.getElementById('pStock').checked = (product.in_stock == 1);
                document.getElementById('pActive').checked = (product.is_active == 1);
                if (product.image_url_1) document.getElementById('imgPreviewText').innerText = 'Current image selected';
            } else {
                title.innerText = 'List New Product';
                action.value = 'add_product';
                btnText.innerText = 'List Product';
            }
        }

        function closeModal() {
            document.getElementById('productModal').classList.remove('active');
            document.body.style.overflow = '';
        }

        function previewFile(input, textId) {
            if (input.files[0]) {
                const el = document.getElementById(textId);
                el.innerText = input.files[0].name;
                el.style.color = 'var(--primary)';
                el.style.fontWeight = '600';
            }
        }

        // Close modal on overlay click
        document.getElementById('productModal').addEventListener('click', function(e) {
            if (e.target === this) closeModal();
        });

        // Close modal on Escape key
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') closeModal();
        });

        // ===== SIDEBAR =====
        function toggleSidebar() {
            const sidebar = document.getElementById('sidebar');
            const overlay = document.getElementById('sidebarOverlay');
            sidebar.classList.toggle('open');
            overlay.classList.toggle('active');
        }

        function scrollToSection(id) {
            const el = document.getElementById(id);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
            // Update active nav
            document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
            event.currentTarget.classList.add('active');
            // Close sidebar on mobile
            if (window.innerWidth <= 768) toggleSidebar();
        }

        // ===== THEME TOGGLE =====
        function toggleTheme() {
            const html = document.documentElement;
            const current = html.getAttribute('data-theme');
            const next = current === 'dark' ? 'light' : 'dark';
            html.setAttribute('data-theme', next);
            localStorage.setItem('theme', next);
            updateThemeUI(next);
        }

        function updateThemeUI(theme) {
            const icon = document.querySelector('#themeBtn i');
            const label = document.getElementById('themeLabel');
            if (theme === 'dark') {
                icon.className = 'ph ph-sun';
                label.textContent = 'Light Mode';
            } else {
                icon.className = 'ph ph-moon';
                label.textContent = 'Dark Mode';
            }
        }

        // Load saved theme
        const savedTheme = localStorage.getItem('theme') || 'light';
        document.documentElement.setAttribute('data-theme', savedTheme);
        updateThemeUI(savedTheme);

        // ===== INTERSECTION OBSERVER FOR ANIMATIONS =====
        const observerOptions = { threshold: 0.1, rootMargin: '0px 0px -50px 0px' };
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                }
            });
        }, observerOptions);

        document.querySelectorAll('.stat-card, .chart-card, .funnel-card, .table-card').forEach(el => {
            observer.observe(el);
        });
    </script>
</body>
</html>
