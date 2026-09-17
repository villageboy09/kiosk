<?php
// ############ CROPSYNC MANAGER DASHBOARD - MULTI CLIENT CODE FIXED ############

session_name('CROPSYNC_CEO_SESSION');
session_start();

if (!isset($_SESSION['admin_id']) || !isset($_SESSION['allowed_client_codes'])) {
    header("Location: chc_manager_login.php");
    exit;
}

if (isset($_GET['switch_client'])) {
    $new_code = $_GET['switch_client'];
    if (in_array($new_code, $_SESSION['allowed_client_codes'] ?? []) || $new_code === 'ALL') {
        $_SESSION['current_client_code'] = $new_code;
        $_SESSION['admin_scope'] = $new_code;
    }

    // Preserve start, end and other important params
    $query = [];
    if (!empty($_GET['start'])) $query['start'] = $_GET['start'];
    if (!empty($_GET['end']))   $query['end']   = $_GET['end'];

    $redirect = strtok($_SERVER["REQUEST_URI"], '?') . '?' . http_build_query($query);
    header("Location: " . $redirect);
    exit;
}

$allowed_codes = $_SESSION['allowed_client_codes'] ?? ['ALL'];
$current_client_code = $_SESSION['current_client_code'] ?? $allowed_codes[0];
$admin_scope = $current_client_code;

if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

if (isset($_GET['logout'])) {
    $_SESSION = array();
    if (ini_get("session.use_cookies")) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $params["path"], $params["domain"], $params["secure"], $params["httponly"]);
    }
    session_destroy();
    header("Location: chc_manager_login.php");
    exit;
}

date_default_timezone_set('Asia/Kolkata');
error_reporting(E_ALL);
ini_set('display_errors', 0);

if (file_exists('config.php')) { include 'config.php'; }
if (!isset($conn)) {
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    try { $conn = new mysqli("localhost", "root", "", "cropsync_db"); }
    catch (Exception $e) { die(json_encode(['error' => 'Database connection failed.'])); }
}

// ================================================================= DATE HANDLING - DEFAULT TO ALL TIME
$start_date = isset($_GET['start']) && !empty($_GET['start']) 
    ? preg_replace('/[^0-9\-]/', '', $_GET['start']) 
    : '2000-01-01';  // All Time default

$end_date   = isset($_GET['end']) && !empty($_GET['end']) 
    ? preg_replace('/[^0-9\-]/', '', $_GET['end']) 
    : date('Y-m-d'); // Today

$today      = date('Y-m-d');
$isAllTime  = ($start_date === '2000-01-01' && $end_date === date('Y-m-d'));

// ====================== MAIN WHERE CLAUSE (CRITICAL FIX) ======================
$where_clause = "1=1";
if ($admin_scope !== 'ALL') {
    $where_clause .= " AND u.client_code = '" . $conn->real_escape_string($admin_scope) . "'";
}

// ================================================================= EXPORT EXCEL REPORT
if (isset($_GET['export']) && $_GET['export'] === 'excel') {
    $range = $_GET['range'] ?? 'current';
    $exp_start = $start_date;
    $exp_end = $end_date;

    if ($range === 'last_week') {
        $exp_start = date('Y-m-d', strtotime('-7 days'));
        $exp_end = date('Y-m-d');
    } elseif ($range === 'last_month') {
        $exp_start = date('Y-m-d', strtotime('-30 days'));
        $exp_end = date('Y-m-d');
    } elseif ($range === 'overall') {
        $exp_start = '2000-01-01'; // Far past date to capture all
        $exp_end = date('Y-m-d');
    }

    // Fetch Overview KPIs for export
    $kpi_res = $conn->query("SELECT COUNT(*) as total_bookings, SUM(CASE WHEN booking_status = 'Completed' THEN total_cost ELSE 0 END) as revenue_realized, SUM(CASE WHEN booking_status IN ('Pending', 'Slot Booked', 'Confirmed') THEN total_cost ELSE 0 END) as revenue_pipeline, COUNT(DISTINCT cb.user_id) as active_farmers FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) WHERE $where_clause AND cb.service_date BETWEEN '$exp_start' AND '$exp_end'");
    $kpi_exp = $kpi_res ? $kpi_res->fetch_assoc() : [];

    // Fetch Equipment Breakdown for export
    $eq_stats_res = $conn->query("SELECT cb.equipment_type, COUNT(*) as total_bookings, SUM(CASE WHEN cb.booking_status = 'Completed' THEN cb.total_cost ELSE 0 END) as total_revenue FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) WHERE $where_clause AND cb.service_date BETWEEN '$exp_start' AND '$exp_end' GROUP BY cb.equipment_type ORDER BY total_bookings DESC");

    // Fetch Bookings by Crop for export
    $crop_stats_exp_res = $conn->query("
        SELECT COALESCE(NULLIF(cb.crop_type, ''), 'Unspecified') as crop,
               COUNT(*) as total_bookings
        FROM chc_bookings cb
        LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number)
        WHERE $where_clause AND cb.service_date BETWEEN '$exp_start' AND '$exp_end'
        GROUP BY crop
        ORDER BY total_bookings DESC
    ");

    // Fetch Farmer Demographics for export
    $farmer_cat_exp_res = $conn->query("
        SELECT 
            CASE 
                WHEN cb.land_size_acres <= 2.00 THEN 'Marginal (≤ 2 Acres)'
                WHEN cb.land_size_acres <= 4.00 THEN 'Small (2.1 - 4 Acres)'
                ELSE 'Large (> 4 Acres)'
            END as category,
            COUNT(*) as total_bookings
        FROM chc_bookings cb
        LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number)
        WHERE $where_clause AND cb.service_date BETWEEN '$exp_start' AND '$exp_end'
        GROUP BY category
        ORDER BY CASE 
            WHEN category LIKE 'Marginal%' THEN 1 
            WHEN category LIKE 'Small%' THEN 2 
            ELSE 3 END
    ");

    // Output Headers to force CSV download
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename=CropSync_Overview_Report_' . date('Y_m_d') . '.csv');
    
    $output = fopen('php://output', 'w');

    // Section 1: Metadata
    fputcsv($output, ['CropSync Overview Report']);
    fputcsv($output, ['Generated On:', date('Y-m-d H:i:s')]);
    fputcsv($output, ['Date Range:', "$exp_start to $exp_end"]);
    fputcsv($output, []);

    // Section 2: KPIs
    fputcsv($output, ['KEY PERFORMANCE INDICATORS']);
    fputcsv($output, ['Realized Revenue (Rs)', 'Pipeline Revenue (Rs)', 'Total Bookings', 'Active Farmers']);
    fputcsv($output, [
        $kpi_exp['revenue_realized'] ?? 0, 
        $kpi_exp['revenue_pipeline'] ?? 0, 
        $kpi_exp['total_bookings'] ?? 0, 
        $kpi_exp['active_farmers'] ?? 0
    ]);
    fputcsv($output, []);

    // Section 3: Equipment Data
    fputcsv($output, ['EQUIPMENT BREAKDOWN']);
    fputcsv($output, ['Equipment Type', 'Total Bookings', 'Realized Revenue (Rs)']);
    
    if ($eq_stats_res) {
        while ($row = $eq_stats_res->fetch_assoc()) {
            fputcsv($output, [
                $row['equipment_type'], 
                $row['total_bookings'], 
                $row['total_revenue'] ?? 0
            ]);
        }
    }
    fputcsv($output, []);

    // Section 4: Bookings by Crop
    fputcsv($output, ['BOOKINGS BY CROP']);
    fputcsv($output, ['Crop Type', 'Total Requests']);
    if ($crop_stats_exp_res) {
        while ($row = $crop_stats_exp_res->fetch_assoc()) {
            fputcsv($output, [
                $row['crop'],
                $row['total_bookings']
            ]);
        }
    }
    fputcsv($output, []);

    // Section 5: Farmer Demographics
    fputcsv($output, ['FARMER DEMOGRAPHICS']);
    fputcsv($output, ['Land Holding Category', 'Total Requests']);
    if ($farmer_cat_exp_res) {
        while ($row = $farmer_cat_exp_res->fetch_assoc()) {
            fputcsv($output, [
                $row['category'],
                $row['total_bookings']
            ]);
        }
    }

    fclose($output);
    exit;
}

// ================================================================= AJAX (VIEW ONLY)
if (isset($_POST['ajax_action'])) {
    header('Content-Type: application/json');
    if (!isset($_POST['csrf_token']) || !hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
        echo json_encode(['success' => false, 'error' => 'Invalid CSRF token.']); exit;
    }
    $action = $_POST['ajax_action'];

    // FETCH FARMERS WHO BOOKED SPECIFIC EQUIPMENT (READ ONLY)
    if ($action === 'get_equipment_farmers') {
        try {
            $eq_type = $_POST['equipment_type'] ?? '';
            $sd = preg_replace('/[^0-9\-]/', '', $_POST['start_date'] ?? date('Y-m-01'));
            $ed = preg_replace('/[^0-9\-]/', '', $_POST['end_date'] ?? date('Y-m-t'));
            $cc = $_POST['client_code'] ?? $admin_scope;

            $wc = "cb.service_date BETWEEN ? AND ? AND cb.equipment_type = ?";
            $types = "sss";
            $params = [$sd, $ed, $eq_type];

            if ($cc !== 'ALL') {
                $wc .= " AND u.client_code = ?";
                $types .= "s";
                $params[] = $cc;
            }

            $stmt = $conn->prepare("SELECT cb.booking_id, cb.crop_type, cb.land_size_acres, u.user_id, u.name, u.village, u.profile_image_url, u.phone_number
                                    FROM chc_bookings cb
                                    LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number)
                                    WHERE $wc
                                    ORDER BY cb.service_date DESC");
            $stmt->bind_param($types, ...$params);
            $stmt->execute();
            $res = $stmt->get_result();

            $farmers = [];
            while ($row = $res->fetch_assoc()) { $farmers[] = $row; }
            echo json_encode(['success' => true, 'farmers' => $farmers]);
        } catch (Exception $e) {
            echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        }
        exit;
    }

    // FETCH FARMER PROFILE AND RECENT BOOKINGS (READ ONLY)
    if ($action === 'get_farmer_details') {
        $uid = $_POST['user_id'] ?? '';
        $stmt1 = $conn->prepare("SELECT * FROM users WHERE user_id = ?");
        $stmt1->bind_param("s", $uid);
        $stmt1->execute();
        $user = $stmt1->get_result()->fetch_assoc();

        $stmt2 = $conn->prepare("SELECT equipment_type, booking_status, total_cost, service_date FROM chc_bookings WHERE user_id = ? ORDER BY service_date DESC LIMIT 5");
        $stmt2->bind_param("s", $uid);
        $stmt2->execute();
        $hist_res = $stmt2->get_result();
        $history = [];
        while ($r = $hist_res->fetch_assoc()) { $history[] = $r; }

        echo json_encode(['user' => $user, 'history' => $history]);
        exit;
    }

    // FETCH ORDER/TASK DETAILS (READ ONLY)
    if ($action === 'get_task_details') {
        $booking_id = $_POST['booking_id'] ?? '';
        $stmt = $conn->prepare("SELECT cb.*, u.name as farmer_name, u.phone_number as farmer_phone, u.village as farmer_village, op.name as op_name, op.phone_number as op_phone, ctc.status as task_status, ctc.breakdown_reason, ctc.breakdown_start, ctc.breakdown_end, ctc.work_start_time, ctc.work_end_time, ctc.measured_qty, ctc.measured_unit, ctc.final_amount, ctc.applied_rate, ctc.start_reading, ctc.end_reading, ctc.transit_start_time, ctc.transit_end_time, ctc.return_time, ctc.cumulative_pause FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) LEFT JOIN chc_operators op ON cb.assigned_operator_id = op.operator_id LEFT JOIN chc_task_completions ctc ON cb.booking_id = ctc.booking_id WHERE cb.booking_id = ?");
        $stmt->bind_param("s", $booking_id);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($row = $res->fetch_assoc()) {
            $row['assigned_at'] = isset($row['updated_at']) ? date('d M Y, h:i A', strtotime($row['updated_at'])) : date('d M Y', strtotime($row['service_date']));
            $row['work_start_fmt'] = !empty($row['work_start_time']) ? date('d M Y, h:i A', strtotime($row['work_start_time'])) : null;
            $row['work_end_fmt'] = !empty($row['work_end_time']) ? date('d M Y, h:i A', strtotime($row['work_end_time'])) : null;
            $row['transit_start_fmt'] = !empty($row['transit_start_time']) ? date('d M Y, h:i A', strtotime($row['transit_start_time'])) : null;
            $row['return_fmt'] = !empty($row['return_time']) ? date('d M Y, h:i A', strtotime($row['return_time'])) : null;
            $pause = intval($row['cumulative_pause'] ?? 0);
            $row['pause_fmt'] = $pause > 0 ? ((floor($pause / 60) > 0 ? floor($pause / 60) . 'm ' : '') . ($pause % 60) . 's') : '0s';
            echo json_encode(['success' => true, 'data' => $row]);
        } else {
            echo json_encode(['success' => false, 'error' => 'Booking not found']);
        }
        exit;
    }

    // GET ONLY CURRENTLY WORKING OPERATORS (READ ONLY)
    if ($action === 'get_current_assignments') {
        $clientCode = $admin_scope ?? 'ALL';
        try {
            $sql = "
                SELECT
                    o.operator_id,
                    o.name AS operator_name,
                    o.phone_number,
                    o.base_village,
                    o.availability,
                    o.skills,
                    o.current_booking_id,
                    o.jobs_completed,
                    b.booking_id,
                    b.equipment_type,
                    b.service_date,
                    b.booking_status,
                    b.assignment_status,
                    b.crop_type,
                    b.land_size_acres,
                    u.name AS farmer_name,
                    u.village AS farmer_village
                FROM chc_operators o
                JOIN chc_bookings b ON o.current_booking_id = b.booking_id
                LEFT JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number)
                WHERE o.status = 'Active'
                  AND o.current_booking_id IS NOT NULL
                  AND b.booking_status NOT IN ('Completed', 'Cancelled')
                  AND (b.assignment_status = 'In Progress' OR o.availability = 'Busy')
            ";

            if ($clientCode !== 'ALL') {
                $sql .= " AND o.client_code = ?";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param("s", $clientCode);
            } else {
                $stmt = $conn->prepare($sql);
            }

            $stmt->execute();
            $result = $stmt->get_result();
            $assignments = [];
            while ($row = $result->fetch_assoc()) {
                $row['is_working'] = true;
                $assignments[] = $row;
            }

            echo json_encode(['success' => true, 'assignments' => $assignments, 'total_working' => count($assignments)]);
        } catch (Exception $e) {
            echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        }
        exit;
    }

      if ($action === 'assign_operator') {
        $booking_id  = trim($_POST['booking_id'] ?? '');
        $operator_id = intval($_POST['operator_id'] ?? 0);

        if ($booking_id === '' || $operator_id <= 0) {
          echo json_encode(['success' => false, 'error' => 'Booking ID and operator are required.']);
          exit;
        }

        $conn->begin_transaction();
        try {
          $booking_stmt = $conn->prepare("
            SELECT booking_status,
                 assignment_status,
                 service_date,
                 assigned_operator_id,
                 last_cancelled_operator_id
            FROM chc_bookings
            WHERE booking_id = ?
            FOR UPDATE
          ");
          $booking_stmt->bind_param("s", $booking_id);
          $booking_stmt->execute();
          $booking = $booking_stmt->get_result()->fetch_assoc();

          if (!$booking) {
            throw new Exception('Booking not found.');
          }

          $old_assigned_operator_id = intval($booking['assigned_operator_id'] ?? 0);
          $last_cancelled_operator_id = intval($booking['last_cancelled_operator_id'] ?? 0);

          $is_operator_cancelled_case = (
            ($booking['assignment_status'] ?? '') === 'Operator Cancelled'
            || ($booking['booking_status'] === 'Cancelled' && $old_assigned_operator_id > 0)
            || (
              $last_cancelled_operator_id > 0
              && $old_assigned_operator_id <= 0
              && !in_array(($booking['assignment_status'] ?? ''), ['Assigned', 'In Progress'], true)
            )
          );

          if ($booking['booking_status'] === 'Completed') {
            throw new Exception('Cannot assign an operator to a completed booking.');
          }

          if ($booking['booking_status'] === 'Cancelled' && !$is_operator_cancelled_case) {
            throw new Exception('This is a fully cancelled booking. Only operator-cancelled bookings can be reassigned.');
          }

          $service_date = $booking['service_date'];
          $max_per_day = 3;

          $check_stmt = $conn->prepare("
            SELECT COUNT(*) as active_count
            FROM chc_bookings
            WHERE assigned_operator_id = ?
              AND service_date = ?
              AND booking_id <> ?
              AND booking_status NOT IN ('Completed', 'Cancelled')
              AND assignment_status IN ('Assigned', 'In Progress')
          ");
          $check_stmt->bind_param("iss", $operator_id, $service_date, $booking_id);
          $check_stmt->execute();
          $active = (int)$check_stmt->get_result()->fetch_assoc()['active_count'];

          if ($active >= $max_per_day) {
            throw new Exception("Operator has reached maximum bookings ($max_per_day) for this service date.");
          }

          $cancelled_operator_for_log = $last_cancelled_operator_id;
          if ($cancelled_operator_for_log <= 0 && $booking['booking_status'] === 'Cancelled' && $old_assigned_operator_id > 0) {
            $cancelled_operator_for_log = $old_assigned_operator_id;
          }

          if ($cancelled_operator_for_log > 0 && $is_operator_cancelled_case) {
            $open_log = $conn->prepare("
              SELECT id
              FROM chc_operator_cancelled_orders
              WHERE booking_id = ?
                AND reassigned_to_operator_id IS NULL
              ORDER BY cancelled_at DESC
              LIMIT 1
            ");
            $open_log->bind_param("s", $booking_id);
            $open_log->execute();
            $open_log_row = $open_log->get_result()->fetch_assoc();

            if (!$open_log_row) {
              $legacy_reason = 'Operator cancelled; legacy Cancelled row reopened for reassignment';
              $created_by = 'admin';
              $log = $conn->prepare("
                INSERT INTO chc_operator_cancelled_orders
                  (booking_id, operator_id, reason, cancelled_at, created_by)
                VALUES (?, ?, ?, NOW(), ?)
              ");
              $log->bind_param("siss", $booking_id, $cancelled_operator_for_log, $legacy_reason, $created_by);
              $log->execute();
            }
          }

          $should_count_reassignment = $is_operator_cancelled_case ? 1 : 0;

          $stmt = $conn->prepare("
            UPDATE chc_bookings
            SET booking_status = CASE
                WHEN booking_status = 'Cancelled' THEN 'Slot Booked'
                ELSE booking_status
              END,
              assigned_operator_id = ?,
              assignment_status = 'Assigned',
              last_cancelled_operator_id = CASE
                WHEN COALESCE(last_cancelled_operator_id, 0) = 0 AND ? > 0 THEN ?
                ELSE last_cancelled_operator_id
              END,
              last_operator_cancelled_at = CASE
                WHEN last_operator_cancelled_at IS NULL AND ? > 0 THEN NOW()
                ELSE last_operator_cancelled_at
              END,
              reassignment_count = CASE
                WHEN ? = 1 THEN COALESCE(reassignment_count, 0) + 1
                ELSE COALESCE(reassignment_count, 0)
              END,
              updated_at = NOW()
            WHERE booking_id = ?
          ");
          $stmt->bind_param(
            "iiiiis",
            $operator_id,
            $cancelled_operator_for_log,
            $cancelled_operator_for_log,
            $cancelled_operator_for_log,
            $should_count_reassignment,
            $booking_id
          );
          $stmt->execute();

          if ($old_assigned_operator_id > 0 && $old_assigned_operator_id !== $operator_id && $is_operator_cancelled_case) {
            $old_op_stmt = $conn->prepare("UPDATE chc_operators SET availability = 'Available', current_booking_id = NULL WHERE operator_id = ?");
            $old_op_stmt->bind_param("i", $old_assigned_operator_id);
            $old_op_stmt->execute();
          }

          $hist = $conn->prepare("
            UPDATE chc_operator_cancelled_orders
            SET reassigned_to_operator_id = ?,
              reassigned_at = NOW()
            WHERE booking_id = ?
              AND reassigned_to_operator_id IS NULL
            ORDER BY cancelled_at DESC
            LIMIT 1
          ");
          $hist->bind_param("is", $operator_id, $booking_id);
          $hist->execute();

          $conn->commit();
          echo json_encode(['success' => true, 'message' => 'Operator assigned successfully']);
        } catch (Exception $e) {
          $conn->rollback();
          echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        }
        exit;
      }

      if ($action === 'get_available_operators') {
        $eq_full_name = $_POST['equipment_type'] ?? '';
        $booking_id   = trim($_POST['booking_id'] ?? '');

        $keyword = '';
        if (stripos($eq_full_name, 'Drone') !== false) $keyword = 'Drone';
        elseif (stripos($eq_full_name, 'Tractor') !== false) $keyword = 'Tractor';
        elseif (stripos($eq_full_name, 'Harvester') !== false) $keyword = 'Harvester';

        $service_date = date('Y-m-d');

        if ($booking_id !== '') {
          $date_stmt = $conn->prepare("
            SELECT booking_status,
                 assignment_status,
                 service_date,
                 assigned_operator_id,
                 last_cancelled_operator_id
            FROM chc_bookings
            WHERE booking_id = ?
          ");
          $date_stmt->bind_param("s", $booking_id);
          $date_stmt->execute();
          $date_row = $date_stmt->get_result()->fetch_assoc();

          if (!$date_row) {
            echo json_encode(['operators' => [], 'error' => 'Booking not found.']);
            exit;
          }

          $current_assigned_operator_id = intval($date_row['assigned_operator_id'] ?? 0);
          $current_last_cancelled_operator_id = intval($date_row['last_cancelled_operator_id'] ?? 0);
          $current_assignment_status = $date_row['assignment_status'] ?? '';

          $is_operator_cancelled_case = (
            $current_assignment_status === 'Operator Cancelled'
            || ($date_row['booking_status'] === 'Cancelled' && $current_assigned_operator_id > 0)
            || (
              $current_last_cancelled_operator_id > 0
              && $current_assigned_operator_id <= 0
              && !in_array($current_assignment_status, ['Assigned', 'In Progress'], true)
            )
          );

          if ($date_row['booking_status'] === 'Completed') {
            echo json_encode(['operators' => [], 'error' => 'Completed bookings cannot be assigned.']);
            exit;
          }

          if ($date_row['booking_status'] === 'Cancelled' && !$is_operator_cancelled_case) {
            echo json_encode(['operators' => [], 'error' => 'This is a fully cancelled booking. Only operator-cancelled bookings can be reassigned.']);
            exit;
          }

          if (!empty($date_row['service_date'])) {
            $service_date = $date_row['service_date'];
          }
        }

        $max_per_day = 3;

        $sql = "
          SELECT o.operator_id, o.name, o.skills, o.base_village,
               COUNT(b.booking_id) as date_bookings
          FROM chc_operators o
          LEFT JOIN chc_bookings b
            ON o.operator_id = b.assigned_operator_id
            AND b.service_date = ?
            AND b.booking_id <> ?
            AND b.booking_status NOT IN ('Completed', 'Cancelled')
            AND b.assignment_status IN ('Assigned', 'In Progress')
          WHERE o.status = 'Active'
        ";

        $params = [$service_date, $booking_id];
        $types = "ss";

        if ($admin_scope !== 'ALL') {
          $sql .= " AND o.client_code = ?";
          $params[] = $admin_scope;
          $types .= "s";
        }

        if ($keyword) {
          $sql .= " AND o.skills LIKE ?";
          $params[] = "%$keyword%";
          $types .= "s";
        }

        $sql .= " GROUP BY o.operator_id
              HAVING date_bookings < ?
              ORDER BY date_bookings ASC, o.name ASC";

        $params[] = $max_per_day;
        $types .= "i";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $res = $stmt->get_result();

        $ops = [];
        while ($r = $res->fetch_assoc()) {
          $r['today_bookings'] = (int)$r['date_bookings'];
          $r['date_bookings'] = (int)$r['date_bookings'];
          $ops[] = $r;
        }

        echo json_encode(['operators' => $ops, 'service_date' => $service_date]);
        exit;
      }

      if ($action === 'update_booking_status') {
        $booking_id = trim($_POST['booking_id'] ?? '');
        $status = $_POST['status'] ?? '';
        $allowed_statuses = ['Completed', 'Cancelled', 'Confirmed', 'Slot Booked', 'Pending'];

        if ($booking_id === '' || !in_array($status, $allowed_statuses)) {
          echo json_encode(['success' => false, 'error' => 'Invalid booking status request.']);
          exit;
        }

        $conn->begin_transaction();
        try {
          $chk = $conn->prepare("
            SELECT booking_status, assigned_operator_id
            FROM chc_bookings
            WHERE booking_id = ?
            FOR UPDATE
          ");
          $chk->bind_param("s", $booking_id);
          $chk->execute();
          $row = $chk->get_result()->fetch_assoc();

          if (!$row) {
            throw new Exception('Booking not found.');
          }

          if (in_array($row['booking_status'], ['Completed', 'Cancelled'])) {
            throw new Exception("Cannot modify a {$row['booking_status']} booking.");
          }

          $op_id = intval($row['assigned_operator_id'] ?? 0);

          $stmt = $conn->prepare("UPDATE chc_bookings SET booking_status = ?, updated_at = NOW() WHERE booking_id = ?");
          $stmt->bind_param("ss", $status, $booking_id);
          $stmt->execute();

          if ($status === 'Completed' && $op_id > 0) {
            $op_stmt = $conn->prepare("UPDATE chc_operators SET jobs_completed = jobs_completed + 1 WHERE operator_id = ?");
            $op_stmt->bind_param("i", $op_id);
            $op_stmt->execute();
          }

          if ($status === 'Cancelled' && $op_id > 0) {
            $clear_stmt = $conn->prepare("
              UPDATE chc_bookings
              SET assigned_operator_id = NULL,
                assignment_status = 'Unassigned'
              WHERE booking_id = ?
            ");
            $clear_stmt->bind_param("s", $booking_id);
            $clear_stmt->execute();

            $op_stmt = $conn->prepare("UPDATE chc_operators SET availability = 'Available', current_booking_id = NULL WHERE operator_id = ?");
            $op_stmt->bind_param("i", $op_id);
            $op_stmt->execute();
          }

          $conn->commit();
          echo json_encode(['success' => true]);
        } catch (Exception $e) {
          $conn->rollback();
          echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        }
        exit;
      }

      if ($action === 'operator_cancel_booking') {
        $booking_id = trim($_POST['booking_id'] ?? '');
        $operator_id = intval($_POST['operator_id'] ?? 0);
        $reason = trim($_POST['reason'] ?? '');
        $created_by = trim($_POST['created_by'] ?? 'admin');

        if ($booking_id === '') {
          echo json_encode(['success' => false, 'error' => 'Booking ID is required.']);
          exit;
        }

        $conn->begin_transaction();
        try {
          $chk = $conn->prepare("
            SELECT booking_status, assignment_status, assigned_operator_id
            FROM chc_bookings
            WHERE booking_id = ?
            FOR UPDATE
          ");
          $chk->bind_param("s", $booking_id);
          $chk->execute();
          $booking = $chk->get_result()->fetch_assoc();

          if (!$booking) {
            throw new Exception('Booking not found.');
          }

          if ($booking['booking_status'] === 'Completed') {
            throw new Exception('Completed booking cannot be released for reassignment.');
          }

          $assigned_operator_id = intval($booking['assigned_operator_id'] ?? 0);

          if ($booking['booking_status'] === 'Cancelled' && $assigned_operator_id <= 0 && ($booking['assignment_status'] ?? '') !== 'Operator Cancelled') {
            throw new Exception('This is a fully cancelled booking and cannot be released for reassignment.');
          }
          if ($assigned_operator_id <= 0) {
            throw new Exception('This booking does not have an assigned operator.');
          }

          if ($operator_id <= 0) {
            $operator_id = $assigned_operator_id;
          }

          if ($operator_id !== $assigned_operator_id) {
            throw new Exception('The selected operator is not assigned to this booking.');
          }

          $existing_log = $conn->prepare("
            SELECT id
            FROM chc_operator_cancelled_orders
            WHERE booking_id = ?
              AND operator_id = ?
              AND reassigned_to_operator_id IS NULL
            ORDER BY cancelled_at DESC
            LIMIT 1
          ");
          $existing_log->bind_param("si", $booking_id, $operator_id);
          $existing_log->execute();
          $existing_log_row = $existing_log->get_result()->fetch_assoc();

          if (!$existing_log_row) {
            $log = $conn->prepare("
              INSERT INTO chc_operator_cancelled_orders
                (booking_id, operator_id, reason, cancelled_at, created_by)
              VALUES (?, ?, ?, NOW(), ?)
            ");
            $log->bind_param("siss", $booking_id, $operator_id, $reason, $created_by);
            $log->execute();
          }

          $upd = $conn->prepare("
            UPDATE chc_bookings
            SET booking_status = CASE
                WHEN booking_status = 'Cancelled' THEN 'Slot Booked'
                ELSE booking_status
              END,
              assigned_operator_id = NULL,
              assignment_status = 'Operator Cancelled',
              last_cancelled_operator_id = ?,
              last_operator_cancel_reason = ?,
              last_operator_cancelled_at = NOW(),
              updated_at = NOW()
            WHERE booking_id = ?
          ");
          $upd->bind_param("iss", $operator_id, $reason, $booking_id);
          $upd->execute();

          $op_stmt = $conn->prepare("UPDATE chc_operators SET availability = 'Available', current_booking_id = NULL WHERE operator_id = ?");
          $op_stmt->bind_param("i", $operator_id);
          $op_stmt->execute();

          $conn->commit();
          echo json_encode(['success' => true, 'message' => 'Operator cancellation recorded. Order is ready for reassignment.']);
        } catch (Exception $e) {
          $conn->rollback();
          echo json_encode(['success' => false, 'error' => $e->getMessage()]);
        }
        exit;
      }

      if ($action === 'reschedule_booking') {
        $booking_id = $_POST['booking_id']; $new_date = $_POST['new_date'];
        $conn->begin_transaction();
        try {
          $chk = $conn->prepare("SELECT assigned_operator_id FROM chc_bookings WHERE booking_id = ?");
          $chk->bind_param("s", $booking_id); $chk->execute();
          if ($row = $chk->get_result()->fetch_assoc()) {
            if ($row['assigned_operator_id']) {
              $op_id = $row['assigned_operator_id'];
              $conn->query("UPDATE chc_operators SET availability = 'Available', current_booking_id = NULL WHERE operator_id = $op_id");
            }
          }
          $stmt = $conn->prepare("UPDATE chc_bookings SET service_date = ?, rescheduled_date = ?, assigned_operator_id = NULL, assignment_status = 'Unassigned', updated_at = NOW() WHERE booking_id = ?");
          $stmt->bind_param("sss", $new_date, $new_date, $booking_id); $stmt->execute();
          $conn->commit(); echo json_encode(['success' => true]);
        } catch (Exception $e) { $conn->rollback(); echo json_encode(['success' => false, 'error' => 'Database error']); }
        exit;
      }

      echo json_encode(['success' => false, 'error' => 'Unsupported action.']);
    exit;
}

// ================================================================= DATA
$kpi_res = $conn->query("SELECT COUNT(*) as total_bookings, SUM(CASE WHEN booking_status = 'Completed' THEN total_cost ELSE 0 END) as revenue_realized, SUM(CASE WHEN booking_status IN ('Pending', 'Slot Booked', 'Confirmed') THEN total_cost ELSE 0 END) as revenue_pipeline, COUNT(DISTINCT cb.user_id) as active_farmers FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) WHERE $where_clause AND service_date BETWEEN '$start_date' AND '$end_date'");
$kpi = $kpi_res ? $kpi_res->fetch_assoc() : ['total_bookings' => 0, 'revenue_realized' => 0, 'revenue_pipeline' => 0, 'active_farmers' => 0];

$today_rev_res = $conn->query("SELECT COALESCE(SUM(total_cost), 0) as amt FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) WHERE $where_clause AND cb.service_date = '$today' AND cb.booking_status = 'Completed'");
$today_rev = $today_rev_res ? $today_rev_res->fetch_assoc()['amt'] : 0;

$chart_res = $conn->query("SELECT cb.service_date, cb.equipment_type, SUM(cb.total_cost) as revenue FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) WHERE $where_clause AND cb.service_date BETWEEN '$start_date' AND '$end_date' AND cb.booking_status = 'Completed' GROUP BY cb.service_date, cb.equipment_type ORDER BY cb.service_date ASC");
$chart_dates = []; $equipment_series = []; $raw_data = [];
if ($chart_res) {
    while ($r = $chart_res->fetch_assoc()) {
        $d = date('d M', strtotime($r['service_date'])); $eq = $r['equipment_type'];
        if (!in_array($d, $chart_dates)) $chart_dates[] = $d;
        $raw_data[$d][$eq] = $r['revenue'];
        if (!isset($equipment_series[$eq])) $equipment_series[$eq] = [];
    }
}

$chart_datasets = [];
$colors = ['#16A34A', '#D97706', '#2563EB', '#DC2626', '#9333EA', '#059669']; $ci = 0;
foreach ($equipment_series as $eq_name => $val) {
    $data_points = [];
    foreach ($chart_dates as $date) { $data_points[] = $raw_data[$date][$eq_name] ?? 0; }
    $chart_datasets[] = ['label' => $eq_name, 'data' => $data_points, 'backgroundColor' => $colors[$ci % count($colors)] . '33', 'borderColor' => $colors[$ci % count($colors)], 'borderWidth' => 2, 'fill' => true, 'tension' => 0.4, 'pointRadius' => 3, 'pointBackgroundColor' => $colors[$ci % count($colors)]];
    $ci++;
}

// Fetch Equipment Specific Stats for the new tables
$eq_stats_res = $conn->query("
    SELECT cb.equipment_type,
           COUNT(*) as total_bookings,
           SUM(CASE WHEN cb.booking_status = 'Completed' THEN cb.total_cost ELSE 0 END) as total_revenue
    FROM chc_bookings cb
    LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number)
    WHERE $where_clause AND cb.service_date BETWEEN '$start_date' AND '$end_date'
    GROUP BY cb.equipment_type
");
$eq_stats = [];
if ($eq_stats_res) {
    while ($row = $eq_stats_res->fetch_assoc()) {
        $eq_stats[] = $row;
    }
}

// Sort for Bookings Table
$eq_bookings = $eq_stats;
usort($eq_bookings, function($a, $b) { return $b['total_bookings'] <=> $a['total_bookings']; });

// Sort for Revenue Table
$eq_revenue = $eq_stats;
usort($eq_revenue, function($a, $b) { return $b['total_revenue'] <=> $a['total_revenue']; });


$today_res = $conn->query("SELECT cb.*, u.name, u.profile_image_url, u.village, op.name as op_name FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) LEFT JOIN chc_operators op ON cb.assigned_operator_id = op.operator_id WHERE $where_clause AND cb.service_date = '$today' ORDER BY cb.created_at DESC");
$list_res = $conn->query("SELECT cb.*, u.name, u.phone_number, u.village, u.profile_image_url, op.name as op_name FROM chc_bookings cb LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number) LEFT JOIN chc_operators op ON cb.assigned_operator_id = op.operator_id WHERE $where_clause AND cb.service_date BETWEEN '$start_date' AND '$end_date' ORDER BY cb.service_date DESC");

// Fetch equipment with custom client pricing and dynamic slabs fallback
$eq_sql = "
    SELECT 
        e.*,
        cip.price_member AS custom_price,
        (SELECT MIN(price_member) FROM client_item_price_slabs cips WHERE cips.item_id = e.id AND cips.client_code = '$admin_scope') as slab_min_price
    FROM chc_equipments e
    LEFT JOIN client_item_pricing cip ON e.id = cip.item_id AND cip.client_code = '$admin_scope'
    ORDER BY e.name_en ASC
";
$eq_res = $conn->query($eq_sql);

// === Fetch Operators with Client Filter ===
$op_sql = "
    SELECT o.*, 
           COALESCE(COUNT(b.booking_id), 0) as today_bookings
    FROM chc_operators o
    LEFT JOIN chc_bookings b 
        ON o.operator_id = b.assigned_operator_id 
        AND b.service_date = CURDATE() 
        AND b.booking_status NOT IN ('Completed', 'Cancelled')
    WHERE " . ($admin_scope !== 'ALL' ? "o.client_code = '" . $conn->real_escape_string($admin_scope) . "'" : "1=1") . "
    GROUP BY o.operator_id
    ORDER BY o.availability ASC, today_bookings ASC, o.name ASC
";

$op_res = $conn->query($op_sql);

$operator_cancelled_sql = "
    SELECT c.id, c.booking_id, c.operator_id, c.reason, c.cancelled_at, 
           c.reassigned_to_operator_id, c.reassigned_at, c.created_by,
           b.equipment_type, b.service_date, b.booking_status, b.assignment_status,
           u.name AS farmer_name, u.village AS farmer_village,
           old_op.name AS cancelled_by_operator,
           new_op.name AS reassigned_to_operator
    FROM chc_operator_cancelled_orders c
    JOIN chc_bookings b ON c.booking_id = b.booking_id
    JOIN users u ON b.user_id = u.user_id
    JOIN chc_operators old_op ON c.operator_id = old_op.operator_id
    LEFT JOIN chc_operators new_op ON c.reassigned_to_operator_id = new_op.operator_id
    WHERE $where_clause
    ORDER BY c.cancelled_at DESC
    LIMIT 50
";
$operator_cancelled_res = $conn->query($operator_cancelled_sql);

$operator_cancelled_kpi = ['total' => 0, 'pending' => 0, 'reassigned' => 0];
$operator_cancelled_kpi_sql = "
    SELECT COUNT(*) AS total,
           COALESCE(SUM(CASE WHEN c.reassigned_to_operator_id IS NULL THEN 1 ELSE 0 END), 0) AS pending,
           COALESCE(SUM(CASE WHEN c.reassigned_to_operator_id IS NOT NULL THEN 1 ELSE 0 END), 0) AS reassigned
    FROM chc_operator_cancelled_orders c
    JOIN chc_bookings b ON c.booking_id = b.booking_id
    JOIN users u ON (b.user_id = u.user_id OR b.user_id = u.phone_number)
    WHERE $where_clause
";
$operator_cancelled_kpi_res = $conn->query($operator_cancelled_kpi_sql);
if ($operator_cancelled_kpi_res) {
    $operator_cancelled_kpi = $operator_cancelled_kpi_res->fetch_assoc() ?: $operator_cancelled_kpi;
    $operator_cancelled_kpi['total'] = (int)($operator_cancelled_kpi['total'] ?? 0);
    $operator_cancelled_kpi['pending'] = (int)($operator_cancelled_kpi['pending'] ?? 0);
    $operator_cancelled_kpi['reassigned'] = (int)($operator_cancelled_kpi['reassigned'] ?? 0);
}

$today_count = $today_res ? $today_res->num_rows : 0;
$today_village_summary = [];
$today_equipment_summary = [];
if ($today_res) {
    $today_res->data_seek(0);
    while ($today_row = $today_res->fetch_assoc()) {
        $village_name = trim((string)($today_row['village'] ?? ''));
        if ($village_name === '') { $village_name = 'Village not set'; }
        if (!isset($today_village_summary[$village_name])) {
            $today_village_summary[$village_name] = ['name' => $village_name, 'count' => 0, 'bookings' => []];
        }
        $today_village_summary[$village_name]['count']++;
        $today_village_summary[$village_name]['bookings'][] = [
            'booking_id' => $today_row['booking_id'] ?? '',
            'farmer' => $today_row['name'] ?? 'Unknown farmer',
            'equipment' => $today_row['equipment_type'] ?? 'Equipment not set',
            'status' => $today_row['booking_status'] ?? 'Pending'
        ];

        $equipment_name = trim((string)($today_row['equipment_type'] ?? ''));
        if ($equipment_name === '') { $equipment_name = 'Equipment not set'; }
        if (!isset($today_equipment_summary[$equipment_name])) {
            $today_equipment_summary[$equipment_name] = ['name' => $equipment_name, 'count' => 0, 'villages' => []];
        }
        $today_equipment_summary[$equipment_name]['count']++;
        $today_equipment_summary[$equipment_name]['villages'][$village_name] = true;
    }
    foreach ($today_equipment_summary as &$eq_summary) {
        $eq_summary['village_count'] = count($eq_summary['villages']);
        $eq_summary['villages'] = array_keys($eq_summary['villages']);
    }
    unset($eq_summary);
    uasort($today_village_summary, function($a, $b) { return $b['count'] <=> $a['count']; });
    uasort($today_equipment_summary, function($a, $b) { return $b['count'] <=> $a['count']; });
    $today_res->data_seek(0);
}
$today_village_count = count($today_village_summary);
$today_equipment_type_count = count($today_equipment_summary);
if ($op_res) $op_res->data_seek(0);
$total_bookings = $kpi['total_bookings'] ?? 0;

// Fetch Crop Type Stats
$crop_stats_res = $conn->query("
    SELECT COALESCE(NULLIF(cb.crop_type, ''), 'Unspecified') as crop,
           COUNT(*) as total_bookings
    FROM chc_bookings cb
    LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number)
    WHERE $where_clause AND cb.service_date BETWEEN '$start_date' AND '$end_date'
    GROUP BY crop
    ORDER BY total_bookings DESC
");
$crop_stats = [];
if ($crop_stats_res) {
    while ($row = $crop_stats_res->fetch_assoc()) {
        $crop_stats[] = $row;
    }
}

// Fetch Farmer Category Stats (Marginal, Small, Large)
$farmer_cat_res = $conn->query("
    SELECT 
        CASE 
            WHEN cb.land_size_acres <= 2.00 THEN 'Marginal (≤ 2 Acres)'
            WHEN cb.land_size_acres <= 4.00 THEN 'Small (2.1 - 4 Acres)'
            ELSE 'Large (> 4 Acres)'
        END as category,
        COUNT(*) as total_bookings
    FROM chc_bookings cb
    LEFT JOIN users u ON (cb.user_id = u.user_id OR cb.user_id = u.phone_number)
    WHERE $where_clause AND cb.service_date BETWEEN '$start_date' AND '$end_date'
    GROUP BY category
    ORDER BY CASE 
        WHEN category LIKE 'Marginal%' THEN 1 
        WHEN category LIKE 'Small%' THEN 2 
        ELSE 3 END
");
$farmer_categories = [];
if ($farmer_cat_res) {
    while ($row = $farmer_cat_res->fetch_assoc()) {
        $farmer_categories[] = $row;
    }
}

// Prepare compact Overview chart datasets for a graph-first dashboard.
$equipment_booking_labels = array_map(function($row) { return $row['equipment_type']; }, $eq_bookings);
$equipment_booking_values = array_map(function($row) { return (int)$row['total_bookings']; }, $eq_bookings);
$equipment_revenue_labels = array_map(function($row) { return $row['equipment_type']; }, $eq_revenue);
$equipment_revenue_values = array_map(function($row) { return (float)$row['total_revenue']; }, $eq_revenue);
$crop_labels = array_map(function($row) { return $row['crop']; }, $crop_stats);
$crop_values = array_map(function($row) { return (int)$row['total_bookings']; }, $crop_stats);
$farmer_category_labels = array_map(function($row) { return $row['category']; }, $farmer_categories);
$farmer_category_values = array_map(function($row) { return (int)$row['total_bookings']; }, $farmer_categories);
$max_equipment_bookings = !empty($equipment_booking_values) ? max($equipment_booking_values) : 0;
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CropSync · Manager Monitoring</title>

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://unpkg.com/@phosphor-icons/web"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script defer src="https://cdn.jsdelivr.net/npm/@alpinejs/collapse@3.x.x/dist/cdn.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/@alpinejs/anchor@3.x.x/dist/cdn.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>

<style>
  :root {
    /* Creamish White Theme */
    --bg: #F9F8F4;
    --surface: #FFFFFF;
    --surface-2: #F3F2EE;
    --surface-3: #EAE9E4;
    --border: rgba(0, 0, 0, 0.08);
    --border-hover: rgba(0, 0, 0, 0.16);
    
    --text-primary: #1F231F;
    --text-secondary: #495449;
    --text-muted: #6B7A6B;
    
    --accent: #16A34A; /* Emerald */
    --accent-dim: rgba(22, 163, 74, 0.12);
    --accent-glow: rgba(22, 163, 74, 0.25);
    
    --amber: #D97706; 
    --amber-dim: rgba(217, 119, 6, 0.12);
    
    --blue: #2563EB;
    --blue-dim: rgba(37, 99, 235, 0.12);
    
    --red: #DC2626;
    --red-dim: rgba(220, 38, 38, 0.12);
    
    /* Poppins Everywhere */
    --font-display: 'Poppins', sans-serif;
    --font-body: 'Poppins', sans-serif;
    --font-mono: 'Poppins', sans-serif;
    
    --radius: 10px;
    --radius-lg: 16px;
    --radius-xl: 20px;
  }

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  html { background: var(--bg); color: var(--text-primary); font-family: var(--font-body); font-size: 14px; line-height: 1.5; -webkit-font-smoothing: antialiased; }

  body { min-height: 100vh; display: flex; }

  [x-cloak] { display: none !important; }

  /* Utilities */
  .mono { font-variant-numeric: tabular-nums; }

  /* Scrollbar */
  ::-webkit-scrollbar { width: 6px; height: 6px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: var(--border-hover); border-radius: 99px; }

  /* Sidebar Nav */
  .sidenav { width: 220px; min-width: 220px; background: var(--surface); border-right: 1px solid var(--border); display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh; overflow-y: auto; z-index: 30; }
  .sidenav-logo { padding: 20px 20px 16px; border-bottom: 1px solid var(--border); }
  .sidenav-logo .wordmark { font-family: var(--font-display); font-weight: 700; font-size: 18px; color: var(--text-primary); letter-spacing: -0.5px; display: flex; align-items: center; gap: 8px; }
  .sidenav-logo .badge { font-family: var(--font-mono); font-size: 10.5px; color: var(--text-muted); margin-top: 4px; font-weight: 500; }
  .nav-section { padding: 12px 12px 4px; font-size: 10.5px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: var(--text-muted); font-family: var(--font-mono); }
  .nav-item { display: flex; align-items: center; gap: 9px; padding: 8px 12px; border-radius: var(--radius); margin: 1px 8px; font-size: 13.5px; font-weight: 500; color: var(--text-secondary); cursor: pointer; transition: all 0.15s; border: 1px solid transparent; text-decoration: none; }
  .nav-item:hover { background: var(--surface-3); color: var(--text-primary); border-color: var(--border); }
  .nav-item.active { background: var(--accent-dim); color: var(--accent); border-color: rgba(22, 163, 74, 0.2); }
  .nav-item i { font-size: 18px; width: 18px; text-align: center; }
  .nav-item .badge-count { margin-left: auto; background: var(--surface-3); color: var(--text-muted); font-size: 10px; font-family: var(--font-mono); padding: 1px 6px; border-radius: 99px; border: 1px solid var(--border); }
  .nav-item.active .badge-count { background: var(--accent-dim); color: var(--accent); border-color: rgba(22, 163, 74, 0.2); }
  .sidenav-footer { margin-top: auto; padding: 12px; border-top: 1px solid var(--border); }

  /* Main content */
  .main-content { flex: 1; overflow: hidden; display: flex; flex-direction: column; min-width: 0; }

  /* Topbar */
  .topbar { display: flex; align-items: center; justify-content: space-between; padding: 0 28px; height: 60px; border-bottom: 1px solid var(--border); background: var(--surface); position: sticky; top: 0; z-index: 20; gap: 16px; flex-shrink: 0; }
  .topbar-title { font-family: var(--font-display); font-size: 16px; font-weight: 700; color: var(--text-primary); }
  .topbar-actions { display: flex; align-items: center; gap: 10px; }
  .date-range-form { display: flex; align-items: center; gap: 6px; background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); padding: 5px 10px; }
  .date-range-form input { background: transparent; border: none; outline: none; color: var(--text-primary); font-family: var(--font-mono); font-size: 12px; font-weight: 500; width: 88px; text-align: center; }
  .date-range-form .sep { color: var(--text-muted); font-size: 11px; }
  .btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; border-radius: var(--radius); font-weight: 500; font-size: 13px; cursor: pointer; border: none; transition: all 0.15s; font-family: var(--font-body); }
  .btn-ghost { background: transparent; color: var(--text-secondary); border: 1px solid transparent; padding: 6px 10px; }
  .btn-ghost:hover { background: var(--surface-3); color: var(--text-primary); border-color: var(--border); }
  .btn-primary { background: var(--accent); color: #FFFFFF; font-weight: 600; padding: 7px 14px; }
  .btn-primary:hover { background: #15803d; }
  .btn-sm { padding: 5px 10px; font-size: 12px; }
  .btn-danger { background: var(--red-dim); color: var(--red); border: 1px solid rgba(220,38,38,0.2); padding: 6px 12px; }
  .btn-danger:hover { background: rgba(220,38,38,0.2); }
  .btn-amber { background: var(--amber-dim); color: var(--amber); border: 1px solid rgba(217,119,6,0.2); padding: 6px 12px; }
  .btn-amber:hover { background: rgba(217,119,6,0.2); }

  /* Page body */
  .page-body { flex: 1; overflow-y: auto; padding: 28px; display: flex; flex-direction: column; gap: 24px; }

  /* KPI cards */
  .kpi-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 24px; }
  .kpi-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 20px 22px; position: relative; overflow: hidden; cursor: default; transition: border-color 0.2s, box-shadow 0.2s; box-shadow: 0 2px 8px rgba(0,0,0,0.02); }
  .kpi-card:hover { border-color: var(--border-hover); box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
  .kpi-card::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px; border-radius: var(--radius-lg) var(--radius-lg) 0 0; }
  .kpi-card.green::before { background: linear-gradient(90deg, var(--accent), transparent); }
  .kpi-card.amber::before { background: linear-gradient(90deg, var(--amber), transparent); }
  .kpi-card.blue::before { background: linear-gradient(90deg, var(--blue), transparent); }
  .kpi-card.purple::before { background: linear-gradient(90deg, #9333EA, transparent); }
  .kpi-label { font-family: var(--font-mono); font-size: 11px; letter-spacing: 0.04em; text-transform: uppercase; color: var(--text-muted); margin-bottom: 8px; font-weight: 600; }
  .kpi-value { font-family: var(--font-display); font-size: 28px; font-weight: 700; color: var(--text-primary); letter-spacing: -0.5px; line-height: 1; }
  .kpi-sub { font-size: 12px; color: var(--text-muted); margin-top: 6px; font-weight: 500;}
  .kpi-icon { position: absolute; right: 18px; top: 18px; font-size: 24px; opacity: 0.08; }

  /* Chart area */
  .chart-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 22px 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.02); }
  .card-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 18px; gap: 16px; }
  .card-title { font-family: var(--font-display); font-size: 15px; font-weight: 700; color: var(--text-primary); }
  .card-subtitle { font-size: 13px; color: var(--text-muted); margin-top: 2px; }

  /* Graph-first Overview */
  .overview-dashboard { display: flex; flex-direction: column; gap: 18px; }
  .overview-summary { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding: 18px 20px; background: linear-gradient(135deg, rgba(22,163,74,0.10), rgba(255,255,255,0.92)); border: 1px solid rgba(22,163,74,0.16); border-radius: var(--radius-xl); box-shadow: 0 2px 10px rgba(0,0,0,0.025); }
  .overview-eyebrow { font-family: var(--font-mono); font-size: 10.5px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: var(--accent); margin-bottom: 4px; }
  .overview-summary h2 { font-family: var(--font-display); font-size: 20px; line-height: 1.2; font-weight: 700; color: var(--text-primary); letter-spacing: -0.4px; }
  .overview-summary p { margin-top: 4px; font-size: 13px; color: var(--text-muted); font-weight: 500; }
  .overview-period-pill { display: inline-flex; align-items: center; gap: 8px; padding: 9px 12px; border-radius: 999px; background: var(--surface); border: 1px solid var(--border); color: var(--text-secondary); font-size: 12.5px; font-weight: 600; white-space: nowrap; }
  .overview-card { min-width: 0; }
  .overview-trend-card { padding-bottom: 18px; }
  .overview-grid { display: grid; grid-template-columns: minmax(0, 1.28fr) minmax(320px, 0.72fr); gap: 18px; align-items: stretch; }
  .overview-grid.equal { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .chart-frame { height: 280px; position: relative; min-height: 0; }
  .chart-frame-lg { height: 285px; }
  .chart-frame-compact { height: 232px; }
  .chart-helper { display: inline-flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 999px; background: var(--surface-2); color: var(--text-muted); font-size: 12px; font-weight: 600; border: 1px solid var(--border); }
  .insight-strip { display: grid; grid-template-columns: repeat(auto-fit, minmax(165px, 1fr)); gap: 10px; margin-top: 16px; }
  .insight-chip { position: relative; overflow: hidden; display: flex; flex-direction: column; align-items: flex-start; gap: 4px; min-height: 70px; padding: 12px 13px; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface-2); color: var(--text-primary); cursor: pointer; text-align: left; transition: transform 0.15s, border-color 0.15s, background 0.15s; font-family: var(--font-body); }
  .insight-chip:hover { transform: translateY(-1px); border-color: var(--border-hover); background: var(--surface-3); }
  .insight-chip.active { background: var(--accent-dim); border-color: rgba(22,163,74,0.32); box-shadow: inset 3px 0 0 var(--accent); }
  .chip-label { position: relative; z-index: 1; width: 100%; font-size: 12.5px; font-weight: 700; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .chip-value { position: relative; z-index: 1; font-family: var(--font-mono); font-size: 12px; color: var(--text-muted); font-weight: 600; }
  .chip-bar { position: absolute; left: 0; bottom: 0; width: calc(var(--value, 0) * 1%); height: 3px; background: var(--accent); border-radius: 0 99px 99px 0; opacity: 0.75; }
  .drill-card { display: flex; flex-direction: column; }
  .drill-card .card-header { margin-bottom: 12px; }
  .drill-placeholder { flex: 1; min-height: 252px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; padding: 24px; color: var(--text-muted); background: var(--surface-2); border: 1px dashed var(--border-hover); border-radius: var(--radius-lg); }
  .drill-placeholder i { font-size: 36px; margin-bottom: 10px; opacity: 0.55; }
  .drill-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 10px 12px; background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); margin-bottom: 10px; }
  .drill-title { min-width: 0; font-weight: 700; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .drill-count { color: var(--text-muted); font-size: 12px; font-weight: 600; white-space: nowrap; }
  .farmer-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 10px; max-height: 306px; overflow-y: auto; padding-right: 4px; }
  .farmer-mini-card { display: flex; align-items: center; gap: 11px; min-width: 0; padding: 11px; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); cursor: pointer; transition: background 0.15s, border-color 0.15s, transform 0.15s; }
  .farmer-mini-card:hover { background: var(--surface-2); border-color: var(--border-hover); transform: translateY(-1px); }
  .farmer-mini-avatar { width: 38px; height: 38px; border-radius: 12px; background: var(--accent-dim); border: 1px solid rgba(22,163,74,0.2); display: flex; align-items: center; justify-content: center; color: var(--accent); font-weight: 700; flex-shrink: 0; overflow: hidden; }
  .farmer-mini-avatar img { width: 100%; height: 100%; object-fit: cover; }
  .farmer-mini-body { flex: 1; min-width: 0; }
  .farmer-mini-name { font-weight: 700; color: var(--text-primary); font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .farmer-mini-village { font-size: 11.5px; color: var(--text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 1px; }
  .farmer-mini-meta { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 7px; }
  .mini-pill { display: inline-flex; align-items: center; max-width: 100%; padding: 2px 7px; border-radius: 999px; background: var(--surface-2); border: 1px solid var(--border); color: var(--text-muted); font-size: 10.5px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .overview-metric-list { display: grid; grid-template-columns: repeat(auto-fit, minmax(145px, 1fr)); gap: 10px; margin-top: 14px; }
  .overview-metric { padding: 10px 12px; border-radius: var(--radius); background: var(--surface-2); border: 1px solid var(--border); }
  .overview-metric-label { display: flex; align-items: center; gap: 7px; font-size: 11.5px; color: var(--text-muted); font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .overview-metric-value { margin-top: 4px; font-family: var(--font-display); font-size: 18px; font-weight: 700; color: var(--text-primary); }
  .overview-empty { min-height: 220px; display: flex; align-items: center; justify-content: center; padding: 24px; text-align: center; color: var(--text-muted); background: var(--surface-2); border-radius: var(--radius-lg); border: 1px dashed var(--border); }
  @media (max-width: 1200px) { .overview-grid, .overview-grid.equal { grid-template-columns: 1fr; } }
  @media (max-width: 900px) { .overview-summary { align-items: flex-start; flex-direction: column; } .chart-frame, .chart-frame-lg, .chart-frame-compact { height: 260px; } }
  @media (max-width: 640px) { .overview-dashboard { gap: 14px; } .farmer-grid, .insight-strip { grid-template-columns: 1fr; } .overview-period-pill { width: 100%; justify-content: center; } }

  /* Equipment Tables in Overview (legacy fallback) */
  .overview-tables { display: grid; grid-template-columns: repeat(2, 1fr); gap: 24px; margin-top: 24px; }
  @media (max-width: 900px) { .overview-tables { grid-template-columns: 1fr; } }

  /* Table */
  .data-table { width: 100%; border-collapse: collapse; }
  .data-table thead th { padding: 12px 16px; font-family: var(--font-mono); font-size: 11.5px; letter-spacing: 0.05em; text-transform: uppercase; color: var(--text-muted); font-weight: 600; border-bottom: 1px solid var(--border); text-align: left; white-space: nowrap; }
  .data-table tbody tr { border-bottom: 1px solid var(--border); transition: background 0.1s; cursor: pointer; }
  .data-table tbody tr:last-child { border-bottom: none; }
  .data-table tbody tr:hover { background: var(--surface-2); }
  .data-table td { padding: 14px 16px; font-size: 13.5px; vertical-align: middle; color: var(--text-secondary); }
  .data-table td.bold { color: var(--text-primary); font-weight: 500; }
  .data-table .farmer-cell { display: flex; align-items: center; gap: 12px; }
  .data-table .farmer-cell img { width: 34px; height: 34px; border-radius: 50%; object-fit: cover; border: 1px solid var(--border); flex-shrink: 0; }
  .data-table .farmer-cell .avatar-fallback { width: 34px; height: 34px; border-radius: 50%; background: var(--accent-dim); border: 1px solid rgba(22, 163, 74, 0.2); display: flex; align-items: center; justify-content: center; font-family: var(--font-display); font-size: 13px; font-weight: 600; color: var(--accent); flex-shrink: 0; }
  .data-table .farmer-name { color: var(--text-primary); font-weight: 600; }
  .data-table .farmer-village { font-size: 12px; color: var(--text-muted); }
  .data-table .cost-pill { background: var(--accent-dim); color: var(--accent); border: 1px solid rgba(22, 163, 74, 0.15); padding: 4px 10px; border-radius: 6px; font-family: var(--font-mono); font-size: 12.5px; font-weight: 600; display: inline-flex; align-items: center; gap: 4px; }

  /* Status badges */
  .badge { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 6px; font-size: 11px; font-weight: 600; font-family: var(--font-mono); letter-spacing: 0.03em; white-space: nowrap; }
  .badge-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
  .badge-green { background: var(--accent-dim); color: var(--accent); border: 1px solid rgba(22,163,74,0.2); }
  .badge-green .badge-dot { background: var(--accent); }
  .badge-red { background: var(--red-dim); color: var(--red); border: 1px solid rgba(220,38,38,0.2); }
  .badge-red .badge-dot { background: var(--red); }
  .badge-amber { background: var(--amber-dim); color: var(--amber); border: 1px solid rgba(217,119,6,0.2); }
  .badge-amber .badge-dot { background: var(--amber); }
  .badge-blue { background: var(--blue-dim); color: var(--blue); border: 1px solid rgba(37,99,235,0.2); }
  .badge-blue .badge-dot { background: var(--blue); }
  .badge-muted { background: var(--surface-3); color: var(--text-muted); border: 1px solid var(--border); }
  .badge-muted .badge-dot { background: var(--text-muted); }

  /* Operator cards */
  .op-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
  .op-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 18px; display: flex; gap: 14px; align-items: flex-start; transition: border-color 0.15s; box-shadow: 0 2px 6px rgba(0,0,0,0.02); }
  .op-card:hover { border-color: var(--border-hover); }
  .op-avatar { width: 46px; height: 46px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-family: var(--font-display); font-size: 18px; font-weight: 700; flex-shrink: 0; }
  .op-avatar.available { background: var(--accent-dim); color: var(--accent); border: 1px solid rgba(22,163,74,0.2); }
  .op-avatar.busy { background: var(--amber-dim); color: var(--amber); border: 1px solid rgba(217,119,6,0.2); }
  .op-name { font-weight: 600; font-size: 14.5px; color: var(--text-primary); }
  .op-phone { font-size: 12.5px; color: var(--text-muted); margin-top: 2px; font-family: var(--font-mono); font-weight: 500;}
  .op-pills { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 10px; }
  .op-pill { font-size: 11px; padding: 3px 8px; border-radius: 6px; background: var(--surface-3); border: 1px solid var(--border); color: var(--text-secondary); font-family: var(--font-mono); font-weight: 500;}
  .op-status-dot { width: 8px; height: 8px; border-radius: 50%; margin-left: auto; flex-shrink: 0; margin-top: 4px; }
  .op-status-dot.available { background: var(--accent); box-shadow: 0 0 6px var(--accent-glow); }
  .op-status-dot.busy { background: var(--amber); }

  /* Equipment cards */
  .eq-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
  .eq-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); overflow: hidden; transition: border-color 0.15s; box-shadow: 0 2px 6px rgba(0,0,0,0.02); }
  .eq-card:hover { border-color: var(--border-hover); }
  .eq-card-body { padding: 18px; display: flex; gap: 14px; align-items: center; }
  .eq-img { width: 60px; height: 60px; object-fit: contain; border-radius: 10px; background: var(--surface-3); padding: 8px; border: 1px solid var(--border); flex-shrink: 0; }
  .eq-name { font-weight: 600; color: var(--text-primary); font-size: 14.5px; }
  .eq-price { font-family: var(--font-mono); font-size: 12px; color: var(--text-muted); margin-top: 4px; font-weight: 500;}
  .eq-card-footer { padding: 12px 18px; background: var(--surface-2); border-top: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
  .qty-control { display: flex; align-items: center; gap: 0; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }
  .qty-btn { width: 32px; height: 30px; background: transparent; border: none; color: var(--text-secondary); cursor: pointer; font-size: 18px; display: flex; align-items: center; justify-content: center; transition: background 0.1s; font-weight: 500; }
  .qty-btn:hover { background: var(--surface-3); color: var(--text-primary); }
  .qty-value { width: 36px; text-align: center; font-family: var(--font-mono); font-size: 13px; font-weight: 600; color: var(--text-primary); background: transparent; border: none; outline: none; pointer-events: none; border-left: 1px solid var(--border); border-right: 1px solid var(--border); }

  /* Section wrapper */
  .section-wrap { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-xl); overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.02); }
  .section-label { font-family: var(--font-mono); font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); padding: 16px 20px 10px; border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; }
  .table-wrap { overflow-x: auto; }
  .empty-state { padding: 48px 24px; text-align: center; color: var(--text-muted); }
  .empty-state i { font-size: 32px; margin-bottom: 10px; opacity: 0.4; display: block; }
  .empty-state p { font-size: 14px; }

  /* Dashboard-style read-only operation tabs and schedule summaries */
  .operation-hero { display:flex; align-items:center; justify-content:space-between; gap:18px; padding:20px 22px; margin-bottom:18px; border:1px solid rgba(22,163,74,0.16); border-radius:var(--radius-xl); background:linear-gradient(135deg, rgba(22,163,74,0.10), rgba(255,255,255,0.94)); box-shadow:0 2px 10px rgba(0,0,0,0.025); }
  .operation-hero.warning { border-color:rgba(217,119,6,0.22); background:linear-gradient(135deg, rgba(217,119,6,0.12), rgba(255,255,255,0.94)); }
  .operation-eyebrow { font-family:var(--font-mono); font-size:10.5px; font-weight:700; letter-spacing:0.08em; text-transform:uppercase; color:var(--accent); margin-bottom:4px; }
  .operation-hero.warning .operation-eyebrow { color:var(--amber); }
  .operation-title { font-family:var(--font-display); font-size:20px; line-height:1.2; font-weight:700; color:var(--text-primary); letter-spacing:-0.4px; }
  .operation-subtitle { margin-top:4px; font-size:13px; color:var(--text-muted); font-weight:500; max-width:780px; }
  .operation-kpi-grid { display:grid; grid-template-columns:repeat(3, minmax(0, 1fr)); gap:14px; margin-bottom:18px; }
  .operation-kpi { background:var(--surface); border:1px solid var(--border); border-radius:var(--radius-lg); padding:16px; position:relative; overflow:hidden; box-shadow:0 2px 8px rgba(0,0,0,0.02); }
  .operation-kpi::before { content:''; position:absolute; left:0; top:0; bottom:0; width:3px; background:var(--accent); opacity:0.85; }
  .operation-kpi.amber::before { background:var(--amber); }
  .operation-kpi.blue::before { background:var(--blue); }
  .operation-kpi-label { font-family:var(--font-mono); font-size:10.5px; font-weight:700; letter-spacing:0.06em; text-transform:uppercase; color:var(--text-muted); }
  .operation-kpi-value { margin-top:8px; font-family:var(--font-display); font-size:26px; line-height:1; font-weight:700; color:var(--text-primary); }
  .operation-kpi-sub { margin-top:6px; font-size:12px; color:var(--text-muted); font-weight:500; }
  .schedule-chip-grid { display:grid; grid-template-columns:repeat(3, minmax(0, 1fr)); gap:12px; padding:16px 20px; border-bottom:1px solid var(--border); background:linear-gradient(180deg, rgba(248,250,248,0.78), rgba(255,255,255,0.98)); }
  .schedule-chip { display:flex; align-items:center; gap:12px; width:100%; padding:14px; background:var(--surface); border:1px solid var(--border); border-radius:var(--radius-lg); text-align:left; font-family:var(--font-body); color:var(--text-primary); box-shadow:0 2px 8px rgba(0,0,0,0.02); transition:transform 0.15s, border-color 0.15s, box-shadow 0.15s; }
  button.schedule-chip { cursor:pointer; }
  button.schedule-chip:hover { transform:translateY(-1px); border-color:var(--border-hover); box-shadow:0 6px 16px rgba(0,0,0,0.055); }
  .schedule-chip-icon { width:42px; height:42px; border-radius:13px; display:flex; align-items:center; justify-content:center; flex-shrink:0; font-size:21px; background:var(--accent-dim); color:var(--accent); border:1px solid rgba(22,163,74,0.18); }
  .schedule-chip-icon.amber { background:var(--amber-dim); color:var(--amber); border-color:rgba(217,119,6,0.18); }
  .schedule-chip-icon.blue { background:var(--blue-dim); color:var(--blue); border-color:rgba(37,99,235,0.18); }
  .schedule-chip-label { font-family:var(--font-mono); font-size:10.5px; font-weight:700; letter-spacing:0.06em; text-transform:uppercase; color:var(--text-muted); }
  .schedule-chip-value { margin-top:3px; font-family:var(--font-display); font-size:22px; line-height:1; font-weight:700; color:var(--text-primary); }
  .schedule-chip-sub { margin-top:4px; font-size:12px; color:var(--text-muted); font-weight:500; }
  .popup-list { display:flex; flex-direction:column; gap:10px; }
  .popup-list-item { padding:12px; border:1px solid var(--border); border-radius:var(--radius); background:var(--surface-2); }
  .popup-list-title { display:flex; align-items:center; justify-content:space-between; gap:10px; font-weight:700; color:var(--text-primary); }
  .popup-booking-list { display:flex; flex-direction:column; gap:6px; margin-top:10px; }
  .popup-booking { display:flex; align-items:center; justify-content:space-between; gap:10px; padding:8px 10px; border-radius:8px; background:var(--surface); border:1px solid var(--border); font-size:12.5px; }
  @media (max-width: 900px) { .operation-hero { align-items:flex-start; flex-direction:column; } .operation-kpi-grid, .schedule-chip-grid { grid-template-columns:1fr; } }

  /* Drawer (farmer profile) */
  .drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.3); backdrop-filter: blur(2px); z-index: 100; }
  .drawer { position: fixed; top: 0; right: 0; bottom: 0; width: 360px; background: var(--surface); border-left: 1px solid var(--border); z-index: 101; display: flex; flex-direction: column; transform: translateX(100%); transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1); box-shadow: -4px 0 24px rgba(0,0,0,0.05); }
  .drawer.open { transform: translateX(0); }
  .drawer-header { padding: 20px; border-bottom: 1px solid var(--border); display: flex; align-items: center; justify-content: space-between; flex-shrink: 0; }
  .drawer-title { font-family: var(--font-display); font-weight: 700; font-size: 16px; color: var(--text-primary); }
  .drawer-close { width: 30px; height: 30px; background: var(--surface-2); border: 1px solid var(--border); border-radius: 8px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: var(--text-secondary); transition: all 0.15s; }
  .drawer-close:hover { background: var(--border); color: var(--text-primary); }
  .drawer-body { flex: 1; overflow-y: auto; padding: 20px; }

  /* Modal */
  .modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.4); backdrop-filter: blur(3px); z-index: 200; display: flex; align-items: center; justify-content: center; padding: 20px; }
  .modal { background: var(--surface); border: 1px solid var(--border-hover); border-radius: var(--radius-xl); width: 100%; max-width: 480px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 16px 48px rgba(0,0,0,0.1); }
  .modal-header { padding: 20px; border-bottom: 1px solid var(--border); display: flex; align-items: flex-start; justify-content: space-between; flex-shrink: 0; }
  .modal-title { font-family: var(--font-display); font-weight: 700; font-size: 16px; color: var(--text-primary); }
  .modal-id { font-family: var(--font-mono); font-size: 12px; font-weight: 500; color: var(--text-muted); margin-top: 3px; }
  .modal-body { padding: 20px; overflow-y: auto; flex: 1; }
  .modal-footer { padding: 16px 20px; border-top: 1px solid var(--border); display: flex; gap: 10px; justify-content: flex-end; flex-shrink: 0; background: var(--surface-2); border-radius: 0 0 var(--radius-xl) var(--radius-xl); }

  /* Detail rows */
  .detail-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .detail-item { background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); padding: 14px; }
  .detail-label { font-family: var(--font-mono); font-size: 11px; font-weight: 600; letter-spacing: 0.05em; text-transform: uppercase; color: var(--text-muted); margin-bottom: 6px; }
  .detail-value { font-size: 14.5px; font-weight: 600; color: var(--text-primary); }
  .detail-value.accent { color: var(--accent); font-family: var(--font-mono); font-size: 16px; font-weight: 600; }

  /* Timeline */
  .timeline { position: relative; padding-left: 22px; }
  .timeline::before { content: ''; position: absolute; left: 6px; top: 8px; bottom: 8px; width: 2px; background: var(--border); border-radius: 2px; }
  .timeline-item { position: relative; margin-bottom: 18px; }
  .timeline-item:last-child { margin-bottom: 0; }
  .timeline-dot { position: absolute; left: -20px; top: 4px; width: 12px; height: 12px; border-radius: 50%; border: 2px solid var(--surface); }
  .timeline-dot.done { background: var(--accent); box-shadow: 0 0 8px var(--accent-glow); }
  .timeline-dot.transit { background: var(--blue); }
  .timeline-dot.working { background: var(--amber); }
  .timeline-dot.grey { background: var(--text-muted); }
  .timeline-label { font-size: 14px; font-weight: 600; color: var(--text-primary); }
  .timeline-time { font-family: var(--font-mono); font-size: 11.5px; font-weight: 500; color: var(--text-muted); margin-top: 3px; }

  /* Alert banner */
  .alert { display: flex; gap: 12px; padding: 14px; border-radius: var(--radius); font-size: 13.5px; align-items: flex-start; }
  .alert-warning { background: var(--amber-dim); border: 1px solid rgba(217,119,6,0.2); color: var(--amber); }
  .alert-success { background: var(--accent-dim); border: 1px solid rgba(22,163,74,0.2); color: var(--accent); }

  /* Reading meter */
  .reading-meter { background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius); padding: 14px; display: flex; align-items: center; justify-content: space-between; gap: 12px; }
  .reading-side { flex: 1; }
  .reading-label { font-family: var(--font-mono); font-size: 11px; font-weight: 600; letter-spacing: 0.05em; text-transform: uppercase; color: var(--text-muted); margin-bottom: 6px; }
  .reading-value { font-family: var(--font-mono); font-size: 15px; font-weight: 600; color: var(--text-primary); }
  .reading-sep { display: flex; flex-direction: column; align-items: center; gap: 4px; color: var(--text-muted); }
  .reading-sep i { font-size: 18px; }
  .pause-chip { font-family: var(--font-mono); font-size: 10px; font-weight: 600; color: var(--amber); background: var(--amber-dim); border: 1px solid rgba(217,119,6,0.2); padding: 2px 6px; border-radius: 4px; }

  /* Flatpickr Light Mode Override */
  .flatpickr-calendar { background: var(--surface) !important; border: 1px solid var(--border) !important; border-radius: var(--radius-lg) !important; box-shadow: 0 8px 32px rgba(0,0,0,0.1) !important; font-family: var(--font-body) !important; z-index: 10600 !important; }
  .flatpickr-day { color: var(--text-primary) !important; font-weight: 500; }
  .flatpickr-day:hover, .flatpickr-day.selected { background: var(--accent-dim) !important; color: var(--accent) !important; border-color: rgba(22,163,74,0.2) !important; font-weight: 600; }
  .flatpickr-day.today { border-color: rgba(22,163,74,0.4) !important; }
  .flatpickr-months, .flatpickr-weekdays { color: var(--text-muted) !important; }
  span.flatpickr-weekday { color: var(--text-muted) !important; font-weight: 600; }
  .flatpickr-current-month, .numInputWrapper input, .numInputWrapper span { color: var(--text-primary) !important; font-weight: 600; }
  .flatpickr-prev-month, .flatpickr-next-month { fill: var(--text-secondary) !important; }

  /* Section header w/ divider */
  .section-divider { display: flex; align-items: center; gap: 12px; margin: 8px 0 16px; }
  .section-divider .label { font-family: var(--font-mono); font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); white-space: nowrap; }
  .section-divider .line { flex: 1; height: 1px; background: var(--border); }

  /* Assign modal operator select */
  .op-select-list { max-height: 240px; overflow-y: auto; border: 1px solid var(--border); border-radius: var(--radius); margin-top: 8px; background: var(--surface-2); }
  .op-select-item { display: flex; align-items: center; gap: 14px; padding: 12px 16px; cursor: pointer; transition: background 0.1s; border-bottom: 1px solid var(--border); background: var(--surface); }
  .op-select-item:last-child { border-bottom: none; }
  .op-select-item:hover { background: var(--surface-2); }
  .op-select-item.selected { background: var(--accent-dim); }
  .op-select-item .op-select-avatar { width: 36px; height: 36px; border-radius: 9px; background: var(--accent-dim); border: 1px solid rgba(22,163,74,0.2); color: var(--accent); font-family: var(--font-display); font-weight: 700; font-size: 15px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
  .op-select-item.selected .op-select-avatar { background: rgba(22,163,74,0.25); }
  .op-select-item .op-select-name { font-weight: 600; color: var(--text-primary); font-size: 14px; }
  .op-select-item .op-select-meta { font-size: 12px; color: var(--text-muted); margin-top: 2px; font-family: var(--font-mono); font-weight: 500;}
  .op-select-item .op-select-check { margin-left: auto; color: var(--accent); font-size: 20px; }

  /* Toast notification */
  .toast-container { position: fixed; bottom: 24px; right: 24px; z-index: 9999; display: flex; flex-direction: column; gap: 10px; pointer-events: none; }
  .toast { background: var(--surface); border: 1px solid var(--border-hover); border-radius: var(--radius); padding: 14px 18px; font-size: 14px; font-weight: 500; display: flex; align-items: center; gap: 12px; min-width: 260px; pointer-events: all; animation: slideInToast 0.3s cubic-bezier(0.16, 1, 0.3, 1); box-shadow: 0 8px 24px rgba(0,0,0,0.1); }
  .toast.success { border-left: 4px solid var(--accent); color: var(--accent); }
  .toast.error { border-left: 4px solid var(--red); color: var(--red); }
  .toast.info { border-left: 4px solid var(--blue); color: var(--blue); }
  @keyframes slideInToast { from { opacity: 0; transform: translateX(20px); } to { opacity: 1; transform: translateX(0); } }

  /* Assign status pills in table */
  .assign-btn { background: var(--amber-dim); color: var(--amber); border: 1px solid rgba(217,119,6,0.2); padding: 5px 12px; border-radius: 6px; font-size: 12.5px; font-weight: 600; cursor: pointer; transition: background 0.15s; font-family: var(--font-body); }
  .assign-btn:hover { background: rgba(217,119,6,0.2); }

  /* Export Dropdown items */
  .export-item { display: block; padding: 8px 10px; font-size: 13px; font-weight: 500; color: var(--text-primary); text-decoration: none; border-radius: 6px; cursor: pointer; transition: background 0.1s; }
  .export-item:hover { background: var(--surface-2); }

  /* Inputs for forms */
  .form-input { width:100%; padding:10px 14px; background:var(--surface-2); border:1px solid var(--border); border-radius:8px; font-family:var(--font-body); font-size:14px; outline:none; color:var(--text-primary); transition: border 0.15s; }
  .form-input:focus { border-color: var(--accent); }

  /* Responsive */
  @media (max-width: 1280px) { .op-grid, .eq-grid { grid-template-columns: repeat(2, 1fr); } }
  @media (max-width: 900px) { .kpi-grid { grid-template-columns: repeat(2, 1fr); } .sidenav { display: none; } .op-grid, .eq-grid { grid-template-columns: 1fr; } }
</style>
</head>

<body x-data="dashApp()">

<input type="hidden" id="csrfToken" value="<?= $_SESSION['csrf_token'] ?>">

<aside class="sidenav">
  <div class="sidenav-logo">
    <div class="wordmark">
      <img src="Logo.jpeg" alt="CropSync Logo" style="height:28px; width:auto; object-fit:contain;">
      Crop<span>Sync</span>
    </div>
    <div class="badge">Manager Workspace · View Only</div>
  </div>

  <div class="nav-section">Workspace</div>
  <a class="nav-item" :class="activeTab === 'overview' ? 'active' : ''" @click.prevent="activeTab = 'overview'" href="#">
    <i class="ph-bold ph-squares-four"></i> Overview
  </a>

  <div class="nav-section">Operations</div>
  <a class="nav-item" :class="activeTab === 'today' ? 'active' : ''" @click.prevent="activeTab = 'today'" href="#">
    <i class="ph-bold ph-calendar-check"></i> Today's Schedule
    <span class="badge-count"><?= $today_count ?></span>
  </a>
  <a class="nav-item" :class="activeTab === 'bookings' ? 'active' : ''" @click.prevent="activeTab = 'bookings'" href="#">
    <i class="ph-bold ph-list-checks"></i> All Bookings
    <span class="badge-count"><?= $total_bookings ?></span>
  </a>
  <a class="nav-item" :class="activeTab === 'operator_cancelled' ? 'active' : ''" @click.prevent="activeTab = 'operator_cancelled'" href="#">
    <i class="ph-bold ph-user-minus"></i> Operator Cancelled Orders
    <span class="badge-count"><?= (int)$operator_cancelled_kpi['pending'] ?></span>
  </a>

  <div class="nav-section">Resources</div>
  <a class="nav-item" :class="activeTab === 'fleet' ? 'active' : ''" @click.prevent="activeTab = 'fleet'" href="#">
    <i class="ph-bold ph-users-three"></i> Operators
  </a>
  <a class="nav-item" :class="activeTab === 'inventory' ? 'active' : ''" @click.prevent="activeTab = 'inventory'" href="#">
    <i class="ph-bold ph-warehouse"></i> Fleet & Inventory
  </a>

  <div class="sidenav-footer">
    <a href="?logout=1" class="nav-item" style="color: var(--red); margin: 0;">
      <i class="ph-bold ph-sign-out"></i> Sign out
    </a>
  </div>
</aside>

<div class="main-content">

<!-- TOPBAR -->
<div class="topbar">
    <div>
        <div class="topbar-title">CropSync · Manager Monitoring</div>
        <div style="font-size:13px; color:var(--text-muted); margin-top:2px;">
            Workspace: <strong><?= htmlspecialchars($current_client_code) ?></strong>
            <?php if (count($allowed_codes) > 1): ?>
                <span style="font-size:11px; color:var(--text-muted);">(Switch available)</span>
            <?php endif; ?>
        </div>
    </div>
    
    <div class="topbar-actions" style="display:flex; align-items:center; gap:12px;">
        
        <!-- CLIENT CODE SWITCHER (Preserves Custom Selected Dates) -->
        <?php if (count($allowed_codes) > 1): ?>
        <div style="background:var(--surface-2); border:1px solid var(--border); border-radius:999px; padding:4px; display:flex;">
            <?php foreach($allowed_codes as $code): 
                $isActive = ($code === $current_client_code);
            ?>
                <a href="?switch_client=<?= urlencode($code) ?>&start=<?= urlencode($start_date) ?>&end=<?= urlencode($end_date) ?>" 
                   class="btn <?= $isActive ? 'btn-primary' : 'btn-ghost' ?>" 
                   style="border-radius:999px; padding:7px 18px; font-size:13px; font-weight:600; white-space:nowrap;">
                    <?= htmlspecialchars($code) ?>
                </a>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>

        <!-- UNIFIED DATE RANGE FORM -->
        <form method="GET" action="" class="date-range-form" style="display:flex; align-items:center; gap:6px; margin:0;">
            <!-- Keeps the active client code scope on filter submit -->
            <input type="hidden" name="switch_client" value="<?= htmlspecialchars($current_client_code) ?>">
            
            <input type="date" name="start" value="<?= htmlspecialchars($start_date) ?>" class="datepicker">
            <span class="sep">→</span>
            <input type="date" name="end" value="<?= htmlspecialchars($end_date) ?>" class="datepicker">
            
            <button type="submit" class="btn btn-primary btn-sm">Apply</button>
            
            <!-- FIXED PERMANENT RESET FILTERS BUTTON (Forces clean return to system clear configurations) -->
            <a href="?switch_client=<?= urlencode($current_client_code) ?>" 
               class="btn btn-ghost btn-sm" 
               style="color: var(--text-muted); border-left: 1px solid var(--border); border-radius:0; padding-left:10px; margin-left:4px; display:inline-flex; align-items:center; gap:4px;" 
               title="Clear filters and show all-time data">
                <i class="ph-bold ph-arrows-clockwise"></i> Reset
            </a>
        </form>

        <!-- DYNAMIC EXPORT REPORT DROPDOWN (Preserves Workspace & Custom Filter Ranges) -->
        <div x-data="{ openExport: false }" style="position: relative;">
            <button @click="openExport = !openExport" class="btn btn-ghost" style="border: 1px solid var(--border); background: var(--surface);">
                <i class="ph-bold ph-download-simple"></i> Export Report <i class="ph-bold ph-caret-down" :class="openExport ? 'rotate-180' : ''" style="transition:transform 0.15s; font-size:11px;"></i>
            </button>
            <div x-show="openExport" @click.away="openExport = false" x-cloak style="position: absolute; right: 0; top: 110%; z-index: 100; background: var(--surface); border: 1px solid var(--border-hover); border-radius: var(--radius); min-width: 200px; padding: 6px; box-shadow: 0 8px 24px rgba(0,0,0,0.1);" x-transition.opacity>
                <div style="font-family: var(--font-mono); font-size: 10px; font-weight: 700; color: var(--text-muted); padding: 6px 10px; text-transform: uppercase; letter-spacing: 0.05em;">Download Format: CSV</div>
                <div style="height:1px; background: var(--border); margin: 2px 0 4px;"></div>
                <a href="?export=excel&range=current&start=<?= urlencode($start_date) ?>&end=<?= urlencode($end_date) ?>&switch_client=<?= urlencode($current_client_code) ?>" class="export-item" @click="openExport = false">
                    <i class="ph-bold ph-calendar-blank" style="margin-right:6px; color:var(--accent);"></i> Current Date Range
                </a>
                <a href="?export=excel&range=last_week&switch_client=<?= urlencode($current_client_code) ?>" class="export-item" @click="openExport = false">
                    <i class="ph-bold ph-clock-counter-clockwise" style="margin-right:6px; color:var(--blue);"></i> Last 7 Days
                </a>
                <a href="?export=excel&range=last_month&switch_client=<?= urlencode($current_client_code) ?>" class="export-item" @click="openExport = false">
                    <i class="ph-bold ph-calendar" style="margin-right:6px; color:var(--amber);"></i> Last 30 Days
                </a>
                <div style="height:1px; background: var(--border); margin: 4px 0;"></div>
                <a href="?export=excel&range=overall&switch_client=<?= urlencode($current_client_code) ?>" class="export-item" style="font-weight: 600; color: var(--text-primary);" @click="openExport = false">
                    <i class="ph-bold ph-database" style="margin-right:6px; color:var(--text-muted);"></i> Overall History
                </a>
            </div>
        </div>
    </div>
</div>

  <div class="page-body">

    <div x-show="activeTab === 'overview'" x-cloak class="overview-dashboard">

      <div class="kpi-grid">
        <div class="kpi-card green">
          <div class="kpi-label">Realized Revenue</div>
          <div class="kpi-value mono">₹<?= number_format($kpi['revenue_realized'] ?? 0) ?></div>
          <div class="kpi-sub">Period revenue from completed jobs</div>
          <i class="ph-fill ph-currency-inr kpi-icon" style="color: var(--accent);"></i>
        </div>
        <div class="kpi-card amber">
          <div class="kpi-label">Today's Earnings</div>
          <div class="kpi-value mono">₹<?= number_format($today_rev ?? 0) ?></div>
          <div class="kpi-sub mono"><?= date('d M Y') ?></div>
          <i class="ph-fill ph-sun kpi-icon" style="color: var(--amber);"></i>
        </div>
        <div class="kpi-card blue">
          <div class="kpi-label">Pipeline</div>
          <div class="kpi-value mono">₹<?= number_format($kpi['revenue_pipeline'] ?? 0) ?></div>
          <div class="kpi-sub">Pending, slot booked and confirmed</div>
          <i class="ph-fill ph-funnel kpi-icon" style="color: var(--blue);"></i>
        </div>
        <div class="kpi-card purple">
          <div class="kpi-label">Active Farmers</div>
          <div class="kpi-value mono"><?= number_format($kpi['active_farmers'] ?? 0) ?></div>
          <div class="kpi-sub">Unique farmers this period</div>
          <i class="ph-fill ph-users kpi-icon" style="color: #9333EA;"></i>
        </div>
      </div>

      <div class="chart-card overview-card overview-trend-card">
        <div class="card-header">
          <div>
            <div class="card-title">Revenue Trend</div>
            <div class="card-subtitle">Completed booking revenue by equipment type</div>
          </div>
          <div class="chart-helper"><i class="ph-bold ph-chart-line-up"></i> Read-only period view</div>
        </div>
        <?php if(empty($chart_dates)): ?>
          <div class="overview-empty">
            <div>
              <i class="ph-duotone ph-chart-bar" style="font-size:32px; display:block; margin-bottom:10px; opacity:.5;"></i>
              <p>No completed bookings in this period.</p>
            </div>
          </div>
        <?php else: ?>
          <div class="chart-frame chart-frame-lg"><canvas id="trendChart"></canvas></div>
        <?php endif; ?>
      </div>

      <div class="overview-grid">
        <div class="chart-card overview-card">
          <div class="card-header">
            <div>
              <div class="card-title">Equipment Bookings</div>
              <div class="card-subtitle">Demand volume by equipment; click a bar or card to see farmers</div>
            </div>
            <div class="chart-helper"><i class="ph-bold ph-cursor-click"></i> Drill down</div>
          </div>
          <?php if (empty($eq_bookings)): ?>
            <div class="overview-empty">No booking data available.</div>
          <?php else: ?>
            <div class="chart-frame chart-frame-compact"><canvas id="equipmentBookingsChart"></canvas></div>
            <div class="insight-strip">
              <?php foreach(array_slice($eq_bookings, 0, 6) as $stat): ?>
                <?php $bookingPercent = $max_equipment_bookings > 0 ? round(($stat['total_bookings'] / $max_equipment_bookings) * 100, 2) : 0; ?>
                <button type="button" class="insight-chip" style="--value: <?= $bookingPercent ?>" @click="fetchEquipmentFarmers('<?= htmlspecialchars($stat['equipment_type'], ENT_QUOTES) ?>')" :class="selectedEqOverview === '<?= htmlspecialchars($stat['equipment_type'], ENT_QUOTES) ?>' ? 'active' : ''">
                  <span class="chip-label"><?= htmlspecialchars($stat['equipment_type']) ?></span>
                  <span class="chip-value mono"><?= number_format($stat['total_bookings']) ?> bookings</span>
                  <span class="chip-bar"></span>
                </button>
              <?php endforeach; ?>
            </div>
          <?php endif; ?>
        </div>

        <div class="chart-card overview-card drill-card">
          <div class="card-header">
            <div>
              <div class="card-title">Fetched Farmers</div>
              <div class="card-subtitle">Compact cards replace the long farmer table</div>
            </div>
          </div>

          <template x-if="!selectedEqOverview">
            <div class="drill-placeholder">
              <i class="ph-duotone ph-hand-tap"></i>
              <div style="font-weight:700; color:var(--text-primary);">Select an equipment item</div>
              <p style="font-size:12.5px; margin-top:4px; max-width:260px;">Use the equipment chart or cards to fetch farmer details in a compact view.</p>
            </div>
          </template>

          <div x-show="selectedEqOverview" x-cloak>
            <div class="drill-toolbar">
              <div class="drill-title" x-text="selectedEqOverview"></div>
              <div class="drill-count mono" x-text="isEqFarmersLoading ? 'Loading…' : eqFarmersList.length + ' farmers'"></div>
            </div>

            <div x-show="isEqFarmersLoading" class="overview-empty" style="min-height:220px;">
              <div>
                <i class="ph-duotone ph-spinner-gap animate-spin" style="font-size:28px; display:block; margin-bottom:10px;"></i>
                Fetching farmer list…
              </div>
            </div>

            <div x-show="!isEqFarmersLoading && eqFarmersList.length === 0" class="overview-empty" style="min-height:220px;">
              No farmer details found for this equipment and date range.
            </div>

            <div x-show="!isEqFarmersLoading && eqFarmersList.length > 0" class="farmer-grid">
              <template x-for="farmer in eqFarmersList" :key="farmer.booking_id">
                <div class="farmer-mini-card" @click="openFarmerBookingProfile(farmer)">
                  <div class="farmer-mini-avatar">
                    <template x-if="farmer.profile_image_url">
                      <img :src="farmer.profile_image_url" :alt="farmer.name">
                    </template>
                    <template x-if="!farmer.profile_image_url">
                      <span x-text="farmer.name ? farmer.name.charAt(0).toUpperCase() : 'F'"></span>
                    </template>
                  </div>
                  <div class="farmer-mini-body">
                    <div class="farmer-mini-name" x-text="farmer.name || 'Unknown farmer'"></div>
                    <div class="farmer-mini-village" x-text="farmer.village || 'Village not specified'"></div>
                    <div class="farmer-mini-meta">
                      <span class="mini-pill" x-text="farmer.crop_type || 'Crop not specified'"></span>
                      <span class="mini-pill mono" x-text="farmer.land_size_acres ? farmer.land_size_acres + ' ac' : 'Land n/a'"></span>
                    </div>
                  </div>
                  <i class="ph-bold ph-caret-right" style="color:var(--text-muted); flex-shrink:0;"></i>
                </div>
              </template>
            </div>
          </div>
        </div>
      </div>

      <div class="overview-grid equal">
        <div class="chart-card overview-card">
          <div class="card-header">
            <div>
              <div class="card-title">Equipment Revenue</div>
              <div class="card-subtitle">Realized income by equipment category</div>
            </div>
            <div class="chart-helper"><i class="ph-bold ph-currency-inr"></i> Revenue mix</div>
          </div>
          <?php if (empty($eq_revenue)): ?>
            <div class="overview-empty">No revenue data available.</div>
          <?php else: ?>
            <div class="chart-frame chart-frame-compact"><canvas id="equipmentRevenueChart"></canvas></div>
          <?php endif; ?>
        </div>

        <div class="chart-card overview-card">
          <div class="card-header">
            <div>
              <div class="card-title">Bookings by Crop</div>
              <div class="card-subtitle">Crop-wise demand distribution</div>
            </div>
            <div class="chart-helper"><i class="ph-bold ph-plant"></i> Crop demand</div>
          </div>
          <?php if (empty($crop_stats)): ?>
            <div class="overview-empty">No crop data available.</div>
          <?php else: ?>
            <div class="chart-frame chart-frame-compact"><canvas id="cropDemandChart"></canvas></div>
          <?php endif; ?>
        </div>
      </div>

      <div class="overview-grid equal">
        <div class="chart-card overview-card">
          <div class="card-header">
            <div>
              <div class="card-title">Farmer Demographics</div>
              <div class="card-subtitle">Bookings by land holding size</div>
            </div>
            <div class="chart-helper"><i class="ph-bold ph-users-three"></i> Segment mix</div>
          </div>
          <?php if (empty($farmer_categories)): ?>
            <div class="overview-empty">No farmer category data available.</div>
          <?php else: ?>
            <div class="chart-frame chart-frame-compact"><canvas id="farmerCategoryChart"></canvas></div>
            <div class="overview-metric-list">
              <?php foreach($farmer_categories as $stat): ?>
                <?php
                  $dotColor = 'var(--accent)';
                  if (strpos($stat['category'], 'Marginal') !== false) { $dotColor = 'var(--blue)'; }
                  elseif (strpos($stat['category'], 'Small') !== false) { $dotColor = 'var(--amber)'; }
                ?>
                <div class="overview-metric">
                  <div class="overview-metric-label"><span class="badge-dot" style="background: <?= $dotColor ?>;"></span><?= htmlspecialchars($stat['category']) ?></div>
                  <div class="overview-metric-value mono"><?= number_format($stat['total_bookings']) ?></div>
                </div>
              <?php endforeach; ?>
            </div>
          <?php endif; ?>
        </div>
 <!-- LIVE WORKING OPERATORS ONLY -->
<div class="chart-card overview-card">
    <div class="card-header">
        <div>
            <div class="card-title">Working Now</div>
            <div class="card-subtitle">
                Operators currently on job • 
                <span class="mono" x-text="liveAssignments.length"></span> active
            </div>
        </div>
        <button @click="loadLiveAssignments()" class="btn btn-ghost btn-sm">
            <i class="ph-bold ph-arrows-clockwise"></i> Refresh
        </button>
    </div>

    <div x-show="liveAssignments.length === 0" class="overview-empty">
        <i class="ph-duotone ph-user-check" style="font-size:36px; opacity:0.5;"></i>
        <p>No operators are currently working.</p>
    </div>

    <div class="farmer-grid" style="max-height: 420px; overflow-y: auto;" x-show="liveAssignments.length > 0">
        <template x-for="item in liveAssignments" :key="item.operator_id">
            <div class="farmer-mini-card border-l-4 border-amber-500 bg-amber-50">
                <div class="farmer-mini-avatar" style="background:#fef3c7; color:#d97706; border-color:#f59e0b">
                    <span x-text="item.operator_name ? item.operator_name.charAt(0).toUpperCase() : 'O'"></span>
                </div>

                <div class="farmer-mini-body">
                    <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                        <div class="farmer-mini-name" x-text="item.operator_name"></div>
                        <span class="mono text-xs bg-amber-100 text-amber-700 px-2 py-0.5 rounded font-semibold">
                            #<span x-text="item.booking_id || '—'"></span>
                        </span>
                    </div>
                    
                    <div class="farmer-mini-village" x-text="item.base_village || '—'"></div>

                    <div class="farmer-mini-meta" style="margin-top: 8px; gap: 6px;">
                        <span class="mini-pill" x-text="item.equipment_type || '—'"></span>
                        <span class="mini-pill mono" x-text="item.service_date ? item.service_date : '—'"></span>
                        <span class="mini-pill" style="background:#fef3c7; color:#d97706; font-weight:700;">
                            WORKING NOW
                        </span>
                    </div>

                    <template x-if="item.farmer_name">
                        <div style="margin-top:6px; font-size:12.5px; color:var(--text-secondary);">
                            Farmer: <span x-text="item.farmer_name"></span>
                        </div>
                    </template>
                </div>
            </div>
        </template>
    </div>
</div>

      </div>
    </div>

    <div x-show="activeTab === 'today'" x-cloak>
      <div class="section-wrap">
        <div class="section-label">
          <span>Today · <span class="mono"><?= date('l, d F Y') ?></span></span>
          <span style="color: var(--accent); font-size: 12px;"><span class="mono"><?= $today_count ?></span> bookings</span>
        </div>
        <div class="schedule-chip-grid">
          <div class="schedule-chip" role="group" aria-label="Total orders today">
            <div class="schedule-chip-icon"><i class="ph-bold ph-calendar-check"></i></div>
            <div>
              <div class="schedule-chip-label">Total Orders Today</div>
              <div class="schedule-chip-value mono"><?= $today_count ?></div>
              <div class="schedule-chip-sub">Scheduled for <?= date('d M Y') ?></div>
            </div>
          </div>
          <button type="button" class="schedule-chip" @click="isTodayVillagesOpen = true" aria-label="View today village list">
            <div class="schedule-chip-icon amber"><i class="ph-bold ph-map-pin"></i></div>
            <div>
              <div class="schedule-chip-label">Villages Covered</div>
              <div class="schedule-chip-value mono"><?= $today_village_count ?></div>
              <div class="schedule-chip-sub">Tap to view village-wise orders</div>
            </div>
          </button>
          <button type="button" class="schedule-chip" @click="isTodayEquipmentOpen = true" aria-label="View today booked equipment count">
            <div class="schedule-chip-icon blue"><i class="ph-bold ph-tractor"></i></div>
            <div>
              <div class="schedule-chip-label">Booked Equipment</div>
              <div class="schedule-chip-value mono"><?= $today_equipment_type_count ?> types</div>
              <div class="schedule-chip-sub"><span class="mono"><?= $today_count ?></span> booking<?= $today_count === 1 ? '' : 's' ?> across equipment</div>
            </div>
          </button>
        </div>
        <div class="table-wrap">
          <?php if($today_count === 0): ?>
            <div class="empty-state">
              <i class="ph-duotone ph-calendar-x"></i>
              <p>No bookings scheduled for today.</p>
            </div>
          <?php else: ?>
          <table class="data-table">
            <thead>
              <tr>
                <th>Farmer</th>
                <th>Equipment</th>
                <th>Booking ID</th>
                <th>Operator</th>
                <th>Status</th>
                <th style="text-align:right;">Details</th>
              </tr>
            </thead>
            <tbody>
              <?php if($today_res) $today_res->data_seek(0); while($row = $today_res->fetch_assoc()):
                $bst = $row['booking_status'];
                $ast = $row['assignment_status'];
                $is_assigned = in_array($ast, ['Assigned', 'In Progress']);
                
                // Dynamic Waterfall Status Logic
                $display_status = $bst; 
                $bcls = 'badge-muted';

                if ($bst === 'Completed') {
                    $display_status = 'Completed';
                    $bcls = 'badge-green';
                } elseif ($bst === 'Cancelled') {
                    $display_status = 'Cancelled';
                    $bcls = 'badge-red';
                } elseif ($ast === 'In Progress') {
                    $display_status = 'In Progress';
                    $bcls = 'badge-amber'; 
                } elseif ($ast === 'Assigned') {
                    $display_status = 'Assigned';
                    $bcls = 'badge-blue';
                } elseif ($bst === 'Pending') {
                    $bcls = 'badge-amber';
                } elseif (in_array($bst, ['Slot Booked', 'Confirmed'])) {
                    $bcls = 'badge-blue';
                }
              ?>
              <tr @click="openTaskDetails('<?= $row['booking_id'] ?>')">
                <td>
                  <div class="farmer-cell" @click.stop="openProfile('<?= $row['user_id'] ?>')">
                    <?php if(!empty($row['profile_image_url'])): ?>
                      <img src="<?= htmlspecialchars($row['profile_image_url']) ?>" alt="">
                    <?php else: ?>
                      <div class="avatar-fallback"><?= strtoupper($row['name'][0]) ?></div>
                    <?php endif; ?>
                    <div>
                      <div class="farmer-name"><?= htmlspecialchars($row['name']) ?></div>
                      <div class="farmer-village"><?= htmlspecialchars($row['village']) ?></div>
                    </div>
                  </div>
                </td>
                <td class="bold"><?= htmlspecialchars($row['equipment_type']) ?></td>
                <td><span class="mono" style="color: var(--text-muted); font-size:13px; font-weight: 500;">#<?= htmlspecialchars($row['booking_id']) ?></span></td>
<td @click.stop>
                  <?php if(!empty($row['assigned_operator_id']) && $row['op_name']): ?>
                    <span style="color: var(--text-primary); font-size:14px; font-weight:600; display:flex; align-items:center; gap:6px;">
                      <i class="ph-fill ph-user-circle" style="color:var(--text-muted); font-size:18px;"></i>
                      <?= htmlspecialchars($row['op_name']) ?>
                    </span>
                  <?php else: ?>
                    <span class="badge badge-muted"><span class="badge-dot"></span>Unassigned</span>
                  <?php endif; ?>
                </td>
                <td @click.stop>
                  <span class="badge <?= $bcls ?>"><span class="badge-dot"></span><?= htmlspecialchars($display_status) ?></span>
                </td>
                <td style="text-align:right;" @click.stop>
                  <button class="btn btn-ghost btn-sm" style="font-size:13px;" @click="openTaskDetails('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>')">
                    <i class="ph-bold ph-eye" style="font-size:14px;"></i> View
                  </button>
                </td>
              </tr>
              <?php endwhile; ?>
            </tbody>
          </table>
          <?php endif; ?>
        </div>
      </div>
    </div>

    <div x-show="activeTab === 'bookings'" x-cloak>
      <div class="section-wrap">
        <div class="section-label">
          <span>All Bookings · <span class="mono"><?= $start_date === '2000-01-01' ? 'All Time' : date('d M Y', strtotime($start_date)) . ' – ' . date('d M Y', strtotime($end_date)) ?></span></span>
          <span style="color: var(--text-muted); font-size:12px;"><span class="mono"><?= $total_bookings ?></span> records</span>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Farmer</th>
                <th>Equipment</th>
                <th>Operator</th>
                <th>Cost</th>
                <th style="text-align:right;">Status</th>
                <th style="text-align:right;">Action</th>
              </tr>
            </thead>
            <tbody>
              <?php if($list_res) $list_res->data_seek(0); while($row = $list_res->fetch_assoc()):
                $bst = $row['booking_status'];
                $ast = $row['assignment_status'];
                $is_operator_cancelled_reassignable = (
                    $ast === 'Operator Cancelled'
                    || ($bst === 'Cancelled' && !empty($row['assigned_operator_id']))
                    || (
                        !empty($row['last_cancelled_operator_id'])
                        && empty($row['assigned_operator_id'])
                        && !in_array($ast, ['Assigned', 'In Progress'], true)
                    )
                );
                $is_final_cancelled = ($bst === 'Cancelled' && !$is_operator_cancelled_reassignable);
                $is_assignable = ($bst !== 'Completed' && !$is_final_cancelled);

                // Dynamic Waterfall Status Logic
                $display_status = $bst; 
                $bcls = 'badge-muted';

                if ($bst === 'Completed') {
                    $display_status = 'Completed';
                    $bcls = 'badge-green';
                } elseif ($is_operator_cancelled_reassignable) {
                    $display_status = 'Pending Reassignment';
                    $bcls = 'badge-amber';
                } elseif ($is_final_cancelled) {
                    $display_status = 'Cancelled';
                    $bcls = 'badge-red';
                } elseif ($ast === 'In Progress') {
                    $display_status = 'In Progress';
                    $bcls = 'badge-amber'; 
                } elseif ($ast === 'Assigned') {
                    $display_status = 'Assigned';
                    $bcls = 'badge-blue';
                } elseif ($bst === 'Pending') {
                    $bcls = 'badge-amber';
                } elseif (in_array($bst, ['Slot Booked', 'Confirmed'])) {
                    $bcls = 'badge-blue';
                }
              ?>
              <tr @click="openTaskDetails('<?= $row['booking_id'] ?>')">
                <td>
                    <span class="mono" style="font-size:13px; font-weight:600; color:var(--text-primary);"><?= date('d M Y', strtotime($row['service_date'])) ?></span>
                    <div class="mono" style="font-size:11px; color:var(--text-muted); margin-top:2px;">Booked: <?= date('d M, h:i A', strtotime($row['created_at'])) ?> IST</div>
                </td>
                <td>
                  <div class="farmer-cell" @click.stop="openProfile('<?= $row['user_id'] ?>')">
                    <?php if(!empty($row['profile_image_url'])): ?>
                      <img src="<?= htmlspecialchars($row['profile_image_url']) ?>" alt="">
                    <?php else: ?>
                      <div class="avatar-fallback"><?= strtoupper($row['name'][0]) ?></div>
                    <?php endif; ?>
                    <div>
                      <div class="farmer-name"><?= htmlspecialchars($row['name']) ?></div>
                      <div class="farmer-village"><?= htmlspecialchars($row['village']) ?></div>
                    </div>
                  </div>
                </td>
                <td class="bold"><?= htmlspecialchars($row['equipment_type']) ?></td>
                <td style="color: var(--text-secondary); font-weight:500;" @click.stop>
                  <?php if(!empty($row['assigned_operator_id']) && $row['op_name']): ?>
                    <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
                      <span style="color: var(--text-primary); font-size:14px; font-weight:600; display:flex; align-items:center; gap:6px;">
                        <i class="ph-fill ph-user-circle" style="color:var(--text-muted); font-size:18px;"></i>
                        <?= htmlspecialchars($row['op_name']) ?>
                      </span>
                      <?php if($is_assignable): ?>
                        <button class="assign-btn" style="padding:4px 9px;" @click.stop="openAssignModal('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>', '<?= htmlspecialchars($row['equipment_type'], ENT_QUOTES) ?>')">
                          Change
                        </button>
                      <?php endif; ?>
                    </div>
                  <?php elseif($is_assignable): ?>
                    <button class="assign-btn" @click.stop="openAssignModal('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>', '<?= htmlspecialchars($row['equipment_type'], ENT_QUOTES) ?>')">
                      <i class="ph-bold ph-plus" style="font-size:12px;"></i> Assign
                    </button>
                  <?php else: ?>
                    <span style="color: var(--text-muted);">—</span>
                  <?php endif; ?>
                </td>
                <td><span class="cost-pill mono"><i class="ph-bold ph-info" style="font-size:12px;"></i>₹<?= number_format($row['total_cost']) ?></span></td>
                <td style="text-align:right;"><span class="badge <?= $bcls ?>"><span class="badge-dot"></span><?= htmlspecialchars($display_status) ?></span></td>
                <td style="text-align:right;" @click.stop>
                  <?php if($bst === 'Completed'): ?>
                    <span style="color: var(--text-muted); font-size: 13px; font-weight: 500;">Settled</span>
                  <?php elseif($is_final_cancelled): ?>
                    <span style="color: var(--text-muted); font-size: 13px; font-weight: 500;">Cancelled</span>
                  <?php else: ?>
                    <div x-data="{ open: false }" style="display:inline-block;">
                      <button @click.stop="open = !open" x-ref="manageAllBtn" class="btn btn-ghost btn-sm" style="font-size:13px;">
                        Manage <i class="ph-bold ph-caret-down" :class="open ? 'rotate-180' : ''" style="transition:transform 0.15s; font-size:12px;"></i>
                      </button>
                      <template x-teleport="body">
                        <div x-show="open" @click.away="open = false" style="position:fixed; z-index:500; background: var(--surface); border: 1px solid var(--border-hover); border-radius: var(--radius); min-width:180px; padding: 6px; box-shadow: 0 8px 24px rgba(0,0,0,0.1);"
                          x-anchor.bottom-end.offset.4="$refs.manageAllBtn" x-transition.opacity>
                          <button @click="openAssignModal('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>', '<?= htmlspecialchars($row['equipment_type'], ENT_QUOTES) ?>'); open = false" style="width:100%; text-align:left; padding:10px 14px; font-size:13.5px; font-weight:600; background:transparent; border:none; color: var(--accent); cursor:pointer; border-radius:8px; font-family:var(--font-body); display:flex; align-items:center; gap:8px;" onmouseover="this.style.background='var(--surface-2)'" onmouseout="this.style.background='transparent'">
                            <i class="ph-bold ph-user-switch"></i> Assign / Reassign
                          </button>
                          <button @click="updateStatus('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>', 'Completed'); open = false" style="width:100%; text-align:left; padding:10px 14px; font-size:13.5px; font-weight:600; background:transparent; border:none; color: var(--accent); cursor:pointer; border-radius:8px; font-family:var(--font-body); display:flex; align-items:center; gap:8px;" onmouseover="this.style.background='var(--surface-2)'" onmouseout="this.style.background='transparent'">
                            <i class="ph-bold ph-check-circle"></i> Complete
                          </button>
                          <button @click="reschedule('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>', '<?= htmlspecialchars($row['service_date'], ENT_QUOTES) ?>'); open = false" style="width:100%; text-align:left; padding:10px 14px; font-size:13.5px; font-weight:600; background:transparent; border:none; color: var(--amber); cursor:pointer; border-radius:8px; font-family:var(--font-body); display:flex; align-items:center; gap:8px;" onmouseover="this.style.background='var(--surface-2)'" onmouseout="this.style.background='transparent'">
                            <i class="ph-bold ph-calendar-plus"></i> Reschedule
                          </button>
                          <?php if(!empty($row['assigned_operator_id'])): ?>
                          <button @click="operatorCancel('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>'); open = false" style="width:100%; text-align:left; padding:10px 14px; font-size:13.5px; font-weight:600; background:transparent; border:none; color: var(--red); cursor:pointer; border-radius:8px; font-family:var(--font-body); display:flex; align-items:center; gap:8px;" onmouseover="this.style.background='var(--red-dim)'" onmouseout="this.style.background='transparent'">
                            <i class="ph-bold ph-user-minus"></i> Operator Cancelled
                          </button>
                          <?php endif; ?>
                          <div style="height:1px; background: var(--border); margin: 4px 0;"></div>
                          <button @click="updateStatus('<?= htmlspecialchars($row['booking_id'], ENT_QUOTES) ?>', 'Cancelled'); open = false" style="width:100%; text-align:left; padding:10px 14px; font-size:13.5px; font-weight:600; background:transparent; border:none; color: var(--red); cursor:pointer; border-radius:8px; font-family:var(--font-body); display:flex; align-items:center; gap:8px;" onmouseover="this.style.background='var(--red-dim)'" onmouseout="this.style.background='transparent'">
                            <i class="ph-bold ph-x-circle"></i> Cancel Booking
                          </button>
                        </div>
                      </template>
                    </div>
                  <?php endif; ?>
                </td>
              </tr>
              <?php endwhile; ?>
            </tbody>
          </table>
        </div>
      </div>
    </div>

<div x-show="activeTab === 'operator_cancelled'" x-cloak>
      <div class="operation-hero warning">
        <div>
          <div class="operation-eyebrow">Operations · View-only audit</div>
          <div class="operation-title">Operator Cancelled Orders</div>
          <div class="operation-subtitle">Monitor operator-cancelled bookings, pending reassignment status, and completed reassignment history without changing any booking or operator assignment from this manager dashboard.</div>
        </div>
        <span class="badge badge-muted"><span class="badge-dot"></span>View Only</span>
      </div>

      <div class="operation-kpi-grid">
        <div class="operation-kpi amber">
          <div class="operation-kpi-label">Pending Reassignment</div>
          <div class="operation-kpi-value mono"><?= (int)$operator_cancelled_kpi['pending'] ?></div>
          <div class="operation-kpi-sub">Open operator-cancelled orders awaiting CEO/operator action</div>
        </div>
        <div class="operation-kpi blue">
          <div class="operation-kpi-label">Reassigned</div>
          <div class="operation-kpi-value mono"><?= (int)$operator_cancelled_kpi['reassigned'] ?></div>
          <div class="operation-kpi-sub">Cancellation records already closed by reassignment</div>
        </div>
        <div class="operation-kpi">
          <div class="operation-kpi-label">Audit Records</div>
          <div class="operation-kpi-value mono"><?= (int)$operator_cancelled_kpi['total'] ?></div>
          <div class="operation-kpi-sub">Total operator-cancelled history in this workspace</div>
        </div>
      </div>

      <div class="section-wrap">
        <div class="section-label">
          <span>Latest Operator-Cancelled Orders</span>
          <span style="color: var(--text-muted); font-size:12px;"><span class="mono"><?= $operator_cancelled_res ? $operator_cancelled_res->num_rows : 0 ?></span> recent records</span>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Cancelled At</th>
                <th>Booking</th>
                <th>Farmer</th>
                <th>Cancelled By</th>
                <th>Reason</th>
                <th>Reassigned To</th>
                <th style="text-align:right;">Status</th>
              </tr>
            </thead>
            <tbody>
              <?php if($operator_cancelled_res && $operator_cancelled_res->num_rows > 0): ?>
                <?php $operator_cancelled_res->data_seek(0); ?>
                <?php while($cancel_row = $operator_cancelled_res->fetch_assoc()):
                  $log_is_open = empty($cancel_row['reassigned_to_operator_id']);
                  $log_status = $log_is_open ? 'Pending Reassignment' : 'Reassigned';
                  $log_badge = $log_is_open ? 'badge-amber' : 'badge-blue';
                ?>
                  <tr @click="openTaskDetails('<?= htmlspecialchars($cancel_row['booking_id'], ENT_QUOTES) ?>')">
                    <td><span class="mono" style="font-size:12.5px; font-weight:600;"><?= date('d M Y, h:i A', strtotime($cancel_row['cancelled_at'])) ?></span></td>
                    <td>
                      <div style="font-weight:700; color:var(--text-primary);"><?= htmlspecialchars($cancel_row['equipment_type']) ?></div>
                      <div class="mono" style="font-size:12px; color:var(--text-muted);">#<?= htmlspecialchars($cancel_row['booking_id']) ?> · <?= date('d M Y', strtotime($cancel_row['service_date'])) ?></div>
                    </td>
                    <td>
                      <div style="font-weight:600;"><?= htmlspecialchars($cancel_row['farmer_name']) ?></div>
                      <div style="font-size:12px; color:var(--text-muted);"><?= htmlspecialchars($cancel_row['farmer_village']) ?></div>
                    </td>
                    <td style="font-weight:600; color:var(--red);"><?= htmlspecialchars($cancel_row['cancelled_by_operator']) ?></td>
                    <td style="max-width:280px; color:var(--text-secondary); font-size:13px;"><?= htmlspecialchars($cancel_row['reason'] ?: 'No reason provided') ?></td>
                    <td>
                      <?php if(!empty($cancel_row['reassigned_to_operator'])): ?>
                        <span style="font-weight:600; color:var(--accent);"><?= htmlspecialchars($cancel_row['reassigned_to_operator']) ?></span>
                        <div class="mono" style="font-size:12px; color:var(--text-muted);"><?= !empty($cancel_row['reassigned_at']) ? date('d M Y, h:i A', strtotime($cancel_row['reassigned_at'])) : '' ?></div>
                      <?php else: ?>
                        <span style="color:var(--amber); font-weight:600;">Pending reassignment</span>
                      <?php endif; ?>
                    </td>
                    <td style="text-align:right;">
                      <span class="badge <?= $log_badge ?>"><span class="badge-dot"></span><?= htmlspecialchars($log_status) ?></span>
                      <div class="mono" style="font-size:11.5px; color:var(--text-muted); margin-top:4px;">Current: <?= htmlspecialchars($cancel_row['assignment_status']) ?></div>
                    </td>
                  </tr>
                <?php endwhile; ?>
              <?php else: ?>
                <tr><td colspan="7" style="text-align:center; padding:28px; color:var(--text-muted);">No operator-cancelled orders recorded yet.</td></tr>
              <?php endif; ?>
            </tbody>
          </table>
        </div>
      </div>
    </div>

<div x-show="activeTab === 'fleet'" x-cloak>
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <div>
            <div style="font-family: var(--font-display); font-size: 16px; font-weight: 700; color: var(--text-primary);">Fleet Operators</div>
            <div style="font-size: 13px; color: var(--text-muted); margin-top: 2px;">Monitor your drivers and machinery operators</div>
        </div>
        <span class="badge badge-muted"><span class="badge-dot"></span>View Only</span>
    </div>

<div class="op-grid">
    <?php 
    if($op_res) $op_res->data_seek(0); 
    while($op = $op_res->fetch_assoc()): 
        $busy = $op['availability'] === 'Busy';
        $today_bookings = (int)($op['today_bookings'] ?? 0);
        $total_jobs = (int)($op['jobs_completed'] ?? 0);
        $skills_array = array_filter(array_map('trim', explode(',', $op['skills'] ?? '')));
    ?>
    <div class="op-card">
        <div class="op-avatar <?= $busy ? 'busy' : 'available' ?>">
            <?= strtoupper(substr($op['name'], 0, 1)) ?>
        </div>
        
        <div style="flex:1; min-width:0;">
            <!-- Header: Name + Phone + Status -->
            <div style="display:flex; align-items:flex-start; justify-content:space-between; gap:8px; margin-bottom:8px;">
                <div>
                    <div class="op-name"><?= htmlspecialchars($op['name']) ?></div>
                    <div class="op-phone mono"><?= htmlspecialchars($op['phone_number']) ?></div>
                </div>
                <div class="op-status-dot <?= $busy ? 'busy' : 'available' ?>" 
                     title="<?= htmlspecialchars($op['availability']) ?>"></div>
            </div>

            <!-- Skills Pills -->
            <div class="op-pills" style="margin-bottom: 10px;">
                <?php foreach($skills_array as $skill): ?>
                    <span class="op-pill"><?= htmlspecialchars($skill) ?></span>
                <?php endforeach; ?>
            </div>

            <!-- Workload Summary - Clean & Prominent -->
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                <!-- Today Bookings -->
                <div class="op-pill mono" style="background: <?= $today_bookings >= 3 ? '#fee2e2' : '#ecfdf5' ?>; 
                                               color: <?= $today_bookings >= 3 ? '#dc2626' : '#10b981' ?>; 
                                               border-color: <?= $today_bookings >= 3 ? '#fecaca' : '#a7f3d0' ?>; 
                                               font-weight: 700; padding: 6px 10px;">
                    <span style="font-size:13px;"><?= $today_bookings ?></span> today
                </div>

                <!-- Total Jobs -->
                <div class="op-pill mono" style="background: var(--accent-dim); 
                                               color: var(--accent); 
                                               border-color: rgba(22,163,74,0.3); 
                                               font-weight: 700; padding: 6px 10px;">
                    <?= $total_jobs ?> total
                </div>
            </div>
        </div>
    </div>
    <?php endwhile; ?>
</div>
</div>

    <div x-show="activeTab === 'inventory'" x-cloak>
      <div class="eq-grid">
        <?php if($eq_res) $eq_res->data_seek(0); while($eq = $eq_res->fetch_assoc()):
          $is_active = $eq['status'] === 'Active';
          $img = (strpos($eq['image'], 'http') === 0) ? $eq['image'] : 'custom_hiring_center/'.$eq['image'];

          // DYNAMIC PRICING LOGIC
          $price_str = '₹' . number_format($eq['price_member']) . ' / ' . htmlspecialchars($eq['unit']);
          if (!empty($eq['slab_min_price'])) {
              $price_str = 'Starts at ₹' . number_format($eq['slab_min_price']);
          } elseif (!empty($eq['custom_price'])) {
              $price_str = '₹' . number_format($eq['custom_price']) . ' / ' . htmlspecialchars($eq['unit']);
          }
        ?>
        <div class="eq-card">
          <div class="eq-card-body">
            <img src="<?= $img ?>" class="eq-img" alt="<?= htmlspecialchars($eq['name_en']) ?>">
            <div>
              <div class="eq-name"><?= htmlspecialchars($eq['name_en']) ?></div>
              <div class="eq-price mono"><?= $price_str ?></div>
            </div>
          </div>
          <div class="eq-card-footer">
            <span class="badge <?= $is_active ? 'badge-green' : 'badge-red' ?>" style="font-size:12px;">
              <span class="badge-dot"></span><?= $is_active ? 'Active' : 'Inactive' ?>
            </span>
            <div class="qty-control" style="gap:8px; padding:4px 8px;">
              <span style="font-size:12px; color:var(--text-muted); font-weight:600;">Qty</span>
              <span class="qty-value mono" id="qty-<?= $eq['id'] ?>"><?= $eq['quantity'] ?></span>
            </div>
          </div>
        </div>
        <?php endwhile; ?>
      </div>
    </div>

  </div>
</div>

<template x-if="isTodayVillagesOpen">
  <div>
    <div class="modal-overlay" @click.self="isTodayVillagesOpen = false" x-transition.opacity>
      <div class="modal" style="max-width:620px;">
        <div class="modal-header">
          <div>
            <div class="modal-title">Today’s Villages</div>
            <div class="modal-id"><span x-text="todayVillages.length"></span> villages with bookings today</div>
          </div>
          <div class="drawer-close" @click="isTodayVillagesOpen = false"><i class="ph-bold ph-x" style="font-size:16px;"></i></div>
        </div>
        <div class="modal-body">
          <template x-if="todayVillages.length === 0">
            <div class="empty-state" style="padding:28px 12px;"><i class="ph-duotone ph-map-pin"></i><p>No village data available for today.</p></div>
          </template>
          <div class="popup-list" x-show="todayVillages.length > 0">
            <template x-for="village in todayVillages" :key="village.name">
              <div class="popup-list-item">
                <div class="popup-list-title">
                  <span x-text="village.name"></span>
                  <span class="badge badge-amber"><span class="badge-dot"></span><span x-text="village.count + ' orders'"></span></span>
                </div>
                <div class="popup-booking-list">
                  <template x-for="booking in village.bookings" :key="booking.booking_id">
                    <div class="popup-booking">
                      <div>
                        <div style="font-weight:700; color:var(--text-primary);" x-text="booking.farmer"></div>
                        <div class="mono" style="font-size:11.5px; color:var(--text-muted);" x-text="'#' + booking.booking_id + ' · ' + booking.equipment"></div>
                      </div>
                      <span class="badge badge-green"><span class="badge-dot"></span><span x-text="booking.status"></span></span>
                    </div>
                  </template>
                </div>
              </div>
            </template>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="isTodayVillagesOpen = false">Close</button>
        </div>
      </div>
    </div>
  </div>
</template>

<template x-if="isTodayEquipmentOpen">
  <div>
    <div class="modal-overlay" @click.self="isTodayEquipmentOpen = false" x-transition.opacity>
      <div class="modal" style="max-width:560px;">
        <div class="modal-header">
          <div>
            <div class="modal-title">Today’s Booked Equipment</div>
            <div class="modal-id"><span x-text="todayEquipmentSummary.length"></span> equipment types booked today</div>
          </div>
          <div class="drawer-close" @click="isTodayEquipmentOpen = false"><i class="ph-bold ph-x" style="font-size:16px;"></i></div>
        </div>
        <div class="modal-body">
          <template x-if="todayEquipmentSummary.length === 0">
            <div class="empty-state" style="padding:28px 12px;"><i class="ph-duotone ph-tractor"></i><p>No equipment bookings available for today.</p></div>
          </template>
          <div class="popup-list" x-show="todayEquipmentSummary.length > 0">
            <template x-for="equipment in todayEquipmentSummary" :key="equipment.name">
              <div class="popup-list-item">
                <div class="popup-list-title">
                  <span x-text="equipment.name"></span>
                  <span class="badge badge-blue"><span class="badge-dot"></span><span x-text="equipment.count + ' booked'"></span></span>
                </div>
                <div style="margin-top:8px; font-size:12.5px; color:var(--text-muted); font-weight:500;">
                  From <span class="mono" x-text="equipment.village_count"></span> village<span x-show="equipment.village_count !== 1">s</span>:
                  <span x-text="equipment.villages.join(', ')"></span>
                </div>
              </div>
            </template>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-ghost" @click="isTodayEquipmentOpen = false">Close</button>
        </div>
      </div>
    </div>
  </div>
</template>

<template x-if="isDrawerOpen">
  <div>
    <div class="drawer-overlay" @click="isDrawerOpen = false" x-transition.opacity></div>
    <div class="drawer" :class="isDrawerOpen ? 'open' : ''" x-transition:enter="transition duration-300" x-transition:enter-start="translate-x-full" x-transition:enter-end="translate-x-0">
      <div class="drawer-header">
        <div class="drawer-title">Farmer Profile</div>
        <div class="drawer-close" @click="isDrawerOpen = false"><i class="ph-bold ph-x" style="font-size:16px;"></i></div>
      </div>
      <div class="drawer-body" id="farmerDrawerContent">
        <div style="text-align:center; padding: 40px 0; color: var(--text-muted);">
          <i class="ph-duotone ph-spinner-gap animate-spin" style="font-size:32px; display:block; margin-bottom:12px;"></i>
          Loading profile…
        </div>
      </div>
    </div>
  </div>
</template>

<template x-if="isTaskOpen">
  <div class="modal-overlay" @click.self="isTaskOpen = false" x-transition.opacity>
    <div class="modal" x-transition:enter="transition duration-200" x-transition:enter-start="opacity-0 scale-95" x-transition:enter-end="opacity-100 scale-100" @click.away="isTaskOpen = false">
      <div class="modal-header">
        <div>
          <div class="modal-title">Order Details</div>
          <div class="modal-id mono" x-text="taskData ? '#' + taskData.booking_id : 'Loading…'"></div>
        </div>
        <div style="display:flex; align-items:center; gap:12px;">
          <template x-if="taskData && taskData.rescheduled_date">
            <span class="badge badge-amber"><span class="badge-dot"></span>Rescheduled</span>
          </template>
          <div class="drawer-close" @click="isTaskOpen = false"><i class="ph-bold ph-x" style="font-size:16px;"></i></div>
        </div>
      </div>
      <div class="modal-body">
        <template x-if="!taskData">
          <div style="text-align:center; padding:40px; color: var(--text-muted);">
            <i class="ph-duotone ph-spinner-gap animate-spin" style="font-size:32px; display:block; margin-bottom:12px;"></i>
            Fetching details…
          </div>
        </template>
        <template x-if="taskData">
          <div style="display: flex; flex-direction: column; gap: 20px;">

            <div style="display:flex; justify-content:space-between; align-items:flex-start; padding-bottom:16px; border-bottom:1px solid var(--border);">
              <div>
                <div style="font-family: var(--font-mono); font-size:11px; font-weight:600; text-transform:uppercase; letter-spacing:0.05em; color:var(--text-muted); margin-bottom:6px;">Equipment</div>
                <div style="font-family: var(--font-display); font-size:20px; font-weight:700; color:var(--text-primary);" x-text="taskData.equipment_type"></div>
                <div style="font-size:13.5px; color: var(--text-muted); margin-top:2px; font-weight:500;" x-text="taskData.crop_type || 'Crop not specified'"></div>
              </div>
              <div style="text-align:right;">
                <div style="font-family: var(--font-mono); font-size:11px; font-weight:600; text-transform:uppercase; letter-spacing:0.05em; color:var(--text-muted); margin-bottom:6px;">Total Cost</div>
                <div style="font-family: var(--font-mono); font-size:24px; font-weight:700; color: var(--accent);" class="mono" x-text="'₹' + Number(taskData.total_cost).toLocaleString('en-IN')"></div>
              </div>
            </div>

            <div class="detail-grid">
              <div class="detail-item">
                <div class="detail-label">Farmer</div>
                <div class="detail-value" x-text="taskData.farmer_name"></div>
                <div style="font-family:var(--font-mono); font-size:12px; font-weight:500; color:var(--text-muted); margin-top:4px;" class="mono" x-text="taskData.farmer_phone || ''"></div>
              </div>
              <div class="detail-item">
                <div class="detail-label">Operator</div>
                <div class="detail-value" x-text="taskData.op_name || '—'"></div>
                <div style="font-family:var(--font-mono); font-size:12px; font-weight:500; color:var(--text-muted); margin-top:4px;" class="mono" x-text="taskData.op_phone || ''"></div>
              </div>
            </div>

            <template x-if="taskData.task_status">
              <div>
                <div class="section-divider"><span class="label">Completion</span><div class="line"></div></div>
                <div style="display:flex; flex-direction:column; gap:12px;">
                  <div class="detail-grid">
                    <div class="detail-item">
                      <div class="detail-label">Status</div>
                      <span class="badge badge-green"><span class="badge-dot"></span><span x-text="taskData.task_status"></span></span>
                    </div>
                    <div class="detail-item">
                      <div class="detail-label">Measured Work</div>
                      <div class="detail-value mono">
                        <span x-text="taskData.measured_qty || '0'"></span>&nbsp;<span x-text="taskData.measured_unit || 'Units'"></span>
                        <template x-if="taskData.applied_rate">
                          <span style="color: var(--text-muted); font-size:12px; font-family: var(--font-mono); font-weight:500;"> @ ₹<span x-text="taskData.applied_rate"></span></span>
                        </template>
                      </div>
                    </div>
                  </div>

                  <template x-if="taskData.start_reading || taskData.end_reading">
                    <div class="reading-meter">
                      <div class="reading-side">
                        <div class="reading-label">Start Reading</div>
                        <template x-if="taskData.start_reading && taskData.start_reading.startsWith('http')">
                          <a :href="taskData.start_reading" target="_blank" style="color:var(--blue); font-size:13px; display:flex; align-items:center; gap:6px; text-decoration:none; font-weight:600;"><i class="ph-bold ph-image" style="font-size:16px;"></i> View Photo</a>
                        </template>
                        <template x-if="taskData.start_reading && !taskData.start_reading.startsWith('http')">
                          <div class="reading-value mono" x-text="taskData.start_reading"></div>
                        </template>
                        <template x-if="!taskData.start_reading"><div class="reading-value mono" style="color:var(--text-muted);">N/A</div></template>
                      </div>
                      <div class="reading-sep">
                        <i class="ph-bold ph-arrow-right"></i>
                        <template x-if="taskData.cumulative_pause > 0">
                          <span class="pause-chip mono" x-text="taskData.pause_fmt + ' paused'"></span>
                        </template>
                      </div>
                      <div class="reading-side" style="text-align:right;">
                        <div class="reading-label">End Reading</div>
                        <template x-if="taskData.end_reading && taskData.end_reading.startsWith('http')">
                          <a :href="taskData.end_reading" target="_blank" style="color:var(--blue); font-size:13px; display:flex; align-items:center; gap:6px; text-decoration:none; font-weight:600; justify-content:flex-end;"><i class="ph-bold ph-image" style="font-size:16px;"></i> View Photo</a>
                        </template>
                        <template x-if="taskData.end_reading && !taskData.end_reading.startsWith('http')">
                          <div class="reading-value mono" x-text="taskData.end_reading"></div>
                        </template>
                        <template x-if="!taskData.end_reading"><div class="reading-value mono" style="color:var(--text-muted);">N/A</div></template>
                      </div>
                    </div>
                  </template>

                  <template x-if="taskData.final_amount && parseFloat(taskData.final_amount) !== parseFloat(taskData.total_cost)">
                    <div class="alert alert-success">
                      <i class="ph-fill ph-check-circle" style="font-size:18px; flex-shrink:0; margin-top:2px;"></i>
                      <div>
                        Final settled amount adjusted to ₹<span class="mono" x-text="Number(taskData.final_amount).toLocaleString('en-IN')" style="font-family:var(--font-mono); font-weight:700; font-size:14.5px;"></span>
                      </div>
                    </div>
                  </template>
                </div>
              </div>
            </template>

            <template x-if="taskData.breakdown_reason">
              <div class="alert alert-warning">
                <i class="ph-fill ph-warning-circle" style="font-size:18px; flex-shrink:0; margin-top:2px;"></i>
                <div>
                  <div style="font-weight:700; margin-bottom:2px; font-size:14px;">Machine Breakdown</div>
                  <div style="font-size:13px; color:var(--text-secondary); font-weight:500;" x-text="taskData.breakdown_reason"></div>
                </div>
              </div>
            </template>

            <div>
              <div class="section-divider"><span class="label">Timeline</span><div class="line"></div></div>
              <div class="timeline">
                <template x-if="taskData.assigned_at">
                  <div class="timeline-item">
                    <div class="timeline-dot grey"></div>
                    <div class="timeline-label">Operator Assigned</div>
                    <div class="timeline-time mono" x-text="taskData.assigned_at"></div>
                  </div>
                </template>
                <template x-if="taskData.transit_start_fmt">
                  <div class="timeline-item">
                    <div class="timeline-dot transit"></div>
                    <div class="timeline-label">En Route to Farm</div>
                    <div class="timeline-time mono" x-text="taskData.transit_start_fmt"></div>
                  </div>
                </template>
                <template x-if="taskData.work_start_fmt">
                  <div class="timeline-item">
                    <div class="timeline-dot working"></div>
                    <div class="timeline-label">Work Started</div>
                    <div class="timeline-time mono" x-text="taskData.work_start_fmt"></div>
                  </div>
                </template>
                <template x-if="taskData.work_end_fmt">
                  <div class="timeline-item">
                    <div class="timeline-dot done"></div>
                    <div class="timeline-label">Work Completed</div>
                    <div class="timeline-time mono" x-text="taskData.work_end_fmt"></div>
                  </div>
                </template>
                <template x-if="taskData.return_fmt">
                  <div class="timeline-item">
                    <div class="timeline-dot grey"></div>
                    <div class="timeline-label">Returned to Base</div>
                    <div class="timeline-time mono" x-text="taskData.return_fmt"></div>
                  </div>
                </template>
                <template x-if="!taskData.transit_start_fmt && !taskData.work_start_fmt && !taskData.work_end_fmt">
                  <div style="color: var(--text-muted); font-size:13.5px; padding: 10px 0; font-weight:500;">No execution events yet.</div>
                </template>
              </div>
            </div>

          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<template x-if="isAssignOpen">
  <div class="modal-overlay" @click.self="isAssignOpen = false" x-transition.opacity>
    <div class="modal" style="max-width:420px;" x-transition:enter="transition duration-200" x-transition:enter-start="opacity-0 scale-95" x-transition:enter-end="opacity-100 scale-100" @click.away="isAssignOpen = false">
      <div class="modal-header">
        <div>
          <div class="modal-title">Assign / Reassign Operator</div>
          <div class="modal-id">Select from operators available for this booking date, including previous-date orders</div>
        </div>
        <div class="drawer-close" @click="isAssignOpen = false"><i class="ph-bold ph-x" style="font-size:16px;"></i></div>
      </div>
      <div class="modal-body">
        <template x-if="isAssignLoading">
          <div style="text-align:center; padding:36px; color:var(--text-muted);">
            <i class="ph-duotone ph-spinner-gap animate-spin" style="font-size:28px; display:block; margin-bottom:10px;"></i>
            Finding available operators…
          </div>
        </template>
        <template x-if="!isAssignLoading && availableOperators.length === 0">
          <div style="text-align:center; padding:36px; color:var(--red);">
            <i class="ph-duotone ph-user-minus" style="font-size:32px; display:block; margin-bottom:12px; opacity:0.6;"></i>
            <span style="font-weight:600;">No operators available for this equipment type.</span>
          </div>
        </template>
        <template x-if="!isAssignLoading && availableOperators.length > 0">
          <div class="op-select-list">
            <template x-for="op in availableOperators" :key="op.operator_id">
              <div class="op-select-item" :class="selectedOperator && selectedOperator.operator_id === op.operator_id ? 'selected' : ''" @click="selectedOperator = op">
                <div class="op-select-avatar" x-text="op.name[0].toUpperCase()"></div>
                <div>
                  <div class="op-select-name" x-text="op.name"></div>
                  <div class="op-select-meta mono" x-text="op.skills + ' · ' + op.base_village"></div>
                </div>
                <template x-if="selectedOperator && selectedOperator.operator_id === op.operator_id">
                  <i class="ph-fill ph-check-circle op-select-check"></i>
                </template>
              </div>
            </template>
          </div>
        </template>
      </div>
      <div class="modal-footer">
        <button @click="isAssignOpen = false" class="btn btn-ghost">Cancel</button>
        <button @click="confirmAssign()" class="btn btn-primary" :disabled="!selectedOperator" :style="!selectedOperator ? 'opacity:0.5; cursor:not-allowed;' : ''">
          <i class="ph-bold ph-check" style="font-size:15px;"></i> Confirm Assignment
        </button>
      </div>
    </div>
  </div>
</template>

<div class="toast-container" id="toastContainer"></div>

<script>
// Initialize Datepickers
flatpickr(".datepicker", { dateFormat: "Y-m-d", disableMobile: true });

/**
 * Standardized AJAX Fetcher
 */
async function sFetch(action, data = {}) {
  const fd = new FormData();
  fd.append('ajax_action', action);
  fd.append('csrf_token', document.getElementById('csrfToken').value);
  for (const k in data) fd.append(k, data[k]);
  const r = await fetch(window.location.href, { method: 'POST', body: fd });
  return r.json();
}

/**
 * Toast Notification System
 */
function showToast(msg, type = 'success') {
  const tc = document.getElementById('toastContainer');
  const t = document.createElement('div');
  t.className = `toast ${type}`;
  const icons = { success: 'ph-check-circle', error: 'ph-warning-circle', info: 'ph-info' };
  t.innerHTML = `<i class="ph-fill ${icons[type] || 'ph-info'}" style="font-size:18px;"></i> ${msg}`;
  tc.appendChild(t);
  setTimeout(() => { 
    t.style.transition = 'opacity 0.3s'; 
    t.style.opacity = '0'; 
    setTimeout(() => t.remove(), 300); 
  }, 3000);
}

document.addEventListener('alpine:init', () => {
  Alpine.data('dashApp', () => ({

    // ====================== STATE ======================
    activeTab: localStorage.getItem('cropsync_manager_tab') || 'overview',

    get tabTitle() {
      const map = { 
        overview: 'Overview', 
        today: "Today's Schedule", 
        bookings: 'All Bookings', 
        operator_cancelled: 'Operator Cancelled Orders',
        fleet: 'Operators', 
        inventory: 'Fleet & Inventory' 
      };
      return map[this.activeTab] || 'Dashboard';
    },

    // UI State
    isDrawerOpen: false,
    isTaskOpen: false,
    isAssignOpen: false,
    isTodayVillagesOpen: false,
    isTodayEquipmentOpen: false,
    todayVillages: <?= json_encode(array_values($today_village_summary), JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>,
    todayEquipmentSummary: <?= json_encode(array_values($today_equipment_summary), JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) ?>,
    taskData: null,

    availableOperators: [],
    selectedOperator: null,
    isAssignLoading: false,
    currentBookingId: null,

    // Equipment Drill Down State
    selectedEqOverview: null,
    eqFarmersList: [],
    isEqFarmersLoading: false,

    // Live Assignments State
    liveAssignments: [],

    // ====================== INIT ======================
    init() {
      // Persist active tab
      this.$watch('activeTab', (val) => {
        localStorage.setItem('cropsync_manager_tab', val);
      });

      // Load Live Assignments when Overview tab is active
      this.$watch('activeTab', (newTab) => {
        if (newTab === 'overview') {
          this.loadLiveAssignments();
        }
      });

      // Initial load for Live Assignments on page refresh
      this.$nextTick(() => {
        if (this.activeTab === 'overview') {
          this.loadLiveAssignments();
        }
      });

      // ==================== CHART INITIALIZATIONS ====================

      // Revenue Trend Chart
      const ctx = document.getElementById('trendChart');
      if (ctx && <?= json_encode(!empty($chart_dates)) ?>) {
        new Chart(ctx.getContext('2d'), {
          type: 'line',
          data: { 
            labels: <?= json_encode($chart_dates) ?>, 
            datasets: <?= json_encode($chart_datasets) ?> 
          },
          options: {
            responsive: true, maintainAspectRatio: false,
            interaction: { mode: 'index', intersect: false },
            scales: {
              x: { grid: { display: false, drawBorder: false }, ticks: { color: '#6B7A6B', font: { family: 'Poppins', size: 11, weight: '500' } }, border: { display: false } },
              y: { grid: { color: 'rgba(0,0,0,0.04)', drawBorder: false }, ticks: { color: '#6B7A6B', font: { family: 'Poppins', size: 11, weight: '500' }, callback: v => '₹' + (v/1000).toFixed(0) + 'k' }, border: { display: false } }
            },
            plugins: {
              legend: { position: 'bottom', labels: { color: '#495449', usePointStyle: true, font: { family: 'Poppins', size: 12, weight: '600' }, padding: 18 } },
              tooltip: {
                backgroundColor: '#FFFFFF', borderColor: 'rgba(0,0,0,0.1)', borderWidth: 1,
                titleColor: '#1F231F', bodyColor: '#495449', titleFont: { family: 'Poppins', size: 12, weight: '600' },
                padding: 12, boxPadding: 6,
                callbacks: { label: ctx => ' ₹' + Number(ctx.raw).toLocaleString('en-IN') }
              }
            }
          }
        });
      }

      const overviewPalette = ['#16A34A', '#2563EB', '#D97706', '#9333EA', '#DC2626', '#059669', '#0F766E', '#7C3AED'];
      const commonChartPlugins = {
        legend: { labels: { color: '#495449', usePointStyle: true, font: { family: 'Poppins', size: 11, weight: '600' }, padding: 14 } },
        tooltip: {
          backgroundColor: '#FFFFFF', borderColor: 'rgba(0,0,0,0.1)', borderWidth: 1,
          titleColor: '#1F231F', bodyColor: '#495449', titleFont: { family: 'Poppins', size: 12, weight: '700' },
          bodyFont: { family: 'Poppins', size: 12, weight: '500' }, padding: 12, boxPadding: 6
        }
      };
      const axisFont = { family: 'Poppins', size: 11, weight: '500' };
      const compactAxis = {
        x: { grid: { color: 'rgba(0,0,0,0.04)', drawBorder: false }, ticks: { color: '#6B7A6B', font: axisFont, precision: 0 }, border: { display: false } },
        y: { grid: { display: false, drawBorder: false }, ticks: { color: '#495449', font: axisFont }, border: { display: false } }
      };

      // Equipment Bookings Chart
      const equipmentBookingsCtx = document.getElementById('equipmentBookingsChart');
      if (equipmentBookingsCtx && <?= json_encode(!empty($equipment_booking_labels)) ?>) {
        new Chart(equipmentBookingsCtx.getContext('2d'), {
          type: 'bar',
          data: {
            labels: <?= json_encode($equipment_booking_labels) ?>,
            datasets: [{ data: <?= json_encode($equipment_booking_values) ?>, backgroundColor: overviewPalette, borderRadius: 8, borderSkipped: false, barThickness: 18 }]
          },
          options: {
            indexAxis: 'y', responsive: true, maintainAspectRatio: false,
            onClick: (event, elements, chart) => {
              if (elements.length) this.fetchEquipmentFarmers(chart.data.labels[elements[0].index]);
            },
            scales: compactAxis,
            plugins: { 
              ...commonChartPlugins, 
              legend: { display: false }, 
              tooltip: { 
                ...commonChartPlugins.tooltip, 
                callbacks: { label: ctx => ` ${Number(ctx.raw).toLocaleString('en-IN')} bookings` } 
              } 
            }
          }
        });
      }

      // Equipment Revenue Chart
      const equipmentRevenueCtx = document.getElementById('equipmentRevenueChart');
      if (equipmentRevenueCtx && <?= json_encode(!empty($equipment_revenue_labels)) ?>) {
        new Chart(equipmentRevenueCtx.getContext('2d'), {
          type: 'doughnut',
          data: {
            labels: <?= json_encode($equipment_revenue_labels) ?>,
            datasets: [{ data: <?= json_encode($equipment_revenue_values) ?>, backgroundColor: overviewPalette, borderWidth: 3, borderColor: '#FFFFFF', hoverOffset: 6 }]
          },
          options: {
            responsive: true, maintainAspectRatio: false, cutout: '64%',
            plugins: { 
              ...commonChartPlugins, 
              legend: { position: 'right', labels: commonChartPlugins.legend.labels }, 
              tooltip: { 
                ...commonChartPlugins.tooltip, 
                callbacks: { label: ctx => ` ${ctx.label}: ₹${Number(ctx.raw).toLocaleString('en-IN')}` } 
              } 
            }
          }
        });
      }

      // Crop Demand Chart
      const cropDemandCtx = document.getElementById('cropDemandChart');
      if (cropDemandCtx && <?= json_encode(!empty($crop_labels)) ?>) {
        new Chart(cropDemandCtx.getContext('2d'), {
          type: 'bar',
          data: {
            labels: <?= json_encode($crop_labels) ?>,
            datasets: [{ data: <?= json_encode($crop_values) ?>, backgroundColor: '#16A34A', borderRadius: 8, borderSkipped: false, barThickness: 18 }]
          },
          options: {
            indexAxis: 'y', responsive: true, maintainAspectRatio: false,
            scales: compactAxis,
            plugins: { 
              ...commonChartPlugins, 
              legend: { display: false }, 
              tooltip: { 
                ...commonChartPlugins.tooltip, 
                callbacks: { label: ctx => ` ${Number(ctx.raw).toLocaleString('en-IN')} requests` } 
              } 
            }
          }
        });
      }

      // Farmer Category Chart
      const farmerCategoryCtx = document.getElementById('farmerCategoryChart');
      if (farmerCategoryCtx && <?= json_encode(!empty($farmer_category_labels)) ?>) {
        new Chart(farmerCategoryCtx.getContext('2d'), {
          type: 'doughnut',
          data: {
            labels: <?= json_encode($farmer_category_labels) ?>,
            datasets: [{ data: <?= json_encode($farmer_category_values) ?>, backgroundColor: ['#2563EB', '#D97706', '#16A34A'], borderWidth: 3, borderColor: '#FFFFFF', hoverOffset: 6 }]
          },
          options: {
            responsive: true, maintainAspectRatio: false, cutout: '60%',
            plugins: { 
              ...commonChartPlugins, 
              legend: { position: 'right', labels: commonChartPlugins.legend.labels }, 
              tooltip: { 
                ...commonChartPlugins.tooltip, 
                callbacks: { label: ctx => ` ${ctx.label}: ${Number(ctx.raw).toLocaleString('en-IN')} requests` } 
              } 
            }
          }
        });
      }
    },

    // ====================== LIVE ASSIGNMENTS ======================
    async loadLiveAssignments() {
      try {
        const res = await sFetch('get_current_assignments', {});
        if (res.success) {
          this.liveAssignments = res.assignments || [];
        } else {
          this.liveAssignments = [];
          console.warn('Live assignments failed:', res.error);
        }
      } catch (err) {
        console.error('Error loading live assignments:', err);
        this.liveAssignments = [];
      }
    },

    // ====================== DRILL DOWN METHODS ======================
    async fetchEquipmentFarmers(eqType) {
      if (this.selectedEqOverview === eqType) {
        this.selectedEqOverview = null;
        return;
      }
      
      this.selectedEqOverview = eqType;
      this.isEqFarmersLoading = true;
      this.eqFarmersList = [];

      const res = await sFetch('get_equipment_farmers', {
        equipment_type: eqType,
        start_date: '<?= $start_date ?>',
        end_date: '<?= $end_date ?>',
        client_code: '<?= $admin_scope ?>'
      });

      this.isEqFarmersLoading = false;
      if (res.success) {
        this.eqFarmersList = res.farmers;
      }
    },

    async openFarmerBookingProfile(farmer) {
      this.isDrawerOpen = true;
      await this.$nextTick();
      const el = document.getElementById('farmerDrawerContent');
      if (!el) return;

      const avatarHtml = farmer.profile_image_url
        ? `<img src="${farmer.profile_image_url}" style="width:80px; height:80px; border-radius:50%; object-fit:cover; margin:0 auto; display:block;">`
        : `<div style="width:80px; height:80px; border-radius:50%; background:var(--accent-dim); border: 1px solid rgba(22,163,74,0.3); display:flex; align-items:center; justify-content:center; font-size:32px; font-weight:700; color:var(--accent); margin:0 auto;">${farmer.name.charAt(0).toUpperCase()}</div>`;

      el.innerHTML = `
        <div style="text-align:center; padding-bottom:24px; border-bottom:1px solid var(--border); margin-bottom:24px;">
          ${avatarHtml}
          <div style="font-size:20px; font-weight:700; margin:16px 0 6px;">${farmer.name}</div>
          <div style="font-size:14px; color:var(--text-secondary); margin-bottom:16px;">${farmer.village || 'N/A'}</div>
          <a href="tel:${farmer.phone_number}" class="mono" style="background:var(--surface-3); padding:8px 18px; border-radius:var(--radius); border: 1px solid var(--border); text-decoration:none; font-weight:600; color:var(--text-primary); transition: all 0.15s;">
            <i class="ph-fill ph-phone"></i> ${farmer.phone_number}
          </a>
        </div>
        
        <div style="font-size:11px; font-weight:600; text-transform:uppercase; color:var(--text-muted); margin-bottom:12px; font-family: var(--font-mono); letter-spacing: 0.05em;">Current Request Details</div>
        
        <div style="background:var(--surface-2); border-radius:var(--radius); padding:16px; border: 1px solid var(--border);">
          <div style="display:flex; justify-content:space-between; margin-bottom:12px;">
             <span style="color:var(--text-muted); font-size:13px; font-weight:500;">Crop Type</span>
             <span style="font-weight:600; color:var(--text-primary);">${farmer.crop_type || 'Not Specified'}</span>
          </div>
          <div style="height: 1px; background: var(--border); margin-bottom: 12px;"></div>
          <div style="display:flex; justify-content:space-between; align-items: center;">
             <span style="color:var(--text-muted); font-size:13px; font-weight:500;">Total Area</span>
             <span style="font-weight:600; font-family: var(--font-mono); font-size: 15px; color:var(--accent); background: var(--accent-dim); padding: 4px 10px; border-radius: 6px;">
               ${farmer.land_size_acres && farmer.land_size_acres > 0 ? parseFloat(farmer.land_size_acres) + ' Acres' : 'N/A'}
             </span>
          </div>
        </div>
      `;
    },

    // ====================== BOOKING & TASK METHODS ======================
    async openTaskDetails(bId) {
      this.isTaskOpen = true;
      this.taskData = null;
      const res = await sFetch('get_task_details', { booking_id: bId });
      if (res.success) this.taskData = res.data;
      else { 
        showToast('Details not found', 'error'); 
        this.isTaskOpen = false; 
      }
    },

    updateStatus(id, status) {
      const color = status === 'Cancelled' ? '#DC2626' : '#16A34A';
      Swal.fire({
        title: `Mark as ${status}?`, text: status === 'Cancelled' ? 'This action cannot be undone.' : '',
        icon: status === 'Cancelled' ? 'warning' : 'question', background: '#FFFFFF', color: '#1F231F',
        showCancelButton: true, confirmButtonColor: color, confirmButtonText: 'Confirm'
      }).then(r => {
        if (r.isConfirmed) {
          sFetch('update_booking_status', { booking_id: id, status }).then(res => {
            if (res.success) { showToast(status === 'Completed' ? 'Booking marked complete ✓' : 'Booking cancelled'); setTimeout(() => window.location.reload(), 800); }
            else showToast(res.error || 'Update failed', 'error');
          });
        }
      });
    },

    operatorCancel(id) {
      Swal.fire({
        title: 'Record operator cancellation?',
        html: `<p style="color:#6B7A6B; font-size:13.5px; margin-bottom:14px; font-weight:500;">This will keep the order active, remove the assigned operator, record the cancellation, and make the order available for reassignment.</p>
               <textarea id="swal-cancel-reason" style="background:#F3F2EE; border:1px solid rgba(0,0,0,0.15); color:#1F231F; padding:10px 14px; border-radius:8px; width:100%; min-height:90px; resize:vertical;" placeholder="Reason given by operator"></textarea>`,
        icon: 'warning', background: '#FFFFFF', color: '#1F231F', showCancelButton: true, confirmButtonColor: '#DC2626', confirmButtonText: 'Record & Release', cancelButtonText: 'Close', focusConfirm: false,
        preConfirm: () => { const el = document.getElementById('swal-cancel-reason'); return el ? el.value.trim() : ''; }
      }).then(r => {
        if (r.isConfirmed) {
          sFetch('operator_cancel_booking', { booking_id: id, reason: r.value || '', created_by: 'admin' }).then(res => {
            if (res.success) { showToast('Operator cancellation recorded. Order is ready for reassignment.'); setTimeout(() => window.location.reload(), 800); }
            else { showToast(res.error || 'Unable to record operator cancellation', 'error'); }
          });
        }
      });
    },

    reschedule(id, currentDate) {
      Swal.fire({
        title: 'Reschedule Booking',
        html: `<p style="color:#6B7A6B; font-size:13.5px; margin-bottom:14px; font-weight:500;">Operator will be automatically unassigned.</p>
               <input type="text" id="swal-date" style="background:#F3F2EE; border:1px solid rgba(0,0,0,0.15); color:#1F231F; padding:10px 14px; border-radius:8px; width:100%;" placeholder="Select new date">`,
        background: '#FFFFFF', color: '#1F231F', showCancelButton: true, confirmButtonColor: '#D97706', confirmButtonText: 'Reschedule', focusConfirm: false,
        didOpen: () => { flatpickr("#swal-date", { defaultDate: currentDate, minDate: "today", dateFormat: "Y-m-d", disableMobile: true }); },
        preConfirm: () => {
          const d = document.getElementById('swal-date').value;
          if (!d || d === currentDate) { Swal.showValidationMessage('Please choose a different date'); return false; }
          return d;
        }
      }).then(r => {
        if (r.isConfirmed) {
          sFetch('reschedule_booking', { booking_id: id, new_date: r.value }).then(res => {
            if (res.success) { showToast('Rescheduled to ' + r.value); setTimeout(() => window.location.reload(), 800); }
            else showToast(res.error || 'Reschedule failed', 'error');
          });
        }
      });
    },

    async openAssignModal(bId, eqType) {
      this.currentBookingId = bId;
      this.isAssignOpen = true;
      this.availableOperators = [];
      this.selectedOperator = null;
      this.isAssignLoading = true;
      const data = await sFetch('get_available_operators', { booking_id: bId, equipment_type: eqType });
      this.isAssignLoading = false;
      if (data.operators) this.availableOperators = data.operators;
      if (data.error) showToast(data.error, 'error');
    },

    confirmAssign() {
      if (!this.selectedOperator) return;
      sFetch('assign_operator', { booking_id: this.currentBookingId, operator_id: this.selectedOperator.operator_id }).then(res => {
        if (res.success) { showToast(`${this.selectedOperator.name} assigned ✓`); this.isAssignOpen = false; setTimeout(() => window.location.reload(), 600); }
        else { showToast(res.error || 'Assignment failed', 'error'); }
      });
    },

    // ====================== PROFILE DRAWER ======================
    async openProfile(uid) {
      this.isDrawerOpen = true;
      await this.$nextTick();
      const el = document.getElementById('farmerDrawerContent');
      if (!el) return;
      
      el.innerHTML = `<div style="text-align:center; padding:40px 0;"><i class="ph-duotone ph-spinner-gap animate-spin" style="font-size:32px;"></i></div>`;

      const data = await sFetch('get_farmer_details', { user_id: uid });
      if (!data.user) { 
        el.innerHTML = '<p style="color:var(--red);">Failed to load profile.</p>'; 
        return; 
      }

      const u = data.user;
      const avatarHtml = u.profile_image_url
        ? `<img src="${u.profile_image_url}" style="width:80px; height:80px; border-radius:50%; object-fit:cover; margin:0 auto; display:block;">`
        : `<div style="width:80px; height:80px; border-radius:50%; background:var(--accent-dim); display:flex; align-items:center; justify-content:center; font-size:32px; font-weight:700; color:var(--accent); margin:0 auto;">${u.name[0].toUpperCase()}</div>`;

      let histHtml = data.history.length === 0 
        ? `<div style="text-align:center; color:var(--text-muted); padding:20px;">No history.</div>`
        : data.history.map(x => `
            <div style="background:var(--surface-2); border-radius:var(--radius); padding:14px; margin-bottom:10px;">
              <div style="display:flex; justify-content:space-between; font-weight:700;">
                <span>${x.equipment_type}</span>
                <span>₹${Number(x.total_cost).toLocaleString('en-IN')}</span>
              </div>
              <div style="display:flex; justify-content:space-between; font-size:12px; color:var(--text-muted);">
                <span>${x.service_date}</span>
                <span>${x.booking_status}</span>
              </div>
            </div>`).join('');

      el.innerHTML = `
        <div style="text-align:center; padding-bottom:24px; border-bottom:1px solid var(--border); margin-bottom:24px;">
          ${avatarHtml}
          <div style="font-size:20px; font-weight:700; margin:16px 0 6px;">${u.name}</div>
          <div style="font-size:14px; color:var(--text-secondary); margin-bottom:16px;">${u.village || 'N/A'}</div>
          <a href="tel:${u.phone_number}" class="mono" style="background:var(--surface-3); padding:8px 18px; border-radius:var(--radius); text-decoration:none; font-weight:600; color:var(--text-primary);">
            <i class="ph-fill ph-phone"></i> ${u.phone_number}
          </a>
        </div>
        <div style="font-size:11px; font-weight:600; text-transform:uppercase; color:var(--text-muted); margin-bottom:12px;">Recent Bookings</div>
        ${histHtml}`;
    }

  }));
});
</script>
</body>
</html>