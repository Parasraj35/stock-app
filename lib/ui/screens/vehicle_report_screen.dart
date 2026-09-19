import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart';
import '../../core/statement.dart'
    show LedgerKind, formatBalance, formatBalanceWith;
import '../../core/vehicles.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/date_range_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_summary.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_widgets.dart';

/// Empty string stands for "All vehicles" in the picker (a real vehicle
/// number is never empty).
const _allVehicles = '';

/// The kinds of entry a vehicle report can include, in the order shown.
const _kindOrder = [
  LedgerKind.purchase,
  LedgerKind.sale,
  LedgerKind.debit,
  LedgerKind.credit,
];

/// Everything by vehicle — its trips (purchases and sales) and its Debit and
/// Credit entries. Pick one vehicle (a statement, like a party's) or all of
/// them, which kinds to include, and a From/To range. Share/Print in the app
/// bar produce the same list as a PDF.
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
  List<MoneyEntry> _money = const [];
  List<String> _options = const [];
  String _selected = _allVehicles;
  final Set<LedgerKind> _kinds = {..._kindOrder};
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
      Repos.instance.money.list(),
    ]);
    final purchases = results[0] as List<Entry>;
    final sales = results[1] as List<Entry>;
    final vehicles = results[2] as List<Vehicle>;
    final money = results[3] as List<MoneyEntry>;
    // Every saved vehicle, plus any number that appears on an entry, so
    // whatever has data can be picked.
    final numbers = <String>{
      for (final v in vehicles)
        if (normalizeVehicleNo(v.vehicleNo) != null)
          normalizeVehicleNo(v.vehicleNo)!,
      for (final e in [...purchases, ...sales])
        if (normalizeVehicleNo(e.vehicleNo) != null)
          normalizeVehicleNo(e.vehicleNo)!,
      for (final m in money)
        if (normalizeVehicleNo(m.vehicleNo) != null)
          normalizeVehicleNo(m.vehicleNo)!,
      if (_selected != _allVehicles) _selected,
    };
    if (!mounted) return;
    setState(() {
      _purchases = purchases;
      _sales = sales;
      _money = money;
      _options = numbers.toList()..sort();
    });
  }

  bool get _wantsTrips =>
      _kinds.contains(LedgerKind.purchase) || _kinds.contains(LedgerKind.sale);

  /// Both purchases and sales are in, so each trip says which it is.
  bool get _showType =>
      _kinds.contains(LedgerKind.purchase) && _kinds.contains(LedgerKind.sale);

  /// Both debit and credit are in, so a balance means something (with only one
  /// of them it would leave out the other half).
  bool get _showBalance =>
      _kinds.contains(LedgerKind.debit) && _kinds.contains(LedgerKind.credit);

  String get _kindsLabel => [
    for (final k in _kindOrder)
      if (_kinds.contains(k)) k.label,
  ].join(', ');

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
      filters: '$_kindsLabel | $_periodLabel',
      groups: groups,
      showType: _showType,
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
    final purchases = _kinds.contains(LedgerKind.purchase)
        ? filterByDateRange(allPurchases, range)
        : const <Entry>[];
    final sales = _kinds.contains(LedgerKind.sale)
        ? filterByDateRange(allSales, range)
        : const <Entry>[];
    final money = [
      for (final m in _money)
        if (range.containsIso(m.date) &&
            _kinds.contains(
              m.type == MoneyType.debit ? LedgerKind.debit : LedgerKind.credit,
            ))
          m,
    ];
    final groups = [
      for (final g in groupLedgerByVehicle(purchases, sales, money))
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final k in _kindOrder)
                    FilterChip(
                      key: ValueKey('kind-${k.name}'),
                      label: Text(k.label),
                      selected: _kinds.contains(k),
                      onSelected: (on) => setState(() {
                        // One kind always stays on: an empty report says
                        // nothing.
                        if (!on && _kinds.length == 1) return;
                        if (on) {
                          _kinds.add(k);
                        } else {
                          _kinds.remove(k);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
              child: _SummaryCard(
                groups: groups,
                wantsTrips: _wantsTrips,
                kinds: _kinds,
                showBalance: _showBalance,
              ),
            ),
            Expanded(
              child: _VehicleList(
                groups: groups,
                showType: _showType,
                showBalance: _showBalance,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.groups,
    required this.wantsTrips,
    required this.kinds,
    required this.showBalance,
  });
  final List<VehicleGroup> groups;
  final bool wantsTrips;
  final Set<LedgerKind> kinds;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final entries = groups.fold<int>(0, (sum, g) => sum + g.lines.length);
    final moneyCount = groups.fold<int>(0, (sum, g) => sum + g.money.length);
    final rounds = groups.fold<double>(0, (sum, g) => sum + g.rounds);
    final cft = groups.fold<double>(0, (sum, g) => sum + g.totalCft);
    final purchased = groups.fold<double>(
      0,
      (sum, g) => sum + g.purchaseAmount,
    );
    final sold = groups.fold<double>(0, (sum, g) => sum + g.saleAmount);
    final debit = groups.fold<double>(0, (sum, g) => sum + g.debit);
    final credit = groups.fold<double>(0, (sum, g) => sum + g.credit);
    final headline = [
      if (wantsTrips)
        '$entries ${entries == 1 ? 'ENTRY' : 'ENTRIES'} • ${formatDecimal(rounds)} ROUNDS • ${formatGroupedNumber(cft)} CFT',
      if (kinds.contains(LedgerKind.debit) || kinds.contains(LedgerKind.credit))
        '$moneyCount DEBIT/CREDIT',
    ].join(' • ');
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
            headline,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppColors.textSecondary,
            ),
          ),
          if (kinds.contains(LedgerKind.purchase) ||
              kinds.contains(LedgerKind.sale)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (kinds.contains(LedgerKind.purchase))
                  Expanded(
                    child: StatColumn(
                      label: 'BOUGHT',
                      value: purchased,
                      color: AppColors.purchaseColor,
                    ),
                  ),
                if (kinds.contains(LedgerKind.sale))
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
          if (kinds.contains(LedgerKind.debit) ||
              kinds.contains(LedgerKind.credit)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (kinds.contains(LedgerKind.debit))
                  Expanded(
                    child: StatColumn(
                      label: 'DEBIT',
                      value: debit,
                      color: moneyTypeColor(MoneyType.debit),
                    ),
                  ),
                if (kinds.contains(LedgerKind.credit))
                  Expanded(
                    child: StatColumn(
                      label: 'CREDIT',
                      value: credit,
                      color: moneyTypeColor(MoneyType.credit),
                    ),
                  ),
              ],
            ),
          ],
          if (showBalance && moneyCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Debit & Credit balance: ${formatBalance(debit - credit)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The small heading above a vehicle's Debit/Credit entries, with their totals
/// (and the balance, when both sides are in the report).
class _MoneyHeader {
  const _MoneyHeader(this.group);
  final VehicleGroup group;
}

/// Every trip and every Debit/Credit entry, with a header above each vehicle.
/// Flattened into one lazily built list so hundreds of entries stay smooth.
class _VehicleList extends StatelessWidget {
  const _VehicleList({
    required this.groups,
    required this.showType,
    required this.showBalance,
  });
  final List<VehicleGroup> groups;
  final bool showType;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[
      for (final g in groups) ...[
        g,
        ...g.lines,
        if (g.money.isNotEmpty) ...[_MoneyHeader(g), ...g.money],
      ],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is VehicleGroup) return _vehicleHeader(row);
        if (row is _MoneyHeader) return _moneyHeader(row.group);
        if (row is MoneyEntry) return MoneyTile(entry: row, showTarget: false);
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

  Widget _vehicleHeader(VehicleGroup g) {
    final title = g.vehicleNo ?? 'No vehicle';
    if (g.lines.isEmpty) {
      return MonthHeader(title: title, detail: 'No trips', trailing: '');
    }
    final base =
        '${g.lines.length} ${g.lines.length == 1 ? 'entry' : 'entries'} • ${formatDecimal(g.rounds)} rounds • ${formatGroupedNumber(g.totalCft)} cft';
    return MonthHeader(
      title: title,
      detail: showType
          ? '$base\nBuy ${formatPkrCurrency(g.purchaseAmount)}  •  Sell ${formatPkrCurrency(g.saleAmount)}'
          : base,
      trailing: showType
          ? ''
          : formatPkrCurrency(g.purchaseAmount + g.saleAmount),
    );
  }

  Widget _moneyHeader(VehicleGroup g) {
    final name = g.vehicleNo ?? 'No vehicle';
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBIT & CREDIT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Debit ${formatPkrCurrency(g.debit)}  •  '
            'Credit ${formatPkrCurrency(g.credit)}',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          if (showBalance) ...[
            const SizedBox(height: 2),
            Text(
              'Balance: ${formatBalanceWith(name, g.balance)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}
