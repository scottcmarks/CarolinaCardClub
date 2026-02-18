// shared/lib/constants.dart

class Shared {
  // --- Remote Server Configuration ---
  static const String dbFileName = 'CarolinaCardClub.db';
  static const String remoteServerBaseUrl = 'https://carolinacardclub.com';
  static const String remoteDbHandlerPath = 'db_handler.php';

  // --- API Keys ---
  static const String remoteApiKey =
      "31221da269c89d6e770cd96ad259433dffedd1f75250597cff41141440861297"
      "97bf09ab6fff19234e9674d7e48e428cd8aeb8a5a23a36abcd705acae8d1c030";

  static const String defaultLocalApiKey =
      '9af85ab7895eb6d8baceb0fe1203c96851c87bdbad9af5fd5d5d0de2a24dad42'
      '8b5906722412bfa5b4fe3a9a07a7a24abea50cff4c9de08c02b8708871f1c2b1';

  // --- Defaults ---
  static const String defaultServerIp = '127.0.0.1';
  static const String defaultServerPort = '5109';
  static const String defaultTheme = 'system'; // Restored for main.dart
  static const int defaultSessionHour = 19;
  static const int defaultSessionMinute = 30;
  static const int secondsPerHour = 3600;

  // --- Floor Manager ---
  static const int defaultFloorManagerPlayerId = 1;
  static const int defaultFloorManagerReservedTable = 1;
  static const int defaultFloorManagerReservedSeat = 7;

  // --- UI Layout ---
  static const double seatSizeMultiplier = 0.13;
  static const double tableWidthMultiplier = 0.75;
  static const double tableHeightMultiplier = 0.65;
}