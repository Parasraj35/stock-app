import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/calc.dart';
import '../../core/models.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/settings_row.dart';
import 'merged_report_screen.dart';
import 'monthly_report_screen.dart';
import 'party_statement_screen.dart';

/// Hub for PDF reports — Purchase/Sale (with monthly breakdown), Party
/// Statement, and Stock, reachable from Settings.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _exportingStock = false;

  Future<void> _exportStockReport() async {
    setState(() => _exportingStock = true);
    try {
      final results = await Future.wait([
        Repos.instance.brands.list(),
        Repos.instance.purchases.list(),
        Repos.instance.sales.list(),
        Repos.instance.users.getUser(),
      ]);
      final brands = results[0] as List<Brand>;
      final purchases = results[1] as List<Entry>;
      final sales = results[2] as List<Entry>;
      final user = results[3] as AppUser?;

      final rows = [
        for (final b in brands)
          StockReportRow(
            brandName: b.name,
            purchaseRate: b.purchaseRate,
            saleRate: b.saleRate,
            stockCft: calcStock(
              purchases
                  .where((e) => e.brandId == b.id)
                  .fold<double>(0, (sum, e) => sum + e.totalCFT),
              sales
                  .where((e) => e.brandId == b.id)
                  .fold<double>(0, (sum, e) => sum + e.totalCFT),
            ),
          ),
      ];
      final bytes = await buildStockReportPdf(
        businessName: user?.businessName,
        rows: rows,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'stock_report.pdf',
      );
    } finally {
      if (mounted) setState(() => _exportingStock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SettingsRow(
            icon: Icons.south_west,
            label: 'Purchase Report',
            subtitle: 'Monthly breakdown and full history',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MonthlyReportScreen(isPurchase: true),
              ),
            ),
          ),
          SettingsRow(
            icon: Icons.north_east,
            label: 'Sale Report',
            subtitle: 'Monthly breakdown and full history',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MonthlyReportScreen(isPurchase: false),
              ),
            ),
          ),
          SettingsRow(
            icon: Icons.swap_vert,
            label: 'Purchase & Sale Report',
            subtitle: 'Combined monthly report with net profit',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MergedReportScreen()),
            ),
          ),
          SettingsRow(
            icon: Icons.receipt_long_outlined,
            label: 'Party Statement',
            subtitle: 'Full purchase + sale history for one party',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PartyStatementScreen()),
            ),
          ),
          SettingsRow(
            icon: Icons.inventory_2_outlined,
            label: 'Stock Report',
            subtitle: 'Current stock on hand per brand',
            onTap: _exportingStock ? () {} : _exportStockReport,
            trailing: _exportingStock
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.ios_share, color: AppColors.inactiveIcon),
          ),
        ],
      ),
    );
  }
}
