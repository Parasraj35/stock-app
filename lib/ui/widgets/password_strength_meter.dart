import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 4-bar password strength meter; bars fill green as strength rises.
/// Shared between Create Account and Forgot Password (new password) forms.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < score ? AppColors.accent : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
