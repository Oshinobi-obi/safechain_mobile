<?php

require_once __DIR__ . '/../../config/conn.php';
require_once __DIR__ . '/send_push.php';

/**
 * Triggers an FCM push notification to all residents except the reporter.
 * Uses the Firebase HTTP v1 API via the getAccessToken() function.
 * @param string $incident_id The ID of the newly created incident
 * @param string $incident_type The type of incident (e.g., 'fire', 'crime')
 * @param string $location_label The readable address of the incident
 * @param string $reporter_id The resident_id of the person reporting
 * @param mysqli $conn The active database connection
 */

function triggerNeighborAlert($incident_id, $incident_type, $location_label, $reporter_id, $conn) {
    $urgent_types = ['fire', 'crime'];
    if (!in_array(strtolower($incident_type), $urgent_types)) return false;

    $accessToken = getAccessToken();
    if (!$accessToken) return false;

    $projectId = 'safechain-4daf7';
    $url       = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

    $tokens_stmt = $conn->prepare("SELECT fcm_token FROM fcm_tokens WHERE resident_id != ? AND fcm_token IS NOT NULL AND fcm_token != ''");
    $tokens_stmt->bind_param("s", $reporter_id);
    $tokens_stmt->execute();
    $result = $tokens_stmt->get_result();

    $overall_success = true;

    while ($row = $result->fetch_assoc()) {
        $token = $row['fcm_token'];

        $incident_title = strtoupper($incident_type) . " ALERT NEARBY";
        $message_body = "A {$incident_type} emergency has been reported nearby at {$location_label}. Please stay alert and safe.";

        $payload = json_encode([
            'message' => [
                'token'        => $token,
                'notification' => [
                    'title' => $incident_title,
                    'body'  => $message_body,
                ],
                'data'         => [
                    'type'        => 'security',
                    'incident_id' => $incident_id
                ],
                'android'      => [
                    'priority'     => 'high',
                    'notification' => [
                        'channel_id'    => 'safechain_channel',
                        'click_action'  => 'FLUTTER_NOTIFICATION_CLICK',
                        'color'         => '#EF4444'
                    ],
                ],
            ],
        ]);

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $accessToken
            ],
        ]);

        $response = curl_exec($ch);
        $httpcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpcode != 200) {
            $overall_success = false;
        }
    }

    $tokens_stmt->close();

    return $overall_success;
}
?>