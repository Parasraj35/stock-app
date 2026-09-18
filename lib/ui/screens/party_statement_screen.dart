import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/date_range_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_widgets.dart';

/// Pick a party, see every purchase and sale with them (optionally filtered
/// to a From/To date range), and share or print it as a PDF statement.
class PartyStatementScreen extends StatefulWidget {
  const PartyStatementScreen({super.key});

  @override
  State<PartyStatementScreen> createState() => _PartyStatementScreenState();
}

class _PartyStatementScreenState extends State<PartyStatementScreen> {
  List<Party> _parties = [];
  bool _loadingParties = true;
  Party? _selected;
  bool _loadingHistory = false;
  List<Entry>? _purchases;
  List<Entry>? _sales;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    final parties = await Repos.instance.parties.list();
    if (!mounted) return;
    setState(() {
      _parties = parties;
      _loadingParties = false;
    });
  }

  Future<void> _selectParty(Party party) async {
    setState(() {
      _selected = party;
      _loadingHistory = true;
      _purchases = null;
      _sales = null;
    });
    final results = await Future.wait([
      Repos.instance.purchases.list(),
      Repos.instance.sales.list(),
    ]);
    if (!mounted) return;
    setState(() {
      _purchases = results[0];
      _sales = results[1];
      _loadingHistory = false;
    });
  }

  Future<Uint8List> _buildPdf(
    Party party,
    List<Entry> purchases,
    List<Entry> sales,
  ) async {
    final user = await Repos.instance.users.getUser();
    return buildPartyStatementPdf(
      partyName: party.name,
      businessName: user?.businessName,
      purchases: purchases,
      sales: sales,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final allPurchases = _purchases;
    final allSales = _sales;
    List<Entry>? purchases;
    List<Entry>? sales;
    List<PartyLedgerEntry>? history;
    if (selected != null && allPurchases != null && allSales != null) {
      final range = DateRange(from: _from, to: _to);
      purchases = filterByDateRange(allPurchases, range);
      sales = filterByDateRange(allSales, range);
      history = partyHistory(selected.name, purchases, sales);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Statement'),
        actions: [
          if (selected != null)
            ReportActions(
              enabled: history != null && history.isNotEmpty,
              filename: pdfFileName('party_statement_${selected.name}'),
              buildPdf: () =>
                  _buildPdf(selected, purchases ?? const [], sales ?? const []),
            ),
        ],
      ),
      body: _loadingParties
          ? const Center(child: CircularProgressIndicator())
          : _parties.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              message:
                  'No parties yet.\nAdd one from the Parties screen first.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: DropdownButtonFormField<Party>(
                    initialValue: _selected,
                    decoration: const InputDecoration(
                      labelText: 'SELECT PARTY',
                    ),
                    items: [
                      for (final p in _parties)
                        DropdownMenuItem(value: p, child: Text(p.name)),
                    ],
                    onChanged: (p) {
                      if (p != null) _selectParty(p);
                    },
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
                if (_loadingHistory)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (history != null)
                  Expanded(child: _HistoryList(history: history)),
              ],
            ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history});
  final List<PartyLedgerEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'No entries for this party in this range.',
      );
    }
    final totalPurchase = history
        .where((l) => l.isPurchase)
        .fold<double>(0, (sum, l) => sum + l.entry.amount);
    final totalSale = history
        .where((l) => !l.isPurchase)
        .fold<double>(0, (sum, l) => sum + l.entry.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchased',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      formatPkrCurrency(totalPurchase),
                      style: TextStyle(
                        color: AppColors.purchaseColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sold',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      formatPkrCurrency(totalSale),
                      style: TextStyle(
                        color: AppColors.saleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final line in history)
          VoucherTile(
            entry: line.entry,
            isPurchase: line.isPurchase,
            showType: true,
            showParty: false,
          ),
      ],
    );
  }
}
