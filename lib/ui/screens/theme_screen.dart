import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import '../theme/tokens.dart';

const _options = [
  (mode: ThemeMode.light, label: 'Light', icon: Icons.light_mode_outlined),
  (mode: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_outlined),
  (
    mode: ThemeMode.system,
    label: 'System default',
    icon: Icons.brightness_auto_outlined,
  ),
];

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) {
          final current = ThemeController.instance.mode;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final option in _options)
                ListTile(
                  onTap: () => ThemeController.instance.setMode(option.mode),
                  leading: Icon(
                    option.icon,
                    color: current == option.mode
                        ? AppColors.primary
                        : AppColors.inactiveIcon,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: current == option.mode ? AppColors.primary : null,
                    ),
                  ),
                  trailing: current == option.mode
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
