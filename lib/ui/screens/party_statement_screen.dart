import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart' show DateRange;
import '../../core/statement.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../widgets/date_range_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_actions.dart';
import '../widgets/statement_widgets.dart';

/// Pick a party and see everything with them — sales, purchases, debits and
/// credits — in date order with a running balance (optionally for a From/To
/// range, starting from the balance brought forward), and share or print it as
/// a PDF statement.
class PartyStatementScreen extends StatefulWidget {
  const PartyStatementScreen({super.key});

  @override
  State<PartyStatementScreen> createState() => _PartyStatementScreenState();
}

class _PartyStatementScreenState extends State<PartyStatementScreen> {
  bool _loading = true;
  List<String> _names = const [];
  List<Entry> _purchases = const [];
  List<Entry> _sales = const [];
  List<MoneyEntry> _money = const [];
  String? _selected;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Repos.instance.parties.list(),
      Repos.instance.purchases.list(),
      Repos.instance.sales.list(),
      Repos.instance.money.list(),
    ]);
    final parties = results[0] as List<Party>;
    final purchases = results[1] as List<Entry>;
    final sales = results[2] as List<Entry>;
    final money = results[3] as List<MoneyEntry>;
    if (!mounted) return;
    setState(() {
      _purchases = purchases;
      _sales = sales;
      _money = money;
      // Saved parties, plus any name that only appears on an entry.
      _names = partyNames(
        saved: parties,
        purchases: purchases,
        sales: sales,
        money: money,
      );
      _loading = false;
    });
  }

  String get _periodLabel {
    if (_from == null && _to == null) return 'All dates';
    final from = _from == null ? 'start' : formatDateIso(_from!);
    final to = _to == null ? 'today' : formatDateIso(_to!);
    return '$from to $to';
  }

  Future<Uint8List> _buildPdf(String name, PartyStatement statement) async {
    final user = await Repos.instance.users.getUser();
    return buildPartyStatementPdf(
      partyName: name,
      businessName: user?.businessName,
      statement: statement,
      filters: _periodLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final statement = selected == null
        ? null
        : buildPartyStatement(
            partyName: selected,
            purchases: _purchases,
            sales: _sales,
            money: _money,
            range: DateRange(from: _from, to: _to),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Statement'),
        actions: [
          if (selected != null && statement != null)
            ReportActions(
              enabled: !statement.isEmpty,
              filename: pdfFileName('party_statement_$selected'),
              buildPdf: () => _buildPdf(selected, statement),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _names.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              message:
                  'No parties yet.\nAdd one from the Parties screen first.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'SELECT PARTY',
                    ),
                    items: [
                      for (final n in _names)
                        DropdownMenuItem(
                          value: n,
                          child: Text(n, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (n) => setState(() => _selected = n),
                  ),
                ),
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: DateRangeBar(
                      from: _from,
                      to: _to,
                      onChanged: (v) => setState(() {
                        _from = v.$1;
                        _to = v.$2;
                      }),
                    ),
                  ),
                if (selected != null && statement != null)
                  Expanded(
                    child: _StatementList(name: selected, statement: statement),
                  ),
              ],
            ),
    );
  }
}

class _StatementList extends StatelessWidget {
  const _StatementList({required this.name, required this.statement});

  final String name;
  final PartyStatement statement;

  @override
  Widget build(BuildContext context) {
    if (statement.isEmpty) {
      final carried = statement.showsOpening && statement.opening.round() != 0
          ? '\nBefore this range: ${formatBalanceWith(name, statement.opening)}.'
          : '';
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'No entries for this party in this range.$carried',
      );
    }
    // The card, the balance brought forward (if the range starts part-way
    // through), then every line — built lazily so a long history stays smooth.
    final head = statement.showsOpening ? 2 : 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: head + statement.lines.length,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BalanceCard(name: name, statement: statement),
          );
        }
        if (statement.showsOpening && i == 1) {
          return BalanceForwardTile(balance: statement.opening);
        }
        return StatementTile(line: statement.lines[i - head]);
      },
    );
  }
}
