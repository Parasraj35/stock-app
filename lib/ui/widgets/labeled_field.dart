import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Boxed outline field decoration — label sitting plainly above the box,
/// placeholder text inside. Shared style for screens that use this richer
/// look instead of the app-wide underline theme (Auth, Profile, Security).
OutlineInputBorder boxedFieldBorder() => OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: BorderSide(color: AppColors.divider),
);

InputDecoration boxedFieldDecoration({String? hint, Widget? suffixIcon}) {
  final border = boxedFieldBorder();
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.inactiveIcon, fontSize: 14),
    counterText: '',
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: AppColors.primary, width: 1.6),
    ),
    errorBorder: border.copyWith(
      borderSide: BorderSide(color: AppColors.negative),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: BorderSide(color: AppColors.negative, width: 1.6),
    ),
    suffixIcon: suffixIcon,
  );
}

TextStyle get labeledFieldLabelStyle => TextStyle(
  color: AppColors.textSecondary,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

/// A label above an arbitrary boxed child — for non-TextFormField inputs
/// (dropdowns, read-only value boxes) that still need the same look.
class LabeledBox extends StatelessWidget {
  const LabeledBox({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labeledFieldLabelStyle),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Label above a boxed TextFormField — the common case.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.maxLength,
    this.suffixIcon,
    this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return LabeledBox(
      label: label,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onChanged: onChanged,
        validator: validator,
        decoration: boxedFieldDecoration(hint: hint, suffixIcon: suffixIcon),
      ),
    );
  }
}
