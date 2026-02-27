// client/lib/widgets/session_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../models/session.dart';

class SessionPanel extends StatelessWidget {
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
          _buildHeader(context, api, sessions.length),
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

  Widget _buildHeader(BuildContext context, ApiProvider api, int count) {
    final bool isSessionOpen = api.isClubSessionOpen;
    final bool isPlayerSelected = api.selectedPlayerId != null;

    String title = isSessionOpen ? "Active Sessions" : "Session History";
    String subtitle = isSessionOpen ? "Active sessions only" : "All sessions";

    String playerInfo = "(All Players)";
    if (isPlayerSelected) {
      final player = api.players.firstWhere(
        (p) => p.playerId == api.selectedPlayerId,
        orElse: () => api.players.first
      );
      playerInfo = player.name;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$title: $count",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

              if (isPlayerSelected)
                TextButton.icon(
                  onPressed: () => api.selectPlayer(null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(playerInfo),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.blue.shade700,
                    backgroundColor: Colors.blue.shade50,
                  ),
                )
              else
                Text(playerInfo, style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: isSessionOpen ? FontStyle.normal : FontStyle.italic
                ),
              ),
              const Spacer(),
              if (isSessionOpen && api.clubSessionStartEpoch != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4)
                  ),
                  child: Text(
                    "Started: ${DateFormat("HH:mm").format(DateTime.fromMillisecondsSinceEpoch(api.clubSessionStartEpoch! * 1000))}",
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                    ),
                  ),
                ),
            ],
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
          child: Icon(session.isPrepaid ? Icons.timer_off_outlined : Icons.timer_outlined),
        ),
        title: Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$tableName ${isActive ? '' : '(Closed)'}"),

            if (!isActive) ...[
              const SizedBox(height: 4),
              Text(
                "${_formatDateTime(session.startEpoch)} • ${_formatDuration(session.startEpoch, session.stopTime!)}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
        trailing: Consumer2<ApiProvider, TimeProvider>(
          builder: (ctx, provider, time, _) {
            // Cleaned up: Using the new getter
            final nowEpoch = time.nowEpoch;

            try {
              final player = provider.players.firstWhere((p) => p.playerId == session.playerId);

              if (isActive) {
                final balance = provider.getDynamicBalance(player, nowEpoch);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Balance", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      "\$$balance",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: balance < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                );
              } else {
                int amount = 0;
                if (session.isPrepaid) {
                  amount = session.prepayAmount;
                } else {
                  final elapsed = session.stopTime! - session.startEpoch;
                  if (elapsed > 0) {
                    amount = ((elapsed * player.hourlyRate) / 3600).round();
                  }
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Amount", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      "\$$amount",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                );
              }
            } catch (e) {
              return const Text("\$---");
            }
          },
        ),
        onTap: isActive ? () => _showStopDialog(context, session, api) : null,
      ),
    );
  }

  String _formatDateTime(int epoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    return DateFormat('MM/dd/yy HH:mm').format(dt);
  }

  String _formatDuration(int start, int stop) {
    final diff = stop - start;
    if (diff <= 0) return "00h00m";
    final hours = diff ~/ 3600;
    final minutes = (diff % 3600) ~/ 60;

    return "${hours.toString().padLeft(2, '0')}h${minutes.toString().padLeft(2, '0')}m";
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

              final timeProvider = Provider.of<TimeProvider>(context, listen: false);
              // Cleaned up: Using the new getter
              final stopEpoch = timeProvider.nowEpoch;

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