import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/vehicles.dart';
import '../../data/repos.dart';
import '../../data/repositories.dart';
import '../theme/tokens.dart';
import '../widgets/date_field.dart';
import '../widgets/party_field.dart';
import '../widgets/report_widgets.dart' show moneyTypeColor;
import '../widgets/vehicle_field.dart';

/// Add/edit a Debit or Credit entry. Both types share the same fields — date,
/// who it is for, rupees — so one form serves both, with a Debit/Credit switch
/// on top. "Who" is a Party / Vehicle switch: the user picks which one this
/// entry is for and fills in only that field.
class MoneyFormScreen extends StatefulWidget {
  const MoneyFormScreen({
    super.key,
    required this.repository,
    required this.parties,
    required this.vehicles,
    this.existing,
    this.initialType = MoneyType.debit,
  });

  final MoneyRepository repository;
  final List<Party> parties;
  final List<Vehicle> vehicles;
  final MoneyEntry? existing;

  /// Which side is selected when adding (an existing entry keeps its own).
  final MoneyType initialType;

  @override
  State<MoneyFormScreen> createState() => _MoneyFormScreenState();
}

class _MoneyFormScreenState extends State<MoneyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late MoneyType _type = widget.existing?.type ?? widget.initialType;
  late MoneyTarget _target = widget.existing?.target ?? MoneyTarget.party;
  late DateTime _date = widget.existing != null
      ? DateTime.parse(widget.existing!.date)
      : DateTime.now();
  // Both fields keep what was typed, so flipping the switch back and forth
  // doesn't lose it; only the selected one is validated and saved.
  late final _party = TextEditingController(text: widget.existing?.party ?? '');
  late final _vehicle = TextEditingController(
    text: widget.existing?.vehicleNo ?? '',
  );
  final _partyFocusNode = FocusNode();
  final _vehicleFocusNode = FocusNode();
  late final _amount = TextEditingController(
    text: widget.existing != null
        ? widget.existing!.amount.toStringAsFixed(0)
        : '',
  );
  // The party field is rebuilt when the switch flips back to it, so the list
  // it suggests from lives here (a party added on the spot stays in it).
  late final List<Party> _parties = [...widget.parties];
  bool _submitting = false;

  @override
  void dispose() {
    _party.dispose();
    _vehicle.dispose();
    _partyFocusNode.dispose();
    _vehicleFocusNode.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final amount = double.parse(_amount.text.trim());
    final date = formatDateIso(_date);
    final id = widget.existing?.id;
    final entry = _target == MoneyTarget.party
        ? MoneyEntry(
            id: id,
            date: date,
            party: _party.text.trim(),
            amount: amount,
            type: _type,
          )
        : MoneyEntry(
            id: id,
            date: date,
            vehicleNo: normalizeVehicleNo(_vehicle.text)!,
            amount: amount,
            type: _type,
          );
    if (widget.existing == null) {
      await widget.repository.add(entry);
    } else {
      await widget.repository.update(entry);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final verb = widget.existing != null ? 'Edit' : 'New';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('$verb ${_type.label.toLowerCase()}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<MoneyType>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in MoneyType.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
              ),
              const SizedBox(height: 20),
              DateField(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<MoneyTarget>(
                  key: const ValueKey('moneyTarget'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: MoneyTarget.party,
                      icon: Icon(Icons.person_outline, size: 18),
                      label: Text('Party'),
                    ),
                    ButtonSegment(
                      value: MoneyTarget.vehicle,
                      icon: Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text('Vehicle'),
                    ),
                  ],
                  selected: {_target},
                  onSelectionChanged: (s) => setState(() => _target = s.first),
                ),
              ),
              const SizedBox(height: 14),
              if (_target == MoneyTarget.party)
                PartyField(
                  controller: _party,
                  focusNode: _partyFocusNode,
                  parties: _parties,
                  onAdded: _parties.add,
                )
              else
                VehicleField(
                  controller: _vehicle,
                  focusNode: _vehicleFocusNode,
                  vehicles: widget.vehicles,
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'RUPEES'),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  return (n == null || n <= 0) ? 'Enter the rupees' : null;
                },
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: moneyTypeColor(_type),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: Text(
                    _submitting
                        ? 'SAVING...'
                        : 'SAVE ${_type.label.toUpperCase()}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the Debit/Credit form with the parties and vehicles to pick from.
Future<void> openMoneyForm(
  BuildContext context, {
  MoneyEntry? existing,
  MoneyType initialType = MoneyType.debit,
}) async {
  final lists = await Future.wait([
    Repos.instance.parties.list(),
    Repos.instance.vehicles.list(),
  ]);
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MoneyFormScreen(
        repository: Repos.instance.money,
        parties: lists[0] as List<Party>,
        vehicles: lists[1] as List<Vehicle>,
        existing: existing,
        initialType: initialType,
      ),
    ),
  );
}
