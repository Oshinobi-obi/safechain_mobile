<?php
ob_start();
include 'db_connection.php';
ob_clean();
header('Content-Type: application/json');

$bt_remote_id = $_GET['bt_remote_id'] ?? null;
$resident_id  = $_GET['resident_id'] ?? null;

if (!$bt_remote_id) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'bt_remote_id is required.']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT resident_id FROM devices WHERE bt_remote_id = ? LIMIT 1");
    $stmt->bind_param("s", $bt_remote_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        // Device not linked to anyone — free to add
        echo json_encode(['status' => 'available']);
    } else {
        $row = $result->fetch_assoc();
        if ($resident_id && $row['resident_id'] === $resident_id) {
            // Already linked to this same user
            echo json_encode(['status' => 'owned']);
        } else {
            // Linked to a different account
            echo json_encode(['status' => 'taken']);
        }
    }
    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
} finally {
    $conn->close();
}