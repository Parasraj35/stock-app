import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/vehicles.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_summary.dart';
import 'vehicle_form_screen.dart';
import 'vehicle_report_screen.dart';

/// What one vehicle has been bought on / sold on, from the entries recorded
/// with its number.
class _VehicleStats {
  double purchased = 0;
  double sold = 0;
  int entries = 0;
}

class _VehiclesData {
  final List<Vehicle> vehicles;
  final Map<String, _VehicleStats> stats;
  const _VehiclesData(this.vehicles, this.stats);

  int get totalEntries => stats.values.fold(0, (sum, s) => sum + s.entries);
}

Future<_VehiclesData> _load() async {
  final results = await Future.wait([
    Repos.instance.vehicles.list(),
    Repos.instance.purchases.list(),
    Repos.instance.sales.list(),
  ]);
  final stats = <String, _VehicleStats>{};
  void add(List<Entry> entries, {required bool purchase}) {
    for (final e in entries) {
      final key = normalizeVehicleNo(e.vehicleNo);
      if (key == null) continue;
      final s = stats.putIfAbsent(key, _VehicleStats.new);
      if (purchase) {
        s.purchased += e.amount;
      } else {
        s.sold += e.amount;
      }
      s.entries++;
    }
  }

  add(results[1] as List<Entry>, purchase: true);
  add(results[2] as List<Entry>, purchase: false);
  return _VehiclesData(results[0] as List<Vehicle>, stats);
}

/// The fixed vehicles and how much CFT each carries. Reached from Settings.
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'vehiclesFab',
        onPressed: () => _openForm(context, const []),
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: DataBus.instance,
        builder: (context, _) {
          return FutureBuilder<_VehiclesData>(
            future: _load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final vehicles = data.vehicles;
              if (vehicles.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_shipping_outlined,
                  message: 'No vehicles yet.\nTap + to add one.',
                );
              }
              return Column(
                children: [
                  SummaryBanner(
                    icon: Icons.local_shipping_outlined,
                    label:
                        '${vehicles.length} VEHICLE${vehicles.length == 1 ? '' : 'S'}',
                    trailing:
                        '${data.totalEntries} ${data.totalEntries == 1 ? 'entry' : 'entries'}',
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                      itemCount: vehicles.length,
                      itemBuilder: (context, i) {
                        final vehicle = vehicles[i];
                        return _VehicleCard(
                          vehicle: vehicle,
                          stats:
                              data.stats[normalizeVehicleNo(vehicle.vehicleNo)],
                          onTap: () =>
                              _openForm(context, vehicles, existing: vehicle),
                          onStatement: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleReportScreen(
                                initialVehicleNo: vehicle.vehicleNo,
                              ),
                            ),
                          ),
                          onDelete: () => _confirmDelete(context, vehicle),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Vehicle vehicle) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete vehicle?',
      message:
          'Delete "${vehicle.vehicleNo}"? Past entries keep their vehicle '
          'number.',
      confirmLabel: 'DELETE',
    );
    if (confirmed) await Repos.instance.vehicles.delete(vehicle.id!);
  }

  Future<void> _openForm(
    BuildContext context,
    List<Vehicle> vehicles, {
    Vehicle? existing,
  }) async {
    // The FAB has no list to hand (an empty list is only right when there are
    // no vehicles yet), so fetch the current one for the uniqueness checks.
    final current = vehicles.isNotEmpty
        ? vehicles
        : await Repos.instance.vehicles.list();
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VehicleFormScreen(existing: existing, vehicles: current),
      ),
    );
  }
}

/// One vehicle — number, the CFT it carries per trip, what's been bought and
/// sold on it, and a shortcut to its statement.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.stats,
    required this.onTap,
    required this.onStatement,
    required this.onDelete,
  });
  final Vehicle vehicle;
  final _VehicleStats? stats;
  final VoidCallback onTap;
  final VoidCallback onStatement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = avatarColorsFor(vehicle.vehicleNo);
    final entries = stats?.entries ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.local_shipping_outlined, color: fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.vehicleNo,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${formatDecimal(vehicle.cft)} cft per trip',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (entries > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$entries ${entries == 1 ? 'entry' : 'entries'}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatColumn(
                      label: 'BOUGHT',
                      value: stats?.purchased ?? 0,
                      color: AppColors.purchaseColor,
                    ),
                  ),
                  Expanded(
                    child: StatColumn(
                      label: 'SOLD',
                      value: stats?.sold ?? 0,
                      color: AppColors.saleColor,
                    ),
                  ),
                  _CardIconButton(
                    tooltip: 'Statement',
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.accent,
                    onPressed: onStatement,
                  ),
                  const SizedBox(width: 8),
                  _CardIconButton(
                    tooltip: 'Delete vehicle',
                    icon: Icons.delete_outline,
                    color: AppColors.negative,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
