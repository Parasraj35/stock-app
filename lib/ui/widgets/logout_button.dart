import 'package:flutter/material.dart';

import '../../data/auth_session.dart';
import '../theme/tokens.dart';
import 'confirm_dialog.dart';

/// Ends the session: asks first, then closes every open screen so the login
/// screen the auth gate switches to isn't hidden behind them. Data stays on
/// the phone.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Log out?',
      message:
          'You will need your password to sign in again. Your data stays on '
          'this phone.',
      confirmLabel: 'LOG OUT',
    );
    if (!confirmed || !context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    AuthSession.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _logout(context),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('LOG OUT'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.negative,
          side: BorderSide(color: AppColors.negative),
          minimumSize: const Size.fromHeight(50),
        ),
      ),
    );
  }
}
