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
$name = $data['name'] ?? null;
$bt_remote_id = $data['bt_remote_id'] ?? null;

if (!$resident_id || !$name || !$bt_remote_id) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

try {
    // --- FEATURE 1: Check 1:1 Device-to-Account Ratio ---
    $check_account_stmt = $conn->prepare("SELECT device_id FROM devices WHERE resident_id = ? AND status != 'deactivated'");
    $check_account_stmt->bind_param("s", $resident_id);
    $check_account_stmt->execute();
    if ($check_account_stmt->get_result()->num_rows > 0) {
        http_response_code(403);
        echo json_encode(['status' => 'error', 'message' => 'You already have an active device registered to your account.']);
        $check_account_stmt->close();
        exit;
    }
    $check_account_stmt->close();

    // --- FEATURE 2: Check 1 Device Per Household ---
    // Fetch the resident's registered address
    $address_stmt = $conn->prepare("SELECT address FROM residents WHERE resident_id = ?");
    $address_stmt->bind_param("s", $resident_id);
    $address_stmt->execute();
    $res_result = $address_stmt->get_result();

    if ($res_result->num_rows > 0) {
        $address = $res_result->fetch_assoc()['address'];

        // Check if any active device is already registered under this address
        $household_stmt = $conn->prepare("
            SELECT d.device_id
            FROM devices d
            JOIN residents r ON d.resident_id = r.resident_id
            WHERE r.address = ? AND d.status != 'deactivated'
        ");
        $household_stmt->bind_param("s", $address);
        $household_stmt->execute();

        if ($household_stmt->get_result()->num_rows > 0) {
            http_response_code(403);
            echo json_encode(['status' => 'error', 'message' => 'A device is already registered for this household/address.']);
            $household_stmt->close();
            $address_stmt->close();
            exit;
        }
        $household_stmt->close();
    }
    $address_stmt->close();

    // --- Original Insert Logic ---
    $stmt = $conn->prepare(
        "INSERT INTO devices (resident_id, name, bt_remote_id) VALUES (?, ?, ?)"
    );
    $stmt->bind_param("sss", $resident_id, $name, $bt_remote_id);

    if ($stmt->execute()) {
        http_response_code(201);
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
    if ($conn->errno == 1062) {
         http_response_code(409);
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