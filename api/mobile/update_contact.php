<?php
include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

$contact_id = $data['contact_id'] ?? null;
$name = $data['name'] ?? null;
$contact_number = $data['contact_number'] ?? null;
$relationship = $data['relationship'] ?? null;

if (!$contact_id || !$name || !$contact_number) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

try {
    $stmt = $conn->prepare("UPDATE emergency_contacts SET name = ?, contact_number = ?, relationship = ? WHERE contact_id = ?");
    $stmt->bind_param("sssi", $name, $contact_number, $relationship, $contact_id);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            http_response_code(200);
            echo json_encode(['status' => 'success', 'message' => 'Contact updated successfully.']);
        } else {
            http_response_code(200);
            echo json_encode(['status' => 'success', 'message' => 'No changes were made to the contact.']);
        }
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to update contact.']);
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