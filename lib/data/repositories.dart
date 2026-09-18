// Repository interfaces + SQLite implementations.
//
// Screens depend only on the abstract classes below. Today they're backed by
// SQLite (via AppDatabase); later a backend-backed implementation (e.g.
// ApiBrandRepository calling a REST API) can replace these without any
// screen changes.
import 'package:sqflite/sqflite.dart';

import '../core/models.dart';
import 'app_database.dart';
import 'data_bus.dart';

abstract class BrandRepository {
  Future<List<Brand>> list();
  Future<Brand> add(Brand brand);
  Future<void> update(Brand brand);
  Future<void> delete(int id);
}

abstract class EntryRepository {
  Future<List<Entry>> list();
  Future<Entry> add(Entry entry);
  Future<void> update(Entry entry);
  Future<void> delete(int id);
}

abstract class UserRepository {
  Future<AppUser?> getUser();
  Future<void> createUser(AppUser user);
  Future<void> updateProfile(AppUser user);
}

abstract class PartyRepository {
  Future<List<Party>> list();
  Future<Party> add(Party party);
  Future<void> update(Party party);
  Future<void> delete(int id);
}

abstract class VehicleRepository {
  Future<List<Vehicle>> list();
  Future<Vehicle> add(Vehicle vehicle);
  Future<void> update(Vehicle vehicle);
  Future<void> delete(int id);
}

// Seeded with the same value for both rates — purchase/sale margins are set
// per-brand afterward via the Brands screen.
const _defaultBrands = [
  Brand(name: 'Crush 16mm', purchaseRate: 35, saleRate: 52),
  Brand(name: 'Crush 10mm', purchaseRate: 30, saleRate: 52),
  Brand(name: 'Crush 50mm', purchaseRate: 28, saleRate: 52),
  Brand(name: 'Crush 0mm', purchaseRate: 28, saleRate: 52),
  Brand(name: 'Ghera', purchaseRate: 22, saleRate: 39),
  Brand(name: 'Khaka', purchaseRate: 6, saleRate: 27),
  Brand(name: 'Mitti', purchaseRate: 16, saleRate: 16),
  Brand(name: 'Retti (Silica)', purchaseRate: 29, saleRate: 39),
  Brand(name: 'Danedar', purchaseRate: 39, saleRate: 39),
];

class SqliteBrandRepository implements BrandRepository {
  SqliteBrandRepository(this._db);
  final AppDatabase _db;

  /// Seeds default brands on first run only; never overwrites existing rows.
  Future<void> seedIfEmpty() async {
    final existing = await list();
    if (existing.isNotEmpty) return;
    for (final brand in _defaultBrands) {
      await add(brand);
    }
  }

  @override
  Future<List<Brand>> list() async {
    final rows = await _db.db.query('brands', orderBy: 'name');
    return rows.map(Brand.fromMap).toList();
  }

  @override
  Future<Brand> add(Brand brand) async {
    final id = await _db.db.insert('brands', brand.toMap()..remove('id'));
    DataBus.instance.notifyChanged();
    return brand.copyWith(id: id);
  }

  @override
  Future<void> update(Brand brand) async {
    await _db.db.update(
      'brands',
      brand.toMap(),
      where: 'id = ?',
      whereArgs: [brand.id],
    );
    DataBus.instance.notifyChanged();
  }

  @override
  Future<void> delete(int id) async {
    await _db.db.delete('brands', where: 'id = ?', whereArgs: [id]);
    DataBus.instance.notifyChanged();
  }
}

/// Backs both the Purchase and Sale screens — same schema, same logic;
/// only the table name differs, so the code isn't duplicated per screen.
class SqliteEntryRepository implements EntryRepository {
  SqliteEntryRepository(this._db, this.tableName);
  final AppDatabase _db;
  final String tableName;

  @override
  Future<List<Entry>> list() async {
    final rows = await _db.db.query(tableName, orderBy: 'date DESC, id DESC');
    return rows.map(Entry.fromMap).toList();
  }

  @override
  Future<Entry> add(Entry entry) async {
    final id = await _db.db.insert(tableName, entry.toMap()..remove('id'));
    DataBus.instance.notifyChanged();
    return entry.copyWith(id: id);
  }

  @override
  Future<void> update(Entry entry) async {
    await _db.db.update(
      tableName,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    DataBus.instance.notifyChanged();
  }

  @override
  Future<void> delete(int id) async {
    await _db.db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    DataBus.instance.notifyChanged();
  }
}

class SqlitePartyRepository implements PartyRepository {
  SqlitePartyRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<Party>> list() async {
    final rows = await _db.db.query(partiesTable, orderBy: 'name');
    return rows.map(Party.fromMap).toList();
  }

  @override
  Future<Party> add(Party party) async {
    final id = await _db.db.insert(partiesTable, party.toMap()..remove('id'));
    DataBus.instance.notifyChanged();
    return party.copyWith(id: id);
  }

  @override
  Future<void> update(Party party) async {
    await _db.db.update(
      partiesTable,
      party.toMap(),
      where: 'id = ?',
      whereArgs: [party.id],
    );
    DataBus.instance.notifyChanged();
  }

  @override
  Future<void> delete(int id) async {
    await _db.db.delete(partiesTable, where: 'id = ?', whereArgs: [id]);
    DataBus.instance.notifyChanged();
  }
}

class SqliteVehicleRepository implements VehicleRepository {
  SqliteVehicleRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<Vehicle>> list() async {
    final rows = await _db.db.query(vehiclesTable, orderBy: 'vehicleNo');
    return rows.map(Vehicle.fromMap).toList();
  }

  @override
  Future<Vehicle> add(Vehicle vehicle) async {
    final id = await _db.db.insert(
      vehiclesTable,
      vehicle.toMap()..remove('id'),
    );
    DataBus.instance.notifyChanged();
    return vehicle.copyWith(id: id);
  }

  @override
  Future<void> update(Vehicle vehicle) async {
    await _db.db.update(
      vehiclesTable,
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
    DataBus.instance.notifyChanged();
  }

  @override
  Future<void> delete(int id) async {
    await _db.db.delete(vehiclesTable, where: 'id = ?', whereArgs: [id]);
    DataBus.instance.notifyChanged();
  }
}

class SqliteUserRepository implements UserRepository {
  SqliteUserRepository(this._db);
  final AppDatabase _db;

  @override
  Future<AppUser?> getUser() async {
    final rows = await _db.db.query('users', limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  @override
  Future<void> createUser(AppUser user) async {
    await _db.db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DataBus.instance.notifyChanged();
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    await _db.db.update(
      'users',
      user.toMap(),
      where: 'username = ?',
      whereArgs: [user.username],
    );
    DataBus.instance.notifyChanged();
  }
}
