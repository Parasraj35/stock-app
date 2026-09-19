import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/app_database.dart';
import 'package:stock/data/repositories.dart';

void main() {
  test('Debit/Credit entries saved by party (schema 9) stay party entries '
      'when an entry can be for a vehicle too (schema 11)', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_money_v9_');
    await databaseFactory.setDatabasesPath(dir.path);

    // Schema 9: money_entries only has the `party` column.
    final old = await openDatabase(
      p.join(dir.path, 'stock.db'),
      version: 9,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE money_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'date TEXT NOT NULL, party TEXT NOT NULL, amount REAL NOT NULL, '
          'type TEXT NOT NULL)',
        );
        await db.insert('money_entries', {
          'date': '2026-09-19',
          'party': 'Ali Traders',
          'amount': 5000.0,
          'type': 'debit',
        });
        await db.insert('money_entries', {
          'date': '2026-09-20',
          'party': 'Zubair',
          'amount': 1200.0,
          'type': 'credit',
        });
      },
    );
    await old.close();

    final db = await AppDatabase.open();
    addTearDown(() async {
      await db.db.close();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    // Nothing lost or changed: same rows, ids, amounts, types — and still
    // party entries, with no vehicle.
    final repo = SqliteMoneyRepository(db);
    var rows = await repo.list();
    expect(rows, hasLength(2));
    expect(rows.map((e) => e.id), [2, 1]); // newest first
    expect(rows.map((e) => e.party), ['Zubair', 'Ali Traders']);
    expect(rows.map((e) => e.vehicleNo), [null, null]);
    expect(rows.map((e) => e.target), everyElement(MoneyTarget.party));
    expect(rows.map((e) => e.amount), [1200, 5000]);
    expect(rows.map((e) => e.type), [MoneyType.credit, MoneyType.debit]);

    // The table now has both columns.
    final columns = (await db.db.rawQuery(
      'PRAGMA table_info($moneyTable)',
    )).map((c) => c['name']).toList();
    expect(columns, ['id', 'date', 'party', 'vehicleNo', 'amount', 'type']);

    // An old entry can now be for a vehicle instead, and new entries carry on
    // from the old ids.
    await repo.update(rows.last.copyWith(vehicleNo: 'TLM-954'));
    final added = await repo.add(
      const MoneyEntry(
        date: '2026-09-21',
        vehicleNo: 'TAB-107',
        amount: 700,
        type: MoneyType.debit,
      ),
    );
    expect(added.id, 3);
    rows = await repo.list();
    expect(rows.map((e) => e.name), ['TAB-107', 'Zubair', 'TLM-954']);
    expect(rows.map((e) => e.target), [
      MoneyTarget.vehicle,
      MoneyTarget.party,
      MoneyTarget.vehicle,
    ]);
  });
}
