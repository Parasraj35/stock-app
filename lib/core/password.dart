// Password hashing + strength rules. Framework-free (no Flutter imports).
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Hashes [password] with a fresh random salt, returned as "salt:hash" (hex).
String hashPassword(String password) {
  final salt = _randomSaltHex();
  return '$salt:${_hashWithSalt(password, salt)}';
}

/// Verifies [password] against a "salt:hash" string produced by [hashPassword].
bool verifyPassword(String password, String stored) {
  final parts = stored.split(':');
  if (parts.length != 2) return false;
  final salt = parts[0];
  final expectedHash = parts[1];
  return _hashWithSalt(password, salt) == expectedHash;
}

/// Scores password strength 0-4: length>=8, has uppercase, has lowercase, has digit.
/// Drives the 4-bar strength meter on the create-account screen.
int passwordStrengthScore(String password) {
  var score = 0;
  if (password.length >= 8) score++;
  if (password.contains(RegExp(r'[A-Z]'))) score++;
  if (password.contains(RegExp(r'[a-z]'))) score++;
  if (password.contains(RegExp(r'[0-9]'))) score++;
  return score;
}

/// Min 8 chars, at least one uppercase, one lowercase, one digit.
bool isStrongPassword(String password) => passwordStrengthScore(password) == 4;

String _hashWithSalt(String password, String salt) {
  final bytes = utf8.encode('$salt:$password');
  return sha256.convert(bytes).toString();
}

String _randomSaltHex() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
