import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';

/// Party directory: name required, phone optional. Reached from the
/// Dashboard's Parties count card.
class PartiesScreen extends StatelessWidget {
  const PartiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parties')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'partiesFab',
        onPressed: () => _openPartyForm(context),
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: DataBus.instance,
        builder: (context, _) {
          return FutureBuilder<List<Party>>(
            future: Repos.instance.parties.list(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final parties = snapshot.data!;
              if (parties.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  message: 'No parties yet.\nTap + to add one.',
                );
              }
              return ListView.separated(
                itemCount: parties.length,
                separatorBuilder: (context, i) =>
                    const Divider(indent: 16, endIndent: 16),
                itemBuilder: (context, i) {
                  final party = parties[i];
                  final (bg, fg) = avatarColorsFor(party.name);
                  return ListTile(
                    onTap: () => _openPartyForm(context, existing: party),
                    leading: CircleAvatar(
                      backgroundColor: bg,
                      child: Text(
                        party.name.isNotEmpty
                            ? party.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(party.name),
                    subtitle: (party.phone != null && party.phone!.isNotEmpty)
                        ? Text(party.phone!)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _openPartyForm(context, existing: party),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppColors.negative,
                          ),
                          onPressed: () => _confirmDelete(context, party),
                        ),
                      ],
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

  Future<void> _confirmDelete(BuildContext context, Party party) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete party?'),
        content: Text('Delete "${party.name}"? This cannot be undone.'),
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
      await Repos.instance.parties.delete(party.id!);
    }
  }

  Future<void> _openPartyForm(BuildContext context, {Party? existing}) {
    return showDialog(
      context: context,
      builder: (context) => _PartyFormDialog(existing: existing),
    );
  }
}

class _PartyFormDialog extends StatefulWidget {
  const _PartyFormDialog({this.existing});
  final Party? existing;

  @override
  State<_PartyFormDialog> createState() => _PartyFormDialogState();
}

class _PartyFormDialogState extends State<_PartyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
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
    if (widget.existing == null) {
      await Repos.instance.parties.add(party);
    } else {
      await Repos.instance.parties.update(
        party.copyWith(id: widget.existing!.id),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit party' : 'Add party'),
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
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'PHONE NUMBER (OPTIONAL)',
              ),
            ),
          ],
        ),
      ),
      actions: [
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
