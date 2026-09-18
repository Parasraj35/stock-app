import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../theme/tokens.dart';

/// One entry as a compact voucher row for the report screens — party/brand
/// and amount, date and vehicle, and the full round × cft @ rate breakdown.
/// [showType] adds a Purchase/Sale badge (for lists that mix both);
/// [showParty] is off where the whole list is already one party's, and
/// [showVehicle] where it's already grouped under one vehicle.
class VoucherTile extends StatelessWidget {
  const VoucherTile({
    super.key,
    required this.entry,
    required this.isPurchase,
    this.showType = false,
    this.showParty = true,
    this.showVehicle = true,
  });

  final Entry entry;
  final bool isPurchase;
  final bool showType;
  final bool showParty;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final accent = isPurchase ? AppColors.purchaseColor : AppColors.saleColor;
    final title = showParty
        ? '${entry.party} — ${entry.brandName}'
        : entry.brandName;
    final vehicle = entry.vehicleNo;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatPkrCurrency(entry.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                        if (showVehicle &&
                            vehicle != null &&
                            vehicle.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              vehicle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (showType)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isPurchase ? 'PURCHASE' : 'SALE',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDecimal(entry.round)} × ${formatDecimal(entry.cftPerVehicle)} = ${formatGroupedNumber(entry.totalCFT)} cft  @  Rs ${formatDecimal(entry.ratePerCft)}/cft',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heading above each month's entries: month name, a one-line detail, and
/// the month's headline figure on the right.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.title,
    required this.detail,
    required this.trailing,
    this.trailingColor,
  });

  final String title;
  final String detail;
  final String trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: trailingColor,
            ),
          ),
        ],
      ),
    );
  }
}
