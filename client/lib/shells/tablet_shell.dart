// client/lib/shells/tablet_shell.dart
//
// Root widget for the tablet entry point. Checks whether a table number has
// been assigned (stored in AppSettings / shared_preferences). If not, shows a
// first-run setup screen so the operator can select this tablet's table.
// Once assigned, it hands off to TabletTablePage for that single table.
//
// If the server cannot be reached on the configured IP, this shell
// automatically scans the local network (reusing SubnetScanner) and updates
// the saved IP if the server is found elsewhere.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_connection/db_connection.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/poker_table.dart';
import '../pages/tablet_table_page.dart';
import '../services/subnet_scanner.dart';

class TabletShell extends StatelessWidget {
  const TabletShell({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = Provider.of<AppSettingsProvider>(context);
    final conn = Provider.of<DbConnectionProvider>(context);
    final api = Provider.of<ApiProvider>(context);
    final tableNumber = settingsProv.currentSettings.tableNumber;

    // ── Normal operation: we have active tables ──────────────────────────────
    if (api.activeTables.isNotEmpty) {
      if (tableNumber == null) {
        return const _TableSetupScreen();
      }

      final table = api.activeTables
          .where((t) => t.pokerTableId == tableNumber)
          .firstOrNull;

      if (table == null) {
        return _TableGoneScreen(tableNumber: tableNumber);
      }

      return TabletTablePage(
        tables: [table],
        onReassign: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Change Table Assignment?'),
              content: Text(
                  'This tablet is currently assigned to ${table.tableName}. '
                  'Reassign it to a different table?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Reassign')),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            await Provider.of<AppSettingsProvider>(context, listen: false)
                .setTableNumber(null);
          }
        },
      );
    }

    // ── Connected but no active tables ───────────────────────────────────────
    if (conn.status == ConnectionStatus.connected) {
      return _cccScaffold(
        'Carolina Card Club',
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Connected. No active tables found.\nAsk the admin to open a table.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }

    // ── Not connected (connecting / failed / disconnected) — auto-discover ────
    // Keep _ServerSearchScreen in the tree for all non-connected states so that
    // DbConnectionProvider's own reconnect timer cannot destroy the scan mid-run.
    return const _ServerSearchScreen();
  }

  static Widget _cccScaffold(String title, Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(Shared.carolinaBlue),
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}

// ── Auto-discovery screen ─────────────────────────────────────────────────────

class _ServerSearchScreen extends StatefulWidget {
  const _ServerSearchScreen();

  @override
  State<_ServerSearchScreen> createState() => _ServerSearchScreenState();
}

class _ServerSearchScreenState extends State<_ServerSearchScreen> {
  final _scanner = SubnetScanner();
  StreamSubscription? _sub;
  Timer? _fallbackTimer;
  String _status = 'Connecting…';
  bool _scanning = false;
  bool _failed = false;
  bool _scanStarted = false;
  final _manualIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fallback: start scan after 8 s even if we never see a failure event.
    _fallbackTimer = Timer(const Duration(seconds: 8), _ensureScanStarted);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start scanning as soon as the connection attempt has definitively failed.
    final conn = Provider.of<DbConnectionProvider>(context);
    if (!_scanStarted &&
        (conn.status == ConnectionStatus.failed ||
         conn.status == ConnectionStatus.disconnected)) {
      _ensureScanStarted();
    }
  }

  void _ensureScanStarted() {
    if (_scanStarted) return;
    _scanStarted = true;
    _fallbackTimer?.cancel();
    _startScan();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _sub?.cancel();
    _manualIpController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    _sub?.cancel();
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _failed = false;
      _status = '';
    });

    final s = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;

    // Try the saved IP first.
    _setStatus('Trying ${s.serverIp}…');
    if (await _scanner.isServerAt(s.serverIp, s.serverPort, s.localApiKey, s.scanTimeoutMs)) {
      _onFound(s.serverIp);
      return;
    }

    if (!mounted) return;
    _setStatus('Scanning local network…');

    _sub = _scanner
        .findServerOnLocalNetwork(
          s.serverPort,
          s.localApiKey,
          s.scanTimeoutMs,
          onTrying: (ip) => _setStatus('Trying $ip…'),
        )
        .listen(
          _onFound,
          onDone: () {
            if (mounted && _scanning) {
              setState(() {
                _scanning = false;
                _failed = true;
                _status = 'Server not found on local network.';
              });
            }
          },
        );
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  void _onFound(String ip) {
    _sub?.cancel();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _status = 'Found server at $ip — connecting…';
    });
    // Saving the new IP causes the ChangeNotifierProxyProvider in main.dart to
    // call DbConnectionProvider.setServerUrl() automatically.
    final settingsProv = Provider.of<AppSettingsProvider>(context, listen: false);
    settingsProv.updateSettings(settingsProv.currentSettings.copyWith(serverIp: ip));
  }

  void _connectManual() {
    final ip = _manualIpController.text.trim();
    if (ip.isEmpty) return;
    _onFound(ip);
  }

  @override
  Widget build(BuildContext context) {
    final savedIp =
        Provider.of<AppSettingsProvider>(context, listen: false).currentSettings.serverIp;

    return TabletShell._cccScaffold(
      'Searching for Server',
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_scanning) const CircularProgressIndicator(),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15)),
              ],
              if (_failed) ...[
                const SizedBox(height: 32),
                TextField(
                  controller: _manualIpController,
                  decoration: InputDecoration(
                    labelText: 'Server IP address',
                    hintText: savedIp,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _connectManual(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _startScan,
                        child: const Text('Retry Scan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _connectManual,
                        child: const Text('Connect'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Table picker (shown once connected and activeTables.isNotEmpty) ───────────

class _TableSetupScreen extends StatelessWidget {
  const _TableSetupScreen();

  @override
  Widget build(BuildContext context) {
    final tables = Provider.of<ApiProvider>(context).activeTables;

    return TabletShell._cccScaffold(
      'Table Setup',
      ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Text(
            'Which table is this tablet at?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          ...tables.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TableButton(table: t),
              )),
        ],
      ),
    );
  }
}

class _TableButton extends StatelessWidget {
  final PokerTable table;
  const _TableButton({required this.table});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        backgroundColor: const Color(Shared.carolinaBluePrimary),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        Provider.of<AppSettingsProvider>(context, listen: false)
            .setTableNumber(table.pokerTableId);
      },
      child: Text(table.tableName),
    );
  }
}

// ── Intermediate states ───────────────────────────────────────────────────────

class _TableGoneScreen extends StatelessWidget {
  final int tableNumber;
  const _TableGoneScreen({required this.tableNumber});

  @override
  Widget build(BuildContext context) {
    return TabletShell._cccScaffold(
      'Table Unavailable',
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Table $tableNumber is not currently active.',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Provider.of<AppSettingsProvider>(context, listen: false)
                    .setTableNumber(null);
              },
              child: const Text('Select a Different Table'),
            ),
          ],
        ),
      ),
    );
  }
}
