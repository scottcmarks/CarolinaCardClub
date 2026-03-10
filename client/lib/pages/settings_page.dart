// client/lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:db_connection/db_connection.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import '../widgets/subnet_scan_dialog.dart';
import 'maintenance_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _apiKeyController;
  late TextEditingController _timeoutController;
  late TextEditingController _fmIdController;
  late TextEditingController _hourController;
  late TextEditingController _minuteController;

  bool _isDirty = false;
  String _lastKnownSavedIp = '';

  @override
  void initState() {
    super.initState();
    final s = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    _lastKnownSavedIp = s.serverIp;
    _ipController = TextEditingController(text: s.serverIp);
    _portController = TextEditingController(text: s.serverPort.toString());
    _apiKeyController = TextEditingController(text: s.localApiKey);
    _timeoutController = TextEditingController(text: s.scanTimeoutMs.toString());
    _fmIdController = TextEditingController(text: s.floorManagerPlayerId?.toString() ?? '');
    _hourController = TextEditingController(text: Shared.defaultSessionHour.toString());
    _minuteController = TextEditingController(text: Shared.defaultSessionMinute.toString());

    for (final c in [_ipController, _portController, _apiKeyController,
                     _timeoutController, _fmIdController, _hourController, _minuteController]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final savedIp =
        Provider.of<AppSettingsProvider>(context, listen: false).currentSettings.serverIp;
    if (savedIp != _lastKnownSavedIp) {
      _lastKnownSavedIp = savedIp;
      _ipController.text = savedIp;
      // External update (auto-discover) — not a user edit, clear dirty flag.
      setState(() => _isDirty = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_ipController, _portController, _apiKeyController,
                     _timeoutController, _fmIdController, _hourController, _minuteController]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _save() async {
    final provider = Provider.of<AppSettingsProvider>(context, listen: false);
    final api = Provider.of<ApiProvider>(context, listen: false);

    final newSettings = provider.currentSettings.copyWith(
      serverIp: _ipController.text.isEmpty ? Shared.defaultServerIp : _ipController.text,
      serverPort: int.tryParse(_portController.text) ?? Shared.defaultServerPort,
      localApiKey: _apiKeyController.text.isEmpty ? Shared.defaultLocalApiKey : _apiKeyController.text,
      scanTimeoutMs: int.tryParse(_timeoutController.text) ?? Shared.defaultScanTimeout,
      floorManagerPlayerId: int.tryParse(_fmIdController.text),
    );
    provider.updateSettings(newSettings);
    api.applySettings(newSettings);
    setState(() => _isDirty = false);
    api.reloadAll(Provider.of<TimeProvider>(context, listen: false).nowEpoch);

    final hour = int.tryParse(_hourController.text) ?? Shared.defaultSessionHour;
    final minute = int.tryParse(_minuteController.text) ?? Shared.defaultSessionMinute;

    try {
      await api.updateDefaultSessionTime(hour, minute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All Configuration & Defaults Saved'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save defaults to server: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          TextButton(
            onPressed: _isDirty ? _save : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isDirty ? Colors.red.shade300 : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionStatusCard(),

          const SizedBox(height: 16),
          const Text('Network Configuration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildTextField('Server IP', _ipController, Shared.defaultServerIp),
          _buildIntField('Server Port', _portController, Shared.defaultServerPort.toString()),
          _buildTextField('Local API Key', _apiKeyController, 'Secret Key'),
          _buildIntField(
              'Scan Timeout (ms)', _timeoutController, Shared.defaultScanTimeout.toString()),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => const SubnetScanDialog(),
            ),
            icon: const Icon(Icons.radar),
            label: const Text('Auto-Discover Server'),
          ),

          const SizedBox(height: 24),
          const Text('Club Session Start Time',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildIntField(
                      'Hour (24h)', _hourController, Shared.defaultSessionHour.toString())),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildIntField(
                      'Minute', _minuteController, Shared.defaultSessionMinute.toString())),
            ],
          ),

          const SizedBox(height: 24),
          const Text('Floor Manager Configuration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildIntField('Manager Player ID', _fmIdController,
              'Default: ${Shared.defaultFloorManagerPlayerId}'),

          const Divider(height: 48),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaintenancePage()),
            ),
            icon: const Icon(Icons.build_rounded),
            label: const Text('Maintenance & Debugging'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  Widget _buildIntField(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  static String _simplifyError(String raw) {
    if (raw.contains('No route to host')) return 'no route to host';
    if (raw.contains('Connection refused')) return 'connection refused';
    if (raw.contains('Connection failed')) return 'connection failed';
    if (raw.contains('timed out') || raw.contains('timeout')) return 'timed out';
    return raw.replaceAll(RegExp(r'\w+Exception:\s*'), '').split('\n').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DbConnectionProvider, AppSettingsProvider>(
      builder: (context, conn, settings, _) {
        final status = conn.status;
        final activeUrl = conn.connectedUrl;
        final savedIp = settings.currentSettings.serverIp;
        final savedPort = settings.currentSettings.serverPort;

        String? activeHost;
        if (activeUrl != null) {
          try { activeHost = Uri.parse(activeUrl).host; } catch (_) { activeHost = activeUrl; }
        }

        // What IP are we actually talking to (or trying to)?
        final displayHost = activeHost ?? savedIp;

        final retrying = conn.isRetryPending;

        final (statusColor, statusLabel) = switch (status) {
          ConnectionStatus.connected    => (Colors.green.shade600,  'connected'),
          ConnectionStatus.connecting   => (Colors.orange.shade600, 'connecting…'),
          ConnectionStatus.failed       => retrying
              ? (Colors.orange.shade600, 'reconnecting…')
              : (Colors.red.shade600,    'failed'),
          ConnectionStatus.disconnected => retrying
              ? (Colors.orange.shade600, 'reconnecting…')
              : (Colors.grey.shade500,   'disconnected'),
        };

        final errorMsg = (status == ConnectionStatus.failed && !retrying && conn.lastError != null)
            ? _simplifyError(conn.lastError!)
            : null;

        final mismatch = activeHost != null && activeHost != savedIp;

        return Card(
          margin: EdgeInsets.zero,
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary line: IP is the headline
                Text(
                  '$displayHost:$savedPort',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                // Secondary line: coloured status dot + label
                Row(
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 10),
                    const SizedBox(width: 5),
                    Text(statusLabel,
                        style: TextStyle(fontSize: 12, color: statusColor)),
                    if (errorMsg != null) ...[
                      Text(' — $errorMsg',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
                    ],
                    if (mismatch) ...[
                      const SizedBox(width: 8),
                      Text('(saved: $savedIp)',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
