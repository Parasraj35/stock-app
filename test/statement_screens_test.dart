import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/statement.dart';
import 'package:stock/data/repos.dart';
import 'package:stock/ui/screens/party_statement_screen.dart';
import 'package:stock/ui/screens/vehicle_report_screen.dart';
import 'package:stock/ui/theme/tokens.dart';
import 'package:stock/ui/widgets/report_widgets.dart';
import 'package:stock/ui/widgets/statement_widgets.dart';

/// Lets real database work finish (widget tests run in fake time), then
/// redraws.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    // One frame (not pumpAndSettle: a loading spinner never settles).
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Widget screen) async {
  // Wide and tall enough for the test font (Ahem), far wider than real fonts.
  tester.view.physicalSize = const Size(480, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
  await _settle(tester);
}

Entry _trade({
  required String date,
  required String party,
  required double amount,
  String? vehicleNo,
}) => Entry(
  date: date,
  party: party,
  brandId: 1,
  brandName: 'Crush',
  cftPerVehicle: 100,
  round: 5,
  vehicleNo: vehicleNo,
  totalCFT: 500,
  amount: amount,
);

Future<void> _pickParty(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _toggleKind(WidgetTester tester, String kind) async {
  await tester.tap(find.byKey(ValueKey('kind-$kind')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_statement_');
    await databaseFactory.setDatabasesPath(dir.path);
    await Repos.init();
    final r = Repos.instance;

    await r.parties.add(const Party(name: 'Ali Traders'));

    // Ali: Sale 50,000, Purchase 20,000, Credit 10,000, Debit 5,000 — he owes
    // you 25,000. Kamran: only a purchase — you owe him 8,000.
    await r.sales.add(
      _trade(
        date: '2026-09-01',
        party: 'Ali Traders',
        amount: 50000,
        vehicleNo: 'TLM-954',
      ),
    );
    await r.purchases.add(
      _trade(
        date: '2026-09-05',
        party: 'Ali Traders',
        amount: 20000,
        vehicleNo: 'TAB-107',
      ),
    );
    await r.purchases.add(
      _trade(date: '2026-09-06', party: 'Kamran', amount: 8000),
    );

    Future<void> money(
      String date,
      double amount,
      MoneyType type, {
      String? party,
      String? vehicleNo,
    }) => r.money.add(
      MoneyEntry(
        date: date,
        party: party,
        vehicleNo: vehicleNo,
        amount: amount,
        type: type,
      ),
    );
    await money('2026-09-10', 10000, MoneyType.credit, party: 'Ali Traders');
    await money('2026-09-12', 5000, MoneyType.debit, party: 'Ali Traders');
    // A party that was typed on a Debit but never saved as a party.
    await money('2026-09-07', 3000, MoneyType.debit, party: 'Zubair');
    // For vehicles: TLM-954 was given 8,000 and paid back 3,000; TKE-994 has
    // only a Debit and no trips at all.
    await money('2026-09-03', 8000, MoneyType.debit, vehicleNo: 'TLM-954');
    await money('2026-09-20', 3000, MoneyType.credit, vehicleNo: 'TLM-954');
    await money('2026-09-04', 1000, MoneyType.debit, vehicleNo: 'TKE-994');
  });

  Finder tiles() => find.byType(StatementTile);

  group('Party Statement', () {
    testWidgets('offers every party, including one only used on a Debit', (
      tester,
    ) async {
      await _show(tester, const PartyStatementScreen());
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Ali Traders'), findsOneWidget);
      expect(find.text('Kamran'), findsOneWidget); // only on a purchase
      expect(find.text('Zubair'), findsOneWidget); // only on a Debit
    });

    testWidgets('lists sale, purchase, credit and debit with a running '
        'balance', (tester) async {
      await _show(tester, const PartyStatementScreen());
      await _pickParty(tester, 'Ali Traders');

      // The closing balance, in words.
      expect(find.text('Ali Traders owes you Rs 25,000'), findsOneWidget);
      // Every kind, oldest first.
      expect(tiles(), findsNWidgets(4));
      final lines = tester
          .widgetList<StatementTile>(tiles())
          .map((t) => t.line)
          .toList();
      expect(lines.map((l) => l.kind), [
        LedgerKind.sale,
        LedgerKind.purchase,
        LedgerKind.credit,
        LedgerKind.debit,
      ]);
      expect(lines.map((l) => l.date), [
        '2026-09-01',
        '2026-09-05',
        '2026-09-10',
        '2026-09-12',
      ]);
      // Each row says what the balance was after it.
      expect(find.text('Balance: Owes you Rs 50,000'), findsOneWidget);
      expect(find.text('Balance: Owes you Rs 30,000'), findsOneWidget);
      expect(find.text('Balance: Owes you Rs 20,000'), findsOneWidget);
      expect(find.text('Balance: Owes you Rs 25,000'), findsOneWidget);
      // And what kind of line it is.
      expect(find.text('SALE'), findsOneWidget);
      expect(find.text('PURCHASE'), findsOneWidget);
      expect(find.text('CREDIT'), findsOneWidget);
      expect(find.text('DEBIT'), findsOneWidget);
      expect(find.text('Money given'), findsOneWidget); // the Debit
      expect(find.text('Money received'), findsOneWidget); // the Credit
    });

    testWidgets('a party you owe shows what you owe', (tester) async {
      await _show(tester, const PartyStatementScreen());
      await _pickParty(tester, 'Kamran');

      expect(find.text('You owe Kamran Rs 8,000'), findsOneWidget);
      expect(tiles(), findsOneWidget);
      expect(find.text('Balance: You owe Rs 8,000'), findsOneWidget);
    });

    testWidgets('a party that only has Debit/Credit has a statement too', (
      tester,
    ) async {
      await _show(tester, const PartyStatementScreen());
      await _pickParty(tester, 'Zubair');

      expect(find.text('Zubair owes you Rs 3,000'), findsOneWidget);
      expect(tiles(), findsOneWidget);
      // The Debit/Credit made for vehicles is not part of any party.
      expect(find.text('Rs 8,000'), findsNothing);
    });

    testWidgets('explains how the balance works', (tester) async {
      await _show(tester, const PartyStatementScreen());
      await _pickParty(tester, 'Ali Traders');
      expect(
        find.text(
          'Sale and Debit raise what the party owes you; '
          'Purchase and Credit lower it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has nothing until a party is chosen', (tester) async {
      await _show(tester, const PartyStatementScreen());
      expect(tiles(), findsNothing);
      expect(find.byType(BalanceCard), findsNothing);
    });
  });

  group('Vehicle Report', () {
    Finder moneyTiles() => find.byType(MoneyTile);
    Finder trips() => find.byType(VoucherTile);

    testWidgets('shows each vehicle\'s trips and its Debit and Credit', (
      tester,
    ) async {
      await _show(tester, const VehicleReportScreen());

      // Three trips (Ali's sale and purchase, Kamran's purchase with no
      // vehicle), and the three Debit/Credit made for vehicles — not the ones
      // made for parties.
      expect(trips(), findsNWidgets(3));
      expect(moneyTiles(), findsNWidgets(3));
      // TLM-954 and TKE-994 each get a Debit & Credit block.
      expect(find.text('DEBIT & CREDIT'), findsNWidgets(2));
      // TKE-994 has no trips, only money — it still has its section.
      expect(
        find.descendant(
          of: find.byType(MonthHeader),
          matching: find.text('TKE-994'),
        ),
        findsOneWidget,
      );
      expect(find.text('No trips'), findsOneWidget);
      expect(find.text('NO VEHICLE'), findsOneWidget); // Kamran's purchase
    });

    testWidgets('gives each vehicle its balance: Debit minus Credit', (
      tester,
    ) async {
      await _show(tester, const VehicleReportScreen());

      expect(
        find.text('Balance: TLM-954 owes you Rs 5,000'),
        findsOneWidget,
      ); // 8,000 given - 3,000 back
      expect(find.text('Balance: TKE-994 owes you Rs 1,000'), findsOneWidget);
      // And all of them together: 9,000 given - 3,000 back.
      expect(
        find.text('Debit & Credit balance: Owes you Rs 6,000'),
        findsOneWidget,
      );
    });

    testWidgets('a vehicle owed money says so', (tester) async {
      await _show(
        tester,
        const VehicleReportScreen(initialVehicleNo: 'TLM-954'),
      );
      // Only TLM-954: Debit 8,000, Credit 3,000.
      expect(moneyTiles(), findsNWidgets(2));
      expect(find.text('Rs 8,000'), findsWidgets);
    });

    testWidgets('a Debit/Credit tile in a vehicle section skips the Party/'
        'Vehicle label', (tester) async {
      await _show(tester, const VehicleReportScreen());
      expect(find.text('Vehicle'), findsNothing);
      expect(find.text('Party'), findsNothing);
    });

    testWidgets('Debit and Credit can be left out of the report', (
      tester,
    ) async {
      await _show(tester, const VehicleReportScreen());
      await _toggleKind(tester, 'debit');
      await _toggleKind(tester, 'credit');

      expect(moneyTiles(), findsNothing);
      expect(find.text('DEBIT & CREDIT'), findsNothing);
      expect(trips(), findsNWidgets(3));
      // TKE-994 had only money, so it drops out with it.
      expect(find.text('TKE-994'), findsNothing);
      expect(find.textContaining('Balance:'), findsNothing);
    });

    testWidgets('trips can be left out, leaving only the money', (
      tester,
    ) async {
      await _show(tester, const VehicleReportScreen());
      await _toggleKind(tester, 'purchase');
      await _toggleKind(tester, 'sale');

      expect(trips(), findsNothing);
      expect(moneyTiles(), findsNWidgets(3));
      expect(find.text('TAB-107'), findsNothing); // it had only a trip
      expect(find.text('NO VEHICLE'), findsNothing);
    });

    testWidgets('with only Debit in, there is no balance (half the picture)', (
      tester,
    ) async {
      await _show(tester, const VehicleReportScreen());
      await _toggleKind(tester, 'credit');

      expect(moneyTiles(), findsNWidgets(2)); // the two Debits
      expect(find.textContaining('Balance:'), findsNothing);
      expect(find.textContaining('Debit & Credit balance'), findsNothing);
    });

    testWidgets('one kind always stays on', (tester) async {
      await _show(tester, const VehicleReportScreen());
      await _toggleKind(tester, 'purchase');
      await _toggleKind(tester, 'sale');
      await _toggleKind(tester, 'debit');
      // Only Credit is left; turning it off is ignored.
      await _toggleKind(tester, 'credit');

      final credit = tester.widget<FilterChip>(
        find.byKey(const ValueKey('kind-credit')),
      );
      expect(credit.selected, isTrue);
      expect(moneyTiles(), findsOneWidget); // TLM-954's Credit
    });

    testWidgets('a vehicle with only money opens with just its money', (
      tester,
    ) async {
      await _show(
        tester,
        const VehicleReportScreen(initialVehicleNo: 'TKE-994'),
      );
      expect(trips(), findsNothing);
      expect(moneyTiles(), findsOneWidget);
      expect(find.text('No trips'), findsOneWidget);
      expect(find.text('Balance: TKE-994 owes you Rs 1,000'), findsOneWidget);
    });
  });
}
