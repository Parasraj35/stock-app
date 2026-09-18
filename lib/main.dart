import 'package:flutter/material.dart';

import 'core/models.dart';
import 'data/data_bus.dart';
import 'data/repos.dart';
import 'ui/app_shell.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/theme/theme_controller.dart';
import 'ui/theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repos = await Repos.init();
  await ThemeController.instance.init();
  runApp(StockApp(repos: repos));
}

class StockApp extends StatelessWidget {
  const StockApp({super.key, required this.repos});
  final Repos repos;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Stock',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: _AuthGate(),
        );
      },
    );
  }
}

/// Routes between: Create-account/Login (no user yet, or no PIN set),
/// LockScreen (PIN set but not yet unlocked this session — cold start, or
/// the auto-lock timer tripped after backgrounding), and AppShell (unlocked).
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  bool _loading = true;
  bool _authenticated = false;
  bool _forceFullLogin = false;
  AppUser? _user;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DataBus.instance.addListener(_reloadUser);
    _reloadUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DataBus.instance.removeListener(_reloadUser);
    super.dispose();
  }

  Future<void> _reloadUser() async {
    final user = await Repos.instance.users.getUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_authenticated || _user?.pinHash == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt == null) return;
      final minutes = _user!.autoLockMinutes ?? 0;
      if (DateTime.now().difference(backgroundedAt) >=
          Duration(minutes: minutes)) {
        setState(() => _authenticated = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_authenticated) {
      return AppShell();
    }
    if (!_forceFullLogin && _user != null && _user!.pinHash != null) {
      return LockScreen(
        user: _user!,
        onUnlocked: () => setState(() => _authenticated = true),
        onUseFullLogin: () => setState(() => _forceFullLogin = true),
      );
    }
    return AuthScreen(
      onAuthenticated: () {
        setState(() {
          _authenticated = true;
          _forceFullLogin = false;
        });
      },
    );
  }
}
