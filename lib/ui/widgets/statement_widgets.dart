import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/statement.dart';
import '../theme/tokens.dart';
import 'list_summary.dart' show StatColumn;

/// Sale and Debit raise what the party owes you; Purchase and Credit lower it.
/// The two directions take the two accent colours (orange / teal) used for
/// sale and purchase everywhere else.
Color ledgerKindColor(LedgerKind kind) =>
    kind.raisesBalance ? AppColors.saleColor : AppColors.purchaseColor;

/// The top of a party statement: the closing balance in words, then what was
/// sold, purchased, debited and credited.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.name, required this.statement});

  final String name;
  final PartyStatement statement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BALANCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatBalanceWith(name, statement.closing),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatColumn(
                  label: 'SOLD',
                  value: statement.sold,
                  color: AppColors.saleColor,
                ),
              ),
              Expanded(
                child: StatColumn(
                  label: 'PURCHASED',
                  value: statement.purchased,
                  color: AppColors.purchaseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatColumn(
                  label: 'DEBIT (GIVEN)',
                  value: statement.debit,
                  color: AppColors.saleColor,
                ),
              ),
              Expanded(
                child: StatColumn(
                  label: 'CREDIT (RECEIVED)',
                  value: statement.credit,
                  color: AppColors.purchaseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Sale and Debit raise what the party owes you; '
            'Purchase and Credit lower it.',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The first line of a statement that starts part-way through: what was
/// already owed by the time the chosen From date came.
class BalanceForwardTile extends StatelessWidget {
  const BalanceForwardTile({super.key, required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.history, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Balance brought forward',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatBalance(balance),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of a party statement — a sale, purchase, debit or credit — with
/// the balance after it.
class StatementTile extends StatelessWidget {
  const StatementTile({super.key, required this.line});

  final StatementLine line;

  @override
  Widget build(BuildContext context) {
    final color = ledgerKindColor(line.kind);
    final trade = line.trade;
    final title = trade != null
        ? trade.brandName
        : (line.kind == LedgerKind.debit ? 'Money given' : 'Money received');
    final vehicle = trade?.vehicleNo;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            line.kind.label.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                          formatPkrCurrency(line.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          line.date,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (vehicle != null && vehicle.isNotEmpty) ...[
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
                      ],
                    ),
                    if (trade != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${formatDecimal(trade.round)} × '
                        '${formatDecimal(trade.cftPerVehicle)} = '
                        '${formatGroupedNumber(trade.totalCFT)} cft  @  '
                        'Rs ${formatDecimal(trade.ratePerCft)}/cft',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Balance: ${formatBalance(line.balance)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
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
