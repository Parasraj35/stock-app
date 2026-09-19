import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/calc.dart';
import 'package:stock/core/format.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/password.dart';
import 'package:stock/core/reports.dart';
import 'package:stock/core/vehicles.dart';

Entry _entry({
  int? id,
  String date = '2026-01-02',
  String party = 'P',
  int brandId = 1,
  double cftPerVehicle = 100,
  double round = 2,
  String? vehicleNo,
  required double amount,
}) {
  final totalCft = round * cftPerVehicle;
  return Entry(
    id: id,
    date: date,
    party: party,
    brandId: brandId,
    brandName: 'Crush',
    cftPerVehicle: cftPerVehicle,
    round: round,
    vehicleNo: vehicleNo,
    totalCFT: totalCft,
    amount: amount,
  );
}

void main() {
  final brands = [Brand(id: 1, name: 'Crush', purchaseRate: 30, saleRate: 50)];

  group('calc', () {
    test('totalCFT = round × cftPerVehicle', () {
      expect(calcTotalCFT(3, 100), 300);
    });

    test('amount = totalCFT × brandRate', () {
      expect(calcAmount(300, 52), 15600);
    });

    test('calcEntryTotals combines both', () {
      final t = calcEntryTotals(3, 100, 52);
      expect(t.totalCFT, 300);
      expect(t.amount, 15600);
    });

    test('a custom rate changes the total for that entry', () {
      final t = calcEntryTotals(3, 100, 40);
      expect(t.totalCFT, 300);
      expect(t.amount, 12000);
    });

    test('realized profit is 0 with no sales, however much was purchased', () {
      final purchases = [_entry(amount: 6000)];
      // Buying stock is an investment, not a loss, so purchases alone never
      // drag realized profit negative.
      expect(calcRealizedProfit(<Entry>[], purchases, brands), 0);
    });

    test('realized profit is margin on what was actually sold', () {
      final sales = [_entry(amount: 10000)]; // 200 cft sold at 50/cft
      // No purchases yet, so cost falls back to the brand default of 30/cft:
      // 10000 - (30 * 200) = 4000
      expect(calcRealizedProfit(sales, <Entry>[], brands), 4000);
    });

    test('realized profit uses the average price actually paid', () {
      // 100 cft @ 20 and 300 cft @ 40 -> average paid = 14000 / 400 = 35/cft,
      // not the brand default of 30.
      final purchases = [
        _entry(id: 1, round: 1, cftPerVehicle: 100, amount: 2000),
        _entry(id: 2, round: 3, cftPerVehicle: 100, amount: 12000),
      ];
      final sales = [_entry(amount: 10000)]; // 200 cft
      expect(costRateByBrand(purchases, brands)[1], 35);
      // 10000 - (35 * 200) = 3000
      expect(calcRealizedProfit(sales, purchases, brands), 3000);
    });
  });

  group('entry rate', () {
    test('ratePerCft is amount ÷ total cft', () {
      expect(_entry(amount: 8000).ratePerCft, 40);
    });

    test('formatDecimal keeps real decimals and drops empty ones', () {
      expect(formatDecimal(35), '35');
      expect(formatDecimal(32.5), '32.5');
      expect(formatDecimal(34.99999999), '35');
      expect(formatDecimal(12.345), '12.35');
    });
  });

  group('reports', () {
    test('groupEntriesByMonth lists every entry, newest month first', () {
      final entries = [
        _entry(id: 1, date: '2026-01-05', amount: 100),
        _entry(id: 2, date: '2026-02-01', amount: 200),
        _entry(id: 3, date: '2026-01-20', amount: 300),
        _entry(id: 4, date: '2026-01-20', amount: 400),
      ];
      final groups = groupEntriesByMonth(entries);
      expect(groups.map((g) => g.total.monthKey), ['2026-02', '2026-01']);
      // Newest first within the month; same-day entries by newest id.
      expect(groups[1].entries.map((e) => e.id), [4, 3, 1]);
      expect(groups[1].total.count, 3);
      expect(groups[1].total.totalAmount, 800);
      expect(groups.expand((g) => g.entries).length, entries.length);
    });

    test('groupLedgerByMonth keeps every purchase and sale with net', () {
      final purchases = [
        _entry(id: 1, date: '2026-03-02', amount: 1000),
        _entry(id: 2, date: '2026-03-09', amount: 500),
      ];
      final sales = [
        _entry(id: 1, date: '2026-03-05', amount: 2500), // id collides
        _entry(id: 2, date: '2026-04-01', amount: 900),
      ];
      final groups = groupLedgerByMonth(purchases, sales);
      expect(groups.map((g) => g.monthKey), ['2026-04', '2026-03']);
      final march = groups[1];
      expect(march.lines.length, 3);
      expect(march.purchaseAmount, 1500);
      expect(march.saleAmount, 2500);
      expect(march.profit, 1000);
      // Newest first, and purchase/sale kept apart despite the shared id.
      expect(march.lines.map((l) => l.isPurchase), [true, false, true]);
    });
  });

  group('vehicles', () {
    const fleet = [
      Vehicle(vehicleNo: 'TLM-954', cft: 980),
      Vehicle(vehicleNo: 'TAB-107', cft: 1050),
    ];

    test('normalizeVehicleNo trims and upper-cases; blank is null', () {
      expect(normalizeVehicleNo('  tlm-954 '), 'TLM-954');
      expect(normalizeVehicleNo('TLM-954'), 'TLM-954');
      expect(normalizeVehicleNo('   '), isNull);
      expect(normalizeVehicleNo(null), isNull);
    });

    test('vehicleForCft finds the vehicle carrying exactly that CFT', () {
      expect(vehicleForCft(fleet, 980)?.vehicleNo, 'TLM-954');
      expect(vehicleForCft(fleet, 1050)?.vehicleNo, 'TAB-107');
      expect(vehicleForCft(fleet, 981), isNull);
      expect(vehicleForCft(const [], 980), isNull);
    });

    test('groupLedgerByVehicle groups both sides, A-Z, no-vehicle last', () {
      final purchases = [
        _entry(id: 1, vehicleNo: 'tlm-954 ', round: 2, amount: 1000),
        _entry(id: 2, vehicleNo: 'TAB-107', round: 1, amount: 500),
        _entry(id: 3, amount: 100), // no vehicle
      ];
      final sales = [
        _entry(
          id: 1,
          date: '2026-01-09',
          vehicleNo: 'TLM-954',
          round: 3,
          amount: 4000,
        ),
      ];
      final groups = groupLedgerByVehicle(purchases, sales);
      expect(groups.map((g) => g.vehicleNo), ['TAB-107', 'TLM-954', null]);

      final tlm = groups[1];
      expect(tlm.lines.length, 2); // the untidy 'tlm-954 ' joined TLM-954
      expect(tlm.rounds, 5); // 2 purchase + 3 sale rounds
      expect(tlm.totalCft, 500); // 5 rounds x 100 cft
      expect(tlm.purchaseAmount, 1000);
      expect(tlm.saleAmount, 4000);
      // Newest first: the sale on 01-09 comes before the purchase on 01-02.
      expect(tlm.lines.map((l) => l.isPurchase), [false, true]);
    });
  });

  group('debit and credit', () {
    MoneyEntry money(
      int id,
      String date,
      double amount,
      MoneyType type, {
      String? vehicleNo,
    }) => MoneyEntry(
      id: id,
      date: date,
      // For a party unless a vehicle is given.
      party: vehicleNo == null ? 'Ali' : null,
      vehicleNo: vehicleNo,
      amount: amount,
      type: type,
    );

    test('a party entry survives the round trip through the database map', () {
      final e = money(4, '2026-09-19', 2500, MoneyType.credit);
      final back = MoneyEntry.fromMap(e.toMap());
      expect(back.id, 4);
      expect(back.date, '2026-09-19');
      expect(back.target, MoneyTarget.party);
      expect(back.party, 'Ali');
      expect(back.vehicleNo, isNull);
      expect(back.name, 'Ali');
      expect(back.amount, 2500);
      expect(back.type, MoneyType.credit);
    });

    test(
      'a vehicle entry survives the round trip through the database map',
      () {
        final e = money(
          5,
          '2026-09-19',
          900,
          MoneyType.debit,
          vehicleNo: 'TLM-954',
        );
        final back = MoneyEntry.fromMap(e.toMap());
        expect(back.target, MoneyTarget.vehicle);
        expect(back.vehicleNo, 'TLM-954');
        expect(back.party, isNull);
        expect(back.name, 'TLM-954');
        expect(back.type, MoneyType.debit);
      },
    );

    test('an entry is for a party or a vehicle — exactly one', () {
      expect(
        () => MoneyEntry(date: '2026-09-19', amount: 1, type: MoneyType.debit),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => MoneyEntry(
          date: '2026-09-19',
          party: 'Ali',
          vehicleNo: 'TLM-954',
          amount: 1,
          type: MoneyType.debit,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith keeps who it is for, or switches to the one given', () {
      final party = money(1, '2026-09-19', 100, MoneyType.debit);
      expect(party.copyWith(amount: 200).party, 'Ali');
      expect(party.copyWith(amount: 200).vehicleNo, isNull);

      final toVehicle = party.copyWith(vehicleNo: 'TAB-107');
      expect(toVehicle.vehicleNo, 'TAB-107');
      expect(toVehicle.party, isNull);
      expect(toVehicle.id, 1);

      final back = toVehicle.copyWith(party: 'Zubair');
      expect(back.party, 'Zubair');
      expect(back.vehicleNo, isNull);
    });

    test('totals keep debit and credit apart', () {
      final list = [
        money(1, '2026-09-01', 1000, MoneyType.debit),
        money(2, '2026-09-02', 400, MoneyType.credit),
        money(3, '2026-09-03', 250, MoneyType.debit),
      ];
      expect(list.debit, 1250);
      expect(list.credit, 400);
      expect(<MoneyEntry>[].debit, 0);
    });

    test('groupMoneyByMonth lists every entry, newest month first', () {
      final list = [
        money(1, '2026-08-30', 100, MoneyType.debit),
        money(2, '2026-09-02', 200, MoneyType.credit),
        money(3, '2026-09-20', 300, MoneyType.debit),
        money(4, '2026-09-20', 50, MoneyType.credit),
      ];
      final groups = groupMoneyByMonth(list);
      expect(groups.map((g) => g.monthKey), ['2026-09', '2026-08']);
      // Newest first; same-day entries by newest id.
      expect(groups[0].entries.map((e) => e.id), [4, 3, 2]);
      expect(groups[0].entries.debit, 300);
      expect(groups[0].entries.credit, 250);
      expect(groups.expand((g) => g.entries).length, list.length);
    });

    test('a date range includes both of its end dates', () {
      final range = DateRange(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(range.containsIso('2026-09-01'), isTrue);
      expect(range.containsIso('2026-09-30'), isTrue);
      expect(range.containsIso('2026-08-31'), isFalse);
      expect(range.containsIso('2026-10-01'), isFalse);
      expect(const DateRange().containsIso('1999-01-01'), isTrue);
    });
  });

  group('diesel', () {
    DieselEntry diesel(
      int id,
      String date,
      String vehicleNo,
      double litres,
      double price,
    ) => DieselEntry(
      id: id,
      date: date,
      vehicleNo: vehicleNo,
      litres: litres,
      price: price,
    );

    test('the total is litres times price: 100 litres at 404 is 40,400', () {
      expect(diesel(1, '2026-09-19', 'TLM-954', 100, 404).total, 40400);
      expect(DieselEntry.totalFor(100, 404), 40400);
      expect(DieselEntry.totalFor(45.5, 404), 18382);
      expect(DieselEntry.totalFor(0, 404), 0);
    });

    test('an entry total is rounded to whole rupees, so rows add up', () {
      final a = diesel(1, '2026-09-01', 'TLM-954', 37.6, 404.5); // 15209.2
      final b = diesel(2, '2026-09-02', 'TLM-954', 41.2, 404.5); // 16665.4
      expect(a.total, 15209);
      expect(b.total, 16665);
      // The report total is the sum of the rows as printed, not of the
      // unrounded products (which would give 31,875).
      expect([a, b].amount, 15209 + 16665);
    });

    test('a saved entry survives the round trip through the database map', () {
      final e = diesel(7, '2026-09-19', 'TLM-954', 45.5, 404.5);
      final back = DieselEntry.fromMap(e.toMap());
      expect(back.id, 7);
      expect(back.date, '2026-09-19');
      expect(back.vehicleNo, 'TLM-954');
      expect(back.litres, 45.5);
      expect(back.price, 404.5);
      expect(back.total, e.total);
      expect(e.copyWith(litres: 50).litres, 50);
      expect(e.copyWith(litres: 50).price, 404.5);
    });

    test('totals add up litres and rupees', () {
      final list = [
        diesel(1, '2026-09-01', 'TLM-954', 100, 404),
        diesel(2, '2026-09-02', 'TAB-107', 50.5, 404),
      ];
      expect(list.litres, 150.5);
      expect(list.amount, 40400 + 20402);
      expect(<DieselEntry>[].litres, 0);
      expect(<DieselEntry>[].amount, 0);
    });

    test('groupDieselByMonth lists every entry, newest month first', () {
      final list = [
        diesel(1, '2026-08-30', 'TLM-954', 10, 400),
        diesel(2, '2026-09-02', 'TLM-954', 20, 400),
        diesel(3, '2026-09-20', 'TAB-107', 30, 400),
        diesel(4, '2026-09-20', 'TAB-107', 5, 400),
      ];
      final groups = groupDieselByMonth(list);
      expect(groups.map((g) => g.monthKey), ['2026-09', '2026-08']);
      // Newest first; same-day entries by newest id.
      expect(groups[0].entries.map((e) => e.id), [4, 3, 2]);
      expect(groups[0].entries.litres, 55);
      expect(groups.expand((g) => g.entries).length, list.length);
    });

    test('dieselByVehicle adds each vehicle up, biggest user first', () {
      final list = [
        diesel(1, '2026-09-01', 'TAB-107', 50, 400),
        diesel(2, '2026-09-02', 'TLM-954', 100, 404),
        diesel(3, '2026-09-03', 'TLM-954', 60, 400),
        diesel(4, '2026-09-04', 'TKE-994', 50, 400), // ties TAB-107 on litres
      ];
      final totals = dieselByVehicle(list);
      expect(totals.map((t) => t.vehicleNo), ['TLM-954', 'TAB-107', 'TKE-994']);
      expect(totals[0].fills, 2);
      expect(totals[0].litres, 160);
      expect(totals[0].amount, 40400 + 24000);
      expect(totals[1].fills, 1);
      // Every litre and rupee is in exactly one vehicle.
      expect(totals.fold<double>(0, (s, t) => s + t.litres), list.litres);
      expect(totals.fold<double>(0, (s, t) => s + t.amount), list.amount);
      expect(dieselByVehicle(const []), isEmpty);
    });

    test('formatLitres keeps decimals and groups thousands', () {
      expect(formatLitres(100), '100');
      expect(formatLitres(0), '0');
      expect(formatLitres(0.5), '0.5');
      expect(formatLitres(45.5), '45.5');
      expect(formatLitres(45.55), '45.55');
      expect(formatLitres(99.999), '100');
      expect(formatLitres(1234), '1,234');
      expect(formatLitres(12345.5), '12,345.5');
      expect(formatLitres(1234567.25), '12,34,567.25');
    });
  });

  group('password', () {
    test('hash then verify round-trips', () {
      final hash = hashPassword('Passw0rd');
      expect(verifyPassword('Passw0rd', hash), isTrue);
      expect(verifyPassword('wrong', hash), isFalse);
    });

    test('strength rules', () {
      expect(isStrongPassword('Passw0rd'), isTrue);
      expect(isStrongPassword('short1A'), isFalse); // < 8 chars
      expect(isStrongPassword('alllowercase1'), isFalse); // no upper
      expect(isStrongPassword('ALLUPPERCASE1'), isFalse); // no lower
      expect(isStrongPassword('NoDigitsHere'), isFalse); // no digit
    });
  });
}
