import 'package:flutter/material.dart';

import '../widgets/settings_row.dart';
import 'merged_report_screen.dart';
import 'monthly_report_screen.dart';
import 'party_statement_screen.dart';
import 'stock_screen.dart';
import 'vehicle_report_screen.dart';

/// Hub for reports — Purchase, Sale, combined, Party Statement, Vehicle and Stock.
/// Each opens an in-app view of every entry with Share and Print in the top
/// bar, reachable from Settings.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
            subtitle: 'Every purchase, month by month',
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
            subtitle: 'Every sale, month by month',
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
            subtitle: 'Every purchase and sale together, with net',
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
            icon: Icons.local_shipping_outlined,
            label: 'Vehicle Report',
            subtitle: 'Every trip by vehicle, with totals',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => VehicleReportScreen()),
            ),
          ),
          SettingsRow(
            icon: Icons.inventory_2_outlined,
            label: 'Stock Report',
            subtitle: 'Current stock on hand per brand',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StockScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
