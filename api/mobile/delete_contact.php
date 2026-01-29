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

if (!$contact_id) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Contact ID is required.']);
    exit;
}

try {
    $stmt = $conn->prepare("DELETE FROM emergency_contacts WHERE contact_id = ?");
    $stmt->bind_param("i", $contact_id);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            http_response_code(200);
            echo json_encode(['status' => 'success', 'message' => 'Contact deleted successfully.']);
        } else {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Contact not found.']);
        }
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to delete contact.']);
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