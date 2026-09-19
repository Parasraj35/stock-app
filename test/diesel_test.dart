import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/reports.dart';
import 'package:stock/data/pdf_export.dart';
import 'package:stock/data/repositories.dart';
import 'package:stock/ui/screens/diesel_form_screen.dart';
import 'package:stock/ui/theme/tokens.dart';
import 'package:stock/ui/widgets/diesel_widgets.dart';

class _FakeDieselRepository implements DieselRepository {
  final saved = <DieselEntry>[];

  @override
  Future<DieselEntry> add(DieselEntry entry) async {
    saved.add(entry);
    return entry;
  }

  @override
  Future<void> update(DieselEntry entry) async => saved.add(entry);

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<DieselEntry>> list() async => saved;
}

const _vehicles = [
  Vehicle(id: 1, vehicleNo: 'TLM-954', cft: 980),
  Vehicle(id: 2, vehicleNo: 'TAB-107', cft: 1050),
];

Future<_FakeDieselRepository> _openForm(
  WidgetTester tester, {
  DieselEntry? existing,
}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = _FakeDieselRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DieselFormScreen(
                    repository: repo,
                    vehicles: _vehicles,
                    existing: existing,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(_field(label)).controller!.text;

Future<void> _fill(
  WidgetTester tester, {
  String vehicle = 'TLM-954',
  String litres = '100',
  String price = '404',
}) async {
  await tester.enterText(_field('VEHICLE NO.'), vehicle);
  await tester.enterText(_field('LITRES'), litres);
  await tester.enterText(_field('PRICE (RS/LITRE)'), price);
}

void main() {
  group('diesel form', () {
    testWidgets('has date, vehicle, litres and price', (tester) async {
      await _openForm(tester);
      expect(find.text('New diesel'), findsOneWidget);
      expect(find.text('DATE'), findsOneWidget);
      expect(_field('VEHICLE NO.'), findsOneWidget);
      expect(_field('LITRES'), findsOneWidget);
      expect(_field('PRICE (RS/LITRE)'), findsOneWidget);
      expect(find.text('SAVE DIESEL'), findsOneWidget);
      expect(find.text('Rs 0'), findsOneWidget); // nothing to total yet
    });

    testWidgets('the total is litres times price, live: 100 x 404 = 40,400', (
      tester,
    ) async {
      await _openForm(tester);
      await tester.enterText(_field('LITRES'), '100');
      await tester.pump();
      expect(find.text('Rs 0'), findsOneWidget); // no price yet

      await tester.enterText(_field('PRICE (RS/LITRE)'), '404');
      await tester.pump();
      expect(find.text('Rs 40,400'), findsOneWidget);
      expect(find.text('100 L × Rs 404'), findsOneWidget);

      // It follows every change.
      await tester.enterText(_field('LITRES'), '50.5');
      await tester.pump();
      expect(find.text('Rs 20,402'), findsOneWidget);
      expect(find.text('50.5 L × Rs 404'), findsOneWidget);
    });

    testWidgets('decimal litres and price work; the total is whole rupees', (
      tester,
    ) async {
      await _openForm(tester);
      await tester.enterText(_field('LITRES'), '45.5');
      await tester.enterText(_field('PRICE (RS/LITRE)'), '404.5');
      await tester.pump();
      expect(find.text('Rs 18,405'), findsOneWidget); // 18,404.75
    });

    testWidgets('litres and price take numbers with two decimals at most', (
      tester,
    ) async {
      await _openForm(tester);
      await tester.enterText(_field('LITRES'), '12');
      await tester.enterText(_field('LITRES'), '12a'); // a letter: ignored
      expect(_text(tester, 'LITRES'), '12');

      await tester.enterText(_field('LITRES'), '12.34');
      await tester.enterText(_field('LITRES'), '12.345'); // a third decimal
      expect(_text(tester, 'LITRES'), '12.34');

      await tester.enterText(_field('PRICE (RS/LITRE)'), '404');
      await tester.enterText(_field('PRICE (RS/LITRE)'), '404..'); // two dots
      expect(_text(tester, 'PRICE (RS/LITRE)'), '404');
    });

    testWidgets('saves the date, vehicle, litres and price', (tester) async {
      final repo = await _openForm(tester);
      await _fill(tester);
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      final e = repo.saved.single;
      expect(e.vehicleNo, 'TLM-954');
      expect(e.litres, 100);
      expect(e.price, 404);
      expect(e.total, 40400);
      final now = DateTime.now();
      expect(
        e.date,
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}',
      );
      expect(find.text('New diesel'), findsNothing); // closed after saving
    });

    testWidgets('tapping the vehicle field lists the saved vehicles', (
      tester,
    ) async {
      final repo = await _openForm(tester);
      await tester.tap(_field('VEHICLE NO.'));
      await tester.pumpAndSettle();
      expect(find.text('TLM-954'), findsOneWidget);
      expect(find.text('TAB-107'), findsOneWidget);
      expect(find.text('980 CFT'), findsOneWidget);

      await tester.tap(find.text('TAB-107'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'VEHICLE NO.'), 'TAB-107');

      await tester.enterText(_field('LITRES'), '60');
      await tester.enterText(_field('PRICE (RS/LITRE)'), '400');
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.vehicleNo, 'TAB-107');
    });

    testWidgets('a typed vehicle is saved trimmed and upper-case', (
      tester,
    ) async {
      final repo = await _openForm(tester);
      await _fill(tester, vehicle: '  tlm-954 ');
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.vehicleNo, 'TLM-954');
    });

    testWidgets('vehicle, litres and price are all required', (tester) async {
      final repo = await _openForm(tester);
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.text('Required'), findsOneWidget); // the vehicle
      expect(find.text('Enter the litres'), findsOneWidget);
      expect(find.text('Enter the price'), findsOneWidget);

      // Blank spaces are not a vehicle; zero is not litres or a price.
      await _fill(tester, vehicle: '   ', litres: '0', price: '0');
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);

      await _fill(tester, litres: '10', price: '0');
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty); // no price

      await _fill(tester, litres: '0', price: '404');
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty); // no litres
    });

    testWidgets('editing opens with the entry and saves it in place', (
      tester,
    ) async {
      final repo = await _openForm(
        tester,
        existing: const DieselEntry(
          id: 5,
          date: '2026-09-18',
          vehicleNo: 'TLM-954',
          litres: 45.5,
          price: 404.5,
        ),
      );
      expect(find.text('Edit diesel'), findsOneWidget);
      expect(find.text('2026-09-18'), findsOneWidget);
      expect(_text(tester, 'VEHICLE NO.'), 'TLM-954');
      expect(_text(tester, 'LITRES'), '45.5');
      expect(_text(tester, 'PRICE (RS/LITRE)'), '404.5');
      expect(find.text('Rs 18,405'), findsOneWidget);

      await tester.enterText(_field('LITRES'), '50');
      await tester.tap(find.text('SAVE DIESEL'));
      await tester.pumpAndSettle();
      final e = repo.saved.single;
      expect(e.id, 5); // updated, not a new one
      expect(e.date, '2026-09-18');
      expect(e.litres, 50);
      expect(e.price, 404.5);
    });
  });

  group('diesel rows', () {
    testWidgets('a row shows vehicle, date, litres x price and the total', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var deleted = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DieselTile(
                  entry: const DieselEntry(
                    id: 1,
                    date: '2026-09-19',
                    vehicleNo: 'TLM-954',
                    litres: 1250.5,
                    price: 404.5,
                  ),
                  onTap: () {},
                  onDelete: () => deleted++,
                ),
                const DieselTile(
                  entry: DieselEntry(
                    id: 2,
                    date: '2026-09-18',
                    vehicleNo: 'A-VERY-LONG-VEHICLE-NUMBER-12345-67890',
                    litres: 100,
                    price: 404,
                  ),
                ),
                const DieselTotalsCard(litres: 1350.5, amount: 546_000),
                const DieselVehicleTile(
                  total: DieselVehicleTotal(
                    vehicleNo: 'TLM-954',
                    fills: 3,
                    litres: 1350.5,
                    amount: 546000,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('TLM-954'), findsNWidgets(2)); // the row + the summary
      expect(find.text('2026-09-19'), findsOneWidget);
      expect(find.text('1,250.5 L × Rs 404.5'), findsOneWidget);
      expect(find.text('Rs 5,05,827'), findsOneWidget); // 505,827.25
      expect(find.text('Rs 40,400'), findsOneWidget);
      expect(find.text('3 fill-ups'), findsOneWidget);
      expect(find.text('1,350.5 L'), findsNWidgets(2)); // the card + the tile
      // Only the editable row has a delete button; the report rows are
      // read-only.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, 1);
    });
  });

  test('the Diesel PDF builds, with and without a per-vehicle summary', () async {
    final entries = [
      for (var i = 0; i < 400; i++)
        DieselEntry(
          id: i,
          date:
              '2026-0${(i % 9) + 1}-${(i % 27 + 1).toString().padLeft(2, '0')}',
          vehicleNo: 'TLM-95${i % 5}',
          litres: 40.0 + (i % 7) + 0.5,
          price: 404,
        ),
    ];
    for (final subset in [entries, entries.where((e) => e.id == 3).toList()]) {
      final bytes = await buildDieselReportPdf(
        businessName: 'Test Traders',
        title: 'Diesel Report',
        filters: 'All vehicles | All dates',
        groups: groupDieselByMonth(subset),
        byVehicle: dieselByVehicle(subset),
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
    final empty = await buildDieselReportPdf(
      businessName: null,
      title: 'Diesel Report',
      filters: 'All dates',
      groups: const [],
      byVehicle: const [],
    );
    expect(String.fromCharCodes(empty.take(5)), '%PDF-');
  });
}
