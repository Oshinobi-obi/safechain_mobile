<?php
// api/mobile/update_profile.php

include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

// --- Data Retrieval and Validation ---
$resident_id = $data['resident_id'] ?? null;
$name = $data['name'] ?? null;
$address = $data['address'] ?? null;
$contact = $data['contact'] ?? null;
$medical_conditions = $data['medical_conditions'] ?? []; // Expect an array

if (!$resident_id || !$name || !$address || !$contact) {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

// Convert the array of medical conditions to a JSON string for storage
$medical_conditions_json = json_encode($medical_conditions);

try {
    $stmt = $conn->prepare(
        "UPDATE residents SET name = ?, address = ?, contact = ?, medical_conditions = ? WHERE resident_id = ?"
    );
    $stmt->bind_param("sssss", $name, $address, $contact, $medical_conditions_json, $resident_id);

    if ($stmt->execute()) {
        // Check if any row was actually updated
        if ($stmt->affected_rows > 0) {
            // Fetch the updated user data to send back
            $select_stmt = $conn->prepare("SELECT resident_id, name, email, address, contact, medical_conditions FROM residents WHERE resident_id = ?");
            $select_stmt->bind_param("s", $resident_id);
            $select_stmt->execute();
            $updated_user = $select_stmt->get_result()->fetch_assoc();
            $select_stmt->close();

            http_response_code(200); // OK
            echo json_encode([
                'status' => 'success',
                'message' => 'Profile updated successfully.',
                'user' => $updated_user
            ]);
        } else {
            http_response_code(200); // OK, but nothing changed
            echo json_encode(['status' => 'success', 'message' => 'No changes were made to the profile.']);
        }
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to update profile.']);
    }

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
