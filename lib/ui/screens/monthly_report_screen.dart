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

/// In-app Purchase or Sale report: every entry, month by month, with a
/// From/To date filter. Share/Print in the app bar produce the same list as
/// a PDF.
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key, required this.isPurchase});
  final bool isPurchase;

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  List<Entry>? _all;
  DateTime? _from;
  DateTime? _to;

  String get _title => widget.isPurchase ? 'Purchase' : 'Sale';
  Color get _accentColor =>
      widget.isPurchase ? AppColors.purchaseColor : AppColors.saleColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = widget.isPurchase
        ? Repos.instance.purchases
        : Repos.instance.sales;
    final entries = await repository.list();
    if (!mounted) return;
    setState(() => _all = entries);
  }

  Future<Uint8List> _buildPdf(List<Entry> entries) async {
    final user = await Repos.instance.users.getUser();
    return buildEntryReportPdf(
      title: '$_title Report',
      businessName: user?.businessName,
      entries: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final entries = all == null
        ? null
        : filterByDateRange(all, DateRange(from: _from, to: _to));
    return Scaffold(
      appBar: AppBar(
        title: Text('$_title Report'),
        actions: [
          ReportActions(
            enabled: entries != null && entries.isNotEmpty,
            filename: pdfFileName('${_title.toLowerCase()}_report'),
            buildPdf: () => _buildPdf(entries ?? const []),
          ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                if (entries.isEmpty)
                  Expanded(
                    child: EmptyState(
                      icon: widget.isPurchase
                          ? Icons.south_west
                          : Icons.north_east,
                      message: 'No $_title entries in this range.',
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _SummaryCard(
                      title: _title,
                      entries: entries,
                      color: _accentColor,
                    ),
                  ),
                  Expanded(
                    child: _EntryList(
                      entries: entries,
                      isPurchase: widget.isPurchase,
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
    required this.title,
    required this.entries,
    required this.color,
  });
  final String title;
  final List<Entry> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final totalCft = entries.fold<double>(0, (sum, e) => sum + e.totalCFT);
    final totalAmount = entries.fold<double>(0, (sum, e) => sum + e.amount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${entries.length} ${title.toUpperCase()}${entries.length == 1 ? '' : 'S'} • ${formatGroupedNumber(totalCft)} cft',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            formatPkrCurrency(totalAmount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every entry, with a header above each month. Flattened into one lazily
/// built list so hundreds of entries stay smooth.
class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries, required this.isPurchase});
  final List<Entry> entries;
  final bool isPurchase;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[
      for (final g in groupEntriesByMonth(entries)) ...[g, ...g.entries],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is MonthGroup) {
          return MonthHeader(
            title: formatMonthLabel(row.total.monthKey),
            detail:
                '${row.total.count} ${row.total.count == 1 ? 'entry' : 'entries'} • ${formatGroupedNumber(row.total.totalCft)} cft',
            trailing: formatPkrCurrency(row.total.totalAmount),
          );
        }
        return VoucherTile(entry: row as Entry, isPurchase: isPurchase);
      },
    );
  }
}
