import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/repos.dart';
import 'package:stock/data/repositories.dart';
import 'package:stock/ui/screens/entry_form_screen.dart';
import 'package:stock/ui/theme/tokens.dart';

class _NoopEntryRepository implements EntryRepository {
  @override
  Future<Entry> add(Entry entry) async => entry;
  @override
  Future<void> update(Entry entry) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  Future<List<Entry>> list() async => const [];
}

const _crush = Brand(id: 1, name: 'Crush', purchaseRate: 35, saleRate: 52);

Future<void> _openForm(WidgetTester tester, List<Party> parties) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
                  builder: (context) => EntryFormScreen(
                    title: 'Purchase',
                    repository: _NoopEntryRepository(),
                    brands: const [_crush],
                    parties: parties,
                    vehicles: const [],
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
}

Future<void> _typeParty(WidgetTester tester, String name) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'PARTY'), name);
  await tester.pump();
}

final _addButton = find.textContaining('as a new party');

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_party_');
    await databaseFactory.setDatabasesPath(dir.path);
    await Repos.init();
  });

  const ali = Party(id: 1, name: 'Ali Traders');

  testWidgets('the Add party button shows only for a party not in the list', (
    tester,
  ) async {
    await _openForm(tester, const [ali]);
    expect(_addButton, findsNothing); // nothing typed yet

    await _typeParty(tester, 'Zubair');
    expect(find.text('Add "Zubair" as a new party'), findsOneWidget);

    await _typeParty(tester, 'ali traders'); // exists (case doesn't matter)
    expect(_addButton, findsNothing);

    await _typeParty(tester, '   ');
    expect(_addButton, findsNothing);
  });

  testWidgets('the button also shows when there are no parties at all', (
    tester,
  ) async {
    await _openForm(tester, const []);
    await _typeParty(tester, 'Zubair');
    expect(_addButton, findsOneWidget);
  });

  testWidgets('a very long name still fits on a phone', (tester) async {
    await _openForm(tester, const [ali]);
    await _typeParty(
      tester,
      'A Very Long Party Name Pvt Ltd Of Lahore And Karachi Trading',
    );
    expect(_addButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding the party on the spot saves it and selects it', (
    tester,
  ) async {
    await _openForm(tester, const [ali]);
    await _typeParty(tester, 'Zubair');

    await tester.tap(_addButton);
    await tester.pumpAndSettle();

    // A full screen, with what was already typed carried over.
    expect(find.text('New party'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'NAME'))
          .controller!
          .text,
      'Zubair',
    );

    await tester.tap(find.text('SAVE PARTY'));
    // The save is a real database write; let it finish, then redraw.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pumpAndSettle();

    // Back on the purchase form with the new party chosen…
    expect(find.text('New party'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'PARTY'))
          .controller!
          .text,
      'Zubair',
    );
    // …so the button is gone, and the party really was stored.
    expect(_addButton, findsNothing);
    final stored = await tester.runAsync(() => Repos.instance.parties.list());
    expect(stored!.map((p) => p.name), contains('Zubair'));
  });
}
