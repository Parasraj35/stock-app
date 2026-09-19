import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/reports.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_widgets.dart';
import 'money_form_screen.dart';

/// Debit & Credit — every entry newest first, with the two totals on top.
/// Tap an entry to edit it; the + button adds one.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  late Future<List<MoneyEntry>> _future = Repos.instance.money.list();

  @override
  void initState() {
    super.initState();
    DataBus.instance.addListener(_reload);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_reload);
    super.dispose();
  }

  // Reload once per save/delete rather than on every rebuild.
  void _reload() {
    if (!mounted) return;
    // A block body: an arrow function here would hand the Future back to
    // setState, which debug builds reject (and then never redraw).
    setState(() {
      _future = Repos.instance.money.list();
    });
  }

  Future<void> _confirmDelete(MoneyEntry e) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete ${e.type.label.toLowerCase()}?',
      message:
          'Delete the ${e.type.label.toLowerCase()} for ${e.name}? '
          'This cannot be undone.',
      confirmLabel: 'DELETE',
    );
    if (confirmed) await Repos.instance.money.delete(e.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debit & Credit')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'moneyFab',
        onPressed: () => openMoneyForm(context),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<MoneyEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              message: 'No debit or credit entries yet.\nTap + to add one.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: MoneyTotalsCard(
                  debit: entries.debit,
                  credit: entries.credit,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => MoneyTile(
                    entry: entries[i],
                    onTap: () => openMoneyForm(context, existing: entries[i]),
                    onDelete: () => _confirmDelete(entries[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
