<?php
include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$resident_id = $_GET['resident_id'] ?? null;

if (!$resident_id) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Resident ID is required.']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT * FROM emergency_contacts WHERE resident_id = ?");
    $stmt->bind_param("s", $resident_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $contacts = $result->fetch_all(MYSQLI_ASSOC);

    http_response_code(200);
    echo json_encode(['status' => 'success', 'contacts' => $contacts]);

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