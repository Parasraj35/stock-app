import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/data_bus.dart';
import '../../data/pdf_export.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/brand_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_actions.dart';

class _BrandStock {
  final Brand brand;
  final double stock;
  const _BrandStock(this.brand, this.stock);
}

/// Stock on hand per brand — purchased CFT minus sold CFT, derived live from
/// the purchases/sales stores (nothing stored redundantly). Reached from the
/// Dashboard's Stock card.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  Future<List<_BrandStock>> _load() async {
    final results = await Future.wait([
      Repos.instance.brands.list(),
      Repos.instance.purchases.list(),
      Repos.instance.sales.list(),
    ]);
    final brands = results[0] as List<Brand>;
    final purchases = results[1] as List<Entry>;
    final sales = results[2] as List<Entry>;

    return [
      for (final b in brands)
        _BrandStock(
          b,
          calcStock(
            purchases
                .where((e) => e.brandId == b.id)
                .fold<double>(0, (sum, e) => sum + e.totalCFT),
            sales
                .where((e) => e.brandId == b.id)
                .fold<double>(0, (sum, e) => sum + e.totalCFT),
          ),
        ),
    ];
  }

  Future<Uint8List> _buildPdf() async {
    final rows = await _load();
    final user = await Repos.instance.users.getUser();
    return buildStockReportPdf(
      businessName: user?.businessName,
      rows: [
        for (final r in rows)
          StockReportRow(
            brandName: r.brand.name,
            purchaseRate: r.brand.purchaseRate,
            saleRate: r.brand.saleRate,
            stockCft: r.stock,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          ReportActions(
            filename: pdfFileName('stock_report'),
            buildPdf: _buildPdf,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: DataBus.instance,
        builder: (context, _) {
          return FutureBuilder<List<_BrandStock>>(
            future: _load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: 'No brands yet.',
                );
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (context, i) =>
                    const Divider(indent: 16, endIndent: 16),
                itemBuilder: (context, i) {
                  final row = rows[i];
                  final negative = row.stock < 0;
                  final color = negative
                      ? AppColors.negative
                      : AppColors.textPrimary;
                  return ListTile(
                    leading: BrandIcon(name: row.brand.name, size: 40),
                    title: Text(row.brand.name),
                    subtitle: Text(
                      'Buy ${formatPkrCurrency(row.brand.purchaseRate)} · Sell ${formatPkrCurrency(row.brand.saleRate)}',
                    ),
                    trailing: Text(
                      '${formatGroupedNumber(row.stock)} cft',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
