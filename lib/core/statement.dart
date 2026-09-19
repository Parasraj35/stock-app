// Framework-free party statement: every sale, purchase, debit and credit with
// one party, oldest first, with a running balance. No Flutter imports.
import 'format.dart';
import 'models.dart';
import 'reports.dart' show DateRange;

/// Party names are compared without regard to capital letters or extra spaces,
/// so "ali  traders" and "Ali Traders" are the same party.
String normalizePartyName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The four kinds of line in a party's statement.
enum LedgerKind {
  sale,
  purchase,
  debit,
  credit;

  String get label => switch (this) {
    LedgerKind.sale => 'Sale',
    LedgerKind.purchase => 'Purchase',
    LedgerKind.debit => 'Debit',
    LedgerKind.credit => 'Credit',
  };

  /// Sale and Debit (money you gave) raise what the party owes you; Purchase
  /// and Credit (money you got) lower it.
  bool get raisesBalance => this == sale || this == debit;
}

/// One line of a statement, with the balance after it. A positive balance
/// means the party owes you; a negative one means you owe the party.
class StatementLine {
  final LedgerKind kind;
  final String date; // ISO yyyy-MM-dd
  final double amount;
  final Entry? trade; // set for a Sale or Purchase
  final MoneyEntry? money; // set for a Debit or Credit
  final double balance;

  const StatementLine({
    required this.kind,
    required this.date,
    required this.amount,
    this.trade,
    this.money,
    required this.balance,
  });

  /// What this line adds to the balance (negative when it lowers it).
  double get signed => kind.raisesBalance ? amount : -amount;
}

/// A party's statement over a date range: [lines] oldest first, each with its
/// running balance, starting from [opening].
class PartyStatement {
  /// The balance carried in from before the range. Zero when there is no From
  /// date, since nothing comes before the first entry.
  final double opening;

  /// True when a From date was chosen, so the statement starts with a
  /// "balance brought forward" line.
  final bool showsOpening;

  final List<StatementLine> lines;

  const PartyStatement({
    required this.opening,
    required this.showsOpening,
    required this.lines,
  });

  bool get isEmpty => lines.isEmpty;

  /// The balance after the last line (the opening balance when there are none).
  double get closing => lines.isEmpty ? opening : lines.last.balance;

  double _total(LedgerKind kind) => lines
      .where((l) => l.kind == kind)
      .fold<double>(0, (sum, l) => sum + l.amount);

  double get sold => _total(LedgerKind.sale);
  double get purchased => _total(LedgerKind.purchase);
  double get debit => _total(LedgerKind.debit);
  double get credit => _total(LedgerKind.credit);
}

class _Raw {
  const _Raw(
    this.kind,
    this.date,
    this.id,
    this.amount, {
    this.trade,
    this.money,
  });
  final LedgerKind kind;
  final String date;
  final int id;
  final double amount;
  final Entry? trade;
  final MoneyEntry? money;

  double get signed => kind.raisesBalance ? amount : -amount;
}

/// Builds the statement for [partyName]: every sale, purchase, debit and credit
/// with that party inside [range], oldest first.
///
/// The balance is what the party owes you: Sales and Debits add to it,
/// Purchases and Credits lower it. With a From date, everything before it is
/// added up into the opening balance, so the statement carries on from where
/// the earlier entries left off. Debit/Credit entries made for a vehicle
/// belong to no party and never appear here.
PartyStatement buildPartyStatement({
  required String partyName,
  required List<Entry> purchases,
  required List<Entry> sales,
  required List<MoneyEntry> money,
  DateRange range = const DateRange(),
}) {
  final key = normalizePartyName(partyName);
  final all = <_Raw>[
    for (final e in sales)
      if (normalizePartyName(e.party) == key)
        _Raw(LedgerKind.sale, e.date, e.id ?? 0, e.amount, trade: e),
    for (final e in purchases)
      if (normalizePartyName(e.party) == key)
        _Raw(LedgerKind.purchase, e.date, e.id ?? 0, e.amount, trade: e),
    for (final m in money)
      if (m.party != null && normalizePartyName(m.party!) == key)
        _Raw(
          m.type == MoneyType.debit ? LedgerKind.debit : LedgerKind.credit,
          m.date,
          m.id ?? 0,
          m.amount,
          money: m,
        ),
  ];
  // Oldest first. Within a day: the goods (sale, purchase), then the money
  // (debit, credit), each in the order they were entered.
  all.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byKind = a.kind.index.compareTo(b.kind.index);
    return byKind != 0 ? byKind : a.id.compareTo(b.id);
  });

  final from = range.from;
  final opening = from == null
      ? 0.0
      : all
            .where((r) => DateTime.parse(r.date).isBefore(from))
            .fold<double>(0, (sum, r) => sum + r.signed);

  var balance = opening;
  final lines = <StatementLine>[];
  for (final r in all) {
    if (!range.containsIso(r.date)) continue;
    balance += r.signed;
    lines.add(
      StatementLine(
        kind: r.kind,
        date: r.date,
        amount: r.amount,
        trade: r.trade,
        money: r.money,
        balance: balance,
      ),
    );
  }
  return PartyStatement(
    opening: opening,
    showsOpening: from != null,
    lines: lines,
  );
}

/// Every party name that can have a statement: the saved parties, plus any name
/// typed on a purchase, sale, debit or credit that was never saved as a party.
/// Names that differ only in capitals or spaces count once (the saved spelling
/// wins). Sorted A-Z.
List<String> partyNames({
  required List<Party> saved,
  required List<Entry> purchases,
  required List<Entry> sales,
  required List<MoneyEntry> money,
}) {
  final byKey = <String, String>{};
  void add(String? name) {
    if (name == null) return;
    final key = normalizePartyName(name);
    if (key.isNotEmpty) byKey.putIfAbsent(key, () => name.trim());
  }

  for (final p in saved) {
    add(p.name);
  }
  for (final e in purchases) {
    add(e.party);
  }
  for (final e in sales) {
    add(e.party);
  }
  for (final m in money) {
    add(m.party);
  }
  return byKey.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// A balance in plain words: "Owes you Rs 25,000", "You owe Rs 8,000" or
/// "Settled". With [withCurrency] false the "Rs" is left out, for a table
/// column already headed "(Rs)".
String formatBalance(double balance, {bool withCurrency = true}) {
  final rounded = balance.round();
  if (rounded == 0) return 'Settled';
  final amount = withCurrency
      ? formatPkrCurrency(rounded.abs())
      : formatGroupedNumber(rounded.abs());
  return rounded > 0 ? 'Owes you $amount' : 'You owe $amount';
}

/// The same with a name: "Ali owes you Rs 25,000", "You owe Ali Rs 8,000" or
/// "All settled with Ali".
String formatBalanceWith(String name, double balance) {
  final rounded = balance.round();
  if (rounded == 0) return 'All settled with $name';
  final amount = formatPkrCurrency(rounded.abs());
  return rounded > 0 ? '$name owes you $amount' : 'You owe $name $amount';
}
