import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/reports.dart';
import 'package:stock/core/statement.dart';

Entry _trade({
  required int id,
  required String date,
  required double amount,
  String party = 'Ali Traders',
  String? vehicleNo,
  double round = 5,
  double cft = 100,
}) => Entry(
  id: id,
  date: date,
  party: party,
  brandId: 1,
  brandName: 'Crush',
  cftPerVehicle: cft,
  round: round,
  vehicleNo: vehicleNo,
  totalCFT: round * cft,
  amount: amount,
);

MoneyEntry _money({
  required int id,
  required String date,
  required double amount,
  required MoneyType type,
  String? party,
  String? vehicleNo,
}) => MoneyEntry(
  id: id,
  date: date,
  party: party,
  vehicleNo: vehicleNo,
  amount: amount,
  type: type,
);

void main() {
  group('party statement', () {
    // The example from the plan: Ali.
    final sales = [_trade(id: 1, date: '2026-09-01', amount: 50000)];
    final purchases = [_trade(id: 1, date: '2026-09-05', amount: 20000)];
    final money = [
      _money(
        id: 1,
        date: '2026-09-10',
        amount: 10000,
        type: MoneyType.credit,
        party: 'Ali Traders',
      ),
      _money(
        id: 2,
        date: '2026-09-12',
        amount: 5000,
        type: MoneyType.debit,
        party: 'Ali Traders',
      ),
    ];

    test('adds up like a ledger: Sale and Debit raise it, Purchase and Credit '
        'lower it', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: purchases,
        sales: sales,
        money: money,
      );
      expect(s.lines.map((l) => l.kind), [
        LedgerKind.sale,
        LedgerKind.purchase,
        LedgerKind.credit,
        LedgerKind.debit,
      ]);
      // Oldest first, with the balance after each line.
      expect(s.lines.map((l) => l.date), [
        '2026-09-01',
        '2026-09-05',
        '2026-09-10',
        '2026-09-12',
      ]);
      expect(s.lines.map((l) => l.balance), [50000, 30000, 20000, 25000]);
      expect(s.closing, 25000);
      expect(s.opening, 0);
      expect(s.showsOpening, isFalse);
      expect(s.sold, 50000);
      expect(s.purchased, 20000);
      expect(s.debit, 5000);
      expect(s.credit, 10000);
      expect(
        formatBalanceWith('Ali Traders', s.closing),
        'Ali Traders owes you Rs 25,000',
      );
    });

    test('each line carries its own trade or money entry', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: purchases,
        sales: sales,
        money: money,
      );
      expect(s.lines[0].trade?.amount, 50000);
      expect(s.lines[0].money, isNull);
      expect(s.lines[2].money?.amount, 10000);
      expect(s.lines[2].trade, isNull);
    });

    test('when the party is owed, the balance goes below zero', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: [_trade(id: 1, date: '2026-09-05', amount: 8000)],
        sales: const [],
        money: const [],
      );
      expect(s.closing, -8000);
      expect(
        formatBalanceWith('Ali Traders', s.closing),
        'You owe Ali Traders Rs 8,000',
      );
    });

    test('a payment can settle it exactly', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: const [],
        sales: [_trade(id: 1, date: '2026-09-01', amount: 12000)],
        money: [
          _money(
            id: 1,
            date: '2026-09-02',
            amount: 12000,
            type: MoneyType.credit,
            party: 'Ali Traders',
          ),
        ],
      );
      expect(s.closing, 0);
      expect(
        formatBalanceWith('Ali Traders', s.closing),
        'All settled with Ali Traders',
      );
    });

    test('names match without regard to capitals or extra spaces', () {
      final s = buildPartyStatement(
        partyName: 'ali  TRADERS ',
        purchases: [
          _trade(
            id: 1,
            date: '2026-09-05',
            amount: 20000,
            party: 'ALI traders',
          ),
        ],
        sales: [
          _trade(
            id: 1,
            date: '2026-09-01',
            amount: 50000,
            party: ' Ali Traders',
          ),
        ],
        money: [
          _money(
            id: 1,
            date: '2026-09-10',
            amount: 10000,
            type: MoneyType.credit,
            party: 'ali traders',
          ),
        ],
      );
      expect(s.lines, hasLength(3));
      expect(s.closing, 20000);
      expect(normalizePartyName('  Ali   TRADERS '), 'ali traders');
    });

    test('other parties, and entries made for a vehicle, are left out', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: [
          _trade(id: 1, date: '2026-09-05', amount: 999, party: 'Kamran'),
        ],
        sales: [
          _trade(id: 1, date: '2026-09-01', amount: 50000),
          _trade(
            id: 2,
            date: '2026-09-02',
            amount: 888,
            party: 'Ali Traders Ltd',
          ),
        ],
        money: [
          _money(
            id: 1,
            date: '2026-09-10',
            amount: 777,
            type: MoneyType.debit,
            party: 'Kamran',
          ),
          // For a vehicle, so it belongs to no party.
          _money(
            id: 2,
            date: '2026-09-11',
            amount: 666,
            type: MoneyType.credit,
            vehicleNo: 'TLM-954',
          ),
        ],
      );
      expect(s.lines, hasLength(1));
      expect(s.closing, 50000);
    });

    test('a From date carries the earlier balance forward', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        sales: [
          _trade(id: 1, date: '2026-08-15', amount: 100000), // before
          _trade(id: 2, date: '2026-09-01', amount: 50000),
        ],
        purchases: const [],
        money: [
          _money(
            id: 1,
            date: '2026-08-20',
            amount: 40000,
            type: MoneyType.credit,
            party: 'Ali Traders',
          ), // before
          _money(
            id: 2,
            date: '2026-09-10',
            amount: 10000,
            type: MoneyType.credit,
            party: 'Ali Traders',
          ),
        ],
        range: DateRange(from: DateTime(2026, 9, 1)),
      );
      expect(s.showsOpening, isTrue);
      expect(s.opening, 60000); // 100,000 - 40,000
      expect(s.lines.map((l) => l.date), ['2026-09-01', '2026-09-10']);
      expect(s.lines.map((l) => l.balance), [110000, 100000]);
      expect(s.closing, 100000);
      // The totals cover only what is inside the range.
      expect(s.sold, 50000);
      expect(s.credit, 10000);
    });

    test('a From date on the very first day carries nothing forward', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: purchases,
        sales: sales,
        money: money,
        range: DateRange(from: DateTime(2026, 9, 1)),
      );
      expect(s.showsOpening, isTrue);
      expect(s.opening, 0);
      expect(s.closing, 25000);
    });

    test('a To date stops the statement there', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: purchases,
        sales: sales,
        money: money,
        range: DateRange(to: DateTime(2026, 9, 10)),
      );
      expect(s.lines.map((l) => l.kind), [
        LedgerKind.sale,
        LedgerKind.purchase,
        LedgerKind.credit,
      ]);
      expect(s.closing, 20000);
    });

    test('a range with no entries still knows the balance before it', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: purchases,
        sales: sales,
        money: money,
        range: DateRange(from: DateTime(2026, 10, 1)),
      );
      expect(s.isEmpty, isTrue);
      expect(s.opening, 25000);
      expect(s.closing, 25000);
    });

    test('on the same day: goods first, then money, each in entry order', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: [_trade(id: 1, date: '2026-09-01', amount: 100)],
        sales: [
          _trade(id: 2, date: '2026-09-01', amount: 300),
          _trade(id: 1, date: '2026-09-01', amount: 200),
        ],
        money: [
          _money(
            id: 5,
            date: '2026-09-01',
            amount: 50,
            type: MoneyType.credit,
            party: 'Ali Traders',
          ),
          _money(
            id: 4,
            date: '2026-09-01',
            amount: 40,
            type: MoneyType.debit,
            party: 'Ali Traders',
          ),
        ],
      );
      expect(s.lines.map((l) => (l.kind, l.amount)), [
        (LedgerKind.sale, 200),
        (LedgerKind.sale, 300),
        (LedgerKind.purchase, 100),
        (LedgerKind.debit, 40),
        (LedgerKind.credit, 50),
      ]);
    });

    test('every balance is the one before it plus this line', () {
      final s = buildPartyStatement(
        partyName: 'Ali Traders',
        purchases: purchases,
        sales: sales,
        money: money,
      );
      var running = s.opening;
      for (final l in s.lines) {
        running += l.signed;
        expect(l.balance, running);
      }
    });

    test('a party with nothing has an empty, settled statement', () {
      final s = buildPartyStatement(
        partyName: 'Nobody',
        purchases: purchases,
        sales: sales,
        money: money,
      );
      expect(s.isEmpty, isTrue);
      expect(s.closing, 0);
    });
  });

  group('balance in words', () {
    test('says who owes whom', () {
      expect(formatBalance(25000), 'Owes you Rs 25,000');
      expect(formatBalance(-8000), 'You owe Rs 8,000');
      expect(formatBalance(0), 'Settled');
      expect(formatBalance(1234567), 'Owes you Rs 12,34,567');
    });

    test('leaves out the Rs for a table column', () {
      expect(formatBalance(25000, withCurrency: false), 'Owes you 25,000');
      expect(formatBalance(-8000, withCurrency: false), 'You owe 8,000');
      expect(formatBalance(0, withCurrency: false), 'Settled');
    });

    test('a fraction of a rupee counts as settled, as it prints', () {
      expect(formatBalance(0.4), 'Settled');
      expect(formatBalance(-0.4), 'Settled');
      expect(formatBalance(0.6), 'Owes you Rs 1');
    });

    test('with a name', () {
      expect(formatBalanceWith('Ali', 25000), 'Ali owes you Rs 25,000');
      expect(formatBalanceWith('Ali', -8000), 'You owe Ali Rs 8,000');
      expect(formatBalanceWith('Ali', 0), 'All settled with Ali');
    });
  });

  group('party names for the picker', () {
    test('saved parties plus any name that only appears on an entry', () {
      final names = partyNames(
        saved: const [Party(id: 1, name: 'Ali Traders')],
        purchases: [
          _trade(id: 1, date: '2026-09-01', amount: 1, party: 'Kamran'),
        ],
        sales: const [],
        money: [
          _money(
            id: 1,
            date: '2026-09-01',
            amount: 1,
            type: MoneyType.debit,
            party: 'Zubair',
          ),
          // For a vehicle: no party name to offer.
          _money(
            id: 2,
            date: '2026-09-01',
            amount: 1,
            type: MoneyType.debit,
            vehicleNo: 'TLM-954',
          ),
        ],
      );
      expect(names, ['Ali Traders', 'Kamran', 'Zubair']);
    });

    test('the same party spelled differently is offered once, as saved', () {
      final names = partyNames(
        saved: const [Party(id: 1, name: 'Ali Traders')],
        purchases: [
          _trade(id: 1, date: '2026-09-01', amount: 1, party: 'ali traders'),
        ],
        sales: [
          _trade(id: 1, date: '2026-09-01', amount: 1, party: 'ALI  TRADERS'),
        ],
        money: [
          _money(
            id: 1,
            date: '2026-09-01',
            amount: 1,
            type: MoneyType.credit,
            party: ' Ali Traders ',
          ),
        ],
      );
      expect(names, ['Ali Traders']);
    });

    test('sorted A-Z ignoring capitals, and blank names are skipped', () {
      final names = partyNames(
        saved: const [
          Party(id: 1, name: 'zubair'),
          Party(id: 2, name: 'Ali'),
          Party(id: 3, name: '  '),
        ],
        purchases: const [],
        sales: const [],
        money: const [],
      );
      expect(names, ['Ali', 'zubair']);
    });
  });

  group('vehicle Debit/Credit', () {
    final trips = [
      _trade(id: 1, date: '2026-09-01', amount: 1000, vehicleNo: 'TLM-954'),
      _trade(id: 2, date: '2026-09-02', amount: 500, vehicleNo: 'TAB-107'),
    ];
    final money = [
      _money(
        id: 1,
        date: '2026-09-03',
        amount: 8000,
        type: MoneyType.debit,
        vehicleNo: 'TLM-954',
      ),
      _money(
        id: 2,
        date: '2026-09-20',
        amount: 3000,
        type: MoneyType.credit,
        vehicleNo: 'tlm-954 ', // untidy, still the same vehicle
      ),
      // Only money, no trips.
      _money(
        id: 3,
        date: '2026-09-04',
        amount: 1000,
        type: MoneyType.debit,
        vehicleNo: 'TKE-994',
      ),
      // For a party: belongs in that party's statement, not here.
      _money(
        id: 4,
        date: '2026-09-05',
        amount: 777,
        type: MoneyType.debit,
        party: 'Ali Traders',
      ),
    ];

    test('a vehicle section holds its trips and its Debit/Credit', () {
      final groups = groupLedgerByVehicle(trips, const [], money);
      // A-Z, and a vehicle with only money still gets a section.
      expect(groups.map((g) => g.vehicleNo), ['TAB-107', 'TKE-994', 'TLM-954']);

      final tlm = groups[2];
      expect(tlm.lines, hasLength(1));
      expect(tlm.money, hasLength(2));
      // Newest first.
      expect(tlm.money.map((m) => m.date), ['2026-09-20', '2026-09-03']);
      expect(tlm.debit, 8000);
      expect(tlm.credit, 3000);
      expect(tlm.balance, 5000); // Debit - Credit: it owes you
    });

    test(
      'trips do not change the balance, and money does not change trips',
      () {
        final withMoney = groupLedgerByVehicle(trips, const [], money);
        final tripsOnly = groupLedgerByVehicle(trips, const []);
        final a = withMoney.firstWhere((g) => g.vehicleNo == 'TLM-954');
        final b = tripsOnly.firstWhere((g) => g.vehicleNo == 'TLM-954');
        expect(a.rounds, b.rounds);
        expect(a.totalCft, b.totalCft);
        expect(a.purchaseAmount, b.purchaseAmount);
        // A vehicle with trips but no Debit/Credit: nothing owed either way.
        final tab = withMoney.firstWhere((g) => g.vehicleNo == 'TAB-107');
        expect(tab.money, isEmpty);
        expect(tab.balance, 0);
      },
    );

    test('a vehicle with only money has no trips and a balance', () {
      final tke = groupLedgerByVehicle(
        trips,
        const [],
        money,
      ).firstWhere((g) => g.vehicleNo == 'TKE-994');
      expect(tke.lines, isEmpty);
      expect(tke.rounds, 0);
      expect(tke.debit, 1000);
      expect(tke.balance, 1000);
    });

    test('when it has paid back more than it was given, you owe it', () {
      final g = groupLedgerByVehicle(const [], const [], [
        _money(
          id: 1,
          date: '2026-09-03',
          amount: 1000,
          type: MoneyType.debit,
          vehicleNo: 'TLM-954',
        ),
        _money(
          id: 2,
          date: '2026-09-04',
          amount: 3500,
          type: MoneyType.credit,
          vehicleNo: 'TLM-954',
        ),
      ]).single;
      expect(g.balance, -2500);
    });

    test(
      'trips with no vehicle stay last, and the old two-argument call works',
      () {
        final groups = groupLedgerByVehicle([
          _trade(id: 1, date: '2026-09-01', amount: 1),
          _trade(id: 2, date: '2026-09-01', amount: 2, vehicleNo: 'TLM-954'),
        ], const []);
        expect(groups.map((g) => g.vehicleNo), ['TLM-954', null]);
        expect(groups.every((g) => g.money.isEmpty), isTrue);
      },
    );
  });
}
