import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_summary.dart';
import 'party_form_screen.dart';

/// What one party has bought from / sold to the business, from the entries
/// recorded under their name.
class _PartyStats {
  double purchased = 0;
  double sold = 0;
  int entries = 0;
}

class _PartiesData {
  final List<Party> parties;
  final Map<String, _PartyStats> stats;
  const _PartiesData(this.parties, this.stats);

  int get totalEntries => stats.values.fold(0, (sum, s) => sum + s.entries);
}

Future<_PartiesData> _load() async {
  final results = await Future.wait([
    Repos.instance.parties.list(),
    Repos.instance.purchases.list(),
    Repos.instance.sales.list(),
  ]);
  final stats = <String, _PartyStats>{};
  for (final e in results[1] as List<Entry>) {
    final s = stats.putIfAbsent(e.party, _PartyStats.new);
    s.purchased += e.amount;
    s.entries++;
  }
  for (final e in results[2] as List<Entry>) {
    final s = stats.putIfAbsent(e.party, _PartyStats.new);
    s.sold += e.amount;
    s.entries++;
  }
  return _PartiesData(results[0] as List<Party>, stats);
}

/// Party directory: name required, phone optional, with each party's totals.
/// Reached from the Dashboard's Parties count card.
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
          return FutureBuilder<_PartiesData>(
            future: _load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final parties = data.parties;
              if (parties.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  message: 'No parties yet.\nTap + to add one.',
                );
              }
              return Column(
                children: [
                  SummaryBanner(
                    icon: Icons.people_outline,
                    label:
                        '${parties.length} PART${parties.length == 1 ? 'Y' : 'IES'}',
                    trailing:
                        '${data.totalEntries} ${data.totalEntries == 1 ? 'entry' : 'entries'}',
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                      itemCount: parties.length,
                      itemBuilder: (context, i) {
                        final party = parties[i];
                        return _PartyCard(
                          party: party,
                          stats: data.stats[party.name],
                          onTap: () => _openPartyForm(context, existing: party),
                          onDelete: () => _confirmDelete(context, party),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Party party) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete party?',
      message: 'Delete "${party.name}"? This cannot be undone.',
      confirmLabel: 'DELETE',
    );
    if (confirmed) await Repos.instance.parties.delete(party.id!);
  }

  Future<void> _openPartyForm(BuildContext context, {Party? existing}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyFormScreen(existing: existing),
      ),
    );
  }
}

/// One party — colored initial, name, phone, and what they've bought from
/// and sold to the business.
class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.party,
    required this.stats,
    required this.onTap,
    required this.onDelete,
  });
  final Party party;
  final _PartyStats? stats;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = avatarColorsFor(party.name);
    final phone = party.phone;
    final hasPhone = phone != null && phone.isNotEmpty;
    final entries = stats?.entries ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: bg,
                    child: Text(
                      party.name.isNotEmpty ? party.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                hasPhone ? phone : 'No phone number',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (entries > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$entries ${entries == 1 ? 'entry' : 'entries'}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatColumn(
                      label: 'BOUGHT',
                      value: stats?.purchased ?? 0,
                      color: AppColors.purchaseColor,
                    ),
                  ),
                  Expanded(
                    child: StatColumn(
                      label: 'SOLD',
                      value: stats?.sold ?? 0,
                      color: AppColors.saleColor,
                    ),
                  ),
                  CardIconButton(
                    tooltip: 'Delete party',
                    icon: Icons.delete_outline,
                    color: AppColors.negative,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
