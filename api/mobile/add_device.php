<?php
// api/mobile/add_device.php

include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

$resident_id = $data['resident_id'] ?? null;
$name = $data['name'] ?? null;
$bt_remote_id = $data['bt_remote_id'] ?? null;

// Basic validation
if (!$resident_id || !$name || !$bt_remote_id) {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

try {
    $stmt = $conn->prepare(
        "INSERT INTO devices (resident_id, name, bt_remote_id) VALUES (?, ?, ?)"
    );
    $stmt->bind_param("sss", $resident_id, $name, $bt_remote_id);

    if ($stmt->execute()) {
        // Success
        http_response_code(201); // Created
        echo json_encode([
            'status' => 'success',
            'message' => 'Device added successfully.',
            'device_id' => $conn->insert_id
        ]);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to add device. Please try again later.']);
    }

    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    // Check for duplicate entry specifically for bt_remote_id if you have a unique constraint
    if ($conn->errno == 1062) {
         http_response_code(409); // Conflict
         echo json_encode(['status' => 'error', 'message' => 'This device has already been registered.']);
    } else {
        echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);
    }
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
