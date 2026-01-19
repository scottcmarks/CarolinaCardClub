// client/lib/widgets/set_clock_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/time_provider.dart';

class SetClockDialog extends StatefulWidget {
  const SetClockDialog({super.key});

  @override
  State<SetClockDialog> createState() => _SetClockDialogState();
}

class _SetClockDialogState extends State<SetClockDialog> {
  late TextEditingController _timeController;
  late DateTime _initialTime;
  final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    _initialTime = timeProvider.currentTime;

    _timeController =
        TextEditingController(text: _dateTimeFormat.format(_initialTime));
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    return AlertDialog(
      title: const Text('Set Clock'),
      content: TextFormField(
        controller: _timeController,
        decoration: const InputDecoration(
          labelText: 'Date & Time (yyyy-MM-dd HH:mm:ss)',
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          child: const Text('Set'),
          onPressed: () {
            try {
              final newTime = _dateTimeFormat.parse(_timeController.text);

              final difference = newTime.difference(_initialTime);
              final currentOffset = timeProvider.offset;
              final newTotalOffset = currentOffset + difference;
              timeProvider.setOffset(newTotalOffset);

              Navigator.of(context).pop();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.red,
                  content:
                      Text('Invalid format. Please use yyyy-MM-dd HH:mm:ss.'),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}