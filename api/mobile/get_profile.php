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
    echo json_encode(['status' => 'error', 'message' => 'resident_id is required.']);
    exit;
}

try {
    $stmt = $conn->prepare(
        "SELECT resident_id, name, email, address, contact,
                medical_conditions, profile_picture_url, avatar, status
         FROM residents
         WHERE resident_id = ? AND is_archived = 0
         LIMIT 1"
    );
    $stmt->bind_param("s", $resident_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Resident not found.']);
        $stmt->close();
        exit;
    }

    $resident = $result->fetch_assoc();
    $stmt->close();

    // Decode medical_conditions from JSON string to array
    if (isset($resident['medical_conditions'])) {
        $decoded = json_decode($resident['medical_conditions'], true);
        $resident['medical_conditions'] = is_array($decoded) ? $decoded : [];
    } else {
        $resident['medical_conditions'] = [];
    }

    http_response_code(200);
    echo json_encode([
        'status'   => 'success',
        'resident' => $resident,
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>