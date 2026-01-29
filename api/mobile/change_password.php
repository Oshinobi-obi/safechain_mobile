<?php
include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

$resident_id = $data['resident_id'] ?? null;
$current_password = $data['current_password'] ?? null;
$new_password = $data['new_password'] ?? null;

if (!$resident_id || !$current_password || !$new_password) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT password FROM residents WHERE resident_id = ?");
    $stmt->bind_param("s", $resident_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'User not found.']);
        $stmt->close();
        exit;
    }

    $user = $result->fetch_assoc();
    $stored_hash = $user['password'];
    $stmt->close();

    if (!password_verify($current_password, $stored_hash)) {
        http_response_code(401);
        echo json_encode(['status' => 'error', 'message' => 'Incorrect current password.']);
        exit;
    }

    $new_password_hash = password_hash($new_password, PASSWORD_BCRYPT);
    $update_stmt = $conn->prepare("UPDATE residents SET password = ? WHERE resident_id = ?");
    $update_stmt->bind_param("ss", $new_password_hash, $resident_id);

    if ($update_stmt->execute()) {
        http_response_code(200);
        echo json_encode(['status' => 'success', 'message' => 'Password updated successfully.']);
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