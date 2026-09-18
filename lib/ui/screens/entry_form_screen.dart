import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/vehicles.dart';
import '../../data/repos.dart';
import '../../data/repositories.dart';
import '../theme/tokens.dart';

/// Add/edit form shared by both the Purchase and Sale screens — same fields,
/// same live totalCFT/amount calculation, only the repository + label and
/// accent color (teal-green vs orange) differ.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.title,
    required this.repository,
    required this.brands,
    required this.parties,
    required this.vehicles,
    this.existing,
  });

  final String title;
  final EntryRepository repository;
  final List<Brand> brands;
  final List<Party> parties;

  /// The fixed vehicles — typing a vehicle's CFT fills in its number.
  final List<Vehicle> vehicles;
  final Entry? existing;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final _party = TextEditingController(text: widget.existing?.party ?? '');
  final _partyFocusNode = FocusNode();
  late final _cftPerVehicle = TextEditingController(
    text: widget.existing != null
        ? _trimZeros(widget.existing!.cftPerVehicle)
        : '',
  );
  late final _round = TextEditingController(
    text: widget.existing != null ? _trimZeros(widget.existing!.round) : '',
  );
  late final _vehicleNo = TextEditingController(
    text: widget.existing?.vehicleNo ?? '',
  );
  // Per-entry price: starts at the brand's default rate (or, when editing, at
  // the price this entry was saved with) and can be changed for this entry
  // only — the brand's own default is never touched.
  final _rate = TextEditingController();
  // True while the vehicle field holds a number we filled in from the CFT
  // (and the user hasn't typed over it).
  bool _vehicleIsAuto = false;
  // The CFT text last acted on, so cursor moves (which also notify the
  // controller) don't re-run the vehicle lookup.
  String _lastCftText = '';
  Brand? _selectedBrand;
  bool _submitting = false;
  double? _brandStock;
  bool _stockLoading = false;

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    _date = widget.existing != null
        ? DateTime.parse(widget.existing!.date)
        : DateTime.now();
    if (widget.existing != null) {
      final existingBrandId = widget.existing!.brandId;
      _selectedBrand = widget.brands
          .where((b) => b.id == existingBrandId)
          .cast<Brand?>()
          .firstWhere((b) => b != null, orElse: () => null);
      _rate.text = formatDecimal(widget.existing!.ratePerCft);
    } else if (widget.brands.isNotEmpty) {
      _selectedBrand = widget.brands.first;
      _rate.text = formatDecimal(_rateFor(_selectedBrand!));
    }
    _lastCftText = _cftPerVehicle.text;
    _cftPerVehicle.addListener(_onCftChanged);
    for (final c in [_round, _rate]) {
      c.addListener(() => setState(() {}));
    }
    _refreshStock();
  }

  /// Live stock on hand for the selected brand — Sale only, so the user can
  /// see what's available before recording how much they're selling.
  Future<void> _refreshStock() async {
    if (_isPurchase || _selectedBrand == null) {
      setState(() => _brandStock = null);
      return;
    }
    final brandId = _selectedBrand!.id;
    setState(() => _stockLoading = true);
    final results = await Future.wait([
      Repos.instance.purchases.list(),
      Repos.instance.sales.list(),
    ]);
    final purchases = results[0];
    final sales = results[1];
    final purchasedCft = purchases
        .where((e) => e.brandId == brandId)
        .fold<double>(0, (sum, e) => sum + e.totalCFT);
    final soldCft = sales
        .where((e) => e.brandId == brandId)
        .fold<double>(0, (sum, e) => sum + e.totalCFT);
    if (!mounted) return;
    setState(() {
      _brandStock = calcStock(purchasedCft, soldCft);
      _stockLoading = false;
    });
  }

  /// Typing a vehicle's exact CFT fills in its number. If the CFT no longer
  /// matches and the number was only auto-filled, it's cleared again — a
  /// number the user typed themselves is left alone.
  void _onCftChanged() {
    if (_cftPerVehicle.text == _lastCftText) return;
    _lastCftText = _cftPerVehicle.text;
    final cft = double.tryParse(_cftPerVehicle.text.trim());
    final match = cft == null ? null : vehicleForCft(widget.vehicles, cft);
    if (match != null) {
      _vehicleNo.text = match.vehicleNo;
      _vehicleIsAuto = true;
    } else if (_vehicleIsAuto) {
      _vehicleNo.clear();
      _vehicleIsAuto = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _party.dispose();
    _partyFocusNode.dispose();
    _cftPerVehicle.dispose();
    _round.dispose();
    _rate.dispose();
    _vehicleNo.dispose();
    super.dispose();
  }

  /// The selected brand's rate for whichever direction this form is —
  /// purchase rate on the Purchase screen, sale rate on the Sale screen.
  double _rateFor(Brand b) => _isPurchase ? b.purchaseRate : b.saleRate;

  EntryTotals get _liveTotals {
    final round = double.tryParse(_round.text.trim()) ?? 0;
    final cft = double.tryParse(_cftPerVehicle.text.trim()) ?? 0;
    final rate = double.tryParse(_rate.text.trim()) ?? 0;
    return calcEntryTotals(round, cft, rate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedBrand == null) return;
    setState(() => _submitting = true);
    final totals = _liveTotals;
    final entry = Entry(
      id: widget.existing?.id,
      date: formatDateIso(_date),
      party: _party.text.trim(),
      brandId: _selectedBrand!.id!,
      brandName: _selectedBrand!.name,
      cftPerVehicle: double.parse(_cftPerVehicle.text.trim()),
      round: double.parse(_round.text.trim()),
      vehicleNo: normalizeVehicleNo(_vehicleNo.text),
      totalCFT: totals.totalCFT,
      amount: totals.amount,
    );
    if (widget.existing == null) {
      await widget.repository.add(entry);
    } else {
      await widget.repository.update(entry);
    }
    if (mounted) Navigator.pop(context);
  }

  bool get _isPurchase => widget.title == 'Purchase';
  Color get _accentColor =>
      _isPurchase ? AppColors.purchaseColor : AppColors.saleColor;
  MetricPalette get _palette =>
      _isPurchase ? MetricPalette.purchase : MetricPalette.sale;

  @override
  Widget build(BuildContext context) {
    final totals = _liveTotals;
    final isEdit = widget.existing != null;
    final verb = isEdit ? 'Edit' : 'New';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('$verb ${widget.title.toLowerCase()}')),
      body: widget.brands.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add a brand first (Brands tab) before recording entries.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'DATE'),
                        child: Text(formatDateIso(_date)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Autocomplete<Party>(
                      textEditingController: _party,
                      focusNode: _partyFocusNode,
                      optionsBuilder: (v) {
                        final q = v.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<Party>.empty();
                        return widget.parties.where(
                          (p) => p.name.toLowerCase().contains(q),
                        );
                      },
                      displayStringForOption: (p) => p.name,
                      onSelected: (p) => _party.text = p.name,
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'PARTY',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 220,
                                minWidth: 260,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, i) {
                                  final p = options.elementAt(i);
                                  return ListTile(
                                    dense: true,
                                    title: Text(p.name),
                                    subtitle:
                                        (p.phone != null && p.phone!.isNotEmpty)
                                        ? Text(p.phone!)
                                        : null,
                                    onTap: () => onSelected(p),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<Brand>(
                      initialValue: _selectedBrand,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'BRAND'),
                      selectedItemBuilder: (context) => [
                        for (final b in widget.brands)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    b.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  formatPkrCurrency(_rateFor(b)),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      items: [
                        for (final b in widget.brands)
                          DropdownMenuItem(
                            value: b,
                            child: Text(
                              '${b.name} (${formatPkrCurrency(_rateFor(b))})',
                            ),
                          ),
                      ],
                      onChanged: (b) {
                        setState(() {
                          _selectedBrand = b;
                          if (b != null) {
                            _rate.text = formatDecimal(_rateFor(b));
                          }
                        });
                        _refreshStock();
                      },
                      validator: (v) => v == null ? 'Select a brand' : null,
                    ),
                    if (!_isPurchase && _selectedBrand != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: (_brandStock ?? 0) < 0
                                ? AppColors.negative
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _stockLoading || _brandStock == null
                                ? 'Checking stock...'
                                : 'In stock: ${formatGroupedNumber(_brandStock!)} cft',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (_brandStock ?? 0) < 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: (_brandStock ?? 0) < 0
                                  ? AppColors.negative
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cftPerVehicle,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'CFT / vehicle',
                            ),
                            validator: (v) {
                              final n = double.tryParse(v?.trim() ?? '');
                              return (n == null || n <= 0) ? 'Required' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _round,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Round',
                            ),
                            validator: (v) {
                              final n = double.tryParse(v?.trim() ?? '');
                              return (n == null || n <= 0) ? 'Required' : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'RATE (RS/CFT)',
                              helperText: _selectedBrand == null
                                  ? null
                                  : 'Default Rs ${formatDecimal(_rateFor(_selectedBrand!))}',
                            ),
                            validator: (v) {
                              final n = double.tryParse(v?.trim() ?? '');
                              return (n == null || n <= 0) ? 'Required' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _vehicleNo,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'VEHICLE NO.',
                              helperText: _vehicleIsAuto
                                  ? 'Auto from CFT'
                                  : null,
                            ),
                            onChanged: (_) =>
                                setState(() => _vehicleIsAuto = false),
                            validator: (v) => normalizeVehicleNo(v) == null
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _palette.highlightBg,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total CFT',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _palette.highlightText.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                              Text(
                                formatGroupedNumber(totals.totalCFT),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _palette.highlightText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Amount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _palette.highlightText.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                              Text(
                                formatPkrCurrency(totals.amount),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _palette.highlightText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_round.text.isEmpty ? '0' : _round.text} × ${_cftPerVehicle.text.isEmpty ? '0' : _cftPerVehicle.text} × '
                            'Rs ${_rate.text.isEmpty ? '0' : _rate.text}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _palette.highlightText.withValues(
                                alpha: 0.65,
                              ),
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
                          backgroundColor: _accentColor,
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: Text(
                          _submitting
                              ? 'SAVING...'
                              : 'SAVE ${widget.title.toUpperCase()}',
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

/// Opens the Purchase/Sale form with the current brands, parties and
/// vehicles. Shared by the Purchase/Sale lists and the Dashboard's quick add.
Future<void> openEntryForm(
  BuildContext context, {
  required String title,
  required EntryRepository repository,
  Entry? existing,
}) async {
  final results = await Future.wait([
    Repos.instance.brands.list(),
    Repos.instance.parties.list(),
    Repos.instance.vehicles.list(),
  ]);
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EntryFormScreen(
        title: title,
        repository: repository,
        brands: results[0] as List<Brand>,
        parties: results[1] as List<Party>,
        vehicles: results[2] as List<Vehicle>,
        existing: existing,
      ),
    ),
  );
}
