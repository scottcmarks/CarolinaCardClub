// shared/lib/src/constants.dart

// --- Remote Server Configuration ---
const String dbFileName = 'CarolinaCardClub.db';
const String remoteServerBaseUrl = 'https://carolinacardclub.com';
const String remoteDbHandlerPath = 'db_handler.php';
const String downloadUrl = '$remoteServerBaseUrl/$remoteDbHandlerPath';
const String uploadUrl = '$remoteServerBaseUrl/$remoteDbHandlerPath';

// --- API Keys ---
const String remoteApiKey =
    "31221da269c89d6e770cd96ad259433dffedd1f75250597cff41141440861297"
    "97bf09ab6fff19234e9674d7e48e428cd8aeb8a5a23a36abcd705acae8d1c030";
const String localApiKey =
    '9af85ab7895eb6d8baceb0fe1203c96851c87bdbad9af5fd5d5d0de2a24dad42'
    '8b5906722412bfa5b4fe3a9a07a7a24abea50cff4c9de08c02b8708871f1c2b1';

// -- Default Settings
const String defaultServerUrl     = 'http://localhost:5109';
const String defaultTheme         = 'light';
const int defaultSessionHour   = 19;
const int defaultSessionMinute = 30;
