import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/calc.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/password.dart';

void main() {
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

    test('profit can be negative', () {
      expect(calcProfit(1000, 1500), -500);
      expect(calcProfit(2000, 1500), 500);
    });

    test('realized profit is 0 with no sales, however much was purchased', () {
      final brands = [Brand(id: 1, name: 'Crush', purchaseRate: 30, saleRate: 50)];
      // Purchases don't feed calcRealizedProfit at all — buying stock is
      // an investment, not a loss, so it never drags this figure negative.
      expect(calcRealizedProfit(<Entry>[], brands), 0);
    });

    test('realized profit is margin on what was actually sold', () {
      final brands = [Brand(id: 1, name: 'Crush', purchaseRate: 30, saleRate: 50)];
      final sales = [
        Entry(
          date: '2026-01-02',
          party: 'P',
          brandId: 1,
          brandName: 'Crush',
          cftPerVehicle: 100,
          round: 2,
          totalCFT: 200,
          amount: 10000, // sold at 50/cft
        ),
      ];
      // Margin = amount - (purchaseRate * totalCFT) = 10000 - (30*200) = 4000
      expect(calcRealizedProfit(sales, brands), 4000);
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
