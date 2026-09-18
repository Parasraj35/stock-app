import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../screens/settings_screen.dart';
import 'profile_avatar.dart';

/// Profile button for the teal top bars — shows the account's photo (once
/// uploaded via Profile) instead of a plain icon, refreshes whenever it
/// changes, and opens Settings (Profile, Security, Reports, Theme).
class ProfileHeaderButton extends StatelessWidget {
  const ProfileHeaderButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DataBus.instance,
      builder: (context, _) {
        return FutureBuilder<AppUser?>(
          future: Repos.instance.users.getUser(),
          builder: (context, snapshot) {
            return InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ProfileAvatar(
                  path: snapshot.data?.profilePicPath,
                  size: 36,
                  iconColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
