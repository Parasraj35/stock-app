import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/password.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_strength_meter.dart';

/// Password recovery without a backend: verify the account's PIN, then set
/// a new password. Only reachable when the account has a PIN configured.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _pinVerified = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: _pinVerified
          ? _NewPasswordStep(user: widget.user)
          : _VerifyPinStep(
              user: widget.user,
              onVerified: () => setState(() => _pinVerified = true),
            ),
    );
  }
}

class _VerifyPinStep extends StatefulWidget {
  const _VerifyPinStep({required this.user, required this.onVerified});
  final AppUser user;
  final VoidCallback onVerified;

  @override
  State<_VerifyPinStep> createState() => _VerifyPinStepState();
}

class _VerifyPinStepState extends State<_VerifyPinStep> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _verify() {
    if (verifyPassword(_pin.text.trim(), widget.user.pinHash!)) {
      widget.onVerified();
    } else {
      setState(() {
        _error = 'Wrong PIN';
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your PIN to confirm it\'s you, then set a new password.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'PIN',
            hint: '4-digit PIN',
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            onChanged: (v) {
              if (v.length == 4) _verify();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppColors.negative)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _verify,
              child: const Text('VERIFY'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPasswordStep extends StatefulWidget {
  const _NewPasswordStep({required this.user});
  final AppUser user;

  @override
  State<_NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends State<_NewPasswordStep> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _strength = 0;
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Repos.instance.users.updateProfile(
        widget.user.copyWith(passwordHash: hashPassword(_password.text)),
      );
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated — log in with it now'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        isStrongPassword(_password.text) && _confirm.text == _password.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledField(
              label: 'NEW PASSWORD',
              hint: 'Enter a new password',
              controller: _password,
              obscureText: _obscurePassword,
              onChanged: (v) =>
                  setState(() => _strength = passwordStrengthScore(v)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) => !isStrongPassword(v ?? '')
                  ? 'Min 8 chars, with upper, lower and a digit'
                  : null,
            ),
            const SizedBox(height: 8),
            PasswordStrengthMeter(score: _strength),
            const SizedBox(height: 16),
            LabeledField(
              label: 'RE-ENTER PASSWORD',
              hint: 'Re-enter the new password',
              controller: _confirm,
              obscureText: _obscureConfirm,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) =>
                  v != _password.text ? "Passwords don't match" : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_saving || !canSubmit) ? null : _save,
                child: Text(_saving ? 'SAVING...' : 'SAVE NEW PASSWORD'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
