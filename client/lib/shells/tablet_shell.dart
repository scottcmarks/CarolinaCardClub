// client/lib/shells/tablet_shell.dart
//
// Root widget for the tablet entry point. Checks whether a table number has
// been assigned (stored in AppSettings / shared_preferences). If not, shows a
// first-run setup screen so the operator can select this tablet's table.
// Once assigned, it hands off to TabletTablePage for that single table.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_connection/db_connection.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/poker_table.dart';
import '../pages/tablet_table_page.dart';

class TabletShell extends StatelessWidget {
  const TabletShell({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = Provider.of<AppSettingsProvider>(context);
    final tableNumber = settingsProv.currentSettings.tableNumber;

    if (tableNumber == null) {
      return const _TableSetupScreen();
    }

    return Consumer<ApiProvider>(
      builder: (context, api, _) {
        final table = api.activeTables
            .where((t) => t.pokerTableId == tableNumber)
            .firstOrNull;

        if (table == null) {
          // Table not found (not yet loaded, or deactivated) — show setup.
          return api.activeTables.isEmpty
              ? const _LoadingScreen()
              : _TableGoneScreen(tableNumber: tableNumber);
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
      },
    );
  }
}

// ── First-run table picker ────────────────────────────────────────────────────

class _TableSetupScreen extends StatelessWidget {
  const _TableSetupScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer2<ApiProvider, DbConnectionProvider>(
      builder: (context, api, conn, _) {
        final tables = api.activeTables;

        Widget body;
        if (tables.isEmpty) {
          final isConnected = conn.status == ConnectionStatus.connected;
          body = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  isConnected ? 'No active tables found.' : 'Connecting to server…',
                  style: const TextStyle(fontSize: 16),
                ),
                if (!isConnected) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${Provider.of<AppSettingsProvider>(context, listen: false).currentSettings.serverIp}'
                    ':${Provider.of<AppSettingsProvider>(context, listen: false).currentSettings.serverPort}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          );
        } else {
          body = ListView(
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
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Table Setup'),
            backgroundColor: Color(Shared.carolinaBlue),
            foregroundColor: Colors.white,
          ),
          body: body,
        );
      },
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
        backgroundColor: Color(Shared.carolinaBluePrimary),
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

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(Shared.carolinaBlue),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _TableGoneScreen extends StatelessWidget {
  final int tableNumber;
  const _TableGoneScreen({required this.tableNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Unavailable'),
        backgroundColor: Color(Shared.carolinaBlue),
        foregroundColor: Colors.white,
      ),
      body: Center(
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
