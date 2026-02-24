// client/lib/services/subnet_scanner.dart

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class SubnetScanner {
  static const int httpOK = 200;

  Future<bool> isServerAt(String ip, int port, String apiKey, int timeoutMs) async {
    try {
      final uri = Uri.parse('http://$ip:$port/state');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
      ).timeout(Duration(milliseconds: timeoutMs));

      return response.statusCode == httpOK;
    } catch (_) {
      return false;
    }
  }

  Stream<String> findServerOnLocalNetwork(int port, String apiKey, int timeoutMs) async* {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);

    for (var interface in interfaces) {
      if (interface.name.toLowerCase().contains('tun')) continue;

      for (var addr in interface.addresses) {
        if (addr.isLoopback) continue;

        final prefix = addr.address.substring(0, addr.address.lastIndexOf('.') + 1);
        final mySuffix = int.parse(addr.address.split('.').last);

        for (int i = 2; i <= 254; i++) {
          if (i == mySuffix) continue;

          final target = '$prefix$i';
          if (await isServerAt(target, port, apiKey, timeoutMs)) {
            yield target;
          }
        }
      }
    }
  }
}