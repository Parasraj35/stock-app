// Framework-free reporting helpers — group entries by month for the
// "monthly purchase/sale" view and PDF exports. No Flutter/pdf imports.
import 'models.dart';
import 'vehicles.dart';

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

int _newestFirst(Entry a, Entry b) {
  final byDate = b.date.compareTo(a.date);
  return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
}

/// One calendar month's entries (newest first) with that month's totals —
/// the building block for listing every entry month by month.
class MonthGroup {
  final MonthlyTotal total;
  final List<Entry> entries;
  const MonthGroup(this.total, this.entries);
}

/// Every entry, grouped by calendar month, most recent month first, newest
/// entry first within each month.
List<MonthGroup> groupEntriesByMonth(List<Entry> entries) {
  final sorted = [...entries]..sort(_newestFirst);
  final byMonth = <String, List<Entry>>{};
  for (final e in sorted) {
    byMonth.putIfAbsent(e.date.substring(0, 7), () => []).add(e);
  }
  return [
    for (final list in byMonth.values)
      MonthGroup(monthlyTotals(list).single, list),
  ];
}

/// One line of a party's ledger — [isPurchase] disambiguates it since
/// purchase/sale ids are independent autoincrement sequences and can
/// collide, so the source table can't be inferred from the entry alone.
class PartyLedgerEntry {
  final Entry entry;
  final bool isPurchase;
  const PartyLedgerEntry(this.entry, this.isPurchase);
}

int _ledgerNewestFirst(PartyLedgerEntry a, PartyLedgerEntry b) {
  final byEntry = _newestFirst(a.entry, b.entry);
  if (byEntry != 0) return byEntry;
  // Same day and id: keep a stable order, sales above purchases.
  return a.isPurchase == b.isPurchase ? 0 : (a.isPurchase ? 1 : -1);
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
  combined.sort(_ledgerNewestFirst);
  return combined;
}

/// An optional inclusive [from]/[to] filter for report exports — either or
/// both may be null, meaning "no lower/upper bound".
class DateRange {
  final DateTime? from;
  final DateTime? to;
  const DateRange({this.from, this.to});

  bool get isEmpty => from == null && to == null;

  /// Whether the ISO date (yyyy-MM-dd) falls inside the range, bounds included.
  bool containsIso(String iso) {
    final d = DateTime.parse(iso);
    if (from != null && d.isBefore(from!)) return false;
    if (to != null && d.isAfter(to!)) return false;
    return true;
  }
}

List<Entry> filterByDateRange(List<Entry> entries, DateRange range) {
  if (range.isEmpty) return entries;
  return entries.where((e) => range.containsIso(e.date)).toList();
}

/// One month of the combined Purchase & Sale report: every purchase and
/// sale line (newest first) plus that month's purchase/sale totals and net.
class LedgerMonthGroup {
  final String monthKey; // 'yyyy-MM'
  final double purchaseAmount;
  final double saleAmount;
  final List<PartyLedgerEntry> lines;
  const LedgerMonthGroup({
    required this.monthKey,
    required this.purchaseAmount,
    required this.saleAmount,
    required this.lines,
  });

  double get profit => saleAmount - purchaseAmount;
}

/// Purchases and sales merged into one newest-first list, grouped by month.
List<LedgerMonthGroup> groupLedgerByMonth(
  List<Entry> purchases,
  List<Entry> sales,
) {
  final combined = [
    for (final e in purchases) PartyLedgerEntry(e, true),
    for (final e in sales) PartyLedgerEntry(e, false),
  ]..sort(_ledgerNewestFirst);
  final byMonth = <String, List<PartyLedgerEntry>>{};
  for (final line in combined) {
    byMonth.putIfAbsent(line.entry.date.substring(0, 7), () => []).add(line);
  }
  return [
    for (final month in byMonth.entries)
      LedgerMonthGroup(
        monthKey: month.key,
        purchaseAmount: month.value
            .where((l) => l.isPurchase)
            .fold<double>(0, (sum, l) => sum + l.entry.amount),
        saleAmount: month.value
            .where((l) => !l.isPurchase)
            .fold<double>(0, (sum, l) => sum + l.entry.amount),
        lines: month.value,
      ),
  ];
}

/// Every purchase and sale that used one vehicle (newest first) with that
/// vehicle's totals — one section of the vehicle report. A null
/// [vehicleNo] holds the entries recorded without a vehicle.
class VehicleGroup {
  final String? vehicleNo;
  final List<PartyLedgerEntry> lines;
  const VehicleGroup(this.vehicleNo, this.lines);

  double _sum(
    bool Function(PartyLedgerEntry) test,
    double Function(Entry) of,
  ) => lines.where(test).fold<double>(0, (sum, l) => sum + of(l.entry));

  /// Trips made — each entry is `round` trips of `cftPerVehicle`.
  double get rounds => _sum((l) => true, (e) => e.round);
  double get totalCft => _sum((l) => true, (e) => e.totalCFT);
  double get purchaseAmount => _sum((l) => l.isPurchase, (e) => e.amount);
  double get saleAmount => _sum((l) => !l.isPurchase, (e) => e.amount);
}

/// Purchases and sales grouped by vehicle number: vehicles A–Z, entries with
/// no vehicle last. Numbers are compared trimmed and upper-case.
List<VehicleGroup> groupLedgerByVehicle(
  List<Entry> purchases,
  List<Entry> sales,
) {
  final combined = [
    for (final e in purchases) PartyLedgerEntry(e, true),
    for (final e in sales) PartyLedgerEntry(e, false),
  ]..sort(_ledgerNewestFirst);
  final byVehicle = <String?, List<PartyLedgerEntry>>{};
  for (final line in combined) {
    byVehicle
        .putIfAbsent(normalizeVehicleNo(line.entry.vehicleNo), () => [])
        .add(line);
  }
  final numbers = byVehicle.keys.whereType<String>().toList()..sort();
  return [
    for (final n in numbers) VehicleGroup(n, byVehicle[n]!),
    if (byVehicle.containsKey(null)) VehicleGroup(null, byVehicle[null]!),
  ];
}

/// Totals of a list of Debit/Credit entries.
extension MoneyTotals on List<MoneyEntry> {
  double get debit => where(
    (e) => e.type == MoneyType.debit,
  ).fold<double>(0, (sum, e) => sum + e.amount);
  double get credit => where(
    (e) => e.type == MoneyType.credit,
  ).fold<double>(0, (sum, e) => sum + e.amount);
}

/// [items] grouped by calendar month (from the ISO date), most recent month
/// first, newest item first within each month (a later id breaks a same-day
/// tie).
Map<String, List<T>> _groupByMonthNewestFirst<T>(
  List<T> items,
  String Function(T) dateOf,
  int? Function(T) idOf,
) {
  final sorted = [...items]
    ..sort((a, b) {
      final byDate = dateOf(b).compareTo(dateOf(a));
      return byDate != 0 ? byDate : (idOf(b) ?? 0).compareTo(idOf(a) ?? 0);
    });
  final byMonth = <String, List<T>>{};
  for (final item in sorted) {
    byMonth.putIfAbsent(dateOf(item).substring(0, 7), () => []).add(item);
  }
  return byMonth;
}

/// One month of the Debit & Credit report: every entry (newest first).
class MoneyMonthGroup {
  final String monthKey; // 'yyyy-MM'
  final List<MoneyEntry> entries;
  const MoneyMonthGroup(this.monthKey, this.entries);
}

/// Every Debit/Credit entry grouped by calendar month, most recent month
/// first, newest entry first within each month.
List<MoneyMonthGroup> groupMoneyByMonth(List<MoneyEntry> entries) => [
  for (final month in _groupByMonthNewestFirst(
    entries,
    (e) => e.date,
    (e) => e.id,
  ).entries)
    MoneyMonthGroup(month.key, month.value),
];

/// Totals of a list of diesel entries.
extension DieselTotals on List<DieselEntry> {
  double get litres => fold<double>(0, (sum, e) => sum + e.litres);
  double get amount => fold<double>(0, (sum, e) => sum + e.total);
}

/// One month of the Diesel report: every entry (newest first).
class DieselMonthGroup {
  final String monthKey; // 'yyyy-MM'
  final List<DieselEntry> entries;
  const DieselMonthGroup(this.monthKey, this.entries);
}

/// Every diesel entry grouped by calendar month, most recent month first,
/// newest entry first within each month.
List<DieselMonthGroup> groupDieselByMonth(List<DieselEntry> entries) => [
  for (final month in _groupByMonthNewestFirst(
    entries,
    (e) => e.date,
    (e) => e.id,
  ).entries)
    DieselMonthGroup(month.key, month.value),
];

/// What one vehicle used: how many fill-ups, litres, and rupees.
class DieselVehicleTotal {
  final String vehicleNo;
  final int fills;
  final double litres;
  final double amount;
  const DieselVehicleTotal({
    required this.vehicleNo,
    required this.fills,
    required this.litres,
    required this.amount,
  });
}

/// Diesel per vehicle, the biggest user (most litres) first; vehicles with the
/// same litres are in number order.
List<DieselVehicleTotal> dieselByVehicle(List<DieselEntry> entries) {
  final byVehicle = <String, List<DieselEntry>>{};
  for (final e in entries) {
    byVehicle.putIfAbsent(e.vehicleNo, () => []).add(e);
  }
  final totals = [
    for (final v in byVehicle.entries)
      DieselVehicleTotal(
        vehicleNo: v.key,
        fills: v.value.length,
        litres: v.value.litres,
        amount: v.value.amount,
      ),
  ];
  totals.sort((a, b) {
    final byLitres = b.litres.compareTo(a.litres);
    return byLitres != 0 ? byLitres : a.vehicleNo.compareTo(b.vehicleNo);
  });
  return totals;
}
