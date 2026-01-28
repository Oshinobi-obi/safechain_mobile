<?php

include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

$token = $data['token'] ?? null;
$new_password = $data['password'] ?? null;

if (!$token || !$new_password) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Token and new password are required.']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT email FROM password_resets WHERE token = ? AND created_at >= NOW() - INTERVAL 1 HOUR");
    $stmt->bind_param("s", $token);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid or expired token.']);
        $stmt->close();
        $conn->close();
        exit;
    }

    $row = $result->fetch_assoc();
    $email = $row['email'];
    $stmt->close();

    $hashed_password = password_hash($new_password, PASSWORD_DEFAULT);

    $update_stmt = $conn->prepare("UPDATE residents SET password = ? WHERE email = ?");
    $update_stmt->bind_param("ss", $hashed_password, $email);
    
    if ($update_stmt->execute()) {
        $delete_stmt = $conn->prepare("DELETE FROM password_resets WHERE email = ?");
        $delete_stmt->bind_param("s", $email);
        $delete_stmt->execute();
        $delete_stmt->close();

        http_response_code(200);
        echo json_encode(['status' => 'success', 'message' => 'Password has been reset successfully.']);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to update password.']);
    }

    $update_stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);

} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>