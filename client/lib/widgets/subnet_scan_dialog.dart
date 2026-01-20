// client/lib/widgets/subnet_scan_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../services/subnet_scanner.dart';

class SubnetScanDialog extends StatefulWidget {
  final String? initialBaseIp;

  const SubnetScanDialog({super.key, this.initialBaseIp});

  @override
  State<SubnetScanDialog> createState() => _SubnetScanDialogState();
}

class _SubnetScanDialogState extends State<SubnetScanDialog> {
  final SubnetScanner _scanner = SubnetScanner();
  final TextEditingController _ipController = TextEditingController();

  StreamSubscription? _scanSubscription;
  Timer? _autoSuccessTimer;

  String _currentScanningIp = 'Initializing...';
  String? _foundIp;
  bool _isScanning = true;
  bool _scanFailed = false;
  int _scanPhase = 0;

  @override
  void initState() {
    super.initState();
    _startRobustScan();
  }

  Future<void> _startRobustScan() async {
    final savedIp = widget.initialBaseIp;
    final Set<String> scannedSubnets = {};

    // --- PHASE 1: Saved IP ---
    if (savedIp != null && savedIp.isNotEmpty) {
      if (mounted) setState(() {
        _scanPhase = 1;
        _currentScanningIp = 'Checking saved address:\n$savedIp';
      });

      final success = await _scanner.isServerAt(savedIp);
      if (success) {
        _onServerFound(savedIp);
        return;
      }
    }

    // --- PHASE 2: Local Subnets ---
    if (!mounted) return;
    List<String> localIps = await _scanner.getLocalIpAddresses();

    for (final localIp in localIps) {
      if (!mounted) return;
      if (_foundIp != null) return;

      final subnet = _getSubnet(localIp);
      if (scannedSubnets.contains(subnet)) continue;

      scannedSubnets.add(subnet);

      if (mounted) setState(() {
        _scanPhase = 2;
        _ipController.text = localIp;
      });

      await _runSubnetScan(localIp);
      if (_foundIp != null) return;
    }

    // --- PHASE 3: Saved IP Subnet ---
    if (!mounted) return;
    if (savedIp != null && savedIp.isNotEmpty) {
      final savedSubnet = _getSubnet(savedIp);
      if (!scannedSubnets.contains(savedSubnet)) {
         if (mounted) setState(() {
          _scanPhase = 3;
        });
        await _runSubnetScan(savedIp);
        if (_foundIp != null) return;
      }
    }

    // --- FAILED ---
    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanFailed = true;
        _currentScanningIp = 'No server found.';
      });
    }
  }

  Future<void> _runSubnetScan(String baseIp) async {
    final completer = Completer<void>();

    if (mounted) setState(() {
        _currentScanningIp = 'Scanning subnet:\n${_getSubnet(baseIp)}.x ...';
    });

    _scanSubscription?.cancel();
    _scanSubscription = _scanner.scanSubnet(baseIp).listen(
      (event) {
        if (event.type == ScanEventType.checking) {
          if (mounted) setState(() => _currentScanningIp = event.ip!);
        } else if (event.type == ScanEventType.found) {
          _onServerFound(event.ip!);
          _scanSubscription?.cancel();
          if (!completer.isCompleted) completer.complete();
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (e) {
        if (!completer.isCompleted) completer.complete();
      }
    );

    return completer.future;
  }

  String _getSubnet(String? ip) {
    if (ip == null || !ip.contains('.')) return 'unknown';
    return ip.substring(0, ip.lastIndexOf('.'));
  }

  void _onServerFound(String ip) {
    if (mounted) {
      setState(() {
        _isScanning = false;
        _foundIp = ip;
        _currentScanningIp = ip;
      });

      _autoSuccessTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _handleSuccess();
      });
    }
  }

  void _handleSuccess() {
    _autoSuccessTimer?.cancel();
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final newUrl = 'http://$_foundIp:5109';

    apiProvider.updateServerUrl(newUrl);
    apiProvider.connect();

    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _retryManual() {
    setState(() {
      _isScanning = true;
      _scanFailed = false;
      _foundIp = null;
    });
    _runSubnetScan(_ipController.text).then((_) {
       if (_foundIp == null && mounted) {
         setState(() {
           _isScanning = false;
           _scanFailed = true;
           _currentScanningIp = 'No server found.';
         });
       }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _autoSuccessTimer?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AlertDialog(
      title: const Text('Network Scan', textAlign: TextAlign.center),
      // **FIX**: Wrap content in SingleChildScrollView + IntrinsicWidth
      content: SingleChildScrollView(
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_foundIp != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Success!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Server found at:\n$_foundIp',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '(Auto-continuing in 5s)',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ]
              else if (_scanFailed) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No server found',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text('Target IP Address (Subnet):'),

                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.5),
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., 172.20.10.2',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'We will scan all 253 addresses near this IP.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ]
              else ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _getPhaseLabel(),
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _currentScanningIp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (_foundIp != null)
           FilledButton(
            onPressed: _handleSuccess,
            child: const Text('OK'),
          ),

        if (_scanFailed) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: _retryManual,
            child: const Text('Retry'),
          ),
        ],

        if (_isScanning)
          TextButton(
            onPressed: () {
               _scanSubscription?.cancel();
               setState(() {
                 _isScanning = false;
                 _scanFailed = true;
                 _currentScanningIp = 'Scan Cancelled';
               });
            },
            child: const Text('Cancel'),
          ),
      ],
    );
  }

  String _getPhaseLabel() {
    switch (_scanPhase) {
      case 1: return 'Step 1: Checking saved IP...';
      case 2: return 'Step 2: Scanning local networks...';
      case 3: return 'Step 3: Scanning last known network...';
      default: return 'Scanning...';
    }
  }
}