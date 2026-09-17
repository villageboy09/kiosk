<?php
// ############ CROPSYNC MANAGER LOGIN - SIMPLIFIED (Selection moved to Dashboard) ############

session_name('CROPSYNC_CEO_SESSION');
session_start();

@include 'config.php';
if (!isset($conn)) {
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    try { 
        $conn = new mysqli("localhost", "root", "", "u511597003_kiosk"); 
    }
    catch (Exception $e) { 
        die("Database connection failed."); 
    }
}

// If already logged in, redirect to dashboard
if (isset($_SESSION['admin_id'])) {
    header("Location: chc_manager.php");
    exit;
}

$error = '';

// Handle Login
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    
    $email = trim($_POST['email']);
    $password = $_POST['password'];

    $stmt = $conn->prepare("SELECT id, role, password FROM admins WHERE email = ? LIMIT 1");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 1) {
        $admin = $result->fetch_assoc();
        
        // Plain text password (as per your current system)
        if ($password === $admin['password']) {
            
            $_SESSION['admin_id'] = $admin['id'];
            $_SESSION['admin_role'] = $admin['role'];

            if ($admin['role'] === 'super_admin') {
                $_SESSION['allowed_client_codes'] = ['ALL'];
                $_SESSION['current_client_code'] = 'ALL';
                $_SESSION['admin_scope'] = 'ALL';
            } else {
                // Fetch all client codes assigned to this admin
                $code_stmt = $conn->prepare("SELECT client_code FROM admin_client_codes WHERE admin_id = ?");
                $code_stmt->bind_param("i", $admin['id']);
                $code_stmt->execute();
                $code_res = $code_stmt->get_result();
                
                $codes = [];
                while ($r = $code_res->fetch_assoc()) {
                    $codes[] = $r['client_code'];
                }

                if (empty($codes)) {
                    $error = "Access Denied: No workspace assigned to this account.";
                } else {
                    $_SESSION['allowed_client_codes'] = $codes;
                    $_SESSION['current_client_code'] = $codes[0];     // Default to first
                    $_SESSION['admin_scope'] = $codes[0];
                }
            }

            if (empty($error)) {
                header("Location: chc_manager.php");
                exit;
            }
        } else {
            $error = "Invalid email or password.";
        }
    } else {
        $error = "Invalid email or password.";
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Manager Login | CropSync</title>
    
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/@phosphor-icons/web"></script>
    
    <style>
        :root {
            --bg-body: #F9FAFB;
            --bg-card: #FFFFFF;
            --border: #E5E7EB;
            --accent: #22C55E;
            --accent-hover: #16A34A;
            --text-main: #111827;
            --text-muted: #6B7280;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Poppins', sans-serif;
            background-color: var(--bg-body);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .login-card {
            background: var(--bg-card);
            padding: 48px 40px;
            border-radius: 20px;
            width: 100%;
            max-width: 420px;
            box-shadow: 0 20px 40px -10px rgba(0,0,0,0.05);
            text-align: center;
        }

        .logo-img {
            height: 56px; 
            width: auto;
            display: block;
            margin: 0 auto 24px;
        }

        h2 { font-size: 22px; font-weight: 600; margin-bottom: 8px; }
        p.sub { color: var(--text-muted); font-size: 14px; margin-bottom: 32px; line-height: 1.5; }
        
        .input-wrapper { position: relative; margin-bottom: 20px; text-align: left; }
        
        .input-icon { 
            position: absolute; left: 16px; top: 50%; transform: translateY(-50%); 
            color: #9CA3AF; font-size: 20px; 
        }
        
        input {
            width: 100%;
            padding: 14px 16px 14px 46px;
            border: 1px solid var(--border);
            border-radius: 12px;
            font-size: 14px;
            font-family: 'Poppins', sans-serif;
            outline: none;
        }
        input:focus { border-color: var(--accent); box-shadow: 0 0 0 4px rgba(34, 197, 94, 0.1); }

        button {
            width: 100%; padding: 14px;
            background: var(--accent); color: white; border: none;
            border-radius: 12px; font-weight: 600; font-size: 15px;
            cursor: pointer;
        }
        button:hover { background: var(--accent-hover); }

        .error-msg {
            background: #FEF2F2; color: #EF4444;
            padding: 12px; border-radius: 10px; margin-top: 20px;
            border: 1px solid #FCA5A5;
            display: flex; align-items: center; gap: 8px;
        }

        .footer { margin-top: 28px; font-size: 12px; color: #9CA3AF; }
    </style>
</head>
<body>

    <div class="login-card">
        <img src="Logo.jpeg" alt="CropSync Logo" class="logo-img">
        
        <h2>Manager Login</h2>
        <p class="sub">Access your CropSync CHC Workspace</p>
        
        <form method="POST">
            <div class="input-wrapper">
                <input type="email" name="email" placeholder="Email Address" required autofocus>
                <i class="ph-bold ph-envelope-simple input-icon"></i>
            </div>

            <div class="input-wrapper">
                <input type="password" name="password" placeholder="Password" required>
                <i class="ph-bold ph-lock-key input-icon"></i>
            </div>

            <button type="submit">Sign In</button>

            <?php if($error): ?>
                <div class="error-msg">
                    <i class="ph-fill ph-warning-circle"></i> <?= htmlspecialchars($error) ?>
                </div>
            <?php endif; ?>
        </form>

        <div class="footer">
            &copy; <?= date('Y') ?> CropSync • Secure Workspace
        </div>
    </div>

</body>
</html>