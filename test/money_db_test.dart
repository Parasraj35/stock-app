import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock/core/models.dart';
import 'package:stock/data/app_database.dart';
import 'package:stock/data/repositories.dart';

void main() {
  test(
    'an existing install gains the debit/credit table and keeps its data',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('stock_money_');
      await databaseFactory.setDatabasesPath(dir.path);

      // An install from before Debit & Credit: schema version 8, with a party
      // already saved that must survive the upgrade.
      final old = await openDatabase(
        p.join(dir.path, 'stock.db'),
        version: 8,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE parties (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, phone TEXT)',
          );
          await db.insert('parties', {'name': 'Old Party'});
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

      expect(await db.db.query('parties'), hasLength(1)); // untouched
      expect(await db.db.query(moneyTable), isEmpty); // new, and empty

      final repo = SqliteMoneyRepository(db);
      final forParty = await repo.add(
        const MoneyEntry(
          date: '2026-09-19',
          party: 'Ali Traders',
          amount: 5000,
          type: MoneyType.debit,
        ),
      );
      final forVehicle = await repo.add(
        const MoneyEntry(
          date: '2026-09-20',
          vehicleNo: 'TAB-107',
          amount: 1200,
          type: MoneyType.credit,
        ),
      );
      expect(forParty.id, isNotNull);
      expect(forVehicle.id, isNot(forParty.id));

      // Newest first; each comes back for the same party / vehicle it went in
      // with, with the right type.
      var rows = await repo.list();
      expect(rows.map((e) => e.type), [MoneyType.credit, MoneyType.debit]);
      expect(rows.map((e) => e.amount), [1200, 5000]);
      expect(rows.map((e) => e.target), [
        MoneyTarget.vehicle,
        MoneyTarget.party,
      ]);
      expect(rows.map((e) => e.name), ['TAB-107', 'Ali Traders']);
      expect(rows[0].party, isNull);
      expect(rows[1].vehicleNo, isNull);

      // Correcting an entry changes it in place.
      await repo.update(forParty.copyWith(date: '2026-09-01', amount: 5500));
      rows = await repo.list();
      expect(rows, hasLength(2));
      final fixed = rows.firstWhere((e) => e.id == forParty.id);
      expect(fixed.date, '2026-09-01');
      expect(fixed.amount, 5500);
      expect(fixed.party, 'Ali Traders');

      // …including which one it is for.
      await repo.update(forParty.copyWith(vehicleNo: 'TLM-954'));
      final switched = (await repo.list()).firstWhere(
        (e) => e.id == forParty.id,
      );
      expect(switched.target, MoneyTarget.vehicle);
      expect(switched.vehicleNo, 'TLM-954');
      expect(switched.party, isNull);

      // The table itself refuses an entry for neither, or for both.
      Future<void> insert(Map<String, Object?> who) => db.db.insert(
        moneyTable,
        {'date': '2026-09-19', 'amount': 1.0, 'type': 'debit', ...who},
      );
      await expectLater(insert({}), throwsA(isA<DatabaseException>()));
      await expectLater(
        insert({'party': 'Ali', 'vehicleNo': 'TLM-954'}),
        throwsA(isA<DatabaseException>()),
      );

      await repo.delete(forVehicle.id!);
      rows = await repo.list();
      expect(rows.map((e) => e.id), [forParty.id]);
    },
  );
}
