import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Circular profile photo, falling back to a plain person icon when no
/// photo is set (or its file is missing) — used on the Dashboard header
/// and the Profile screen.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.path,
    this.size = 36,
    this.iconColor,
    this.backgroundColor,
  });

  final String? path;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    final hasPhoto = file != null && file.existsSync();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AppColors.divider,
      backgroundImage: hasPhoto ? FileImage(file) : null,
      child: hasPhoto
          ? null
          : Icon(
              Icons.person_outline,
              color: iconColor ?? AppColors.textSecondary,
              size: size * 0.6,
            ),
    );
  }
}
