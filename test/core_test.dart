import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/calc.dart';
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
