// client/lib/widgets/name_filter_keyboard.dart

import 'package:flutter/material.dart';

/// Compact QWERTY keyboard for filtering a list by name prefix.
/// Each key appends to [filter]; ⌫ removes the last character; the ✕ in the
/// filter bar clears it entirely.
class NameFilterKeyboard extends StatelessWidget {
  final String filter;
  final void Function(String) onFilterChanged;

  const NameFilterKeyboard({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  static const _rows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filter.isEmpty ? 'All players' : 'Filter: ${filter.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: filter.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: filter.isEmpty ? Colors.grey : Colors.blue.shade900,
                    fontWeight: filter.isEmpty ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ),
              if (filter.isNotEmpty)
                GestureDetector(
                  onTap: () => onFilterChanged(''),
                  child: Icon(Icons.clear, size: 16, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        for (int r = 0; r < _rows.length; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final key in _rows[r])
                  _Key(
                    label: key,
                    onTap: () => onFilterChanged(filter + key.toLowerCase()),
                  ),
                if (r == _rows.length - 1) ...[
                  const SizedBox(width: 4),
                  _Key(
                    label: '⌫',
                    onTap: filter.isEmpty
                        ? null
                        : () => onFilterChanged(filter.substring(0, filter.length - 1)),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _Key({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Material(
        color: onTap == null ? Colors.grey.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: 28,
            height: 30,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
