import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A small confirm/cancel dialog for destructive actions (delete, log out).
/// Resolves to true only when the user taps the red confirm button.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: AppColors.negative),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}
