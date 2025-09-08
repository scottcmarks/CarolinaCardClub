<?php
// The name of your primary database file.
$db_file = 'CarolinaCardClub.db';

// The directory for storing backups.
$backup_dir = 'backups/';

// --- SECURITY ---
// Define your secret key. The client app MUST send this key to upload.
// REPLACE THIS with your own long, random string.
$secret_api_key = "31221da269c89d6e770cd96ad259433dffedd1f75250597cff4114144086129797bf09ab6fff19234e9674d7e48e428cd8aeb8a5a23a36abcd705acae8d1c030";

// Check the request method (GET or POST)
$request_method = $_SERVER['REQUEST_METHOD'];

if ($request_method === 'GET') {
    // --- Handle Download Request ---
    if (file_exists($db_file)) {
        header('Content-Description: File Transfer');
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . basename($db_file) . '"');
        header('Expires: 0');
        header('Cache-Control: must-revalidate');
        header('Pragma: public');
        header('Content-Length: ' . filesize($db_file));
        flush();
        readfile($db_file);
        exit;
    } else {
        header("HTTP/1.1 404 Not Found");
        echo "Error: Database file not found on the server.";
    }
} elseif ($request_method === 'POST') {
    // --- Handle Upload Request ---

    // SECURITY CHECK: Verify the secret key.
    if (!isset($_POST['apiKey']) || $_POST['apiKey'] !== $secret_api_key) {
        header("HTTP/1.1 403 Forbidden");
        die("Error: Invalid or missing API key.");
    }

    // Check if the 'database' file field is part of the upload
    if (!isset($_FILES['database']) || $_FILES['database']['error'] !== UPLOAD_ERR_OK) {
        header("HTTP/1.1 500 Internal Server Error");
        die("Error: File upload failed with error code: " . $_FILES['database']['error']);
    }

    $timestamp = date("Y-m-d_H-i-s");
    $original_filename = basename($_FILES["database"]["name"]);
    $target_file = $backup_dir . $timestamp . "_" . $original_filename;

    if (move_uploaded_file($_FILES['database']['tmp_name'], $target_file)) {
        header("HTTP/1.1 200 OK");
        echo "Success: File uploaded and saved as " . basename($target_file);
    } else {
        header("HTTP/1.1 500 Internal Server Error");
        echo "Error: Could not move uploaded file. Check permissions and paths.";
    }
} else {
    header("HTTP/1.1 405 Method Not Allowed");
    echo "Error: This endpoint only supports GET and POST requests.";
}
?>
