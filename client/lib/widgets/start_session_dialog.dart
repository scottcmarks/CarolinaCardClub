// client/lib/widgets/start_session_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import 'seat_selector_widget.dart';

class StartSessionDialog extends StatefulWidget {
  final PlayerSelectionItem player;
  const StartSessionDialog({super.key, required this.player});

  @override
  State<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<StartSessionDialog> {
  int? _selectedTableId;
  int? _selectedSeat;

  bool _isPrepaid = false;
  final TextEditingController _amountController = TextEditingController();

  int _currentBalance = 0;
  int _targetPrepay = 0;
  bool _initialized = false;

  bool get _isValid => _selectedTableId != null && _selectedSeat != null;

  String get _prepaySubtitle {
    if (_currentBalance >= _targetPrepay) {
      return "Cost: \$$_targetPrepay (Fully covered by balance)";
    } else if (_currentBalance < 0) {
      final totalNeeded = _targetPrepay - _currentBalance;
      return "Requires \$$totalNeeded payment (Cost + Debt)";
    } else if (_currentBalance > 0) {
      final totalNeeded = _targetPrepay - _currentBalance;
      return "Requires \$$totalNeeded payment (After applied credit)";
    } else {
      return "Cost: \$$_targetPrepay";
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      final api = Provider.of<ApiProvider>(context, listen: false);
      final timeProvider = Provider.of<TimeProvider>(context, listen: false);

      _targetPrepay = (widget.player.prepayHours * widget.player.hourlyRate).round();
      _currentBalance = api.getDynamicBalance(widget.player, timeProvider.nowEpoch);

      if (_currentBalance < 0) {
        _amountController.text = (_currentBalance * -1).toString();
      }

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Insufficient Funds", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final timeProvider = Provider.of<TimeProvider>(context);

    final activeTables = api.activeTables;
    final bool needsPaymentUI = _targetPrepay > 0 || _currentBalance < 0;

    return AlertDialog(
      title: Text("Seat ${widget.player.name}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeTables.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "There are no active tables to seat this player. Please open a table in Settings.",
                  style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              if (_currentBalance < 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text("Action Required", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Player has a negative balance (-\$${-_currentBalance}) that must be cleared before proceeding.",
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ],
                  ),
                ),

              // NEW: Grey-out dropdown mapping
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Select Table"),
                initialValue: _selectedTableId,
                items: activeTables.map((t) {
                  final occupiedCount = api.getOccupiedSeatsAndNamesForTable(
                    t.pokerTableId,
                    seatingPlayerId: widget.player.playerId
                  ).length;
                  final isFull = occupiedCount >= t.capacity;

                  return DropdownMenuItem<int>(
                    value: t.pokerTableId,
                    enabled: !isFull,
                    child: Text(
                      isFull
                          ? "${t.tableName} (Full)"
                          : "${t.tableName}  ($occupiedCount/${t.capacity} seated)",
                      style: TextStyle(
                        color: isFull ? Colors.grey : null,
                        fontStyle: isFull ? FontStyle.italic : null,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() {
                  _selectedTableId = val;
                  _selectedSeat = null;
                }),
              ),
              const SizedBox(height: 16),

              if (_selectedTableId != null)
                SeatSelectorWidget(
                  initialSeat: _selectedSeat,
                  maxSeats: activeTables.firstWhere((t) => t.pokerTableId == _selectedTableId).capacity,
                  tableName: activeTables.firstWhere((t) => t.pokerTableId == _selectedTableId).tableName,
                  occupiedSeats: api.getOccupiedSeatsAndNamesForTable(_selectedTableId!, seatingPlayerId: widget.player.playerId),
                  onSeatSelected: (seat) => setState(() => _selectedSeat = seat),
                ),

              if (needsPaymentUI) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: "Payment / Cash Received",
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 12),

                if (_targetPrepay > 0)
                  SwitchListTile(
                    title: const Text("Prepaid Session", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_prepaySubtitle),
                    value: _isPrepaid,
                    activeThumbColor: Colors.blue,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isPrepaid = val;
                        int currentInput = int.tryParse(_amountController.text) ?? 0;
                        int resultingBalance = _currentBalance + currentInput;

                        if (_isPrepaid && resultingBalance < _targetPrepay) {
                          _amountController.text = (_targetPrepay - _currentBalance).toString();
                        } else if (!_isPrepaid && resultingBalance < 0) {
                          _amountController.text = (-_currentBalance).toString();
                        }
                      });
                    },
                  ),
              ]
            ]
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isValid ? () async {
            int paymentAmount = int.tryParse(_amountController.text) ?? 0;
            int resultingBalance = _currentBalance + paymentAmount;

            if (!_isPrepaid && resultingBalance < 0) {
              _showErrorPopup(
                "Resulting balance cannot be negative.\n\n"
                "You must collect at least \$${-_currentBalance} to clear the existing debt."
              );
              return;
            }

            if (_isPrepaid && resultingBalance < _targetPrepay) {
              _showErrorPopup(
                "Insufficient funds for a Prepaid Session.\n\n"
                "The resulting balance must be at least \$$_targetPrepay. "
                "You must collect at least \$${_targetPrepay - _currentBalance}."
              );
              return;
            }

            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);

            int startEpoch = timeProvider.nowEpoch;
            if (api.isClubSessionOpen && api.clubSessionStartEpoch != null) {
              if (api.clubSessionStartEpoch! > startEpoch) {
                startEpoch = api.clubSessionStartEpoch!;
              }
            }

            try {
              if (paymentAmount != 0) {
                await api.addPayment(widget.player.playerId, paymentAmount, startEpoch);
              }

              final session = Session(
                sessionId: 0,
                playerId: widget.player.playerId,
                name: widget.player.name,
                pokerTableId: _selectedTableId,
                seatNumber: _selectedSeat,
                startEpoch: startEpoch,
                isPrepaid: _isPrepaid,
                prepayAmount: _isPrepaid ? _targetPrepay : 0,
                hourlyRate: widget.player.hourlyRate,
              );

              await api.addSession(session);
              api.selectPlayer(widget.player.playerId);
              navigator.pop();
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text("Error: $e"),
                  backgroundColor: Colors.red.shade800,
                )
              );
            }
          } : null,
          child: const Text("Start Session"),
        ),
      ],
    );
  }
}