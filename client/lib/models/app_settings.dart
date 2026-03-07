// client/lib/models/app_settings.dart

import 'package:shared/shared.dart';

class AppSettings {
  final String serverIp;
  final int serverPort;
  final String localApiKey;
  final int scanTimeoutMs;
  final String preferredTheme;
  final int? floorManagerPlayerId;
  final int floorManagerReservedTable;
  final int floorManagerReservedSeat;
  final int defaultSessionHour;
  final int defaultSessionMinute;

  AppSettings({
    this.serverIp = Shared.defaultServerIp,
    this.serverPort = Shared.defaultServerPort,
    this.localApiKey = Shared.defaultLocalApiKey,
    this.scanTimeoutMs = Shared.defaultScanTimeout,
    this.preferredTheme = Shared.defaultTheme,
    this.floorManagerPlayerId = Shared.defaultFloorManagerPlayerId,
    this.floorManagerReservedTable = Shared.defaultFloorManagerReservedTable,
    this.floorManagerReservedSeat = Shared.defaultFloorManagerReservedSeat,
    this.defaultSessionHour = Shared.defaultSessionHour,
    this.defaultSessionMinute = Shared.defaultSessionMinute,
  });

  AppSettings copyWith({
    String? serverIp,
    int? serverPort,
    String? localApiKey,
    int? scanTimeoutMs,
    String? preferredTheme,
    int? floorManagerPlayerId,
    int? floorManagerReservedTable,
    int? floorManagerReservedSeat,
    int? defaultSessionHour,
    int? defaultSessionMinute,
  }) {
    return AppSettings(
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      localApiKey: localApiKey ?? this.localApiKey,
      scanTimeoutMs: scanTimeoutMs ?? this.scanTimeoutMs,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      floorManagerPlayerId: floorManagerPlayerId ?? this.floorManagerPlayerId,
      floorManagerReservedTable: floorManagerReservedTable ?? this.floorManagerReservedTable,
      floorManagerReservedSeat: floorManagerReservedSeat ?? this.floorManagerReservedSeat,
      defaultSessionHour: defaultSessionHour ?? this.defaultSessionHour,
      defaultSessionMinute: defaultSessionMinute ?? this.defaultSessionMinute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serverIp': serverIp,
      'serverPort': serverPort,
      'localApiKey': localApiKey,
      'scanTimeoutMs': scanTimeoutMs,
      'preferredTheme': preferredTheme,
      'floorManagerPlayerId': floorManagerPlayerId,
      'floorManagerReservedTable': floorManagerReservedTable,
      'floorManagerReservedSeat': floorManagerReservedSeat,
      'defaultSessionHour': defaultSessionHour,
      'defaultSessionMinute': defaultSessionMinute,
    };
  }

  bool isFloorManagerReservedSeat(int tableId, int seatNum) =>
      floorManagerPlayerId != null &&
      tableId == floorManagerReservedTable &&
      seatNum == floorManagerReservedSeat;

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      serverIp: map['serverIp'] ?? Shared.defaultServerIp,
      serverPort: map['serverPort'] ?? Shared.defaultServerPort,
      localApiKey: map['localApiKey'] ?? Shared.defaultLocalApiKey,
      scanTimeoutMs: map['scanTimeoutMs'] ?? Shared.defaultScanTimeout,
      preferredTheme: map['preferredTheme'] ?? Shared.defaultTheme,
      floorManagerPlayerId: map['floorManagerPlayerId'],
      floorManagerReservedTable: map['floorManagerReservedTable'] ?? Shared.defaultFloorManagerReservedTable,
      floorManagerReservedSeat: map['floorManagerReservedSeat'] ?? Shared.defaultFloorManagerReservedSeat,
      defaultSessionHour: map['defaultSessionHour'] ?? Shared.defaultSessionHour,
      defaultSessionMinute: map['defaultSessionMinute'] ?? Shared.defaultSessionMinute,
    );
  }
}