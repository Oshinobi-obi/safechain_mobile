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

$data       = json_decode(file_get_contents('php://input'), true);
$device_id  = $data['device_id'] ?? null;
$name       = $data['name'] ?? null;

if (!$device_id || !$name) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'device_id and name are required.']);
    exit;
}

try {
    $stmt = $conn->prepare("UPDATE devices SET name = ? WHERE device_id = ?");
    $stmt->bind_param("si", $name, $device_id);
    if ($stmt->execute()) {
        echo json_encode(['status' => 'success', 'message' => 'Device name updated.']);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to update device.']);
    }
    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
} finally {
    $conn->close();
}