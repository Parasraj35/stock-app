import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/reports.dart';
import 'package:stock/data/pdf_export.dart';
import 'package:stock/data/repositories.dart';
import 'package:stock/ui/screens/money_form_screen.dart';
import 'package:stock/ui/theme/tokens.dart';
import 'package:stock/ui/widgets/report_widgets.dart';

class _FakeMoneyRepository implements MoneyRepository {
  final saved = <MoneyEntry>[];

  @override
  Future<MoneyEntry> add(MoneyEntry entry) async {
    saved.add(entry);
    return entry;
  }

  @override
  Future<void> update(MoneyEntry entry) async => saved.add(entry);

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<MoneyEntry>> list() async => saved;
}

const _ali = Party(id: 1, name: 'Ali Traders');
const _vehicles = [
  Vehicle(id: 1, vehicleNo: 'TLM-954', cft: 980),
  Vehicle(id: 2, vehicleNo: 'TAB-107', cft: 1050),
];

Future<_FakeMoneyRepository> _openForm(
  WidgetTester tester, {
  MoneyEntry? existing,
  MoneyType initialType = MoneyType.debit,
}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = _FakeMoneyRepository();
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
                  builder: (context) => MoneyFormScreen(
                    repository: repo,
                    parties: const [_ali],
                    vehicles: _vehicles,
                    existing: existing,
                    initialType: initialType,
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

/// Flips the Party / Vehicle switch.
Future<void> _chooseWho(WidgetTester tester, String side) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('moneyTarget')),
      matching: find.text(side),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('debit / credit form', () {
    testWidgets(
      'has date, a Party/Vehicle switch, the party field and rupees',
      (tester) async {
        await _openForm(tester);
        expect(find.text('DATE'), findsOneWidget);
        expect(find.byKey(const ValueKey('moneyTarget')), findsOneWidget);
        expect(_field('PARTY'), findsOneWidget); // Party is selected to begin
        expect(_field('VEHICLE NO.'), findsNothing);
        expect(_field('RUPEES'), findsOneWidget);
        expect(find.text('SAVE DEBIT'), findsOneWidget);
      },
    );

    testWidgets('the switch shows the party field or the vehicle field', (
      tester,
    ) async {
      await _openForm(tester);

      await _chooseWho(tester, 'Vehicle');
      expect(_field('VEHICLE NO.'), findsOneWidget);
      expect(_field('PARTY'), findsNothing);

      await _chooseWho(tester, 'Party');
      expect(_field('PARTY'), findsOneWidget);
      expect(_field('VEHICLE NO.'), findsNothing);
    });

    testWidgets('the Debit/Credit switch changes the title and Save button', (
      tester,
    ) async {
      await _openForm(tester);
      expect(find.text('New debit'), findsOneWidget);

      await tester.tap(find.text('Credit'));
      await tester.pumpAndSettle();
      expect(find.text('New credit'), findsOneWidget);
      expect(find.text('SAVE CREDIT'), findsOneWidget);
      expect(find.text('SAVE DEBIT'), findsNothing);
    });

    testWidgets('saves a debit for a party with its date and rupees', (
      tester,
    ) async {
      final repo = await _openForm(tester);
      await tester.enterText(_field('PARTY'), 'Ali Traders');
      await tester.enterText(_field('RUPEES'), '15000');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      final e = repo.saved.single;
      expect(e.type, MoneyType.debit);
      expect(e.target, MoneyTarget.party);
      expect(e.party, 'Ali Traders');
      expect(e.vehicleNo, isNull);
      expect(e.amount, 15000);
      final now = DateTime.now();
      expect(
        e.date,
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}',
      );
      expect(find.text('New debit'), findsNothing); // closed after saving
    });

    testWidgets('saves a credit for a vehicle when Vehicle is chosen', (
      tester,
    ) async {
      final repo = await _openForm(tester);
      await tester.tap(find.text('Credit'));
      await tester.pumpAndSettle();
      await _chooseWho(tester, 'Vehicle');
      await tester.enterText(_field('VEHICLE NO.'), 'TLM-954');
      await tester.enterText(_field('RUPEES'), '500');
      await tester.tap(find.text('SAVE CREDIT'));
      await tester.pumpAndSettle();

      final e = repo.saved.single;
      expect(e.type, MoneyType.credit);
      expect(e.target, MoneyTarget.vehicle);
      expect(e.vehicleNo, 'TLM-954');
      expect(e.party, isNull);
      expect(e.amount, 500);
    });

    testWidgets(
      'only the chosen one is saved, not what was typed in the other',
      (tester) async {
        final repo = await _openForm(tester);
        await tester.enterText(_field('PARTY'), 'Ali Traders');
        await _chooseWho(tester, 'Vehicle');
        await tester.enterText(_field('VEHICLE NO.'), 'TAB-107');
        await tester.enterText(_field('RUPEES'), '100');
        await tester.tap(find.text('SAVE DEBIT'));
        await tester.pumpAndSettle();

        expect(repo.saved.single.vehicleNo, 'TAB-107');
        expect(repo.saved.single.party, isNull);
      },
    );

    testWidgets('what was typed is kept when the switch flips back', (
      tester,
    ) async {
      await _openForm(tester);
      await tester.enterText(_field('PARTY'), 'Ali Traders');
      await _chooseWho(tester, 'Vehicle');
      await tester.enterText(_field('VEHICLE NO.'), 'TAB-107');

      await _chooseWho(tester, 'Party');
      expect(_text(tester, 'PARTY'), 'Ali Traders');
      await _chooseWho(tester, 'Vehicle');
      expect(_text(tester, 'VEHICLE NO.'), 'TAB-107');
    });

    testWidgets('the chosen one, and rupees, are required', (tester) async {
      final repo = await _openForm(tester);
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.text('Required'), findsOneWidget); // the party
      expect(find.text('Enter the rupees'), findsOneWidget);

      // On Vehicle it is the vehicle that is asked for — not the party.
      await _chooseWho(tester, 'Vehicle');
      await tester.enterText(_field('RUPEES'), '100');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.text('Required'), findsOneWidget); // the vehicle

      await tester.enterText(_field('VEHICLE NO.'), '   ');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty); // blank is not a vehicle

      await tester.enterText(_field('VEHICLE NO.'), 'TLM-954');
      await tester.enterText(_field('RUPEES'), '0');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty); // zero rupees isn't an entry
    });

    testWidgets('the rupees field takes digits only', (tester) async {
      await _openForm(tester);
      await tester.enterText(_field('RUPEES'), '12ab.5,0');
      expect(_text(tester, 'RUPEES'), '1250');
    });

    testWidgets('a party that is not in the list can be added on the spot', (
      tester,
    ) async {
      await _openForm(tester);
      await tester.enterText(_field('PARTY'), 'Zubair');
      await tester.pump();
      expect(find.text('Add "Zubair" as a new party'), findsOneWidget);

      await tester.enterText(_field('PARTY'), 'ali traders');
      await tester.pump();
      expect(find.textContaining('as a new party'), findsNothing);
    });

    testWidgets('on Vehicle, tapping the field lists the saved vehicles', (
      tester,
    ) async {
      final repo = await _openForm(tester);
      await _chooseWho(tester, 'Vehicle');
      await tester.tap(_field('VEHICLE NO.'));
      await tester.pumpAndSettle();
      expect(find.text('TLM-954'), findsOneWidget);
      expect(find.text('TAB-107'), findsOneWidget);
      expect(find.text('980 CFT'), findsOneWidget);
      expect(find.text('1050 CFT'), findsOneWidget);

      await tester.tap(find.text('TAB-107'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'VEHICLE NO.'), 'TAB-107');

      await tester.enterText(_field('RUPEES'), '2500');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.vehicleNo, 'TAB-107');
    });

    testWidgets('typing narrows the vehicle list', (tester) async {
      await _openForm(tester);
      await _chooseWho(tester, 'Vehicle');
      await tester.enterText(_field('VEHICLE NO.'), 'tlm');
      await tester.pumpAndSettle();
      expect(find.text('TLM-954'), findsOneWidget);
      expect(find.text('TAB-107'), findsNothing);
    });

    testWidgets('a typed vehicle is saved trimmed and upper-case', (
      tester,
    ) async {
      final repo = await _openForm(tester);
      await _chooseWho(tester, 'Vehicle');
      await tester.enterText(_field('VEHICLE NO.'), '  tlm-954 ');
      await tester.enterText(_field('RUPEES'), '100');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.vehicleNo, 'TLM-954');
    });

    testWidgets('editing a party entry opens on Party, on its own side', (
      tester,
    ) async {
      final repo = await _openForm(
        tester,
        existing: const MoneyEntry(
          id: 8,
          date: '2026-09-19',
          party: 'Ali Traders',
          amount: 7500,
          type: MoneyType.credit,
        ),
      );
      expect(find.text('Edit credit'), findsOneWidget);
      expect(find.text('2026-09-19'), findsOneWidget);
      expect(_text(tester, 'PARTY'), 'Ali Traders');
      expect(_field('VEHICLE NO.'), findsNothing);
      expect(_text(tester, 'RUPEES'), '7500');

      await tester.enterText(_field('RUPEES'), '8000');
      await tester.tap(find.text('SAVE CREDIT'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.id, 8); // updated in place
      expect(repo.saved.single.amount, 8000);
      expect(repo.saved.single.party, 'Ali Traders');
      expect(repo.saved.single.type, MoneyType.credit);
    });

    testWidgets('editing a vehicle entry opens on Vehicle', (tester) async {
      final repo = await _openForm(
        tester,
        existing: const MoneyEntry(
          id: 9,
          date: '2026-09-18',
          vehicleNo: 'TLM-954',
          amount: 1200,
          type: MoneyType.debit,
        ),
      );
      expect(find.text('Edit debit'), findsOneWidget);
      expect(_text(tester, 'VEHICLE NO.'), 'TLM-954');
      expect(_field('PARTY'), findsNothing);

      await tester.enterText(_field('RUPEES'), '1300');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.id, 9);
      expect(repo.saved.single.vehicleNo, 'TLM-954');
      expect(repo.saved.single.party, isNull);
      expect(repo.saved.single.amount, 1300);
    });

    testWidgets('an entry can be changed from a party to a vehicle', (
      tester,
    ) async {
      final repo = await _openForm(
        tester,
        existing: const MoneyEntry(
          id: 8,
          date: '2026-09-19',
          party: 'Ali Traders',
          amount: 7500,
          type: MoneyType.debit,
        ),
      );
      await _chooseWho(tester, 'Vehicle');
      await tester.enterText(_field('VEHICLE NO.'), 'TAB-107');
      await tester.tap(find.text('SAVE DEBIT'));
      await tester.pumpAndSettle();

      final e = repo.saved.single;
      expect(e.id, 8);
      expect(e.vehicleNo, 'TAB-107');
      expect(e.party, isNull); // no longer a party entry
      expect(e.amount, 7500);
    });
  });

  group('debit / credit rows', () {
    testWidgets('a row shows type, who, date and rupees without overflow', (
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
                MoneyTile(
                  entry: const MoneyEntry(
                    id: 1,
                    date: '2026-09-19',
                    party: 'A Very Long Party Name Pvt Ltd Of Lahore Karachi',
                    amount: 123456,
                    type: MoneyType.debit,
                  ),
                  onTap: () {},
                  onDelete: () => deleted++,
                ),
                const MoneyTile(
                  entry: MoneyEntry(
                    id: 2,
                    date: '2026-09-18',
                    vehicleNo: 'TLM-954',
                    amount: 900,
                    type: MoneyType.credit,
                  ),
                ),
                const MoneyTotalsCard(debit: 123456, credit: 900),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('DEBIT'), findsOneWidget);
      expect(find.text('CREDIT'), findsOneWidget);
      expect(find.text('TLM-954'), findsOneWidget);
      // Each row says which kind it is for.
      expect(find.text('Party'), findsOneWidget);
      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.text('Rs 1,23,456'), findsWidgets);
      // Only the editable row has a delete button; the report row is read-only.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, 1);
    });
  });

  test('the Debit & Credit PDF builds, month by month', () async {
    final entries = [
      for (var i = 0; i < 400; i++)
        MoneyEntry(
          id: i,
          date:
              '2026-0${(i % 9) + 1}-${(i % 27 + 1).toString().padLeft(2, '0')}',
          // A mix: every third entry is for a vehicle, the rest for parties.
          party: i % 3 == 0 ? null : 'Some Long Party Name Pvt Ltd',
          vehicleNo: i % 3 == 0 ? 'TLM-954' : null,
          amount: 1000.0 + i,
          type: i.isEven ? MoneyType.debit : MoneyType.credit,
        ),
    ];
    // Every column combination the report screen can ask for.
    for (final showType in [true, false]) {
      for (final (showParty, showVehicle) in [
        (true, true),
        (true, false),
        (false, true),
      ]) {
        final bytes = await buildMoneyReportPdf(
          businessName: 'Test Traders',
          title: 'Debit & Credit Report',
          filters: 'Debit and Credit | All dates',
          groups: groupMoneyByMonth(entries),
          showType: showType,
          showParty: showParty,
          showVehicle: showVehicle,
        );
        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
    }
    final empty = await buildMoneyReportPdf(
      businessName: null,
      title: 'Debit & Credit Report',
      filters: 'All dates',
      groups: const [],
      showType: true,
    );
    expect(String.fromCharCodes(empty.take(5)), '%PDF-');
  });
}
