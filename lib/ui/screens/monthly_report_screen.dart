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

/// In-app monthly breakdown for Purchase or Sale, with a From/To date
/// filter and a PDF export action in the app bar.
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key, required this.isPurchase});
  final bool isPurchase;

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  bool _exporting = false;
  DateTime? _from;
  DateTime? _to;

  String get _title => widget.isPurchase ? 'Purchase' : 'Sale';
  Color get _accentColor =>
      widget.isPurchase ? AppColors.purchaseColor : AppColors.saleColor;

  Future<void> _export(List<Entry> entries) async {
    setState(() => _exporting = true);
    try {
      final user = await Repos.instance.users.getUser();
      final bytes = await buildEntryReportPdf(
        title: '$_title Report',
        businessName: user?.businessName,
        entries: entries,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '${_title.toLowerCase()}_report.pdf',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.isPurchase
        ? Repos.instance.purchases
        : Repos.instance.sales;
    final range = DateRange(from: _from, to: _to);
    return Scaffold(
      appBar: AppBar(
        title: Text('$_title Report'),
        actions: [
          FutureBuilder<List<Entry>>(
            future: repository.list(),
            builder: (context, snapshot) {
              final entries = snapshot.data == null
                  ? null
                  : filterByDateRange(snapshot.data!, range);
              return IconButton(
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
                onPressed: (entries == null || entries.isEmpty || _exporting)
                    ? null
                    : () => _export(entries),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Entry>>(
        future: repository.list(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = filterByDateRange(snapshot.data!, range);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DateRangeBar(
                from: _from,
                to: _to,
                onChanged: (v) => setState(() {
                  _from = v.$1;
                  _to = v.$2;
                }),
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                EmptyState(
                  icon: widget.isPurchase ? Icons.south_west : Icons.north_east,
                  message: 'No $_title entries in this range.',
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entries.length} ${_title.toUpperCase()}${entries.length == 1 ? '' : 'S'} • ${formatGroupedNumber(entries.fold<double>(0, (sum, e) => sum + e.totalCFT))} cft',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _accentColor,
                          ),
                        ),
                      ),
                      Text(
                        formatPkrCurrency(
                          entries.fold<double>(0, (sum, e) => sum + e.amount),
                        ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'MONTHLY BREAKDOWN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                for (final m in monthlyTotals(entries))
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1.5,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    child: ListTile(
                      title: Text(
                        formatMonthLabel(m.monthKey),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${m.count} entries • ${formatGroupedNumber(m.totalCft)} cft',
                      ),
                      trailing: Text(
                        formatPkrCurrency(m.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
