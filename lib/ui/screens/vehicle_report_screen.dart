import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart';
import '../../core/vehicles.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/date_range_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_summary.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_widgets.dart';

enum _TypeFilter { both, purchase, sale }

/// Empty string stands for "All vehicles" in the picker (a real vehicle
/// number is never empty).
const _allVehicles = '';

/// Every trip by vehicle — pick one vehicle (a statement, like a party's) or
/// all of them, Purchase / Sale / both, and a From/To range. Share/Print in
/// the app bar produce the same list as a PDF.
class VehicleReportScreen extends StatefulWidget {
  const VehicleReportScreen({super.key, this.initialVehicleNo});

  /// Opens with this vehicle already picked (from the Vehicles screen).
  final String? initialVehicleNo;

  @override
  State<VehicleReportScreen> createState() => _VehicleReportScreenState();
}

class _VehicleReportScreenState extends State<VehicleReportScreen> {
  List<Entry>? _purchases;
  List<Entry>? _sales;
  List<String> _options = const [];
  String _selected = _allVehicles;
  _TypeFilter _type = _TypeFilter.both;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _selected = normalizeVehicleNo(widget.initialVehicleNo) ?? _allVehicles;
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Repos.instance.purchases.list(),
      Repos.instance.sales.list(),
      Repos.instance.vehicles.list(),
    ]);
    final purchases = results[0] as List<Entry>;
    final sales = results[1] as List<Entry>;
    final vehicles = results[2] as List<Vehicle>;
    // Every saved vehicle, plus any number that appears on an entry, so
    // whatever has data can be picked.
    final numbers = <String>{
      for (final v in vehicles)
        if (normalizeVehicleNo(v.vehicleNo) != null)
          normalizeVehicleNo(v.vehicleNo)!,
      for (final e in [...purchases, ...sales])
        if (normalizeVehicleNo(e.vehicleNo) != null)
          normalizeVehicleNo(e.vehicleNo)!,
      if (_selected != _allVehicles) _selected,
    };
    if (!mounted) return;
    setState(() {
      _purchases = purchases;
      _sales = sales;
      _options = numbers.toList()..sort();
    });
  }

  String get _typeLabel => switch (_type) {
    _TypeFilter.both => 'Purchase and Sale',
    _TypeFilter.purchase => 'Purchase only',
    _TypeFilter.sale => 'Sale only',
  };

  String get _periodLabel {
    if (_from == null && _to == null) return 'All dates';
    final from = _from == null ? 'start' : formatDateIso(_from!);
    final to = _to == null ? 'today' : formatDateIso(_to!);
    return '$from to $to';
  }

  Future<Uint8List> _buildPdf(List<VehicleGroup> groups) async {
    final user = await Repos.instance.users.getUser();
    return buildVehicleReportPdf(
      businessName: user?.businessName,
      title: _selected == _allVehicles
          ? 'Vehicle Report - All vehicles'
          : 'Vehicle Statement - $_selected',
      filters: '$_typeLabel | $_periodLabel',
      groups: groups,
      showType: _type == _TypeFilter.both,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPurchases = _purchases;
    final allSales = _sales;
    if (allPurchases == null || allSales == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final range = DateRange(from: _from, to: _to);
    final purchases = _type == _TypeFilter.sale
        ? const <Entry>[]
        : filterByDateRange(allPurchases, range);
    final sales = _type == _TypeFilter.purchase
        ? const <Entry>[]
        : filterByDateRange(allSales, range);
    final groups = [
      for (final g in groupLedgerByVehicle(purchases, sales))
        if (_selected == _allVehicles || g.vehicleNo == _selected) g,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Report'),
        actions: [
          ReportActions(
            enabled: groups.isNotEmpty,
            filename: pdfFileName(
              _selected == _allVehicles
                  ? 'vehicle_report'
                  : 'vehicle_$_selected',
            ),
            buildPdf: () => _buildPdf(groups),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'VEHICLE'),
              items: [
                const DropdownMenuItem(
                  value: _allVehicles,
                  child: Text('All vehicles'),
                ),
                for (final n in _options)
                  DropdownMenuItem(value: n, child: Text(n)),
              ],
              onChanged: (v) => setState(() => _selected = v ?? _allVehicles),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_TypeFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _TypeFilter.both, label: Text('Both')),
                  ButtonSegment(
                    value: _TypeFilter.purchase,
                    label: Text('Purchase'),
                  ),
                  ButtonSegment(value: _TypeFilter.sale, label: Text('Sale')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
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
          if (groups.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.local_shipping_outlined,
                message: 'No entries for this vehicle and range.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _SummaryCard(groups: groups, type: _type),
            ),
            Expanded(
              child: _VehicleList(
                groups: groups,
                showType: _type == _TypeFilter.both,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.groups, required this.type});
  final List<VehicleGroup> groups;
  final _TypeFilter type;

  @override
  Widget build(BuildContext context) {
    final entries = groups.fold<int>(0, (sum, g) => sum + g.lines.length);
    final rounds = groups.fold<double>(0, (sum, g) => sum + g.rounds);
    final cft = groups.fold<double>(0, (sum, g) => sum + g.totalCft);
    final purchased = groups.fold<double>(
      0,
      (sum, g) => sum + g.purchaseAmount,
    );
    final sold = groups.fold<double>(0, (sum, g) => sum + g.saleAmount);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$entries ${entries == 1 ? 'ENTRY' : 'ENTRIES'} • ${formatDecimal(rounds)} ROUNDS • ${formatGroupedNumber(cft)} CFT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (type != _TypeFilter.sale)
                Expanded(
                  child: StatColumn(
                    label: 'BOUGHT',
                    value: purchased,
                    color: AppColors.purchaseColor,
                  ),
                ),
              if (type != _TypeFilter.purchase)
                Expanded(
                  child: StatColumn(
                    label: 'SOLD',
                    value: sold,
                    color: AppColors.saleColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every trip, with a header above each vehicle. Flattened into one lazily
/// built list so hundreds of entries stay smooth.
class _VehicleList extends StatelessWidget {
  const _VehicleList({required this.groups, required this.showType});
  final List<VehicleGroup> groups;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[
      for (final g in groups) ...[g, ...g.lines],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is VehicleGroup) {
          final base =
              '${row.lines.length} ${row.lines.length == 1 ? 'entry' : 'entries'} • ${formatDecimal(row.rounds)} rounds • ${formatGroupedNumber(row.totalCft)} cft';
          return MonthHeader(
            title: row.vehicleNo ?? 'No vehicle',
            detail: showType
                ? '$base\nBuy ${formatPkrCurrency(row.purchaseAmount)}  •  Sell ${formatPkrCurrency(row.saleAmount)}'
                : base,
            trailing: showType
                ? ''
                : formatPkrCurrency(row.purchaseAmount + row.saleAmount),
          );
        }
        final line = row as PartyLedgerEntry;
        return VoucherTile(
          entry: line.entry,
          isPurchase: line.isPurchase,
          showType: showType,
          showVehicle: false,
        );
      },
    );
  }
}
