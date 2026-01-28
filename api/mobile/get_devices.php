<?php

include 'db_connection.php';

header('Content-Type: application/json');

if (!isset($_GET['resident_id'])) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'resident_id is required.']);
    exit;
}

$resident_id = $_GET['resident_id'];

try {
    $stmt = $conn->prepare("SELECT device_id, name, bt_remote_id, battery, created_at FROM devices WHERE resident_id = ? ORDER BY created_at DESC");
    $stmt->bind_param("s", $resident_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $devices = [];
    while ($row = $result->fetch_assoc()) {
        $devices[] = $row;
    }

    http_response_code(200);
    echo json_encode(['status' => 'success', 'devices' => $devices]);

    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);

} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>