import 'package:flutter/material.dart';

import '../../data/repos.dart';

/// Drives light/dark/system theme app-wide. AppColors reads [isDark] from
/// this singleton, so switching mode + calling notifyListeners() is enough
/// to repaint every screen — no BuildContext threading required.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._();
  static final instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  bool _isDark = false;
  bool get isDark => _isDark;

  bool _initialized = false;

  /// Loads the persisted choice (from the users row) and starts observing
  /// platform brightness changes for "System" mode. Call once at startup.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final user = await Repos.instance.users.getUser();
    _mode = _parseMode(user?.themeMode);
    _resolve();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    _resolve();
    notifyListeners();
    final user = await Repos.instance.users.getUser();
    if (user != null) {
      await Repos.instance.users.updateProfile(
        user.copyWith(themeMode: _modeName(mode)),
      );
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode != ThemeMode.system) return;
    final wasDark = _isDark;
    _resolve();
    if (wasDark != _isDark) notifyListeners();
  }

  void _resolve() {
    _isDark = switch (_mode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  ThemeMode _parseMode(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  String _modeName(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
