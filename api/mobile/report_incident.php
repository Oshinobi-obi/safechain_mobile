<?php

include 'db_connection.php';
// Include the neighbor alert script we created previously
require_once 'trigger_neighbor_alert.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method.']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

$reporter_id = $data['reporter_id'] ?? null;
$type = $data['type'] ?? null; // 'fire', 'flood', or 'crime'
$latitude = $data['latitude'] ?? 0.00000000;
$longitude = $data['longitude'] ?? 0.00000000;
$location = $data['location'] ?? 'Unknown Location';
$device_id = $data['device_id'] ?? 'Mobile App';

if (!$reporter_id || !$type) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Missing required fields.']);
    exit;
}

// Map the app's terminology to the database enum if necessary
$type = strtolower($type);
$valid_types = ['fire', 'flood', 'crime'];
if (!in_array($type, $valid_types)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid incident type.']);
    exit;
}

try {
    $conn->begin_transaction();

    // 1. Get the Reporter's Name
    $name_stmt = $conn->prepare("SELECT name, status FROM residents WHERE resident_id = ?");
    $name_stmt->bind_param("s", $reporter_id);
    $name_stmt->execute();
    $resident_result = $name_stmt->get_result();

    if ($resident_result->num_rows === 0) {
        throw new Exception("Resident not found.");
    }

    $resident_data = $resident_result->fetch_assoc();
    $reporter_name = $resident_data['name'];

    // Optional: Block restricted users from reporting
    if ($resident_data['status'] === 'restricted') {
        http_response_code(403);
        echo json_encode(['status' => 'error', 'message' => 'Your account is restricted. Please coordinate with the Barangay.']);
        exit;
    }
    $name_stmt->close();

    // 2. Generate a unique Incident ID (e.g., EMG-2026-1054)
    $current_year = date('Y');
    $prefix = "EMG-$current_year-";

    $id_query = $conn->query("SELECT id FROM incidents WHERE id LIKE '$prefix%' ORDER BY id DESC LIMIT 1");
    if ($id_query->num_rows > 0) {
        $last_id = $id_query->fetch_assoc()['id'];
        $last_num = (int)str_replace($prefix, '', $last_id);
        $new_num = $last_num + 1;
    } else {
        $new_num = 1001; // Start at 1001 for the new year
    }

    $incident_id = $prefix . str_pad($new_num, 4, '0', STR_PAD_LEFT);
    $current_time = date('Y-m-d H:i:s');
    $status = 'pending';

    // 3. Insert the Incident
    $incident_stmt = $conn->prepare(
        "INSERT INTO incidents (id, type, location, latitude, longitude, device_id, reporter, reporter_id, date_time, status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    $incident_stmt->bind_param(
        "sssddssssss",
        $incident_id, $type, $location, $latitude, $longitude, $device_id, $reporter_name, $reporter_id, $current_time, $status, $current_time
    );

    if (!$incident_stmt->execute()) {
        throw new Exception("Failed to save incident record.");
    }
    $incident_stmt->close();

    // 4. Insert into Incident Timeline
    $timeline_title = "Incident reported";
    $timeline_desc = "Emergency reported by $reporter_name via device $device_id";

    $timeline_stmt = $conn->prepare(
        "INSERT INTO incident_timeline (incident_id, title, description, actor, user_id, created_at)
         VALUES (?, ?, ?, ?, ?, ?)"
    );
    $timeline_stmt->bind_param("ssssss", $incident_id, $timeline_title, $timeline_desc, $reporter_name, $reporter_id, $current_time);
    $timeline_stmt->execute();
    $timeline_stmt->close();

    // Commit the transaction since all database operations succeeded
    $conn->commit();

    // 5. Trigger the Neighbor Alert Push Notification (runs in the background)
    // We do this after the commit so that the incident is definitely in the DB when the notification goes out.
    triggerNeighborAlert($incident_id, $type, $location, $reporter_id, $conn);

    // 6. Return Success Response
    http_response_code(201);
    echo json_encode([
        'status' => 'success',
        'message' => 'Emergency reported successfully.',
        'incident_id' => $incident_id
    ]);

} catch (Exception $e) {
    // Rollback the transaction if anything fails
    $conn->rollback();
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'An error occurred: ' . $e->getMessage()
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>