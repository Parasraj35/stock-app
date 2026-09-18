import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/date_range_bar.dart';
import '../widgets/empty_state.dart';

/// Pick a party, see their full purchase+sale history and running totals
/// (optionally filtered to a From/To date range), export as a PDF statement.
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
  bool _exporting = false;
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

  Future<void> _export() async {
    final party = _selected;
    if (party == null || _purchases == null || _sales == null) return;
    setState(() => _exporting = true);
    try {
      final range = DateRange(from: _from, to: _to);
      final user = await Repos.instance.users.getUser();
      final bytes = await buildPartyStatementPdf(
        partyName: party.name,
        businessName: user?.businessName,
        purchases: filterByDateRange(_purchases!, range),
        sales: filterByDateRange(_sales!, range),
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'party_statement_${party.name}.pdf',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Statement'),
        actions: [
          if (_selected != null)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.ios_share),
              onPressed: _exporting ? null : _export,
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
                if (_selected != null)
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
                if (_purchases != null && _sales != null)
                  Expanded(
                    child: _HistoryList(
                      history: partyHistory(
                        _selected!.name,
                        filterByDateRange(
                          _purchases!,
                          DateRange(from: _from, to: _to),
                        ),
                        filterByDateRange(
                          _sales!,
                          DateRange(from: _from, to: _to),
                        ),
                      ),
                      totalPurchase:
                          filterByDateRange(
                                _purchases!,
                                DateRange(from: _from, to: _to),
                              )
                              .where((e) => e.party == _selected!.name)
                              .fold<double>(0, (sum, e) => sum + e.amount),
                      totalSale:
                          filterByDateRange(
                                _sales!,
                                DateRange(from: _from, to: _to),
                              )
                              .where((e) => e.party == _selected!.name)
                              .fold<double>(0, (sum, e) => sum + e.amount),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.history,
    required this.totalPurchase,
    required this.totalSale,
  });
  final List<PartyLedgerEntry> history;
  final double totalPurchase;
  final double totalSale;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'No entries for this party in this range.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
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
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1.5,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            child: ListTile(
              leading: Icon(
                line.isPurchase ? Icons.south_west : Icons.north_east,
                color: line.isPurchase
                    ? AppColors.purchaseColor
                    : AppColors.saleColor,
              ),
              title: Text(
                line.entry.brandName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(line.entry.date),
              trailing: Text(
                formatPkrCurrency(line.entry.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
