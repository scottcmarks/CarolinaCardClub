// client/lib/widgets/subnet_scan_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/subnet_scanner.dart';

class SubnetScanDialog extends StatefulWidget {
  const SubnetScanDialog({super.key});

  @override
  State<SubnetScanDialog> createState() => _SubnetScanDialogState();
}

class _SubnetScanDialogState extends State<SubnetScanDialog> {
  final SubnetScanner _scanner = SubnetScanner();
  StreamSubscription? _scanSubscription;
  String _status = 'Initializing...';
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    final s = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;

    setState(() => _status = 'Verifying saved IP: ${s.serverIp}...');
    if (await _scanner.isServerAt(s.serverIp, s.serverPort, s.localApiKey, s.scanTimeoutMs)) {
      _onFound(s.serverIp);
      return;
    }

    setState(() => _status = 'Scanning network...');
    _scanSubscription = _scanner
        .findServerOnLocalNetwork(s.serverPort, s.localApiKey, s.scanTimeoutMs)
        .listen((ip) => _onFound(ip), onDone: () {
          if (mounted && _isScanning) {
            setState(() {
              _status = 'Server not found.';
              _isScanning = false;
            });
          }
        });
  }

  void _onFound(String ip) {
    _scanSubscription?.cancel();
    final provider = Provider.of<AppSettingsProvider>(context, listen: false);
    provider.updateSettings(provider.currentSettings.copyWith(serverIp: ip));
    Provider.of<ApiProvider>(context, listen: false).reloadServerDatabase();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Searching for Server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isScanning) const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_status, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}