// client/lib/widgets/session_panel_header.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionPanelHeader extends StatelessWidget {
  final DateTime? clubSessionStartDateTime;
  final DateTime defaultSessionStartDateTime;
  final VoidCallback onToggleClubSessionTime;
  final String playerFilterText;
  final int? selectedPlayerId;
  final ValueChanged<int?>? onPlayerSelected;

  const SessionPanelHeader({
    super.key,
    required this.clubSessionStartDateTime,
    required this.defaultSessionStartDateTime,
    required this.onToggleClubSessionTime,
    required this.playerFilterText,
    this.selectedPlayerId,
    this.onPlayerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool showOnlyActiveSessions = clubSessionStartDateTime != null;
    final line1 =
        showOnlyActiveSessions ? 'Active sessions only' : 'All sessions';
    final combinedText = '$line1\n$playerFilterText';

    final bool isPlayerSelected = selectedPlayerId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggleClubSessionTime,
              child: Text(
                showOnlyActiveSessions
                    ? 'Club session started at ${DateFormat("yyyy-MM-dd HH:mm").format(clubSessionStartDateTime!)}'
                    : 'Tap to start club session at ${DateFormat("yyyy-MM-dd HH:mm").format(defaultSessionStartDateTime)}',
                style: TextStyle(
                    fontSize: 16,
                    fontStyle: showOnlyActiveSessions
                        ? FontStyle.normal
                        : FontStyle.italic),
              ),
            ),
          ),
          InkWell(
            onTap: isPlayerSelected ? () => onPlayerSelected?.call(null) : null,
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: isPlayerSelected
                    ? Theme.of(context).highlightColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                combinedText,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      ),
    );
  }
}