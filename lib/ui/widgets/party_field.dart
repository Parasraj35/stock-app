import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../screens/party_form_screen.dart';
import '../theme/tokens.dart';

/// The form's PARTY field: type to get suggestions from [parties]. When the
/// typed name isn't in the list yet, an "Add ... as a new party" button
/// appears; it opens the full-screen party form (name filled in) and selects
/// the party once saved.
class PartyField extends StatefulWidget {
  const PartyField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.parties,
    this.onAdded,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Party> parties;

  /// Called with a party saved from here, for a form that can rebuild this
  /// field (its own copy of [parties] would otherwise forget the new one).
  final ValueChanged<Party>? onAdded;

  @override
  State<PartyField> createState() => _PartyFieldState();
}

class _PartyFieldState extends State<PartyField> {
  // A growable copy, so a party added from here is offered straight away.
  late final List<Party> _parties = [...widget.parties];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // Repaint so the Add button follows what's typed.
  void _onTextChanged() => setState(() {});

  /// True when a party name has been typed that isn't in the list yet.
  bool get _isNew {
    final name = widget.controller.text.trim().toLowerCase();
    return name.isNotEmpty &&
        !_parties.any((p) => p.name.trim().toLowerCase() == name);
  }

  Future<void> _addParty() async {
    final saved = await Navigator.push<Party>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PartyFormScreen(initialName: widget.controller.text.trim()),
      ),
    );
    if (saved == null || !mounted) return;
    widget.onAdded?.call(saved);
    setState(() {
      _parties.add(saved);
      widget.controller.text = saved.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<Party>(
          textEditingController: widget.controller,
          focusNode: widget.focusNode,
          optionsBuilder: (v) {
            final q = v.text.trim().toLowerCase();
            if (q.isEmpty) return const Iterable<Party>.empty();
            return _parties.where((p) => p.name.toLowerCase().contains(q));
          },
          displayStringForOption: (p) => p.name,
          onSelected: (p) => widget.controller.text = p.name,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'PARTY'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                        subtitle: (p.phone != null && p.phone!.isNotEmpty)
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
        // Only when the typed party isn't in the list yet.
        if (_isNew)
          TextButton.icon(
            onPressed: _addParty,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text(
              'Add "${widget.controller.text.trim()}" as a new party',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}
