import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/app_database.dart';
import 'package:stock/data/repositories.dart';

void main() {
  test('Debit/Credit entries saved by vehicle only (schema 10) keep their '
      'vehicle — and a saved party stays a party (schema 11)', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_money_v10_');
    await databaseFactory.setDatabasesPath(dir.path);

    // Schema 10: money_entries had one name column, `vehicleNo` (it also held
    // the party names carried over from schema 9).
    final old = await openDatabase(
      p.join(dir.path, 'stock.db'),
      version: 10,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE parties (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, phone TEXT)',
        );
        await db.execute(
          'CREATE TABLE vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'vehicleNo TEXT NOT NULL, cft REAL NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE money_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'date TEXT NOT NULL, vehicleNo TEXT NOT NULL, amount REAL NOT NULL, '
          'type TEXT NOT NULL)',
        );
        await db.insert('parties', {'name': 'Ali Traders'});
        await db.insert('parties', {'name': 'Shared'});
        await db.insert('vehicles', {'vehicleNo': 'TLM-954', 'cft': 980.0});
        await db.insert('vehicles', {'vehicleNo': 'SHARED', 'cft': 500.0});
        Future<void> money(String date, String name, double amount) =>
            db.insert('money_entries', {
              'date': date,
              'vehicleNo': name,
              'amount': amount,
              'type': 'debit',
            });
        await money(
          '2026-09-01',
          'ali traders',
          100,
        ); // a saved party (any case)
        await money('2026-09-02', 'TLM-954', 200); // a saved vehicle
        await money('2026-09-03', 'TKZ-000', 300); // typed, in neither list
        await money('2026-09-04', 'Shared', 400); // both: a vehicle wins
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

    final repo = SqliteMoneyRepository(db);
    final rows = {for (final e in await repo.list()) e.id!: e};
    expect(rows, hasLength(4)); // nothing lost
    expect(rows.values.map((e) => e.amount).toSet(), {100, 200, 300, 400});

    // A name that is a saved party (and not a vehicle) is a party again.
    expect(rows[1]!.target, MoneyTarget.party);
    expect(rows[1]!.party, 'ali traders');
    // Everything else stays for a vehicle, as it was saved.
    expect(rows[2]!.target, MoneyTarget.vehicle);
    expect(rows[2]!.vehicleNo, 'TLM-954');
    expect(rows[3]!.target, MoneyTarget.vehicle);
    expect(rows[3]!.vehicleNo, 'TKZ-000');
    expect(rows[4]!.target, MoneyTarget.vehicle);
    expect(rows[4]!.vehicleNo, 'Shared');
    // Exactly one of the two is set on every row.
    for (final e in rows.values) {
      expect((e.party == null) != (e.vehicleNo == null), isTrue);
    }

    final columns = (await db.db.rawQuery(
      'PRAGMA table_info($moneyTable)',
    )).map((c) => c['name']).toList();
    expect(columns, ['id', 'date', 'party', 'vehicleNo', 'amount', 'type']);
  });
}
