import 'package:flutter/foundation.dart';

/// Lets any screen end the session (log out) without threading callbacks
/// through every route; the auth gate listens and returns to the login
/// screen. Same tiny ChangeNotifier pattern as [DataBus].
class AuthSession extends ChangeNotifier {
  AuthSession._();
  static final AuthSession instance = AuthSession._();

  void logout() => notifyListeners();
}
