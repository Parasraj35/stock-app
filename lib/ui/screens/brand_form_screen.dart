import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_dialog.dart';

/// Add/edit a brand on a full screen — same layout as the Purchase and Sale
/// forms. Editing also offers Delete in the top bar.
class BrandFormScreen extends StatefulWidget {
  const BrandFormScreen({super.key, this.existing});
  final Brand? existing;

  @override
  State<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends State<BrandFormScreen> {
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
  void initState() {
    super.initState();
    for (final c in [_purchaseRate, _saleRate]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _purchaseRate.dispose();
    _saleRate.dispose();
    super.dispose();
  }

  double? get _margin {
    final purchase = double.tryParse(_purchaseRate.text.trim());
    final sale = double.tryParse(_saleRate.text.trim());
    if (purchase == null || sale == null) return null;
    return sale - purchase;
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
    final confirmed = await confirmDialog(
      context,
      title: 'Delete brand?',
      message: 'Delete "${widget.existing!.name}"? This cannot be undone.',
      confirmLabel: 'DELETE',
    );
    if (!confirmed) return;
    await Repos.instance.brands.delete(widget.existing!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final margin = _margin;
    final palette = (margin ?? 0) >= 0
        ? MetricPalette.profit
        : MetricPalette.profitNegative;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit brand' : 'New brand'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete brand',
              icon: const Icon(Icons.delete_outline),
              onPressed: _submitting ? null : _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'NAME'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
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
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.highlightBg,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Margin per cft',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.highlightText.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      margin == null ? '-' : 'Rs ${formatDecimal(margin)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: palette.highlightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sale rate − purchase rate',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.highlightText.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'SAVING...' : 'SAVE BRAND'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
