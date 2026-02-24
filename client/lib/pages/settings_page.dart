// client/lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import '../widgets/subnet_scan_dialog.dart';
import '../widgets/set_clock_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    final s = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    _ipController = TextEditingController(text: s.serverIp);
    _portController = TextEditingController(text: s.serverPort.toString());
    _apiKeyController = TextEditingController(text: s.localApiKey);
    _timeoutController = TextEditingController(text: s.scanTimeoutMs.toString());
    _fmIdController = TextEditingController(text: s.floorManagerPlayerId?.toString() ?? '');

    _hourController = TextEditingController(text: Shared.defaultSessionHour.toString());
    _minuteController = TextEditingController(text: Shared.defaultSessionMinute.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _apiKeyController.dispose();
    _timeoutController.dispose();
    _fmIdController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _save() {
    final provider = Provider.of<AppSettingsProvider>(context, listen: false);

    provider.updateSettings(provider.currentSettings.copyWith(
      serverIp: _ipController.text.isEmpty ? Shared.defaultServerIp : _ipController.text,
      serverPort: int.tryParse(_portController.text) ?? Shared.defaultServerPort,
      localApiKey: _apiKeyController.text.isEmpty ? Shared.defaultLocalApiKey : _apiKeyController.text,
      scanTimeoutMs: int.tryParse(_timeoutController.text) ?? Shared.defaultScanTimeout,
      floorManagerPlayerId: int.tryParse(_fmIdController.text),
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All Configuration Saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Settings")), // FIXED: appBar
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Network Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildTextField("Server IP", _ipController, Shared.defaultServerIp),
          _buildIntField("Server Port", _portController, Shared.defaultServerPort.toString()),
          _buildTextField("Local API Key", _apiKeyController, "Secret Key"),
          _buildIntField("Scan Timeout (ms)", _timeoutController, Shared.defaultScanTimeout.toString()),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => const SubnetScanDialog(),
            ),
            icon: const Icon(Icons.radar),
            label: const Text("Auto-Discover Server"),
          ),

          const SizedBox(height: 24),
          const Text("Club Session Start Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildIntField("Hour (24h)", _hourController, Shared.defaultSessionHour.toString())),
              const SizedBox(width: 16),
              Expanded(child: _buildIntField("Minute", _minuteController, Shared.defaultSessionMinute.toString())),
            ],
          ),

          const SizedBox(height: 24),
          const Text("Floor Manager Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildIntField("Manager Player ID", _fmIdController, "Default: ${Shared.defaultFloorManagerPlayerId}"),

          const Divider(height: 48),
          const Text("System Debugging", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Consumer<TimeProvider>(
            builder: (context, time, _) => Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.history_toggle_off, color: Colors.orange),
                title: const Text("Game Clock Offset"),
                subtitle: Text("${time.offset.inMinutes} minutes from system time"),
                trailing: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const SetClockDialog(),
                  ),
                  child: const Text("Set Clock"),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text("Save All Configuration"),
          ),
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