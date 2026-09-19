import 'package:flutter/material.dart';

import '../widgets/settings_row.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'security_screen.dart';
import 'theme_screen.dart';
import 'vehicles_screen.dart';

/// Hub for account-level screens — Profile, Security, Vehicles, Reports and
/// Theme.
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
        ],
      ),
    );
  }
}
