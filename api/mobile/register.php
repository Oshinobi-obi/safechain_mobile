<?php

include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$name = $_POST['name'] ?? null;
$email = $_POST['email'] ?? null;
$password = $_POST['password'] ?? null;
$address = $_POST['address'] ?? '';
$contact = $_POST['contact'] ?? '';

if (!$name || !$email || !$password) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Name, email, and password are required from POST.']);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT resident_id FROM residents WHERE email = ? AND is_archived = 0");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $stmt->store_result();

    if ($stmt->num_rows > 0) {
        http_response_code(409);
        echo json_encode(['status' => 'error', 'message' => 'An account with this email already exists.']);
        $stmt->close();
        $conn->close();
        exit;
    }
    $stmt->close();

    $hashed_password = password_hash($password, PASSWORD_DEFAULT);
    $resident_id = 'USR-' . time();
    $registered_date = date('Y-m-d');

    $insert_stmt = $conn->prepare(
        "INSERT INTO residents (resident_id, name, email, password, address, contact, registered_date) VALUES (?, ?, ?, ?, ?, ?, ?)"
    );
    $insert_stmt->bind_param("sssssss", $resident_id, $name, $email, $hashed_password, $address, $contact, $registered_date);

    if ($insert_stmt->execute()) {
        http_response_code(201);
        echo json_encode([
            'status' => 'success',
            'message' => 'Registration successful.',
            'resident_id' => $resident_id
        ]);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Registration failed. Please try again later.']);
    }

    $insert_stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);

} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>