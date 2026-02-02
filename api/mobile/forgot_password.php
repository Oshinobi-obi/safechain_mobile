<?php

include 'db_connection.php';

require '../../vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$email = $_POST['email'] ?? null;

if (!$email) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Email is required.']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT resident_id FROM residents WHERE email = ? AND is_archived = 0");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $stmt->store_result();

    if ($stmt->num_rows === 0) {
        http_response_code(200);
        echo json_encode(['status' => 'success', 'message' => 'If an account with that email exists, a password reset link has been sent.']);
        exit;
    }
    $stmt->close();

    $token = bin2hex(random_bytes(32));
    $delete_stmt = $conn->prepare("DELETE FROM password_resets WHERE email = ?");
    $delete_stmt->bind_param("s", $email);
    $delete_stmt->execute();
    $delete_stmt->close();

    $insert_stmt = $conn->prepare("INSERT INTO password_resets (email, token) VALUES (?, ?)");
    $insert_stmt->bind_param("ss", $email, $token);
    $insert_stmt->execute();
    $insert_stmt->close();

    $mail = new PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host       = 'smtp.gmail.com';
        $mail->SMTPAuth   = true;
        $mail->Username   = '';
        $mail->Password   = '';
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = 587;
        $mail->setFrom('', '');
        $mail->addAddress($email);
        $reset_link = "https://safechain.site/reset-password-page?token=" . $token;
        $mail->isHTML(true);
        $mail->Subject = 'Password Reset Request for SafeChain';
        $mail->Body    = "Hello,<br><br>Please click the following link to reset your password: <a href=\"".$reset_link."\">Reset Password</a><br><br>This link will expire in one hour.";
        $mail->AltBody = 'Please use the following link to reset your password: ' . $reset_link;

        $mail->send();

    } catch (Exception $e) {
        error_log("PHPMailer Error: " . $mail->ErrorInfo);
    }
    
    http_response_code(200);
    echo json_encode(['status' => 'success', 'message' => 'If an account with that email exists, a password reset link has been sent.']);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
