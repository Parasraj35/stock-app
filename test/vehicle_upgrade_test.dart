import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/data/app_database.dart';

void main() {
  test(
    'upgrading an existing install adds and seeds the 12 vehicles',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('stock_upgrade_');
      await databaseFactory.setDatabasesPath(dir.path);

      // An install from before vehicles existed: schema version 7.
      final old = await openDatabase(p.join(dir.path, 'stock.db'), version: 7);
      await old.close();

      final db = await AppDatabase.open();
      addTearDown(() async {
        await db.db.close();
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });

      final rows = await db.db.query(vehiclesTable, orderBy: 'vehicleNo');
      expect(rows, hasLength(12));
      final byNumber = {for (final r in rows) r['vehicleNo']: r['cft']};
      expect(byNumber['TLM-954'], 980);
      expect(byNumber['TAB-107'], 1050);
      expect(byNumber['TKY-300'], 539);
      expect(byNumber['TKJ-577'], 959);
      // Each CFT points to exactly one vehicle.
      expect(byNumber.values.toSet(), hasLength(12));
    },
  );
}
