<?php

ini_set('display_errors', 0);
header('Content-Type: application/json');
ob_start();

register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        ob_end_clean();
        http_response_code(500);
        echo json_encode([
            'status' => 'error',
            'message' => 'A fatal server error occurred.',
            'debug' => $error['message'] . "\n" . $error['file'] . " on line " . $error['line']
        ]);
    }
});

$response = [];

try {
    if (!file_exists('db_connection.php')) {
        throw new Exception('Database connection file not found.');
    }
    include 'db_connection.php';

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Invalid request method.', 405);
    }

    $resident_id = $_POST['resident_id'] ?? null;
    $name = $_POST['name'] ?? null;
    $email = $_POST['email'] ?? null;
    $address = $_POST['address'] ?? null;
    $contact = $_POST['contact'] ?? null;
    $avatar = $_POST['avatar'] ?? null;

    $medical_conditions_input = $_POST['medical_conditions'] ?? '[]';
    $medical_conditions = json_decode($medical_conditions_input, true);
    if (!is_array($medical_conditions)) {
        $medical_conditions = [];
    }

    if (!$resident_id || !$name || !$email || !$address || !$contact) {
        throw new Exception('Missing required fields.', 400);
    }

    $medical_conditions_json = json_encode($medical_conditions);
    $profile_picture_url = null;

    if (isset($_FILES['profile_picture']) && $_FILES['profile_picture']['error'] === UPLOAD_ERR_OK) {
        $target_dir = "uploads/";
        if (!file_exists($target_dir)) {
            if (!mkdir($target_dir, 0755, true)) {
                 throw new Exception('Failed to create uploads directory. Check permissions.');
            }
        }

        $file_extension = pathinfo($_FILES["profile_picture"]["name"], PATHINFO_EXTENSION);
        $new_filename = uniqid('profile_', true) . '.' . $file_extension;
        $target_file = $target_dir . $new_filename;

        if (move_uploaded_file($_FILES["profile_picture"]["tmp_name"], $target_file)) {
            $profile_picture_url = 'https://safechain.site/api/mobile/' . $target_file;
        } else {
            throw new Exception('Failed to move uploaded file. Check folder permissions.');
        }
    } elseif (isset($_FILES['profile_picture']) && $_FILES['profile_picture']['error'] !== UPLOAD_ERR_NO_FILE) {
        throw new Exception('File upload error code: ' . $_FILES['profile_picture']['error']);
    }

    $sql = "";
    if ($profile_picture_url) {
        $sql = "UPDATE residents SET name = ?, email = ?, address = ?, contact = ?, medical_conditions = ?, profile_picture_url = ?, avatar = NULL WHERE resident_id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("sssssss", $name, $email, $address, $contact, $medical_conditions_json, $profile_picture_url, $resident_id);
    } elseif ($avatar) {
        $sql = "UPDATE residents SET name = ?, email = ?, address = ?, contact = ?, medical_conditions = ?, avatar = ?, profile_picture_url = NULL WHERE resident_id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("sssssss", $name, $email, $address, $contact, $medical_conditions_json, $avatar, $resident_id);
    } else {
        $sql = "UPDATE residents SET name = ?, email = ?, address = ?, contact = ?, medical_conditions = ? WHERE resident_id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ssssss", $name, $email, $address, $contact, $medical_conditions_json, $resident_id);
    }

    if (!$stmt) {
         throw new Exception('Database prepare failed: ' . $conn->error);
    }

    if ($stmt->execute()) {
        $select_stmt = $conn->prepare("SELECT resident_id, name, email, address, contact, medical_conditions, profile_picture_url, avatar FROM residents WHERE resident_id = ?");
        $select_stmt->bind_param("s", $resident_id);
        $select_stmt->execute();
        $result = $select_stmt->get_result();
        $updated_user = $result->fetch_assoc();
        $select_stmt->close();

        if (!$updated_user) {
             throw new Exception('User not found after update.');
        }

        if (isset($updated_user['medical_conditions'])) {
            $temp_conditions = json_decode($updated_user['medical_conditions'], true);
            $updated_user['medical_conditions'] = is_array($temp_conditions) ? $temp_conditions : [];
        } else {
            $updated_user['medical_conditions'] = [];
        }

        $response_message = ($stmt->affected_rows > 0) ? 'Profile updated successfully.' : 'No changes were made to the profile.';
        http_response_code(200);
        $response = [
            'status' => 'success',
            'message' => $response_message,
            'user' => $updated_user
        ];
    } else {
        throw new Exception('Database execute failed: ' . $stmt->error);
    }
    $stmt->close();

} catch (Exception $e) {
    $http_code = ($e->getCode() >= 400 && $e->getCode() < 600) ? $e->getCode() : 500;
    http_response_code($http_code);
    $response = [
        'status' => 'error',
        'message' => $e->getMessage()
    ];
} finally {
    if (isset($conn)) {
        $conn->close();
    }
    ob_end_clean();
    echo json_encode($response);
}
?>