<?php
/**
 * CancerCare Connect - configuration + PDO connection.
 * Default XAMPP: user "root", empty password.
 * If your folder name is different, change BASE_URL below.
 */

define('APP_NAME', 'Cancer Care Connect');
define('BASE_URL', '/cancercare-connect');          // URL path of this project
define('UPLOAD_DIR', dirname(__DIR__) . '/uploads'); // protected by uploads/.htaccess
define('MAX_UPLOAD_BYTES', 5 * 1024 * 1024);         // 5 MB

define('DB_HOST', 'localhost');
define('DB_NAME', 'cancercare_connect');
define('DB_USER', 'root');
define('DB_PASS', '');

date_default_timezone_set('Asia/Colombo');

try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );
} catch (PDOException $e) {
    error_log('DB connection failed: ' . $e->getMessage());
    http_response_code(500);
    die('Database connection failed. Start Apache and MySQL in XAMPP and import database/cancercare_connect.sql in phpMyAdmin.');
}
