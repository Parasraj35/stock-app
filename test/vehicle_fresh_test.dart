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
  });
}
