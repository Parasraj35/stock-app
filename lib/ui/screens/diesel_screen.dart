import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/reports.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/diesel_widgets.dart';
import '../widgets/empty_state.dart';
import 'diesel_form_screen.dart';
import 'diesel_report_screen.dart';

/// Diesel — every entry newest first, with total litres and total amount on
/// top. Tap an entry to edit it; the + button adds one; the report button
/// opens the printable report.
class DieselScreen extends StatefulWidget {
  const DieselScreen({super.key});

  @override
  State<DieselScreen> createState() => _DieselScreenState();
}

class _DieselScreenState extends State<DieselScreen> {
  late Future<List<DieselEntry>> _future = Repos.instance.diesel.list();

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
      _future = Repos.instance.diesel.list();
    });
  }

  Future<void> _confirmDelete(DieselEntry e) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete diesel entry?',
      message:
          'Delete ${formatLitres(e.litres)} L for ${e.vehicleNo} on ${e.date}? '
          'This cannot be undone.',
      confirmLabel: 'DELETE',
    );
    if (confirmed) await Repos.instance.diesel.delete(e.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diesel'),
        actions: [
          IconButton(
            tooltip: 'Report',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DieselReportScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dieselFab',
        onPressed: () => openDieselForm(context),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<DieselEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.local_gas_station_outlined,
              message: 'No diesel entries yet.\nTap + to add one.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: DieselTotalsCard(
                  litres: entries.litres,
                  amount: entries.amount,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => DieselTile(
                    entry: entries[i],
                    onTap: () => openDieselForm(context, existing: entries[i]),
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
