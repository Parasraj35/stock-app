// Framework-free trend helpers derived from purchase/sale entries — no
// separate history table, everything is computed from the existing stores.
import 'calc.dart';
import 'format.dart';
import 'models.dart';

/// One day's net profit — feeds the Dashboard's profit trend chart.
class TrendPoint {
  final DateTime date;
  final double value;
  const TrendPoint(this.date, this.value);
}

/// Realized profit for each of the last [days] days, oldest first — feeds
/// the Dashboard's profit trend chart. Only sales count: buying inventory
/// is an investment, not a loss, so a purchase-heavy day with no sales
/// shows 0 rather than a dip. Each sale's margin is its amount minus the
/// average price actually paid for that brand × the quantity sold.
List<TrendPoint> dailyRealizedProfitSeries(
  List<Entry> sales,
  List<Entry> purchases,
  List<Brand> brands, {
  int days = 7,
}) {
  final costRates = costRateByBrand(purchases, brands);
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  return [
    for (var i = days - 1; i >= 0; i--)
      TrendPoint(
        startOfToday.subtract(Duration(days: i)),
        _marginOnDay(
          sales,
          costRates,
          startOfToday.subtract(Duration(days: i)),
        ),
      ),
  ];
}

double _marginOnDay(
  List<Entry> sales,
  Map<int, double> costRates,
  DateTime day,
) {
  final dayIso = formatDateIso(day);
  return sales.where((e) => e.date == dayIso).fold<double>(0, (sum, e) {
    final costRate = costRates[e.brandId] ?? 0;
    return sum + (e.amount - costRate * e.totalCFT);
  });
}

/// Percent change in [entries]' total amount this calendar month vs last.
/// Null when last month has no data to compare against.
double? monthOverMonthChangePercent(List<Entry> entries, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final startOfThisMonth = DateTime(n.year, n.month, 1);
  final startOfLastMonth = DateTime(n.year, n.month - 1, 1);
  final startOfNextDay = DateTime(n.year, n.month, n.day + 1);

  double sumInRange(DateTime start, DateTime end) {
    return entries
        .where((e) {
          final d = DateTime.parse(e.date);
          return !d.isBefore(start) && d.isBefore(end);
        })
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  final thisMonthTotal = sumInRange(startOfThisMonth, startOfNextDay);
  final lastMonthTotal = sumInRange(startOfLastMonth, startOfThisMonth);

  if (lastMonthTotal == 0) return null;
  return (thisMonthTotal - lastMonthTotal) / lastMonthTotal * 100;
}
