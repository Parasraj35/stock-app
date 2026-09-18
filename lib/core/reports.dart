// Framework-free reporting helpers — group entries by month for the
// "monthly purchase/sale" view and PDF exports. No Flutter/pdf imports.
import 'models.dart';

class MonthlyTotal {
  final String monthKey; // 'yyyy-MM'
  final int count;
  final double totalCft;
  final double totalAmount;

  const MonthlyTotal({
    required this.monthKey,
    required this.count,
    required this.totalCft,
    required this.totalAmount,
  });
}

/// Groups [entries] by calendar month (from the ISO date), most recent
/// month first.
List<MonthlyTotal> monthlyTotals(List<Entry> entries) {
  final byMonth = <String, List<Entry>>{};
  for (final e in entries) {
    final key = e.date.substring(0, 7);
    byMonth.putIfAbsent(key, () => []).add(e);
  }
  final result = [
    for (final entry in byMonth.entries)
      MonthlyTotal(
        monthKey: entry.key,
        count: entry.value.length,
        totalCft: entry.value.fold<double>(0, (sum, e) => sum + e.totalCFT),
        totalAmount: entry.value.fold<double>(0, (sum, e) => sum + e.amount),
      ),
  ];
  result.sort((a, b) => b.monthKey.compareTo(a.monthKey));
  return result;
}

/// One line of a party's ledger — [isPurchase] disambiguates it since
/// purchase/sale ids are independent autoincrement sequences and can
/// collide, so the source table can't be inferred from the entry alone.
class PartyLedgerEntry {
  final Entry entry;
  final bool isPurchase;
  const PartyLedgerEntry(this.entry, this.isPurchase);
}

/// Combined chronological history (newest first) of both purchase and sale
/// entries for one party — the party statement.
List<PartyLedgerEntry> partyHistory(
  String partyName,
  List<Entry> purchases,
  List<Entry> sales,
) {
  final combined = [
    for (final e in purchases.where((e) => e.party == partyName))
      PartyLedgerEntry(e, true),
    for (final e in sales.where((e) => e.party == partyName))
      PartyLedgerEntry(e, false),
  ];
  combined.sort((a, b) => b.entry.date.compareTo(a.entry.date));
  return combined;
}

/// An optional inclusive [from]/[to] filter for report exports — either or
/// both may be null, meaning "no lower/upper bound".
class DateRange {
  final DateTime? from;
  final DateTime? to;
  const DateRange({this.from, this.to});

  bool get isEmpty => from == null && to == null;
}

List<Entry> filterByDateRange(List<Entry> entries, DateRange range) {
  if (range.isEmpty) return entries;
  return entries.where((e) {
    final d = DateTime.parse(e.date);
    if (range.from != null && d.isBefore(range.from!)) return false;
    if (range.to != null && d.isAfter(range.to!)) return false;
    return true;
  }).toList();
}

/// One month's purchase + sale totals side by side, with the net profit —
/// the "merged" report combining both entry types into a single table.
class MergedMonthlyTotal {
  final String monthKey;
  final double purchaseCft;
  final double purchaseAmount;
  final double saleCft;
  final double saleAmount;
  const MergedMonthlyTotal({
    required this.monthKey,
    required this.purchaseCft,
    required this.purchaseAmount,
    required this.saleCft,
    required this.saleAmount,
  });

  double get profit => saleAmount - purchaseAmount;
}

List<MergedMonthlyTotal> mergedMonthlyTotals(
  List<Entry> purchases,
  List<Entry> sales,
) {
  final purchaseByMonth = {
    for (final m in monthlyTotals(purchases)) m.monthKey: m,
  };
  final saleByMonth = {for (final m in monthlyTotals(sales)) m.monthKey: m};
  final allKeys = {...purchaseByMonth.keys, ...saleByMonth.keys}.toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final key in allKeys)
      MergedMonthlyTotal(
        monthKey: key,
        purchaseCft: purchaseByMonth[key]?.totalCft ?? 0,
        purchaseAmount: purchaseByMonth[key]?.totalAmount ?? 0,
        saleCft: saleByMonth[key]?.totalCft ?? 0,
        saleAmount: saleByMonth[key]?.totalAmount ?? 0,
      ),
  ];
}
