import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/password.dart';
import '../../data/biometric_service.dart';
import '../theme/tokens.dart';
import '../widgets/labeled_field.dart';

/// Shown instead of the full phone+password login once a PIN is configured
/// — on cold start, and again whenever the auto-lock timer trips.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.user,
    required this.onUnlocked,
    required this.onUseFullLogin,
  });
  final AppUser user;
  final VoidCallback onUnlocked;
  final VoidCallback onUseFullLogin;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.user.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final ok = await BiometricService.instance.authenticate();
    if (ok && mounted) widget.onUnlocked();
  }

  void _submitPin() {
    if (widget.user.pinHash != null &&
        verifyPassword(_pin.text.trim(), widget.user.pinHash!)) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Wrong PIN';
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter your PIN',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
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
                      if (v.length == 4) _submitPin();
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: AppColors.negative)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitPin,
                      child: const Text('UNLOCK'),
                    ),
                  ),
                  if (widget.user.biometricEnabled) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _tryBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('USE BIOMETRIC'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: widget.onUseFullLogin,
                    child: Text(
                      'Forgot PIN? Log in with password',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
