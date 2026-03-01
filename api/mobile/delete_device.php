<?php
ob_start();
include 'db_connection.php';
ob_clean();
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data      = json_decode(file_get_contents('php://input'), true);
$device_id = $data['device_id'] ?? null;

if (!$device_id) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'device_id is required.']);
    exit;
}

try {
    $stmt = $conn->prepare("DELETE FROM devices WHERE device_id = ?");
    $stmt->bind_param("i", $device_id);
    if ($stmt->execute()) {
        echo json_encode(['status' => 'success', 'message' => 'Device unlinked successfully.']);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to unlink device.']);
    }
    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
} finally {
    $conn->close();
}