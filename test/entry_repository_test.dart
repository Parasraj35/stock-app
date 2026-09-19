import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/app_database.dart';
import 'package:stock/data/repositories.dart';

void main() {
  test('updating an entry in the database really changes its date', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_entry_');
    await databaseFactory.setDatabasesPath(dir.path);
    final db = await AppDatabase.open();
    addTearDown(() async {
      await db.db.close();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    final repo = SqliteEntryRepository(db, salesTable);
    final saved = await repo.add(
      const Entry(
        date: '2026-09-19',
        party: 'Ali',
        brandId: 1,
        brandName: 'Crush',
        cftPerVehicle: 100,
        round: 2,
        totalCFT: 200,
        amount: 7000,
      ),
    );

    await repo.update(saved.copyWith(date: '2026-09-01', party: 'Ahmed'));

    final rows = await repo.list();
    expect(rows, hasLength(1)); // updated in place, not duplicated
    expect(rows.single.id, saved.id);
    expect(rows.single.date, '2026-09-01');
    expect(rows.single.party, 'Ahmed');
  });
}
