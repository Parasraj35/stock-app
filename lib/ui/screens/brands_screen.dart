import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/brand_icon.dart';
import '../widgets/empty_state.dart';

class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brands'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _openBrandForm(context),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'add', child: Text('ADD BRAND')),
            ],
          ),
        ],
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
                  message: 'No brands yet.\nUse the menu to add one.',
                );
              }
              final avgMargin =
                  brands
                      .map((b) => b.saleRate - b.purchaseRate)
                      .fold<double>(0, (sum, m) => sum + m) /
                  brands.length;
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: MetricPalette.profit.highlightBg,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: MetricPalette.profit.highlightText
                                .withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.local_offer_outlined,
                            color: MetricPalette.profit.highlightText,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${brands.length} BRAND${brands.length == 1 ? '' : 'S'} LISTED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: MetricPalette.profit.highlightText
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: MetricPalette.profit.highlightText.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        Text(
                          'Avg margin ${formatPkrCurrency(avgMargin)}/cft',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: MetricPalette.profit.highlightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
    return showDialog(
      context: context,
      builder: (context) => _BrandFormDialog(existing: existing),
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

class _BrandFormDialog extends StatefulWidget {
  const _BrandFormDialog({this.existing});
  final Brand? existing;

  @override
  State<_BrandFormDialog> createState() => _BrandFormDialogState();
}

class _BrandFormDialogState extends State<_BrandFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _purchaseRate = TextEditingController(
    text: widget.existing != null
        ? _trimZeros(widget.existing!.purchaseRate)
        : '',
  );
  late final _saleRate = TextEditingController(
    text: widget.existing != null ? _trimZeros(widget.existing!.saleRate) : '',
  );
  bool _submitting = false;

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _purchaseRate.dispose();
    _saleRate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final name = _name.text.trim();
    final purchaseRate = double.parse(_purchaseRate.text.trim());
    final saleRate = double.parse(_saleRate.text.trim());
    if (widget.existing == null) {
      await Repos.instance.brands.add(
        Brand(name: name, purchaseRate: purchaseRate, saleRate: saleRate),
      );
    } else {
      await Repos.instance.brands.update(
        widget.existing!.copyWith(
          name: name,
          purchaseRate: purchaseRate,
          saleRate: saleRate,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete brand?'),
        content: Text(
          'Delete "${widget.existing!.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Repos.instance.brands.delete(widget.existing!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit brand' : 'Add brand'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'NAME'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchaseRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'PURCHASE RATE PER CFT (RS)',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Enter a valid rate';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _saleRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'SALE RATE PER CFT (RS)',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Enter a valid rate';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            onPressed: _submitting ? null : _delete,
            child: Text('DELETE', style: TextStyle(color: AppColors.negative)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
