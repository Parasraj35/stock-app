import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/repositories.dart';
import 'package:stock/ui/screens/brand_form_screen.dart';
import 'package:stock/ui/screens/entry_form_screen.dart';
import 'package:stock/ui/screens/party_form_screen.dart';
import 'package:stock/ui/screens/vehicle_form_screen.dart';
import 'package:stock/ui/theme/tokens.dart';
import 'package:stock/ui/widgets/report_widgets.dart';

class _FakeEntryRepository implements EntryRepository {
  final saved = <Entry>[];

  @override
  Future<Entry> add(Entry entry) async {
    saved.add(entry);
    return entry;
  }

  @override
  Future<void> update(Entry entry) async => saved.add(entry);

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<Entry>> list() async => saved;
}

const _crush = Brand(id: 1, name: 'Crush', purchaseRate: 35, saleRate: 52);
const _ghera = Brand(id: 2, name: 'Ghera', purchaseRate: 22, saleRate: 39);
const _vehicles = [
  Vehicle(id: 1, vehicleNo: 'TLM-954', cft: 980),
  Vehicle(id: 2, vehicleNo: 'TAB-107', cft: 1050),
];

/// Phone-sized surface (360 wide) so overflow problems show up in tests.
void _phoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  _phoneSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => screen),
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
}

String _text(WidgetTester tester, String label) => tester
    .widget<TextFormField>(find.widgetWithText(TextFormField, label))
    .controller!
    .text;

void main() {
  group('entry form price', () {
    testWidgets('rate starts at the brand default and drives the total', (
      tester,
    ) async {
      final repo = _FakeEntryRepository();
      await _open(
        tester,
        EntryFormScreen(
          title: 'Purchase',
          repository: repo,
          brands: const [_crush, _ghera],
          parties: const [],
          vehicles: _vehicles,
        ),
      );

      expect(_text(tester, 'RATE (RS/CFT)'), '35');
      expect(find.text('Default Rs 35'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'PARTY'),
        'Ali',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CFT / vehicle'),
        '100',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Round'), '3');
      // 100 cft matches no saved vehicle, so the vehicle is typed by hand.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'VEHICLE NO.'),
        'lea-1',
      );
      await tester.pump();
      expect(find.text('Rs 10,500'), findsOneWidget); // 3 x 100 x 35

      // Change the price for this entry only.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'RATE (RS/CFT)'),
        '40',
      );
      await tester.pump();
      expect(find.text('Rs 12,000'), findsOneWidget); // 3 x 100 x 40

      await tester.tap(find.text('SAVE PURCHASE'));
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.totalCFT, 300);
      expect(repo.saved.single.amount, 12000);
      expect(repo.saved.single.ratePerCft, 40);
      expect(repo.saved.single.vehicleNo, 'LEA-1'); // saved in capitals
      // The brand's own default is untouched.
      expect(_crush.purchaseRate, 35);
    });

    testWidgets('picking another brand resets the rate to its default', (
      tester,
    ) async {
      await _open(
        tester,
        EntryFormScreen(
          title: 'Purchase',
          repository: _FakeEntryRepository(),
          brands: const [_crush, _ghera],
          parties: const [],
          vehicles: _vehicles,
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'RATE (RS/CFT)'),
        '99',
      );
      await tester.tap(find.byType(DropdownButtonFormField<Brand>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghera (Rs 22)').last);
      await tester.pumpAndSettle();

      expect(_text(tester, 'RATE (RS/CFT)'), '22');
    });

    testWidgets('editing an entry shows the price it was saved with', (
      tester,
    ) async {
      final existing = Entry(
        id: 7,
        date: '2026-01-10',
        party: 'Ali',
        brandId: 1,
        brandName: 'Crush',
        cftPerVehicle: 100,
        round: 3,
        totalCFT: 300,
        amount: 9000, // 30/cft — differs from the brand's current 35
      );
      // Purchase, not Sale: a Sale form also looks up live stock in the
      // database, which these UI-only tests don't set up. The saved-rate
      // logic is the same for both.
      await _open(
        tester,
        EntryFormScreen(
          title: 'Purchase',
          repository: _FakeEntryRepository(),
          brands: const [_crush, _ghera],
          parties: const [],
          vehicles: _vehicles,
          existing: existing,
        ),
      );
      expect(_text(tester, 'RATE (RS/CFT)'), '30');
    });
  });

  group('full-screen forms', () {
    testWidgets('brand form shows a live margin and no pop-up', (tester) async {
      await _open(tester, const BrandFormScreen());
      expect(find.text('New brand'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'PURCHASE RATE PER CFT (RS)'),
        '30',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'SALE RATE PER CFT (RS)'),
        '52.5',
      );
      await tester.pump();
      expect(find.text('Rs 22.5'), findsOneWidget);
      expect(find.text('SAVE BRAND'), findsOneWidget);
      // Adding a brand has no delete action.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('editing a brand offers delete in the top bar', (tester) async {
      await _open(tester, const BrandFormScreen(existing: _crush));
      expect(find.text('Edit brand'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('party form is a full screen', (tester) async {
      await _open(tester, const PartyFormScreen());
      expect(find.text('New party'), findsOneWidget);
      expect(find.text('SAVE PARTY'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('report rows', () {
    testWidgets('voucher rows fit a narrow phone with long text', (
      tester,
    ) async {
      _phoneSurface(tester);
      final entry = Entry(
        id: 1,
        date: '2026-09-18',
        party: 'A Very Long Party Name Pvt Ltd Of Lahore',
        brandId: 1,
        brandName: 'Retti (Silica) Fine Grade',
        cftPerVehicle: 100.5,
        round: 3,
        vehicleNo: 'LEA-123456-EXTRA',
        totalCFT: 301.5,
        amount: 9798.75,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const MonthHeader(
                  title: 'September 2026',
                  detail: 'Buy Rs 1,00,000  •  Sell Rs 2,00,000',
                  trailing: 'Rs 1,00,000',
                ),
                VoucherTile(entry: entry, isPurchase: true, showType: true),
                VoucherTile(entry: entry, isPurchase: false),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('100.5'), findsWidgets);
      expect(find.textContaining('Rs 32.5/cft'), findsWidgets);
    });
  });

  group('vehicle on purchase/sale', () {
    Future<_FakeEntryRepository> openForm(
      WidgetTester tester, {
      Entry? existing,
    }) async {
      final repo = _FakeEntryRepository();
      await _open(
        tester,
        EntryFormScreen(
          title: 'Purchase',
          repository: repo,
          brands: const [_crush, _ghera],
          parties: const [],
          vehicles: _vehicles,
          existing: existing,
        ),
      );
      return repo;
    }

    Future<void> typeCft(WidgetTester tester, String value) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CFT / vehicle'),
        value,
      );
      await tester.pump();
    }

    testWidgets("typing a vehicle's CFT fills in its number", (tester) async {
      await openForm(tester);
      expect(_text(tester, 'VEHICLE NO.'), '');

      await typeCft(tester, '980');
      expect(_text(tester, 'VEHICLE NO.'), 'TLM-954');
      expect(find.text('Auto from CFT'), findsOneWidget);

      await typeCft(tester, '1050');
      expect(_text(tester, 'VEHICLE NO.'), 'TAB-107');
    });

    testWidgets('an auto-filled vehicle clears when the CFT stops matching', (
      tester,
    ) async {
      await openForm(tester);
      await typeCft(tester, '980');
      expect(_text(tester, 'VEHICLE NO.'), 'TLM-954');
      await typeCft(tester, '9800');
      expect(_text(tester, 'VEHICLE NO.'), '');
    });

    testWidgets('a vehicle edited by hand is kept', (tester) async {
      await openForm(tester);
      await typeCft(tester, '980');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'VEHICLE NO.'),
        'X-1',
      );
      await tester.pump();
      expect(_text(tester, 'VEHICLE NO.'), 'X-1');
      expect(find.text('Auto from CFT'), findsNothing);

      // A CFT that matches nothing leaves the hand-typed number alone.
      await typeCft(tester, '9800');
      expect(_text(tester, 'VEHICLE NO.'), 'X-1');
    });

    testWidgets('the vehicle is required to save', (tester) async {
      final repo = await openForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'PARTY'),
        'Ali',
      );
      await typeCft(tester, '100'); // matches no vehicle
      await tester.enterText(find.widgetWithText(TextFormField, 'Round'), '3');
      await tester.tap(find.text('SAVE PURCHASE'));
      await tester.pumpAndSettle();

      expect(repo.saved, isEmpty);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('saving an auto-filled vehicle stores its number', (
      tester,
    ) async {
      final repo = await openForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'PARTY'),
        'Ali',
      );
      await typeCft(tester, '980');
      await tester.enterText(find.widgetWithText(TextFormField, 'Round'), '2');
      await tester.tap(find.text('SAVE PURCHASE'));
      await tester.pumpAndSettle();

      expect(repo.saved.single.vehicleNo, 'TLM-954');
      expect(repo.saved.single.cftPerVehicle, 980);
      expect(repo.saved.single.totalCFT, 1960);
    });

    testWidgets('editing an entry keeps the vehicle it was saved with', (
      tester,
    ) async {
      final existing = Entry(
        id: 3,
        date: '2026-01-10',
        party: 'Ali',
        brandId: 1,
        brandName: 'Crush',
        cftPerVehicle: 980,
        round: 2,
        vehicleNo: 'OLD-1',
        totalCFT: 1960,
        amount: 68600,
      );
      await openForm(tester, existing: existing);
      // 980 matches TLM-954, but opening an old entry must not overwrite it.
      expect(_text(tester, 'VEHICLE NO.'), 'OLD-1');
    });
  });

  group('editing an existing entry', () {
    Entry entry({String? vehicleNo}) => Entry(
      id: 9,
      date: '2026-09-19',
      party: 'Ali',
      brandId: 1,
      brandName: 'Crush',
      cftPerVehicle: 100,
      round: 2,
      vehicleNo: vehicleNo,
      totalCFT: 200,
      amount: 7000,
    );

    Future<_FakeEntryRepository> editDate(
      WidgetTester tester,
      Entry existing,
    ) async {
      final repo = _FakeEntryRepository();
      await _open(
        tester,
        EntryFormScreen(
          title: 'Purchase',
          repository: repo,
          brands: const [_crush, _ghera],
          parties: const [],
          vehicles: _vehicles,
          existing: existing,
        ),
      );
      // Change the date to the 1st, exactly as a user would.
      await tester.tap(find.text('2026-09-19'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('1'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE PURCHASE'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('an entry that has a vehicle saves its new date', (
      tester,
    ) async {
      final repo = await editDate(tester, entry(vehicleNo: 'LEA-1'));
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.id, 9);
      expect(repo.saved.single.date, '2026-09-01');
    });

    testWidgets('an old entry saved before vehicles existed can still be '
        'edited', (tester) async {
      final repo = await editDate(tester, entry());
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.date, '2026-09-01');
      expect(repo.saved.single.vehicleNo, isNull);
    });
  });

  group('vehicle form', () {
    testWidgets('rejects a CFT another vehicle already carries', (
      tester,
    ) async {
      await _open(tester, const VehicleFormScreen(vehicles: _vehicles));
      expect(find.text('New vehicle'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'VEHICLE NO.'),
        'new-1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CFT CARRIED PER TRIP'),
        '980',
      );
      await tester.tap(find.text('SAVE VEHICLE'));
      await tester.pumpAndSettle();
      expect(find.text('TLM-954 already carries 980 cft'), findsOneWidget);
    });

    testWidgets('rejects a vehicle number that is already added', (
      tester,
    ) async {
      await _open(tester, const VehicleFormScreen(vehicles: _vehicles));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'VEHICLE NO.'),
        ' tlm-954',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CFT CARRIED PER TRIP'),
        '700',
      );
      await tester.tap(find.text('SAVE VEHICLE'));
      await tester.pumpAndSettle();
      expect(find.text('This vehicle is already added'), findsOneWidget);
    });

    testWidgets('editing a vehicle offers delete in the top bar', (
      tester,
    ) async {
      await _open(
        tester,
        VehicleFormScreen(existing: _vehicles[0], vehicles: _vehicles),
      );
      expect(find.text('Edit vehicle'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(_text(tester, 'CFT CARRIED PER TRIP'), '980');
    });
  });
}
