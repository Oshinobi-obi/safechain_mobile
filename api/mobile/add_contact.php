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
$contact_number = $data['contact_number'] ?? null;
$relationship = $data['relationship'] ?? null;

if (!$resident_id || !$name || !$contact_number) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

try {
    $stmt = $conn->prepare("INSERT INTO emergency_contacts (resident_id, name, contact_number, relationship) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("ssss", $resident_id, $name, $contact_number, $relationship);

    if ($stmt->execute()) {
        http_response_code(201);
        echo json_encode(['status' => 'success', 'message' => 'Emergency contact added successfully.']);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to add emergency contact.']);
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