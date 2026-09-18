import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// From/To date picker row shared across report screens — tap either side
/// to pick a date, "All time" clears both.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
  });
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<(DateTime?, DateTime?)> onChanged;

  String _label(DateTime? d) => d == null
      ? 'Any'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickFrom(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: to ?? DateTime(2100),
    );
    if (picked != null) onChanged((picked, to));
  }

  Future<void> _pickTo(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: to ?? DateTime.now(),
      firstDate: from ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged((from, picked));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pickFrom(context),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'FROM'),
              child: Text(_label(from)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _pickTo(context),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'TO'),
              child: Text(_label(to)),
            ),
          ),
        ),
        if (from != null || to != null)
          IconButton(
            icon: Icon(Icons.close, color: AppColors.inactiveIcon),
            tooltip: 'Clear date range',
            onPressed: () => onChanged((null, null)),
          ),
      ],
    );
  }
}
