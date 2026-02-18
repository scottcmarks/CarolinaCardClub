// client/lib/models/app_settings.dart

import 'package:shared/shared.dart';

class AppSettings {
  final String serverIp;
  final String serverPort;
  final String localApiKey;
  final String preferredTheme;

  final int? floorManagerPlayerId;
  final int floorManagerReservedTable;
  final int floorManagerReservedSeat;

  // Time Settings
  final int defaultSessionHour;
  final int defaultSessionMinute;

  AppSettings({
    this.serverIp = Shared.defaultServerIp,
    this.serverPort = Shared.defaultServerPort,
    this.localApiKey = Shared.defaultLocalApiKey,
    this.preferredTheme = Shared.defaultTheme,
    this.floorManagerPlayerId = Shared.defaultFloorManagerPlayerId,
    this.floorManagerReservedTable = Shared.defaultFloorManagerReservedTable,
    this.floorManagerReservedSeat = Shared.defaultFloorManagerReservedSeat,
    this.defaultSessionHour = Shared.defaultSessionHour,
    this.defaultSessionMinute = Shared.defaultSessionMinute,
  });

  Map<String, dynamic> toMap() {
    return {
      'serverIp': serverIp,
      'serverPort': serverPort,
      'localApiKey': localApiKey,
      'preferredTheme': preferredTheme,
      'floorManagerPlayerId': floorManagerPlayerId,
      'floorManagerReservedTable': floorManagerReservedTable,
      'floorManagerReservedSeat': floorManagerReservedSeat,
      'defaultSessionHour': defaultSessionHour,
      'defaultSessionMinute': defaultSessionMinute,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      serverIp: map['serverIp'] ?? Shared.defaultServerIp,
      serverPort: map['serverPort'] ?? Shared.defaultServerPort,
      localApiKey: map['localApiKey'] ?? Shared.defaultLocalApiKey,
      preferredTheme: map['preferredTheme'] ?? Shared.defaultTheme,
      floorManagerPlayerId: map['floorManagerPlayerId'],
      floorManagerReservedTable: map['floorManagerReservedTable'] ?? Shared.defaultFloorManagerReservedTable,
      floorManagerReservedSeat: map['floorManagerReservedSeat'] ?? Shared.defaultFloorManagerReservedSeat,
      defaultSessionHour: map['defaultSessionHour'] ?? Shared.defaultSessionHour,
      defaultSessionMinute: map['defaultSessionMinute'] ?? Shared.defaultSessionMinute,
    );
  }
}