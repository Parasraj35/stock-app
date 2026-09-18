import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../theme/tokens.dart';

/// Animates from 0 up to [value] once, on first build — a cheap "count up"
/// feel without any animation package.
class _CountUpText extends StatelessWidget {
  const _CountUpText({
    required this.value,
    required this.style,
    this.formatter,
  });
  final double value;
  final TextStyle style;
  final String Function(double)? formatter;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final text = formatter != null
            ? formatter!(animatedValue)
            : formatGroupedNumber(animatedValue);
        return Text(text, style: style);
      },
    );
  }
}

/// Big hero highlight card for net profit — flips between the positive
/// (mint) and negative (rose) highlight chip colors, with a profit/loss
/// tag. The trend visualization itself lives in the Dashboard's separate
/// Profit Trend section below, where the user can pick a chart type.
class HeroProfitCard extends StatelessWidget {
  const HeroProfitCard({super.key, required this.profit});
  final double profit;

  @override
  Widget build(BuildContext context) {
    final positive = profit >= 0;
    final palette = positive
        ? MetricPalette.profit
        : MetricPalette.profitNegative;
    final sign = positive ? '+' : '-';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.highlightBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: palette.highlightText.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'NET PROFIT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: palette.highlightText.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.highlightText.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      positive ? Icons.trending_up : Icons.trending_down,
                      size: 13,
                      color: palette.highlightText,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      positive ? 'PROFIT' : 'LOSS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: palette.highlightText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _CountUpText(
            value: profit.abs(),
            formatter: (v) => '$sign ${formatPkrCurrency(v)}',
            style: TextStyle(
              color: palette.highlightText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Half-width metric card (Total purchase / Total sale), with an optional
/// month-over-month change line. Dims to a muted look when there's no
/// activity yet, so a genuine zero doesn't read like a loading glitch.
class HalfMetricCard extends StatelessWidget {
  const HalfMetricCard({
    super.key,
    required this.label,
    required this.amount,
    required this.cft,
    required this.palette,
    this.changePercent,
  });

  final String label;
  final double amount;
  final double cft;
  final MetricPalette palette;
  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    final isEmpty = amount == 0 && cft == 0;
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              color: isEmpty ? AppColors.divider : palette.color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _CountUpText(
                      value: amount,
                      style: TextStyle(
                        color: isEmpty
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEmpty
                          ? 'No activity yet'
                          : 'CFT ${formatGroupedNumber(cft)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (changePercent != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${changePercent! >= 0 ? '+' : ''}${changePercent!.toStringAsFixed(0)}% vs last month',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: changePercent! >= 0
                              ? MetricPalette.profit.color
                              : MetricPalette.profitNegative.color,
                        ),
                      ),
                    ],
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

/// Half-width count card (Parties / Brands), tappable — big count over a
/// plain label, no icon or subtitle.
class CountCard extends StatelessWidget {
  const CountCard({
    super.key,
    required this.label,
    required this.count,
    this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CountUpText(
                value: count.toDouble(),
                formatter: (v) => v.round().toString(),
                style: TextStyle(
                  color: count == 0
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
