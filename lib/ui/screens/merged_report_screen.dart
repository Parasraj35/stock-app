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

/// Purchase and Sale side by side, month by month, with net profit —
/// answers "one report with both" instead of two separate ones.
class MergedReportScreen extends StatefulWidget {
  const MergedReportScreen({super.key});

  @override
  State<MergedReportScreen> createState() => _MergedReportScreenState();
}

class _MergedReportScreenState extends State<MergedReportScreen> {
  List<Entry>? _purchases;
  List<Entry>? _sales;
  bool _loading = true;
  bool _exporting = false;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Repos.instance.purchases.list(),
      Repos.instance.sales.list(),
    ]);
    if (!mounted) return;
    setState(() {
      _purchases = results[0];
      _sales = results[1];
      _loading = false;
    });
  }

  Future<void> _export(List<Entry> purchases, List<Entry> sales) async {
    setState(() => _exporting = true);
    try {
      final user = await Repos.instance.users.getUser();
      final bytes = await buildMergedReportPdf(
        businessName: user?.businessName,
        purchases: purchases,
        sales: sales,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'purchase_sale_report.pdf',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = DateRange(from: _from, to: _to);
    final purchases = _purchases == null
        ? null
        : filterByDateRange(_purchases!, range);
    final sales = _sales == null ? null : filterByDateRange(_sales!, range);
    final merged = (purchases == null || sales == null)
        ? null
        : mergedMonthlyTotals(purchases, sales);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase & Sale Report'),
        actions: [
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
            onPressed:
                (purchases == null ||
                    sales == null ||
                    _exporting ||
                    (purchases.isEmpty && sales.isEmpty))
                ? null
                : () => _export(purchases, sales),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                if (merged!.isEmpty)
                  const EmptyState(
                    icon: Icons.swap_vert,
                    message: 'No purchase or sale entries in this range.',
                  )
                else ...[
                  Builder(
                    builder: (context) {
                      final totalPurchase = purchases!.fold<double>(
                        0,
                        (sum, e) => sum + e.amount,
                      );
                      final totalSale = sales!.fold<double>(
                        0,
                        (sum, e) => sum + e.amount,
                      );
                      final profit = totalSale - totalPurchase;
                      final positive = profit >= 0;
                      final palette = positive
                          ? MetricPalette.profit
                          : MetricPalette.profitNegative;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.highlightBg,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PURCHASE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        formatPkrCurrency(totalPurchase),
                                        style: TextStyle(
                                          color: AppColors.purchaseColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'SALE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        formatPkrCurrency(totalSale),
                                        style: TextStyle(
                                          color: AppColors.saleColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Net profit: ${formatPkrCurrency(profit)}',
                              style: TextStyle(
                                color: palette.highlightText,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                  for (final m in merged)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1.5,
                      shadowColor: Colors.black.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatMonthLabel(m.monthKey),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Buy ${formatPkrCurrency(m.purchaseAmount)}',
                                    style: TextStyle(
                                      color: AppColors.purchaseColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Sell ${formatPkrCurrency(m.saleAmount)}',
                                    style: TextStyle(
                                      color: AppColors.saleColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatPkrCurrency(m.profit),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: m.profit >= 0
                                        ? AppColors.accent
                                        : AppColors.negative,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
