// Framework-free vehicle helpers: no Flutter, no DB imports.
import 'models.dart';

/// Vehicle numbers are compared and stored trimmed and upper-case, so
/// "tlm-954 " and "TLM-954" are the same vehicle. Null when there's nothing
/// left (blank or missing).
String? normalizeVehicleNo(String? value) {
  final v = value?.trim().toUpperCase();
  return (v == null || v.isEmpty) ? null : v;
}

/// The vehicle that carries exactly [cft] per trip, or null if none does.
/// Each vehicle's CFT is unique, so there is at most one match.
Vehicle? vehicleForCft(List<Vehicle> vehicles, double cft) {
  for (final v in vehicles) {
    if ((v.cft - cft).abs() < 1e-9) return v;
  }
  return null;
}
