import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/password.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/labeled_field.dart';

/// Set a new PIN, or change the existing one — same form either way.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  String? _validatePin(String? v) {
    final value = v?.trim() ?? '';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) return 'Enter a 4-digit PIN';
    return null;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_pin.text != _confirmPin.text) {
      setState(() => _error = "PINs don't match");
      return;
    }
    setState(() => _saving = true);
    try {
      await Repos.instance.users.updateProfile(
        widget.user.copyWith(
          pinHash: hashPassword(_pin.text),
          autoLockMinutes: widget.user.autoLockMinutes ?? 0,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChange = widget.user.pinHash != null;
    return Scaffold(
      appBar: AppBar(title: Text(isChange ? 'Change PIN' : 'Set PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Used to unlock the app instead of typing your password every time.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              LabeledField(
                label: 'NEW PIN',
                hint: '4-digit PIN',
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: _validatePin,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'CONFIRM PIN',
                hint: 'Re-enter the PIN',
                controller: _confirmPin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: _validatePin,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: AppColors.negative)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'SAVING...' : 'SAVE PIN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
