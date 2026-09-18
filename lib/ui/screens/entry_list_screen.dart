import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../data/data_bus.dart';
import '../../data/repositories.dart';
import '../theme/tokens.dart';
import '../widgets/brand_icon.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/profile_header_button.dart';
import 'entry_form_screen.dart';

/// List + add/edit/delete screen shared by both Purchase and Sale — same
/// UI and logic, only the backing repository and label differ.
class EntryListScreen extends StatelessWidget {
  const EntryListScreen({
    super.key,
    required this.title,
    required this.repository,
  });

  final String title;
  final EntryRepository repository;

  bool get _isPurchase => title == 'Purchase';
  Color get _accentColor =>
      _isPurchase ? AppColors.purchaseColor : AppColors.saleColor;
  MetricPalette get _palette =>
      _isPurchase ? MetricPalette.purchase : MetricPalette.sale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [ProfileHeaderButton(), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'entryListFab_$title',
        backgroundColor: _accentColor,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: DataBus.instance,
        builder: (context, _) {
          return FutureBuilder<List<Entry>>(
            future: repository.list(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!;
              if (entries.isEmpty) {
                return EmptyState(
                  icon: _isPurchase ? Icons.south_west : Icons.north_east,
                  message: 'No $title entries yet.\nTap + to add one.',
                );
              }
              final totalAmount = entries.fold<double>(
                0,
                (sum, e) => sum + e.amount,
              );
              final totalCft = entries.fold<double>(
                0,
                (sum, e) => sum + e.totalCFT,
              );
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _palette.highlightBg,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _palette.highlightText.withValues(
                              alpha: 0.14,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPurchase ? Icons.south_west : Icons.north_east,
                            color: _palette.highlightText,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entries.length} ${title.toUpperCase()}${entries.length == 1 ? '' : 'S'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: _palette.highlightText.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatGroupedNumber(totalCft)} cft total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _palette.highlightText.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: _palette.highlightText.withValues(alpha: 0.2),
                        ),
                        Text(
                          formatPkrCurrency(totalAmount),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _palette.highlightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: entries.length,
                      itemBuilder: (context, i) => _EntryCard(
                        entry: entries[i],
                        accentColor: _accentColor,
                        onTap: () => _openForm(context, existing: entries[i]),
                        onDelete: () => _confirmDelete(context, entries[i]),
                      ),
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

  Future<void> _confirmDelete(BuildContext context, Entry e) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete $title entry?',
      message: 'Delete the entry for "${e.party}"? This cannot be undone.',
      confirmLabel: 'DELETE',
    );
    if (confirmed) await repository.delete(e.id!);
  }

  Future<void> _openForm(BuildContext context, {Entry? existing}) {
    return openEntryForm(
      context,
      title: title,
      repository: repository,
      existing: existing,
    );
  }
}

/// A single Purchase/Sale entry — product thumbnail, party/brand + amount,
/// date + vehicle reference, the round×cft breakdown, and the applied rate.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.accentColor,
    required this.onTap,
    required this.onDelete,
  });
  final Entry entry;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rate = entry.ratePerCft;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BrandIcon(name: entry.brandName, size: 60),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${entry.party} — ${entry.brandName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      formatPkrCurrency(entry.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      entry.date,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (entry.vehicleNo != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '·',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.description_outlined,
                                        size: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        entry.vehicleNo!,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.grain,
                                            size: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${entry.round.toStringAsFixed(0)} round × ${entry.cftPerVehicle.toStringAsFixed(0)} cft',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.sell_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Rate Rs ${formatDecimal(rate)}/cft',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.negative.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: AppColors.negative,
                                size: 18,
                              ),
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
