import 'package:flutter/material.dart';

import '../../data/auth_session.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/settings_row.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'security_screen.dart';
import 'theme_screen.dart';
import 'vehicles_screen.dart';

/// Hub for account-level screens — Profile, Security, Vehicles, Reports and
/// Theme — plus Log out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsRow(
            icon: Icons.person_outline,
            label: 'Profile',
            subtitle: 'Business name, age, gender',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            ),
          ),
          SettingsRow(
            icon: Icons.shield_outlined,
            label: 'Security',
            subtitle: 'PIN lock, auto-lock, biometric unlock',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SecurityScreen()),
            ),
          ),
          SettingsRow(
            icon: Icons.local_shipping_outlined,
            label: 'Vehicles',
            subtitle: 'Vehicle numbers and the CFT each carries',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => VehiclesScreen()),
            ),
          ),
          SettingsRow(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Reports',
            subtitle: 'Export party, purchase, sale and stock PDFs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ReportsScreen()),
            ),
          ),
          SettingsRow(
            icon: Icons.palette_outlined,
            label: 'Theme',
            subtitle: 'Light, dark, or match system',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ThemeScreen()),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          SettingsRow(
            icon: Icons.logout,
            label: 'Log out',
            subtitle: 'Sign out of this account on this phone',
            danger: true,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

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
    // Close every screen above the root so the login screen the auth gate
    // switches to isn't hidden behind Settings.
    Navigator.popUntil(context, (route) => route.isFirst);
    AuthSession.instance.logout();
  }
}
