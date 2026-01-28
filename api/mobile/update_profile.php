<?php

include 'db_connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$resident_id = $_POST['resident_id'] ?? null;
$name = $_POST['name'] ?? null;
$email = $_POST['email'] ?? null;
$address = $_POST['address'] ?? null;
$contact = $_POST['contact'] ?? null;
$medical_conditions = isset($_POST['medical_conditions']) ? json_decode($_POST['medical_conditions'], true) : [];
$avatar = $_POST['avatar'] ?? null;

if (!$resident_id || !$name || !$email || !$address || !$contact) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

$medical_conditions_json = json_encode($medical_conditions);
$profile_picture_url = null;

if (isset($_FILES['profile_picture'])) {
    $target_dir = "uploads/";
    if (!file_exists($target_dir)) {
        mkdir($target_dir, 0777, true);
    }
    $target_file = $target_dir . basename($_FILES["profile_picture"]["name"]);
    if (move_uploaded_file($_FILES["profile_picture"]["tmp_name"], $target_file)) {
        $profile_picture_url = 'https://safechain.site/api/mobile/' . $target_file;
    }
}

try {
    if ($profile_picture_url) {
        $stmt = $conn->prepare("UPDATE residents SET name = ?, email = ?, address = ?, contact = ?, medical_conditions = ?, profile_picture_url = ?, avatar = NULL WHERE resident_id = ?");
        $stmt->bind_param("ssssssss", $name, $email, $address, $contact, $medical_conditions_json, $profile_picture_url, $resident_id);
    } elseif ($avatar) {
        $stmt = $conn->prepare("UPDATE residents SET name = ?, email = ?, address = ?, contact = ?, medical_conditions = ?, avatar = ?, profile_picture_url = NULL WHERE resident_id = ?");
        $stmt->bind_param("ssssssss", $name, $email, $address, $contact, $medical_conditions_json, $avatar, $resident_id);
    } else {
        $stmt = $conn->prepare("UPDATE residents SET name = ?, email = ?, address = ?, contact = ?, medical_conditions = ? WHERE resident_id = ?");
        $stmt->bind_param("ssssss", $name, $email, $address, $contact, $medical_conditions_json, $resident_id);
    }

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            $select_stmt = $conn->prepare("SELECT resident_id, name, email, address, contact, medical_conditions, profile_picture_url, avatar FROM residents WHERE resident_id = ?");
            $select_stmt->bind_param("s", $resident_id);
            $select_stmt->execute();
            $updated_user = $select_stmt->get_result()->fetch_assoc();
            $select_stmt->close();

            http_response_code(200);
            echo json_encode([
                'status' => 'success',
                'message' => 'Profile updated successfully.',
                'user' => $updated_user
            ]);
        } else {
            $select_stmt = $conn->prepare("SELECT resident_id, name, email, address, contact, medical_conditions, profile_picture_url, avatar FROM residents WHERE resident_id = ?");
            $select_stmt->bind_param("s", $resident_id);
            $select_stmt->execute();
            $updated_user = $select_stmt->get_result()->fetch_assoc();
            $select_stmt->close();

            http_response_code(200);
            echo json_encode([
                'status' => 'success',
                'message' => 'No changes were made to the profile.',
                'user' => $updated_user
            ]);
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