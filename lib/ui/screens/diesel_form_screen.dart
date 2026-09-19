import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/vehicles.dart';
import '../../data/repos.dart';
import '../../data/repositories.dart';
import '../theme/tokens.dart';
import '../widgets/date_field.dart';
import '../widgets/vehicle_field.dart';

/// Digits with at most one dot and two decimals. A keystroke that would break
/// that is ignored (rather than wiping what was typed).
final _decimalInput = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text) ? newValue : oldValue,
);

/// Add/edit a diesel entry: date, vehicle, litres and price per litre. The
/// total (litres × price) updates as the numbers are typed.
class DieselFormScreen extends StatefulWidget {
  const DieselFormScreen({
    super.key,
    required this.repository,
    required this.vehicles,
    this.existing,
  });

  final DieselRepository repository;
  final List<Vehicle> vehicles;
  final DieselEntry? existing;

  @override
  State<DieselFormScreen> createState() => _DieselFormScreenState();
}

class _DieselFormScreenState extends State<DieselFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date = widget.existing != null
      ? DateTime.parse(widget.existing!.date)
      : DateTime.now();
  late final _vehicle = TextEditingController(
    text: widget.existing?.vehicleNo ?? '',
  );
  final _vehicleFocusNode = FocusNode();
  late final _litres = TextEditingController(
    text: widget.existing == null ? '' : formatDecimal(widget.existing!.litres),
  );
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : formatDecimal(widget.existing!.price),
  );
  bool _submitting = false;

  double get _litresValue => double.tryParse(_litres.text.trim()) ?? 0;
  double get _priceValue => double.tryParse(_price.text.trim()) ?? 0;

  @override
  void dispose() {
    _vehicle.dispose();
    _vehicleFocusNode.dispose();
    _litres.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final entry = DieselEntry(
      id: widget.existing?.id,
      date: formatDateIso(_date),
      vehicleNo: normalizeVehicleNo(_vehicle.text)!,
      litres: double.parse(_litres.text.trim()),
      price: double.parse(_price.text.trim()),
    );
    if (widget.existing == null) {
      await widget.repository.add(entry);
    } else {
      await widget.repository.update(entry);
    }
    if (mounted) Navigator.pop(context);
  }

  String? _positive(String? v, String message) {
    final n = double.tryParse(v?.trim() ?? '');
    return (n == null || n <= 0) ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetricPalette.profit;
    final total = DieselEntry.totalFor(_litresValue, _priceValue);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit diesel' : 'New diesel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateField(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 14),
              VehicleField(
                controller: _vehicle,
                focusNode: _vehicleFocusNode,
                vehicles: widget.vehicles,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _litres,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalInput],
                      decoration: const InputDecoration(labelText: 'LITRES'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => _positive(v, 'Enter the litres'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalInput],
                      decoration: const InputDecoration(
                        labelText: 'PRICE (RS/LITRE)',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => _positive(v, 'Enter the price'),
                    ),
                  ),
                ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.highlightText.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                        Text(
                          formatPkrCurrency(total),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: palette.highlightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDecimal(_litresValue)} L × '
                      'Rs ${formatDecimal(_priceValue)}',
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.dieselColor,
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'SAVING...' : 'SAVE DIESEL'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the diesel form with the saved vehicles to pick from.
Future<void> openDieselForm(
  BuildContext context, {
  DieselEntry? existing,
}) async {
  final vehicles = await Repos.instance.vehicles.list();
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DieselFormScreen(
        repository: Repos.instance.diesel,
        vehicles: vehicles,
        existing: existing,
      ),
    ),
  );
}
