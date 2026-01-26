<?php
// api/mobile/login.php

// Include the database connection
include 'db_connection.php';

// Set headers to return JSON
header('Content-Type: application/json');

// The endpoint should only accept POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

// --- Data Retrieval ---
$data = json_decode(file_get_contents('php://input'), true);

$email = $data['email'] ?? null;
$password = $data['password'] ?? null;

// Basic validation
if (!$email || !$password) {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'Email and password are required.']);
    exit;
}

// --- User Authentication ---
try {
    // Prepare statement to prevent SQL injection
    $stmt = $conn->prepare("SELECT resident_id, name, email, password, address, contact FROM residents WHERE email = ? AND is_archived = 0");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 1) {
        // User found, now verify password
        $user = $result->fetch_assoc();
        
        if (password_verify($password, $user['password'])) {
            // Password is correct
            http_response_code(200); // OK

            // Remove password from the response for security
            unset($user['password']);

            echo json_encode([
                'status' => 'success',
                'message' => 'Login successful.',
                'user' => $user
            ]);

        } else {
            // Incorrect password
            http_response_code(401); // Unauthorized
            echo json_encode(['status' => 'error', 'message' => 'Invalid email or password.']);
        }
    } else {
        // User not found or is archived
        http_response_code(404); // Not Found
        echo json_encode(['status' => 'error', 'message' => 'Invalid email or password.']);
    }

    $stmt->close();

} catch (Exception $e) {
    // General server error
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'An internal error occurred: ' . $e->getMessage()]);

} finally {
    // Always close the connection
    if (isset($conn)) {
        $conn->close();
    }
}
?>
