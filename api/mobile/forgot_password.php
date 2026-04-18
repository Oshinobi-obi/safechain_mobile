<?php
ob_start();

ini_set('display_errors', 0);
ini_set('log_errors', 1);
set_time_limit(30);
ignore_user_abort(true);

include 'db_connection.php';

ob_clean();
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);
$email = $data['email'] ?? $_POST['email'] ?? null;

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
        $stmt->close();
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

<<<<<<< HEAD
    $conn->close();
=======
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
>>>>>>> ca0f650a0731c047b404bc8b184d2b43328be640

    // Send response to Flutter immediately
    http_response_code(200);
    $json_response = json_encode(['status' => 'success', 'message' => 'If an account with that email exists, a password reset link has been sent.']);
    header('Content-Length: ' . strlen($json_response));
    echo $json_response;
    ob_end_flush();
    flush();

    // Build HTML email
    $reset_link = "https://safechain.site/reset-password-page?token=" . $token;
    $subject = '🔐 Password Reset Request - SafeChain';

    $html_body = '
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0; padding:0; background-color:#f0fdf4; font-family: Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0fdf4; padding: 40px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff; border-radius:16px; overflow:hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08);">

          <!-- Header -->
          <tr>
            <td align="center" style="background: linear-gradient(135deg, #20C997, #12b886); padding: 40px 30px;">
              <img src="https://safechain.site/images/logo.png" alt="SafeChain Logo" width="80" style="border-radius:50%; background:#d1fae5; padding:10px; display:block; margin: 0 auto 16px auto;">
              <h1 style="color:#ffffff; margin:0; font-size:26px; font-weight:bold; letter-spacing:1px;">SafeChain</h1>
              <p style="color:#d1fae5; margin:6px 0 0 0; font-size:14px;">Community Safety & Incident Reporting</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding: 40px 40px 20px 40px;">
              <h2 style="color:#1a1a1a; font-size:22px; margin:0 0 12px 0;">🔐 Password Reset Request</h2>
              <p style="color:#555; font-size:15px; line-height:1.7; margin:0 0 20px 0;">
                Hey there! 👋 We received a request to reset the password for your SafeChain account.
                No worries — it happens to the best of us!
              </p>
              <p style="color:#555; font-size:15px; line-height:1.7; margin:0 0 30px 0;">
                Click the button below to create a new password. This link is valid for <strong>1 hour</strong> ⏰.
              </p>

              <!-- Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding: 10px 0 30px 0;">
                    <a href="' . $reset_link . '"
                       style="background: linear-gradient(135deg, #20C997, #12b886);
                              color: #ffffff;
                              text-decoration: none;
                              padding: 16px 40px;
                              border-radius: 50px;
                              font-size: 16px;
                              font-weight: bold;
                              display: inline-block;
                              box-shadow: 0 4px 15px rgba(32,201,151,0.4);">
                      🔑 Reset My Password
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Fallback link -->
              <p style="color:#888; font-size:13px; line-height:1.6; margin:0 0 10px 0;">
                If the button doesn\'t work, copy and paste this link into your browser:
              </p>
              <p style="word-break:break-all; font-size:12px; color:#20C997; margin:0 0 30px 0;">
                <a href="' . $reset_link . '" style="color:#20C997;">' . $reset_link . '</a>
              </p>

              <!-- Warning box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#fff8e6; border-left: 4px solid #f59e0b; border-radius:8px; margin-bottom:30px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="margin:0; color:#92400e; font-size:13px; line-height:1.6;">
                      ⚠️ <strong>Didn\'t request this?</strong> If you didn\'t ask to reset your password, you can safely ignore this email. Your account remains secure.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#f8fafc; padding:24px 40px; border-top:1px solid #e2e8f0;">
              <p style="margin:0; color:#94a3b8; font-size:12px; text-align:center; line-height:1.8;">
                © 2026 SafeChain. All rights reserved. 🛡️<br>
                This is an automated message, please do not reply to this email.<br>
                <a href="https://safechain.site" style="color:#20C997; text-decoration:none;">safechain.site</a>
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>';

    $plain_text = "Hello,\n\nWe received a request to reset your SafeChain password.\n\nReset your password here:\n" . $reset_link . "\n\nThis link expires in 1 hour.\n\nIf you didn't request this, ignore this email.\n\n- SafeChain Team";

    // Send as HTML email
    $headers  = "From: SafeChain Support <safechain.support@safechain.site>\r\n";
    $headers .= "Reply-To: safechain.support@safechain.site\r\n";
    $headers .= "MIME-Version: 1.0\r\n";
    $headers .= "Content-Type: text/html; charset=UTF-8\r\n";
    $headers .= "X-Mailer: PHP/" . phpversion();

    mail($email, $subject, $html_body, $headers);

} catch (\Exception $e) {
    ob_clean();
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);
<<<<<<< HEAD
    ob_end_flush();
}
=======
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
>>>>>>> ca0f650a0731c047b404bc8b184d2b43328be640
