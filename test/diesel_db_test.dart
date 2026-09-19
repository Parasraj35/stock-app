import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/app_database.dart';
import 'package:stock/data/repositories.dart';

void main() {
  test('an install from before diesel gains the diesel table, keeps its data, '
      'and saves entries', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_diesel_');
    await databaseFactory.setDatabasesPath(dir.path);

    // Schema 11: Debit & Credit already there, with an entry that must
    // survive the upgrade.
    final old = await openDatabase(
      p.join(dir.path, 'stock.db'),
      version: 11,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE money_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'date TEXT NOT NULL, party TEXT, vehicleNo TEXT, '
          'amount REAL NOT NULL, type TEXT NOT NULL)',
        );
        await db.insert('money_entries', {
          'date': '2026-09-19',
          'party': 'Ali Traders',
          'amount': 5000.0,
          'type': 'debit',
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

    expect(await db.db.query(moneyTable), hasLength(1)); // untouched
    expect(await db.db.query(dieselTable), isEmpty); // new, and empty

    final repo = SqliteDieselRepository(db);
    final first = await repo.add(
      const DieselEntry(
        date: '2026-09-19',
        vehicleNo: 'TLM-954',
        litres: 100,
        price: 404,
      ),
    );
    final second = await repo.add(
      const DieselEntry(
        date: '2026-09-20',
        vehicleNo: 'TAB-107',
        litres: 45.5,
        price: 404.5,
      ),
    );
    expect(first.id, isNotNull);
    expect(second.id, isNot(first.id));

    // Newest first, with every figure coming back as it went in.
    var rows = await repo.list();
    expect(rows.map((e) => e.vehicleNo), ['TAB-107', 'TLM-954']);
    expect(rows.map((e) => e.litres), [45.5, 100]);
    expect(rows.map((e) => e.price), [404.5, 404]);
    expect(rows.map((e) => e.total), [18405, 40400]);

    // Correcting an entry changes it in place.
    await repo.update(first.copyWith(date: '2026-09-01', litres: 110));
    rows = await repo.list();
    expect(rows, hasLength(2));
    final fixed = rows.firstWhere((e) => e.id == first.id);
    expect(fixed.date, '2026-09-01');
    expect(fixed.litres, 110);
    expect(fixed.price, 404);
    expect(fixed.total, 44440);

    // The table itself refuses zero (or no) litres or price.
    Future<void> insert(double litres, double price) =>
        db.db.insert(dieselTable, {
          'date': '2026-09-19',
          'vehicleNo': 'TLM-954',
          'litres': litres,
          'price': price,
        });
    await expectLater(insert(0, 404), throwsA(isA<DatabaseException>()));
    await expectLater(insert(100, 0), throwsA(isA<DatabaseException>()));
    await expectLater(insert(-5, 404), throwsA(isA<DatabaseException>()));
    expect(await repo.list(), hasLength(2)); // nothing slipped in

    await repo.delete(second.id!);
    rows = await repo.list();
    expect(rows.map((e) => e.id), [first.id]);
  });
}
