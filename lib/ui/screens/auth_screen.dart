import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/password.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_strength_meter.dart';
import 'forgot_password_screen.dart';

/// Shows CREATE ACCOUNT on the very first run (no user in the DB yet),
/// LOGIN on every run after that. A footer link lets either screen be
/// switched to manually, independent of that initial DB check.
///
/// Field styling here is local to this screen (soft blurred header, boxed
/// outline fields) — intentionally different from the app-wide underline
/// theme, matching a UI reference the user asked to be applied only to Auth.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});
  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = true;
  bool _showLogin = false;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final user = await Repos.instance.users.getUser();
    setState(() {
      _showLogin = user != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _BlurredHeader(
                title: _showLogin ? 'Welcome back' : 'Create account',
                subtitle: _showLogin
                    ? 'Log in to continue tracking your stock.'
                    : 'Set up your account to get started.',
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    child: _showLogin
                        ? _LoginForm(
                            onAuthenticated: widget.onAuthenticated,
                            onSwitchToCreate: () =>
                                setState(() => _showLogin = false),
                          )
                        : _CreateAccountForm(
                            onCreated: widget.onAuthenticated,
                            onSwitchToLogin: () =>
                                setState(() => _showLogin = true),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft blurred teal/mint blobs behind the bold title — a code-only
/// (no image asset) stand-in for the gradient-blob header in the reference.
class _BlurredHeader extends StatelessWidget {
  const _BlurredHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      left: -30,
                      child: _blob(
                        170,
                        AppColors.primary.withValues(alpha: 0.30),
                      ),
                    ),
                    Positioned(
                      top: -30,
                      right: -50,
                      child: _blob(
                        150,
                        AppColors.accent.withValues(alpha: 0.28),
                      ),
                    ),
                    Positioned(
                      bottom: -70,
                      left: 70,
                      child: _blob(
                        140,
                        AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateAccountForm extends StatefulWidget {
  const _CreateAccountForm({
    required this.onCreated,
    required this.onSwitchToLogin,
  });
  final VoidCallback onCreated;
  final VoidCallback onSwitchToLogin;

  @override
  State<_CreateAccountForm> createState() => _CreateAccountFormState();
}

class _CreateAccountFormState extends State<_CreateAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _strength = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _passwordsMatch =>
      _confirm.text.isNotEmpty && _confirm.text == _password.text;
  bool get _passwordsMismatch =>
      _confirm.text.isNotEmpty && _confirm.text != _password.text;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await Repos.instance.users.createUser(
        AppUser(
          username: _username.text.trim(),
          passwordHash: hashPassword(_password.text),
        ),
      );
      widget.onCreated();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = isStrongPassword(_password.text) && _passwordsMatch;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledField(
            label: 'PHONE NUMBER',
            hint: 'Enter your phone number',
            controller: _username,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Phone number is required';
              if (!RegExp(r'^[0-9]{7,15}$').hasMatch(value)) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'PASSWORD',
            hint: 'Enter your password',
            controller: _password,
            obscureText: _obscurePassword,
            onChanged: (v) =>
                setState(() => _strength = passwordStrengthScore(v)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.inactiveIcon,
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
          const SizedBox(height: 14),
          LabeledField(
            label: 'RE-ENTER PASSWORD',
            hint: 'Re-enter your password',
            controller: _confirm,
            obscureText: _obscureConfirm,
            onChanged: (_) => setState(() {}),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.inactiveIcon,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) =>
                v != _password.text ? "Passwords don't match" : null,
          ),
          if (_passwordsMatch || _passwordsMismatch) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _passwordsMatch
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 16,
                  color: _passwordsMatch
                      ? AppColors.accent
                      : AppColors.negative,
                ),
                const SizedBox(width: 6),
                Text(
                  _passwordsMatch ? 'Passwords match' : "Passwords don't match",
                  style: TextStyle(
                    fontSize: 12,
                    color: _passwordsMatch
                        ? AppColors.accent
                        : AppColors.negative,
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppColors.negative)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_submitting || !canSubmit) ? null : _submit,
              child: Text(
                _submitting ? 'CREATING ACCOUNT...' : 'CREATE ACCOUNT',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToLogin,
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'Already have one? '),
                    TextSpan(
                      text: 'Log in',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({
    required this.onAuthenticated,
    required this.onSwitchToCreate,
  });
  final VoidCallback onAuthenticated;
  final VoidCallback onSwitchToCreate;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final user = await Repos.instance.users.getUser();
      final ok =
          user != null &&
          user.username == _username.text.trim() &&
          verifyPassword(_password.text, user.passwordHash);
      if (ok) {
        widget.onAuthenticated();
      } else {
        setState(() => _error = 'Wrong phone number or password');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledField(
            label: 'PHONE NUMBER',
            hint: 'Enter your phone number',
            controller: _username,
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'PASSWORD',
            hint: 'Enter your password',
            controller: _password,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.inactiveIcon,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final user = await Repos.instance.users.getUser();
                if (!context.mounted) return;
                if (user == null || user.pinHash == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Set a PIN in Settings → Security to enable password recovery',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ForgotPasswordScreen(user: user),
                  ),
                );
              },
              child: Text(
                'Forgot password?',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: AppColors.negative)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'LOGGING IN...' : 'LOG IN'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: widget.onSwitchToCreate,
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'New here? '),
                    TextSpan(
                      text: 'Create account',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
