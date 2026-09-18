import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/brand_icon.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_summary.dart';
import '../widgets/profile_header_button.dart';
import 'brand_form_screen.dart';

class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brands'),
        actions: const [ProfileHeaderButton(), SizedBox(width: 8)],
      ),
      // No hero tag: this screen exists both as a tab and when pushed from
      // the Dashboard, so a shared tag would make the two FABs collide.
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _openBrandForm(context),
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: DataBus.instance,
        builder: (context, _) {
          return FutureBuilder<List<Brand>>(
            future: Repos.instance.brands.list(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final brands = snapshot.data!;
              if (brands.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_offer_outlined,
                  message: 'No brands yet.\nTap + to add one.',
                );
              }
              final avgMargin =
                  brands
                      .map((b) => b.saleRate - b.purchaseRate)
                      .fold<double>(0, (sum, m) => sum + m) /
                  brands.length;
              return Column(
                children: [
                  SummaryBanner(
                    icon: Icons.local_offer_outlined,
                    label:
                        '${brands.length} BRAND${brands.length == 1 ? '' : 'S'} LISTED',
                    trailing: 'Avg margin ${formatPkrCurrency(avgMargin)}/cft',
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                      itemCount: brands.length,
                      itemBuilder: (context, i) => _BrandCard(
                        brand: brands[i],
                        onTap: () =>
                            _openBrandForm(context, existing: brands[i]),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openBrandForm(BuildContext context, {Brand? existing}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandFormScreen(existing: existing),
      ),
    );
  }
}

/// A single brand row — real material photo, name, buy/sell rates, and the
/// per-cft margin between them.
class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.brand, required this.onTap});
  final Brand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final margin = brand.saleRate - brand.purchaseRate;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BrandIcon(name: brand.name, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      brand.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Buy ${formatPkrCurrency(brand.purchaseRate)}',
                        style: TextStyle(
                          color: AppColors.purchaseColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Sell ${formatPkrCurrency(brand.saleRate)}',
                        style: TextStyle(
                          color: AppColors.saleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.trending_up,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Margin ${formatPkrCurrency(margin)}/cft',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
