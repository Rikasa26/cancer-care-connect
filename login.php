<?php
require_once __DIR__ . '/includes/auth.php';

if (isLoggedIn()) redirect(homeFor($_SESSION['user_role']));

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verifyCsrf();
    $email = strtolower(trim($_POST['email'] ?? ''));
    $password = $_POST['password'] ?? '';

    // very small brute-force guard: max 5 failures per 10 minutes per session
    $_SESSION['fails'] = array_filter($_SESSION['fails'] ?? [], fn($t) => $t > time() - 600);
    if (count($_SESSION['fails']) >= 5) {
        $error = 'Too many failed attempts. Please wait 10 minutes.';
    } else {
        $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if ($user && password_verify($password, $user['password_hash'])) {
            if ($user['status'] === 'suspended') {
                $error = 'This account has been suspended. Contact the administrator.';
            } else {
                session_regenerate_id(true); // defeats session fixation
                $_SESSION['user_id'] = (int)$user['id'];
                $_SESSION['user_name'] = $user['name'];
                $_SESSION['user_role'] = $user['role'];
                $_SESSION['csrf'] = bin2hex(random_bytes(32));
                unset($_SESSION['fails']);
                logAudit($pdo, 'AUTH', 'LOGIN', "{$user['email']} logged in.", 'info', (int)$user['id'], $user['role']);
                redirect(homeFor($user['role']));
            }
        } else {
            $_SESSION['fails'][] = time();
            logAudit($pdo, 'AUTH', 'LOGIN_FAILED', 'Failed login for ' . $email, 'warning', null, null);
            $error = 'Invalid email or password.';
        }
    }
}

$pageTitle = 'Login';
require __DIR__ . '/includes/header.php';
?>
<!-- Centered login box matching your dashboard layout and theme -->
<div class="row justify-content-center align-items-center flex-fill my-auto">
    <div class="col-md-6 col-lg-5">
        <div class="card p-4 shadow-sm">
            <div class="text-center mb-3">
                <img src="assets/images/logo.svg.png" alt="Logo" width="80" height="80" class="mb-2 object-fit-contain">
                <h2 class="h3 fw-bold">Welcome Back</h2>
                <p class="text-muted small">Sign in to Cancer Care Connect</p>
            </div>

            <?php if (!empty($error)): ?>
                <div class="alert alert-danger py-2 small"><?= htmlspecialchars($error); ?></div>
            <?php endif; ?>
    <?php if (($_GET['error'] ?? '') === 'unauthorized' && !$error): ?><div class="alert alert-warning">Please sign in to continue.</div><?php endif; ?>
    <?php if ($error): ?><div class="alert alert-danger"><?= e($error) ?></div><?php endif; ?>
    <form method="post" autocomplete="on">
      <?= csrfField() ?>
      <div class="mb-3"><label class="form-label">Email</label><input type="email" name="email" class="form-control" required autofocus></div>
      <div class="mb-3"><label class="form-label">Password</label><input type="password" name="password" class="form-control" required></div>
      <button class="btn btn-primary w-100">Login</button>
    </form>
    <hr>
    <p class="small text-muted mb-1"> (password <code>CancerCare@2024</code>):</p>
   
  </div></div>
</div></div>
<?php require __DIR__ . '/includes/footer.php'; ?>
