import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../widgets/date_range_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_widgets.dart';

enum _TypeFilter { both, debit, credit }

/// Which entries the report covers: everything, only those for parties, or
/// only those for vehicles.
enum _Who { all, party, vehicle }

/// Empty string stands for "All parties" / "All vehicles" in the picker (a
/// real party name or vehicle number is never empty).
const _everyone = '';

/// Every Debit and Credit entry — optionally only parties or only vehicles
/// (and then one of them), one side, and a From/To range — grouped month by
/// month. Share/Print in the app bar produce the same list as a PDF.
class MoneyReportScreen extends StatefulWidget {
  const MoneyReportScreen({super.key});

  @override
  State<MoneyReportScreen> createState() => _MoneyReportScreenState();
}

class _MoneyReportScreenState extends State<MoneyReportScreen> {
  List<MoneyEntry>? _all;
  _Who _who = _Who.all;
  String _name = _everyone; // one party / vehicle, when _who is not "all"
  _TypeFilter _type = _TypeFilter.both;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await Repos.instance.money.list();
    if (!mounted) return;
    setState(() => _all = entries);
  }

  String get _typeLabel => switch (_type) {
    _TypeFilter.both => 'Debit and Credit',
    _TypeFilter.debit => 'Debit only',
    _TypeFilter.credit => 'Credit only',
  };

  String get _whoLabel => switch (_who) {
    _Who.all => 'Parties and vehicles',
    _Who.party => _name == _everyone ? 'All parties' : 'Party $_name',
    _Who.vehicle => _name == _everyone ? 'All vehicles' : 'Vehicle $_name',
  };

  bool _wantsType(MoneyEntry e) => switch (_type) {
    _TypeFilter.both => true,
    _TypeFilter.debit => e.type == MoneyType.debit,
    _TypeFilter.credit => e.type == MoneyType.credit,
  };

  bool _wantsWho(MoneyEntry e) => switch (_who) {
    _Who.all => true,
    _Who.party =>
      e.target == MoneyTarget.party && (_name == _everyone || e.party == _name),
    _Who.vehicle =>
      e.target == MoneyTarget.vehicle &&
          (_name == _everyone || e.vehicleNo == _name),
  };

  String get _periodLabel {
    if (_from == null && _to == null) return 'All dates';
    final from = _from == null ? 'start' : formatDateIso(_from!);
    final to = _to == null ? 'today' : formatDateIso(_to!);
    return '$from to $to';
  }

  Future<Uint8List> _buildPdf(List<MoneyEntry> entries) async {
    final user = await Repos.instance.users.getUser();
    return buildMoneyReportPdf(
      businessName: user?.businessName,
      title: _name == _everyone
          ? 'Debit & Credit Report'
          : 'Debit & Credit - $_name',
      filters: '$_typeLabel | $_whoLabel | $_periodLabel',
      groups: groupMoneyByMonth(entries),
      showType: _type == _TypeFilter.both,
      showParty: _who != _Who.vehicle,
      showVehicle: _who != _Who.party,
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    if (all == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debit & Credit Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final range = DateRange(from: _from, to: _to);
    final entries = [
      for (final e in all)
        if (range.containsIso(e.date) && _wantsWho(e) && _wantsType(e)) e,
    ];
    // The names to pick from: every party (or vehicle) that has an entry.
    final names = <String>{
      for (final e in all)
        if (_who == _Who.party ? e.party != null : e.vehicleNo != null) e.name,
      _name,
    }..remove(_everyone);
    final options = names.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debit & Credit Report'),
        actions: [
          ReportActions(
            enabled: entries.isNotEmpty,
            filename: pdfFileName(
              _name == _everyone ? 'debit_credit_report' : 'debit_$_name',
            ),
            buildPdf: () => _buildPdf(entries),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Who>(
                key: const ValueKey('moneyWho'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Who.all, label: Text('All')),
                  ButtonSegment(
                    value: _Who.party,
                    icon: Icon(Icons.person_outline, size: 18),
                    label: Text('Party'),
                  ),
                  ButtonSegment(
                    value: _Who.vehicle,
                    icon: Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text('Vehicle'),
                  ),
                ],
                selected: {_who},
                onSelectionChanged: (s) => setState(() {
                  _who = s.first;
                  // A party's name means nothing as a vehicle: start over.
                  _name = _everyone;
                }),
              ),
            ),
          ),
          if (_who != _Who.all)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: DropdownButtonFormField<String>(
                // A new picker per side, so it starts on "All ...".
                key: ValueKey('moneyName-${_who.name}'),
                initialValue: _name,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _who == _Who.party ? 'PARTY' : 'VEHICLE',
                ),
                items: [
                  DropdownMenuItem(
                    value: _everyone,
                    child: Text(
                      _who == _Who.party ? 'All parties' : 'All vehicles',
                    ),
                  ),
                  for (final n in options)
                    DropdownMenuItem(
                      value: n,
                      child: Text(n, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _name = v ?? _everyone),
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
                  ButtonSegment(value: _TypeFilter.debit, label: Text('Debit')),
                  ButtonSegment(
                    value: _TypeFilter.credit,
                    label: Text('Credit'),
                  ),
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
          if (entries.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message: 'No debit or credit entries for this selection.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: MoneyTotalsCard(
                debit: entries.debit,
                credit: entries.credit,
              ),
            ),
            Expanded(child: _MoneyList(groups: groupMoneyByMonth(entries))),
          ],
        ],
      ),
    );
  }
}

/// Every entry, with a header above each month. Flattened into one lazily
/// built list so hundreds of entries stay smooth.
class _MoneyList extends StatelessWidget {
  const _MoneyList({required this.groups});
  final List<MoneyMonthGroup> groups;

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
        if (row is MoneyMonthGroup) {
          final count = row.entries.length;
          return MonthHeader(
            title: formatMonthLabel(row.monthKey),
            detail:
                '$count ${count == 1 ? 'entry' : 'entries'}\n'
                'Debit ${formatPkrCurrency(row.entries.debit)}  •  '
                'Credit ${formatPkrCurrency(row.entries.credit)}',
            trailing: '',
          );
        }
        return MoneyTile(entry: row as MoneyEntry);
      },
    );
  }
}
