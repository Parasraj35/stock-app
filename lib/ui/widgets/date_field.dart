import 'package:flutter/material.dart';

import '../../core/format.dart';

/// The form's DATE field: shows the date and opens the calendar on tap.
/// Shared by the Purchase/Sale and Debit/Credit forms.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'DATE'),
        child: Text(formatDateIso(value)),
      ),
    );
  }
}
