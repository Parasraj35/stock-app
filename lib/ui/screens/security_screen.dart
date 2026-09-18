import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/biometric_service.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/settings_row.dart';
import 'pin_setup_screen.dart';

const _autoLockOptions = {
  0: 'Immediate',
  1: '1 minute',
  5: '5 minutes',
  15: '15 minutes',
  30: '30 minutes',
};

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  AppUser? _user;
  bool _biometricAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Repos.instance.users.getUser(),
      BiometricService.instance.isAvailable(),
    ]);
    if (!mounted) return;
    setState(() {
      _user = results[0] as AppUser?;
      _biometricAvailable = results[1] as bool;
      _loading = false;
    });
  }

  Future<void> _openPinSetup() async {
    if (_user == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => PinSetupScreen(user: _user!)),
    );
    if (changed == true) await _load();
  }

  Future<void> _disablePin() async {
    if (_user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off PIN lock?'),
        content: const Text(
          'You will need your phone number and password to open the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'TURN OFF',
              style: TextStyle(color: AppColors.negative),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Repos.instance.users.updateProfile(_user!.copyWith(clearPin: true));
      await _load();
    }
  }

  Future<void> _pickAutoLock() async {
    if (_user == null) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Auto-lock after'),
        children: [
          for (final entry in _autoLockOptions.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Row(
                children: [
                  Icon(
                    (_user!.autoLockMinutes ?? 0) == entry.key
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: (_user!.autoLockMinutes ?? 0) == entry.key
                        ? AppColors.primary
                        : AppColors.inactiveIcon,
                  ),
                  const SizedBox(width: 12),
                  Text(entry.value),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null) {
      await Repos.instance.users.updateProfile(
        _user!.copyWith(autoLockMinutes: selected),
      );
      await _load();
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_user == null) return;
    await Repos.instance.users.updateProfile(
      _user!.copyWith(biometricEnabled: value),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Security')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final hasPin = _user?.pinHash != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsRow(
            icon: Icons.lock_outline,
            label: hasPin ? 'Change PIN' : 'Set PIN',
            subtitle: hasPin
                ? 'PIN lock is on'
                : 'Unlock with a 4-digit PIN instead of your password',
            onTap: _openPinSetup,
          ),
          if (hasPin) ...[
            SettingsRow(
              icon: Icons.timer_outlined,
              label: 'Auto-lock',
              subtitle:
                  'Lock after ${_autoLockOptions[_user!.autoLockMinutes ?? 0]}',
              onTap: _pickAutoLock,
            ),
            SwitchListTile(
              secondary: Icon(
                Icons.fingerprint,
                color: _biometricAvailable
                    ? AppColors.primary
                    : AppColors.inactiveIcon,
              ),
              title: const Text(
                'Biometric unlock',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _biometricAvailable
                    ? 'Use fingerprint or face unlock'
                    : 'No fingerprint/face unlock enrolled on this device — set one up in your phone\'s system settings first',
                style: const TextStyle(fontSize: 12),
              ),
              value: _biometricAvailable && _user!.biometricEnabled,
              onChanged: _biometricAvailable ? _toggleBiometric : null,
            ),
            SettingsRow(
              icon: Icons.lock_open_outlined,
              label: 'Turn off PIN lock',
              subtitle: 'Go back to logging in with your password',
              onTap: _disablePin,
              danger: true,
            ),
          ],
        ],
      ),
    );
  }
}
