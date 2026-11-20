<?php
/**
 * Session, role-based access control (RBAC), CSRF, flash messages and shared helpers.
 * Every page starts with:  require_once __DIR__ . '/../includes/auth.php';
 */

require_once __DIR__ . '/../config/database.php';

if (session_status() === PHP_SESSION_NONE) {
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'secure'   => !empty($_SERVER['HTTPS']),
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    session_start();
}

/* ---------- output + navigation helpers ---------- */

function e($value): string {
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function url(string $path = ''): string {
    return BASE_URL . '/' . ltrim($path, '/');
}

function redirect(string $path): void {
    header('Location: ' . url($path));
    exit;
}

function lkr($amount): string {
    return 'LKR ' . number_format((float)$amount, 2);
}

function label(string $value): string {
    return ucwords(str_replace('_', ' ', $value));
}

function statusBadge(string $status): string {
    $map = [
        'verified' => 'success', 'approved' => 'success', 'disbursed' => 'success', 'active' => 'success',
        'pending' => 'warning', 'submitted' => 'primary', 'under_review' => 'info', 'pending_approval' => 'warning',
        'needs_info' => 'warning', 'needs_more_info' => 'warning',
        'duplicate_flagged' => 'danger', 'rejected' => 'danger', 'suspended' => 'danger', 'cancelled' => 'secondary',
        'critical' => 'danger', 'high' => 'warning', 'standard' => 'secondary',
    ];
    $c = $map[$status] ?? 'secondary';
    return '<span class="badge text-bg-' . $c . '">' . e(label($status)) . '</span>';
}

/* ---------- session / roles ---------- */

function isLoggedIn(): bool {
    return isset($_SESSION['user_id'], $_SESSION['user_role']);
}

function currentUser(): array {
    return [
        'id'   => $_SESSION['user_id'] ?? null,
        'name' => $_SESSION['user_name'] ?? '',
        'role' => $_SESSION['user_role'] ?? '',
    ];
}

function homeFor(string $role): string {
    return $role . '/dashboard.php';
}

/** Stop anyone whose role is not allowed - prevents URL tampering. */
function requireRole(array $allowed): void {
    if (!isLoggedIn()) {
        redirect('login.php?error=unauthorized');
    }
    if (!in_array($_SESSION['user_role'], $allowed, true)) {
        http_response_code(403);
        redirect(homeFor($_SESSION['user_role']) . '?error=forbidden');
    }
}

/* ---------- CSRF ---------- */

function csrfToken(): string {
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function csrfField(): string {
    return '<input type="hidden" name="csrf" value="' . e(csrfToken()) . '">';
}

/** Call at the top of every POST handler. */
function verifyCsrf(): void {
    $sent = $_POST['csrf'] ?? '';
    if (!is_string($sent) || !hash_equals($_SESSION['csrf'] ?? '', $sent)) {
        http_response_code(419);
        die('Security token expired. Go back, refresh the page and try again.');
    }
}

/* ---------- flash messages ---------- */

function flash(string $type, string $message): void {
    $_SESSION['flash'][] = ['type' => $type, 'message' => $message];
}

function takeFlashes(): array {
    $f = $_SESSION['flash'] ?? [];
    unset($_SESSION['flash']);
    return $f;
}

/* ---------- audit log + notifications ---------- */

function clientIp(): string {
    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

function logAudit(PDO $pdo, string $module, string $action, string $details, string $severity = 'info', ?int $userId = null, ?string $role = null): void {
    $stmt = $pdo->prepare(
        'INSERT INTO audit_logs (user_id, user_role, module, action, details, ip_address, severity)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $userId ?? ($_SESSION['user_id'] ?? null),
        $role ?? ($_SESSION['user_role'] ?? null),
        $module, $action, $details, clientIp(), $severity,
    ]);
}

function notify(PDO $pdo, int $userId, string $title, string $message, string $category = 'system', ?int $requestId = null): void {
    $stmt = $pdo->prepare(
        'INSERT INTO notifications (recipient_user_id, title, message, category, related_request_id)
         VALUES (?, ?, ?, ?, ?)'
    );
    $stmt->execute([$userId, $title, $message, $category, $requestId]);
}

function unreadCount(PDO $pdo): int {
    if (!isLoggedIn()) return 0;
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM notifications WHERE recipient_user_id = ? AND is_read = 0');
    $stmt->execute([$_SESSION['user_id']]);
    return (int)$stmt->fetchColumn();
}

/* ---------- lookups used by several pages ---------- */

const SL_DISTRICTS = [
    'Colombo','Gampaha','Kalutara','Kandy','Matale','Nuwara Eliya','Galle','Matara','Hambantota',
    'Jaffna','Kilinochchi','Mannar','Vavuniya','Mullaitivu','Batticaloa','Ampara','Trincomalee',
    'Kurunegala','Puttalam','Anuradhapura','Polonnaruwa','Badulla','Monaragala','Ratnapura','Kegalle',
];

const SL_HOSPITALS = [
    'Apeksha Hospital Maharagama (National Cancer Institute of Sri Lanka)',
    'Teaching Hospital Kandy (Cancer Treatment Center)',
    'Teaching Hospital Karapitiya, Galle (Oncology Unit)',
    'Teaching Hospital Jaffna',
    'Teaching Hospital Anuradhapura (Oncology Care Unit)',
    'Provincial General Hospital Badulla (Cancer Treatment Wing)',
    'Teaching Hospital Batticaloa (Oncology Unit)',
    'Teaching Hospital Ratnapura (Oncology Clinic)',
];

function getPatientProfile(PDO $pdo, int $userId): ?array {
    $stmt = $pdo->prepare('SELECT * FROM patient_profiles WHERE user_id = ?');
    $stmt->execute([$userId]);
    return $stmt->fetch() ?: null;
}

function getCharityProfile(PDO $pdo, int $userId): ?array {
    $stmt = $pdo->prepare('SELECT * FROM charities WHERE user_id = ?');
    $stmt->execute([$userId]);
    return $stmt->fetch() ?: null;
}

function getCategories(PDO $pdo): array {
    return $pdo->query('SELECT * FROM aid_categories WHERE is_active = 1 ORDER BY name')->fetchAll();
}

/** Valid Sri Lankan NIC: old format 9 digits + V/X, or new format 12 digits. */
function validNic(string $nic): bool {
    return (bool)preg_match('/^(\d{9}[VvXx]|\d{12})$/', $nic);
}
