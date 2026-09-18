import 'package:flutter/foundation.dart';

/// Fires whenever any repository writes data, so screens can refresh.
/// Uses Flutter's built-in ChangeNotifier — no state-management package needed.
class DataBus extends ChangeNotifier {
  DataBus._();
  static final DataBus instance = DataBus._();

  void notifyChanged() => notifyListeners();
}
