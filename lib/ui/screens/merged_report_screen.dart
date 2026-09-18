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

/// Purchases and sales together, month by month — every entry listed, each
/// marked Purchase or Sale, with the net for the month. Share/Print in the
/// app bar produce the same list as a PDF.
class MergedReportScreen extends StatefulWidget {
  const MergedReportScreen({super.key});

  @override
  State<MergedReportScreen> createState() => _MergedReportScreenState();
}

class _MergedReportScreenState extends State<MergedReportScreen> {
  List<Entry>? _purchases;
  List<Entry>? _sales;
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
    });
  }

  Future<Uint8List> _buildPdf(List<Entry> purchases, List<Entry> sales) async {
    final user = await Repos.instance.users.getUser();
    return buildMergedReportPdf(
      businessName: user?.businessName,
      purchases: purchases,
      sales: sales,
    );
  }

  @override
  Widget build(BuildContext context) {
    const title = Text('Purchase & Sale Report');
    final allPurchases = _purchases;
    final allSales = _sales;
    if (allPurchases == null || allSales == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final range = DateRange(from: _from, to: _to);
    final purchases = filterByDateRange(allPurchases, range);
    final sales = filterByDateRange(allSales, range);
    final isEmpty = purchases.isEmpty && sales.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: [
          ReportActions(
            enabled: !isEmpty,
            filename: pdfFileName('purchase_sale_report'),
            buildPdf: () => _buildPdf(purchases, sales),
          ),
        ],
      ),
      body: Column(
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
          if (isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.swap_vert,
                message: 'No purchase or sale entries in this range.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _TotalsCard(purchases: purchases, sales: sales),
            ),
            Expanded(
              child: _LedgerList(groups: groupLedgerByMonth(purchases, sales)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.purchases, required this.sales});
  final List<Entry> purchases;
  final List<Entry> sales;

  @override
  Widget build(BuildContext context) {
    final totalPurchase = purchases.fold<double>(0, (sum, e) => sum + e.amount);
    final totalSale = sales.fold<double>(0, (sum, e) => sum + e.amount);
    final profit = totalSale - totalPurchase;
    final palette = profit >= 0
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PURCHASE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.highlightText.withValues(alpha: 0.75),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.highlightText.withValues(alpha: 0.75),
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
  }
}

/// Every purchase and sale, with a header above each month. Flattened into
/// one lazily built list so hundreds of entries stay smooth.
class _LedgerList extends StatelessWidget {
  const _LedgerList({required this.groups});
  final List<LedgerMonthGroup> groups;

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
        if (row is LedgerMonthGroup) {
          return MonthHeader(
            title: formatMonthLabel(row.monthKey),
            detail:
                'Buy ${formatPkrCurrency(row.purchaseAmount)}  •  Sell ${formatPkrCurrency(row.saleAmount)}',
            trailing: formatPkrCurrency(row.profit),
            trailingColor: row.profit >= 0
                ? AppColors.accent
                : AppColors.negative,
          );
        }
        final line = row as PartyLedgerEntry;
        return VoucherTile(
          entry: line.entry,
          isPurchase: line.isPurchase,
          showType: true,
        );
      },
    );
  }
}
