<?php
// db_connection.php

$servername = "localhost";
$username = "u131483420_safechain";
$password = "r?5Rd&S=|";
$dbname = "u131483420_safechain";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => 'Connection failed: ' . $conn->connect_error
    ]);
    die();
}
?>