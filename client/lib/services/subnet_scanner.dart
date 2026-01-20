// client/lib/services/subnet_scanner.dart

import 'dart:async';
import 'dart:io';

class SubnetScanner {
  static const int _scanTimeoutMs = 500; // Fast timeout per IP
  static const int _serverPort = 5109;

  /// Scans the local subnet for a reachable server on port 5109.
  Future<String?> findServer() async {
    final String? localIp = await _getLocalIpAddress();
    if (localIp == null) {
      return null;
    }

    final String subnetPrefix = localIp.substring(0, localIp.lastIndexOf('.') + 1);
    final int localHostSuffix = int.parse(localIp.split('.').last);

    final List<Future<String?>> checks = [];

    // **FIX**: Start at 2.
    // .0 is Network, .1 is Gateway, .255 is Broadcast.
    // We scan .2 through .254.
    for (int i = 2; i < 255; i++) {
      if (i == localHostSuffix) continue; // Skip ourselves

      final targetIp = '$subnetPrefix$i';
      checks.add(_checkConnection(targetIp));
    }

    try {
      // Return the first successful IP, or null if all fail/timeout
      final foundIp = await Stream.fromFutures(checks)
          .firstWhere((ip) => ip != null, orElse: () => null);

      return foundIp;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        // Filter out VPNs/Tunneled interfaces if possible
        if (interface.name.contains('tun')) continue;

        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _checkConnection(String ip) async {
    try {
      final socket = await Socket.connect(ip, _serverPort,
          timeout: const Duration(milliseconds: _scanTimeoutMs));
      await socket.close();
      return ip;
    } catch (e) {
      return null;
    }
  }
}