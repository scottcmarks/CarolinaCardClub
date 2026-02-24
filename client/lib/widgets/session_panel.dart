// client/lib/widgets/session_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../models/session.dart'; // Updated from SessionPanelItem

class SessionPanel extends StatelessWidget {
  // FIXED: Converted 'key' to a super parameter
  const SessionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final sessions = api.displayedSessions;

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(api, sessions.length),
          const Divider(height: 1),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      api.isClubSessionOpen
                        ? "No Active Sessions"
                        : "No Recorded History",
                      style: TextStyle(color: Colors.grey.shade500),
                    )
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: sessions.length,
                    itemBuilder: (ctx, i) => _buildSessionCard(context, sessions[i], api),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ApiProvider api, int count) {
    String title = "Session History";
    if (api.isClubSessionOpen) {
      title = "Active Floor";
    }

    if (api.selectedPlayerId != null) {
      final player = api.players.firstWhere(
        (p) => p.playerId == api.selectedPlayerId,
        orElse: () => api.players.first
      );
      title += " (${player.name})";
    } else {
      title += " (All)";
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$title: $count",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (api.isClubSessionOpen && api.clubSessionStartDateTime != null)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: Colors.green.shade100,
                 borderRadius: BorderRadius.circular(4)
               ),
               child: Text(
                 "Billing Active",
                 style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Session session, ApiProvider api) {
    final tableName = session.pokerTableId != null
        ? "Table ${session.pokerTableId} - Seat ${session.seatNumber ?? '?'}"
        : "Unseated (Legacy)";

    final bool isActive = session.stopTime == null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive ? Colors.white : Colors.grey.shade200,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: session.isPrepaid ? Colors.purple.shade100 : Colors.blue.shade100,
          child: Icon(session.isPrepaid ? Icons.timelapse : Icons.access_time),
        ),
        title: Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$tableName ${isActive ? '' : '(Closed)'}"),
        trailing: Consumer<ApiProvider>(
          builder: (ctx, provider, _) {
            try {
              // Safely find the player object to feed into the new dynamic balance method
              final player = provider.players.firstWhere((p) => p.playerId == session.playerId);
              final balance = provider.getDynamicBalance(player);

              return Text(
                "\$$balance", // Simplified for integer display
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: balance < 0 ? Colors.red : Colors.green,
                ),
              );
            } catch (e) {
              return const Text("\$---"); // Fallback if player data is missing
            }
          },
        ),
        onTap: isActive ? () => _showStopDialog(context, session, api) : null,
      ),
    );
  }

  void _showStopDialog(BuildContext context, Session session, ApiProvider api) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Stop Session: ${session.name}?"),
        content: const Text("This will calculate the final cost and update the player's balance."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);

              final stopEpoch = (DateTime.now().millisecondsSinceEpoch / 1000).round();

              try {
                await api.stopSession(session.sessionId, stopEpoch);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${session.name}'s session stopped successfully."))
                  );
                }
              } catch (e) {
                 if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to stop session: $e"))
                  );
                }
              }
            },
            child: const Text("Stop Session"),
          ),
        ],
      ),
    );
  }
}