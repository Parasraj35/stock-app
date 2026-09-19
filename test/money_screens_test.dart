import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/repos.dart';
import 'package:stock/ui/screens/money_report_screen.dart';
import 'package:stock/ui/screens/money_screen.dart';
import 'package:stock/ui/theme/tokens.dart';
import 'package:stock/ui/widgets/report_widgets.dart';

/// Lets real database work finish (widget tests run in fake time), then
/// redraws. Two rounds, because one step can start the next (a delete, then
/// the screen reloading its list).
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
  // Wide enough for the test font (Ahem), which is far wider than real fonts.
  tester.view.physicalSize = const Size(480, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
  await _settle(tester);
}

/// Picks "All / Party / Vehicle" on the report.
Future<void> _showOnly(WidgetTester tester, String who) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('moneyWho')),
      matching: find.text(who),
    ),
  );
  await tester.pumpAndSettle();
}

/// Chooses one name in the report's party / vehicle picker.
Future<void> _pickName(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_money_ui_');
    await databaseFactory.setDatabasesPath(dir.path);
    await Repos.init();
    // Two for parties, two for vehicles — the report shows them together.
    const seed = [
      MoneyEntry(
        date: '2026-09-19',
        party: 'Ali',
        amount: 5000,
        type: MoneyType.debit,
      ),
      MoneyEntry(
        date: '2026-09-20',
        vehicleNo: 'TLM-954',
        amount: 1200,
        type: MoneyType.credit,
      ),
      MoneyEntry(
        date: '2026-08-15',
        party: 'Zubair',
        amount: 800,
        type: MoneyType.debit,
      ),
      MoneyEntry(
        date: '2026-08-16',
        vehicleNo: 'TAB-107',
        amount: 300,
        type: MoneyType.credit,
      ),
    ];
    for (final e in seed) {
      await Repos.instance.money.add(e);
    }
  });

  Finder tiles() => find.byType(MoneyTile);
  Finder inTiles(String text) =>
      find.descendant(of: tiles(), matching: find.text(text));

  group('Debit & Credit report', () {
    testWidgets('lists every entry — parties and vehicles — with the totals', (
      tester,
    ) async {
      await _show(tester, const MoneyReportScreen());

      expect(tiles(), findsNWidgets(4));
      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('Rs 5,800'), findsOneWidget); // total debit
      expect(find.text('Rs 1,500'), findsOneWidget); // total credit
      // Both kinds show up, and each row says which it is for.
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('TLM-954'), findsOneWidget);
      expect(inTiles('Party'), findsNWidgets(2));
      expect(inTiles('Vehicle'), findsNWidgets(2));
      // Read-only rows: nothing to delete on a report.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('can be narrowed to Debit or Credit only', (tester) async {
      await _show(tester, const MoneyReportScreen());

      await tester.tap(find.text('Debit'));
      await tester.pumpAndSettle();
      expect(tiles(), findsNWidgets(2));
      expect(find.text('DEBIT'), findsNWidgets(2));
      expect(find.text('CREDIT'), findsNothing);

      await tester.tap(find.text('Credit'));
      await tester.pumpAndSettle();
      expect(tiles(), findsNWidgets(2));
      expect(find.text('CREDIT'), findsNWidgets(2));
    });

    testWidgets('can show only the entries for parties', (tester) async {
      await _show(tester, const MoneyReportScreen());
      // No picker until Party or Vehicle is chosen.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      await _showOnly(tester, 'Party');
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tiles(), findsNWidgets(2));
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Zubair'), findsOneWidget);
      expect(find.text('TLM-954'), findsNothing);
      expect(find.text('TAB-107'), findsNothing);
    });

    testWidgets('can be narrowed to one party', (tester) async {
      await _show(tester, const MoneyReportScreen());
      await _showOnly(tester, 'Party');
      await _pickName(tester, 'Zubair');

      expect(tiles(), findsOneWidget);
      expect(find.text('Zubair'), findsWidgets);
      expect(find.text('Ali'), findsNothing);
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('SEPTEMBER 2026'), findsNothing);
      // Its debit shows on the row and again in the totals.
      expect(find.text('Rs 800'), findsNWidgets(2));
    });

    testWidgets('can show only the entries for vehicles', (tester) async {
      await _show(tester, const MoneyReportScreen());
      await _showOnly(tester, 'Vehicle');

      expect(tiles(), findsNWidgets(2));
      expect(find.text('TLM-954'), findsOneWidget);
      expect(find.text('TAB-107'), findsOneWidget);
      expect(find.text('Ali'), findsNothing);
      expect(find.text('Zubair'), findsNothing);
    });

    testWidgets('can be narrowed to one vehicle', (tester) async {
      await _show(tester, const MoneyReportScreen());
      await _showOnly(tester, 'Vehicle');
      await _pickName(tester, 'TAB-107');

      expect(tiles(), findsOneWidget);
      expect(find.text('TAB-107'), findsWidgets);
      expect(find.text('TLM-954'), findsNothing);
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('SEPTEMBER 2026'), findsNothing);
      expect(find.text('Rs 300'), findsNWidgets(2));
    });

    testWidgets('the picker offers only that kind, each name once', (
      tester,
    ) async {
      await _show(tester, const MoneyReportScreen());
      await _showOnly(tester, 'Vehicle');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('All vehicles'), findsWidgets);
      // The open menu lists each vehicle once (the row behind it is a second).
      expect(find.text('TLM-954'), findsNWidgets(2));
      expect(find.text('TAB-107'), findsNWidgets(2));
      expect(find.text('Ali'), findsNothing); // parties are not offered here
      expect(find.text('Zubair'), findsNothing);
    });

    testWidgets('switching Party / Vehicle starts again from "All"', (
      tester,
    ) async {
      await _show(tester, const MoneyReportScreen());
      await _showOnly(tester, 'Party');
      await _pickName(tester, 'Zubair');
      expect(tiles(), findsOneWidget);

      await _showOnly(tester, 'Vehicle');
      expect(tiles(), findsNWidgets(2)); // every vehicle entry, not filtered
      await _showOnly(tester, 'All');
      expect(tiles(), findsNWidgets(4));
    });

    testWidgets('a party or vehicle can be combined with Debit / Credit', (
      tester,
    ) async {
      await _show(tester, const MoneyReportScreen());
      await _showOnly(tester, 'Vehicle');
      await tester.tap(find.text('Debit'));
      await tester.pumpAndSettle();
      // Both vehicle entries are credits, so nothing is left.
      expect(tiles(), findsNothing);

      await tester.tap(find.text('Credit'));
      await tester.pumpAndSettle();
      expect(tiles(), findsNWidgets(2));
    });
  });

  group('Debit & Credit list', () {
    testWidgets('shows every entry newest first with both totals', (
      tester,
    ) async {
      await _show(tester, const MoneyScreen());

      expect(tiles(), findsNWidgets(4));
      expect(find.text('Rs 5,800'), findsOneWidget);
      expect(find.text('Rs 1,500'), findsOneWidget);
      // Newest first: the 20th sits above the 19th, above the August ones.
      final order = tester
          .widgetList<MoneyTile>(tiles())
          .map((t) => t.entry.date)
          .toList();
      expect(order, ['2026-09-20', '2026-09-19', '2026-08-16', '2026-08-15']);
    });

    testWidgets('deleting an entry asks first, then removes it', (
      tester,
    ) async {
      await _show(tester, const MoneyScreen());

      // Cancel keeps it.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Delete credit?'), findsOneWidget);
      expect(find.textContaining('TLM-954'), findsWidgets); // says which one
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(tiles(), findsNWidgets(4));

      // Confirming removes the newest (the 1,200 credit) and updates totals.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle(); // the dialog closes, then the delete starts
      await _settle(tester);

      expect(tiles(), findsNWidgets(3));
      // The credit total is now 300 (the 1,200 credit is gone).
      expect(find.text('Rs 1,500'), findsNothing);
      expect(find.text('Rs 300'), findsWidgets);
      final left = await tester.runAsync(() => Repos.instance.money.list());
      expect(left, hasLength(3));
    });
  });
}
