import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/vehicles.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_dialog.dart';

/// Add/edit a vehicle and how much CFT it carries per trip, on a full
/// screen like the other forms. Vehicle numbers and CFT values must each be
/// unique — the CFT is what picks the vehicle on Purchase/Sale.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.existing, required this.vehicles});
  final Vehicle? existing;

  /// Every saved vehicle, used to keep numbers and CFT values unique.
  final List<Vehicle> vehicles;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _vehicleNo = TextEditingController(
    text: widget.existing?.vehicleNo ?? '',
  );
  late final _cft = TextEditingController(
    text: widget.existing != null ? formatDecimal(widget.existing!.cft) : '',
  );
  bool _submitting = false;

  /// The other vehicles — everything except the one being edited.
  List<Vehicle> get _others => [
    for (final v in widget.vehicles)
      if (v.id == null || v.id != widget.existing?.id) v,
  ];

  @override
  void dispose() {
    _vehicleNo.dispose();
    _cft.dispose();
    super.dispose();
  }

  String? _validateVehicleNo(String? v) {
    final number = normalizeVehicleNo(v);
    if (number == null) return 'Required';
    final taken = _others.any((o) => normalizeVehicleNo(o.vehicleNo) == number);
    return taken ? 'This vehicle is already added' : null;
  }

  String? _validateCft(String? v) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null || n <= 0) return 'Enter a valid CFT';
    final clash = vehicleForCft(_others, n);
    if (clash != null) {
      return '${clash.vehicleNo} already carries ${formatDecimal(n)} cft';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final vehicle = Vehicle(
      vehicleNo: normalizeVehicleNo(_vehicleNo.text)!,
      cft: double.parse(_cft.text.trim()),
    );
    if (widget.existing == null) {
      await Repos.instance.vehicles.add(vehicle);
    } else {
      await Repos.instance.vehicles.update(
        vehicle.copyWith(id: widget.existing!.id),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete vehicle?',
      message:
          'Delete "${widget.existing!.vehicleNo}"? Past entries keep their '
          'vehicle number.',
      confirmLabel: 'DELETE',
    );
    if (!confirmed) return;
    await Repos.instance.vehicles.delete(widget.existing!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit vehicle' : 'New vehicle'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete vehicle',
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
                controller: _vehicleNo,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'VEHICLE NO.'),
                validator: _validateVehicleNo,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cft,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'CFT CARRIED PER TRIP',
                  helperText:
                      'Typing this CFT on a purchase or sale fills in this vehicle',
                  helperMaxLines: 2,
                ),
                validator: _validateCft,
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'SAVING...' : 'SAVE VEHICLE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
