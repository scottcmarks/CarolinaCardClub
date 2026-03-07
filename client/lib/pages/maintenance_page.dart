// client/lib/pages/maintenance_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../widgets/set_clock_dialog.dart';
import '../widgets/table_closing_wizard.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance & Debugging')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Database Maintenance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade800,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Backup Database to Remote Vault'),
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Initiating backup...')));
                await api.triggerRemoteBackup();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Backup Successful!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),

          const Divider(height: 48),
          const Text('System Debugging',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Consumer<TimeProvider>(
            builder: (context, time, _) => Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.history_toggle_off, color: Colors.orange),
                title: const Text('Game Clock Offset'),
                subtitle: Text('${time.offset.inMinutes} minutes from system time'),
                trailing: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const SetClockDialog(),
                  ),
                  child: const Text('Set Clock'),
                ),
              ),
            ),
          ),

          const Divider(height: 48),
          const Text('Table Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Column(
              children: api.tables.map((table) {
                return Column(
                  children: [
                    SwitchListTile(
                      title: Text(table.tableName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Capacity: ${table.capacity} seats'),
                      value: table.isActive,
                      activeThumbColor: Colors.green,
                      onChanged: (val) {
                        final nowEpoch =
                            Provider.of<TimeProvider>(context, listen: false).nowEpoch;
                        if (val) {
                          api.toggleTableStatus(table.pokerTableId, true, nowEpoch);
                        } else {
                          final activeSessions = api.sessions
                              .where((s) =>
                                  s.pokerTableId == table.pokerTableId && s.stopTime == null)
                              .toList();
                          if (activeSessions.isEmpty) {
                            api.toggleTableStatus(table.pokerTableId, false, nowEpoch);
                          } else {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => TableClosingWizard(
                                closingTable: table,
                                strandedSessions: activeSessions,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 0),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
