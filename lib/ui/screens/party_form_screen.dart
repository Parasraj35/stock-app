import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';

/// Add/edit a party on a full screen — same layout as the Purchase and Sale
/// forms.
class PartyFormScreen extends StatefulWidget {
  const PartyFormScreen({super.key, this.existing, this.initialName});
  final Party? existing;

  /// Pre-fills the name when adding a party — used by the Purchase/Sale form's
  /// "Add party" button so what was already typed isn't lost.
  final String? initialName;

  @override
  State<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends State<PartyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName ?? '',
  );
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final party = Party(name: name, phone: phone.isEmpty ? null : phone);
    final Party saved;
    if (widget.existing == null) {
      saved = await Repos.instance.parties.add(party);
    } else {
      saved = party.copyWith(id: widget.existing!.id);
      await Repos.instance.parties.update(saved);
    }
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit party' : 'New party')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'NAME'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'PHONE NUMBER (OPTIONAL)',
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'SAVING...' : 'SAVE PARTY'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
