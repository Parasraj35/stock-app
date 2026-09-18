// Single composition point: builds concrete repositories once at startup.
// Screens import this, not app_database.dart or sqflite directly.
import 'app_database.dart';
import 'repositories.dart';

class Repos {
  Repos._({
    required this.users,
    required this.brands,
    required this.purchases,
    required this.sales,
    required this.parties,
    required this.vehicles,
  });

  final UserRepository users;
  final BrandRepository brands;
  final EntryRepository purchases;
  final EntryRepository sales;
  final PartyRepository parties;
  final VehicleRepository vehicles;

  static Repos? _instance;
  static Repos get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('Repos.init() must be awaited before use');
    }
    return i;
  }

  static Future<Repos> init() async {
    final db = await AppDatabase.open();
    final brandRepo = SqliteBrandRepository(db);
    await brandRepo.seedIfEmpty();

    final repos = Repos._(
      users: SqliteUserRepository(db),
      brands: brandRepo,
      purchases: SqliteEntryRepository(db, purchasesTable),
      sales: SqliteEntryRepository(db, salesTable),
      parties: SqlitePartyRepository(db),
      vehicles: SqliteVehicleRepository(db),
    );
    _instance = repos;
    return repos;
  }
}
