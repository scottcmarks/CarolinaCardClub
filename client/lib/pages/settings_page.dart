// client/lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../providers/app_settings_provider.dart';
import '../models/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _apiKeyController;
  late TextEditingController _fmIdController;
  late TextEditingController _fmTableController;
  late TextEditingController _fmSeatController;
  late TextEditingController _hourController;
  late TextEditingController _minuteController;

  @override
  void initState() {
    super.initState();
    final s = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    _ipController = TextEditingController(text: s.serverIp);
    _portController = TextEditingController(text: s.serverPort);
    _apiKeyController = TextEditingController(text: s.localApiKey);
    _fmIdController = TextEditingController(text: s.floorManagerPlayerId?.toString() ?? '');
    _fmTableController = TextEditingController(text: s.floorManagerReservedTable.toString());
    _fmSeatController = TextEditingController(text: s.floorManagerReservedSeat.toString());
    _hourController = TextEditingController(text: s.defaultSessionHour.toString());
    _minuteController = TextEditingController(text: s.defaultSessionMinute.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _apiKeyController.dispose();
    _fmIdController.dispose();
    _fmTableController.dispose();
    _fmSeatController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _save() {
    final provider = Provider.of<AppSettingsProvider>(context, listen: false);
    final current = provider.currentSettings;

    provider.updateSettings(AppSettings(
      serverIp: _ipController.text.isEmpty ? Shared.defaultServerIp : _ipController.text,
      serverPort: _portController.text.isEmpty ? Shared.defaultServerPort : _portController.text,
      localApiKey: _apiKeyController.text.isEmpty ? Shared.defaultLocalApiKey : _apiKeyController.text,
      preferredTheme: current.preferredTheme,
      floorManagerPlayerId: int.tryParse(_fmIdController.text),
      floorManagerReservedTable: int.tryParse(_fmTableController.text) ?? Shared.defaultFloorManagerReservedTable,
      floorManagerReservedSeat: int.tryParse(_fmSeatController.text) ?? Shared.defaultFloorManagerReservedSeat,
      defaultSessionHour: int.tryParse(_hourController.text) ?? Shared.defaultSessionHour,
      defaultSessionMinute: int.tryParse(_minuteController.text) ?? Shared.defaultSessionMinute,
    ));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All Configuration Saved")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Network Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _buildTextField("Server IP", _ipController, Shared.defaultServerIp),
          _buildTextField("Server Port", _portController, Shared.defaultServerPort),
          _buildTextField("Local API Key", _apiKeyController, "Secret Key"),

          const SizedBox(height: 24),
          const Text("Club Session Start Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Row(
            children: [
              Expanded(child: _buildIntField("Default Hour (24h)", _hourController, "19")),
              const SizedBox(width: 16),
              Expanded(child: _buildIntField("Default Minute", _minuteController, "30")),
            ],
          ),

          const SizedBox(height: 24),
          const Text("Floor Manager Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _buildIntField("Manager Player ID", _fmIdController, "Default: ${Shared.defaultFloorManagerPlayerId}"),
          _buildIntField("Reserved Table ID", _fmTableController, "Default: ${Shared.defaultFloorManagerReservedTable}"),
          _buildIntField("Reserved Seat Number", _fmSeatController, "Default: ${Shared.defaultFloorManagerReservedSeat}"),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
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
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _buildIntField(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}