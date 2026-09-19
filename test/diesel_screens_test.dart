import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/repos.dart';
import 'package:stock/ui/screens/diesel_report_screen.dart';
import 'package:stock/ui/screens/diesel_screen.dart';
import 'package:stock/ui/theme/tokens.dart';
import 'package:stock/ui/widgets/diesel_widgets.dart';

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

/// Chooses one vehicle in the report's picker.
Future<void> _pickVehicle(WidgetTester tester, String vehicleNo) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(vehicleNo).last);
  await tester.pumpAndSettle();
}

Future<void> _showView(WidgetTester tester, String view) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('dieselView')),
      matching: find.text(view),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_diesel_ui_');
    await databaseFactory.setDatabasesPath(dir.path);
    await Repos.init();
    // 360.5 litres and Rs 1,44,802 in all: TLM-954 300 L, TAB-107 50.5 L,
    // TKE-994 10 L.
    const seed = [
      DieselEntry(
        date: '2026-09-19',
        vehicleNo: 'TLM-954',
        litres: 100,
        price: 404, // 40,400
      ),
      DieselEntry(
        date: '2026-09-20',
        vehicleNo: 'TAB-107',
        litres: 50.5,
        price: 404, // 20,402
      ),
      DieselEntry(
        date: '2026-08-15',
        vehicleNo: 'TLM-954',
        litres: 200,
        price: 400, // 80,000
      ),
      DieselEntry(
        date: '2026-08-16',
        vehicleNo: 'TKE-994',
        litres: 10,
        price: 400, // 4,000
      ),
    ];
    for (final e in seed) {
      await Repos.instance.diesel.add(e);
    }
  });

  Finder tiles() => find.byType(DieselTile);
  Finder vehicleTiles() => find.byType(DieselVehicleTile);

  group('Diesel report', () {
    testWidgets(
      'lists every entry month by month, with the totals at the top',
      (tester) async {
        await _show(tester, const DieselReportScreen());

        expect(tiles(), findsNWidgets(4));
        expect(find.text('SEPTEMBER 2026'), findsOneWidget);
        expect(find.text('AUGUST 2026'), findsOneWidget);
        // Total litres and total amount of everything.
        expect(find.text('360.5 L'), findsOneWidget);
        expect(find.text('Rs 1,44,802'), findsOneWidget);
        // Each entry: date, litres x price, and its own total.
        expect(find.text('2026-09-19'), findsOneWidget);
        expect(find.text('100 L × Rs 404'), findsOneWidget);
        expect(find.text('Rs 40,400'), findsOneWidget);
        expect(find.text('50.5 L × Rs 404'), findsOneWidget);
        expect(find.text('Rs 20,402'), findsOneWidget);
        // Each month says its own litres and rupees.
        expect(find.textContaining('150.5 L'), findsOneWidget); // September
        expect(find.textContaining('210 L'), findsOneWidget); // August
        // Read-only rows: nothing to delete on a report.
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      },
    );

    testWidgets('can be narrowed to one vehicle', (tester) async {
      await _show(tester, const DieselReportScreen());
      await _pickVehicle(tester, 'TLM-954');

      expect(tiles(), findsNWidgets(2));
      expect(find.text('TAB-107'), findsNothing);
      expect(find.text('TKE-994'), findsNothing);
      // That vehicle's litres and rupees: 100 + 200, 40,400 + 80,000.
      expect(find.text('300 L'), findsOneWidget);
      expect(find.text('Rs 1,20,400'), findsOneWidget);
    });

    testWidgets('the picker lists each vehicle that has diesel, once', (
      tester,
    ) async {
      await _show(tester, const DieselReportScreen());
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('All vehicles'), findsWidgets);
      // The open menu lists each vehicle once (TLM-954 shows on two rows
      // behind it as well).
      expect(find.text('TAB-107'), findsNWidgets(2));
      expect(find.text('TKE-994'), findsNWidgets(2));
      expect(find.text('TLM-954'), findsNWidgets(3));
    });

    testWidgets('By vehicle adds each vehicle up, the biggest user first', (
      tester,
    ) async {
      await _show(tester, const DieselReportScreen());
      await _showView(tester, 'By vehicle');

      expect(tiles(), findsNothing);
      expect(vehicleTiles(), findsNWidgets(3));
      final totals = tester
          .widgetList<DieselVehicleTile>(vehicleTiles())
          .map((t) => t.total)
          .toList();
      expect(totals.map((t) => t.vehicleNo), ['TLM-954', 'TAB-107', 'TKE-994']);
      expect(totals.map((t) => t.litres), [300, 50.5, 10]);
      expect(totals.map((t) => t.fills), [2, 1, 1]);
      expect(totals.map((t) => t.amount), [120400, 20402, 4000]);
      expect(find.text('2 fill-ups'), findsOneWidget);
      expect(find.text('1 fill-up'), findsNWidgets(2));
      // The totals on top are still everything.
      expect(find.text('360.5 L'), findsOneWidget);
      expect(find.text('Rs 1,44,802'), findsOneWidget);

      // And back to the full list.
      await _showView(tester, 'Entries');
      expect(tiles(), findsNWidgets(4));
    });

    testWidgets('By vehicle follows the vehicle chosen', (tester) async {
      await _show(tester, const DieselReportScreen());
      await _pickVehicle(tester, 'TAB-107');
      await _showView(tester, 'By vehicle');

      expect(vehicleTiles(), findsOneWidget);
      expect(find.text('50.5 L'), findsNWidgets(2)); // the card + the vehicle
    });
  });

  group('Diesel list', () {
    testWidgets('shows every entry newest first with the totals', (
      tester,
    ) async {
      await _show(tester, const DieselScreen());

      expect(tiles(), findsNWidgets(4));
      expect(find.text('360.5 L'), findsOneWidget);
      expect(find.text('Rs 1,44,802'), findsOneWidget);
      final order = tester
          .widgetList<DieselTile>(tiles())
          .map((t) => t.entry.date)
          .toList();
      expect(order, ['2026-09-20', '2026-09-19', '2026-08-16', '2026-08-15']);
      // The report is one tap away.
      expect(find.byIcon(Icons.assessment_outlined), findsOneWidget);
    });

    testWidgets('the report button opens the report', (tester) async {
      await _show(tester, const DieselScreen());
      await tester.tap(find.byIcon(Icons.assessment_outlined));
      await _settle(tester);
      expect(find.text('Diesel Report'), findsOneWidget);
      expect(tiles(), findsNWidgets(4));
    });

    testWidgets('deleting an entry asks first, then removes it', (
      tester,
    ) async {
      await _show(tester, const DieselScreen());

      // Cancel keeps it.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Delete diesel entry?'), findsOneWidget);
      expect(find.textContaining('TAB-107'), findsWidgets); // says which one
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(tiles(), findsNWidgets(4));

      // Confirming removes the newest (TAB-107, 50.5 L) and updates the totals.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle(); // the dialog closes, then the delete starts
      await _settle(tester);

      expect(tiles(), findsNWidgets(3));
      expect(find.text('310 L'), findsOneWidget);
      expect(find.text('Rs 1,24,400'), findsOneWidget);
      final left = await tester.runAsync(() => Repos.instance.diesel.list());
      expect(left, hasLength(3));
    });
  });
}
