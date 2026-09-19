import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../widgets/date_range_bar.dart';
import '../widgets/diesel_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_widgets.dart' show MonthHeader;

/// The two ways to read the same figures.
enum _View { entries, byVehicle }

/// Empty string stands for "All vehicles" in the picker (a real vehicle
/// number is never empty).
const _allVehicles = '';

/// Every diesel entry — optionally for one vehicle and a From/To range —
/// month by month with the total litres and amount, or added up per vehicle
/// to show who used how many litres. Share/Print in the app bar produce the
/// same as a PDF.
class DieselReportScreen extends StatefulWidget {
  const DieselReportScreen({super.key});

  @override
  State<DieselReportScreen> createState() => _DieselReportScreenState();
}

class _DieselReportScreenState extends State<DieselReportScreen> {
  List<DieselEntry>? _all;
  String _vehicle = _allVehicles;
  _View _view = _View.entries;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await Repos.instance.diesel.list();
    if (!mounted) return;
    setState(() => _all = entries);
  }

  String get _periodLabel {
    if (_from == null && _to == null) return 'All dates';
    final from = _from == null ? 'start' : formatDateIso(_from!);
    final to = _to == null ? 'today' : formatDateIso(_to!);
    return '$from to $to';
  }

  Future<Uint8List> _buildPdf(List<DieselEntry> entries) async {
    final user = await Repos.instance.users.getUser();
    return buildDieselReportPdf(
      businessName: user?.businessName,
      title: _vehicle == _allVehicles ? 'Diesel Report' : 'Diesel - $_vehicle',
      filters:
          '${_vehicle == _allVehicles ? 'All vehicles' : 'Vehicle $_vehicle'}'
          ' | $_periodLabel',
      groups: groupDieselByMonth(entries),
      byVehicle: dieselByVehicle(entries),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    if (all == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diesel Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final range = DateRange(from: _from, to: _to);
    final entries = [
      for (final e in all)
        if (range.containsIso(e.date) &&
            (_vehicle == _allVehicles || e.vehicleNo == _vehicle))
          e,
    ];
    final vehicles = <String>{for (final e in all) e.vehicleNo, _vehicle}
      ..remove(_allVehicles);
    final options = vehicles.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diesel Report'),
        actions: [
          ReportActions(
            enabled: entries.isNotEmpty,
            filename: pdfFileName(
              _vehicle == _allVehicles ? 'diesel_report' : 'diesel_$_vehicle',
            ),
            buildPdf: () => _buildPdf(entries),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _vehicle,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'VEHICLE'),
              items: [
                const DropdownMenuItem(
                  value: _allVehicles,
                  child: Text('All vehicles'),
                ),
                for (final n in options)
                  DropdownMenuItem(
                    value: n,
                    child: Text(n, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _vehicle = v ?? _allVehicles),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: DateRangeBar(
              from: _from,
              to: _to,
              onChanged: (v) => setState(() {
                _from = v.$1;
                _to = v.$2;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_View>(
                key: const ValueKey('dieselView'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _View.entries, label: Text('Entries')),
                  ButtonSegment(
                    value: _View.byVehicle,
                    label: Text('By vehicle'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
          if (entries.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.local_gas_station_outlined,
                message: 'No diesel entries for this selection.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: DieselTotalsCard(
                litres: entries.litres,
                amount: entries.amount,
              ),
            ),
            Expanded(
              child: _view == _View.entries
                  ? _DieselList(groups: groupDieselByMonth(entries))
                  : _VehicleList(totals: dieselByVehicle(entries)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every entry, with a header above each month. Flattened into one lazily
/// built list so hundreds of entries stay smooth.
class _DieselList extends StatelessWidget {
  const _DieselList({required this.groups});
  final List<DieselMonthGroup> groups;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[
      for (final g in groups) ...[g, ...g.entries],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is DieselMonthGroup) {
          final count = row.entries.length;
          return MonthHeader(
            title: formatMonthLabel(row.monthKey),
            detail:
                '$count ${count == 1 ? 'entry' : 'entries'}\n'
                '${formatLitres(row.entries.litres)} L  •  '
                '${formatPkrCurrency(row.entries.amount)}',
            trailing: '',
          );
        }
        return DieselTile(entry: row as DieselEntry);
      },
    );
  }
}

/// One row per vehicle, the biggest user first.
class _VehicleList extends StatelessWidget {
  const _VehicleList({required this.totals});
  final List<DieselVehicleTotal> totals;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: totals.length,
      itemBuilder: (context, i) => DieselVehicleTile(total: totals[i]),
    );
  }
}
