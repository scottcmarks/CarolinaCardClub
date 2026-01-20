// client/lib/services/subnet_scanner.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum ScanEventType { checking, found }

class ScanEvent {
  final ScanEventType type;
  final String? ip;
  ScanEvent(this.type, [this.ip]);
}

class SubnetScanner {
  static const int _scanTimeoutMs = 500;
  static const int _serverPort = 5109;

  String? lastUsedBaseIp;

  /// Rapidly checks a single IP address. Returns true if server is found.
  Future<bool> isServerAt(String ip) async {
    try {
      debugPrint('Scanner: Checking single target $ip...');
      final socket = await Socket.connect(ip, _serverPort,
          timeout: const Duration(milliseconds: _scanTimeoutMs));
      await socket.close();
      debugPrint('Scanner: SUCCESS! Found server at $ip');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Scans the subnet of the provided [baseIp].
  Stream<ScanEvent> scanSubnet(String baseIp) async* {
    lastUsedBaseIp = baseIp;
    debugPrint('Scanner: Starting scan on subnet for $baseIp');

    final String subnetPrefix = baseIp.substring(0, baseIp.lastIndexOf('.') + 1);
    final int localHostSuffix = int.parse(baseIp.split('.').last);

    final controller = StreamController<ScanEvent>();
    final List<Future<void>> futures = [];

    // Scan .2 to .254
    for (int i = 2; i < 255; i++) {
      if (i == localHostSuffix) continue;

      final targetIp = '$subnetPrefix$i';
      futures.add(_checkWithReporting(targetIp, controller));
    }

    Future.wait(futures).then((_) {
      debugPrint('Scanner: All checks complete for $baseIp.');
      controller.close();
    });

    yield* controller.stream;
  }

  Future<void> _checkWithReporting(String ip, StreamController<ScanEvent> controller) async {
    if (controller.isClosed) return;

    controller.add(ScanEvent(ScanEventType.checking, ip));

    try {
      final socket = await Socket.connect(ip, _serverPort,
          timeout: const Duration(milliseconds: _scanTimeoutMs));

      await socket.close();

      debugPrint('Scanner: SUCCESS! Found server at $ip');
      if (!controller.isClosed) {
        controller.add(ScanEvent(ScanEventType.found, ip));
      }
    } catch (e) {
      // Expected failure for most IPs
    }
  }

  /// Returns ALL valid IPv4 addresses found on the device.
  Future<List<String>> getLocalIpAddresses() async {
    final List<String> ips = [];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        // Skip VPN tunnels or other clearly non-physical interfaces if possible
        if (interface.name.toLowerCase().contains('tun')) continue;

        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
             ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('Scanner: Failed to list network interfaces: $e');
    }
    return ips;
  }
}