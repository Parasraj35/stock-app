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

    test('partyHistory returns only that party, newest first', () {
      final purchases = [
        _entry(id: 1, date: '2026-01-01', party: 'A', amount: 1),
        _entry(id: 2, date: '2026-01-03', party: 'B', amount: 2),
      ];
      final sales = [_entry(id: 1, date: '2026-01-02', party: 'A', amount: 3)];
      final history = partyHistory('A', purchases, sales);
      expect(history.map((l) => l.entry.date), ['2026-01-02', '2026-01-01']);
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
