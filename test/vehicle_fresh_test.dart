import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/data/app_database.dart';

void main() {
  test('a fresh install starts with the 12 vehicles', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('stock_fresh_');
    await databaseFactory.setDatabasesPath(dir.path);

    final db = await AppDatabase.open();
    addTearDown(() async {
      await db.db.close();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    final rows = await db.db.query(vehiclesTable);
    expect(rows, hasLength(12));
    // The rest of the schema is created alongside it.
    expect(await db.db.query('brands'), isEmpty);
    expect(await db.db.query('purchases'), isEmpty);
    // Debit & Credit is for a party or a vehicle, from the first install.
    final money = await db.db.rawQuery('PRAGMA table_info($moneyTable)');
    expect(money.map((c) => c['name']), [
      'id',
      'date',
      'party',
      'vehicleNo',
      'amount',
      'type',
    ]);
    // …and diesel, with its litres and price.
    final diesel = await db.db.rawQuery('PRAGMA table_info($dieselTable)');
    expect(diesel.map((c) => c['name']), [
      'id',
      'date',
      'vehicleNo',
      'litres',
      'price',
    ]);
  });
}
