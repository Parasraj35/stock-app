// Low-level SQLite wrapper: schema + a single opened Database instance.
// Nothing above this file talks to sqflite directly — repositories.dart is
// the only consumer, so the storage engine can be swapped later by
// reimplementing that one file.
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const purchasesTable = 'purchases';
const salesTable = 'sales';
const partiesTable = 'parties';
const vehiclesTable = 'vehicles';
const moneyTable = 'money_entries';
const dieselTable = 'diesel_entries';

const _partiesSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT
''';

const _vehiclesSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicleNo TEXT NOT NULL,
    cft REAL NOT NULL
''';

// The fixed fleet and what each carries per trip. Seeded once — when the app
// is first installed or upgraded to a version that has vehicles — after which
// the list belongs to the user (add/edit/delete in the Vehicles screen).
const _defaultVehicles = <(String, double)>[
  ('TLM-954', 980),
  ('TAB-107', 1050),
  ('TKE-994', 940),
  ('TKU-327', 910),
  ('TAP-213', 1040),
  ('TAJ-439', 1000),
  ('TKY-300', 539),
  ('TKG-116', 620),
  ('TKN-630', 586),
  ('TKE-927', 610),
  ('TKV-785', 510),
  ('TKJ-577', 959),
];

Future<void> _createAndSeedVehicles(Database db) async {
  await db.execute('CREATE TABLE $vehiclesTable ($_vehiclesSchema)');
  for (final (vehicleNo, cft) in _defaultVehicles) {
    await db.insert(vehiclesTable, {'vehicleNo': vehicleNo, 'cft': cft});
  }
}

// A Debit/Credit entry is for a party or a vehicle: exactly one is filled in.
const _moneySchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    party TEXT,
    vehicleNo TEXT,
    amount REAL NOT NULL,
    type TEXT NOT NULL,
    CHECK ((party IS NULL) <> (vehicleNo IS NULL))
''';

/// Debit & Credit was first saved per party (schema 9), then briefly per
/// vehicle (schema 10); it is now for either. Rebuilds the table with both
/// columns and keeps every entry.
Future<void> _rebuildMoneyTable(Database db, int oldVersion) async {
  const fresh = '${moneyTable}_new';
  await db.execute('CREATE TABLE $fresh ($_moneySchema)');
  if (oldVersion == 9) {
    // Schema 9 only had parties.
    await db.execute(
      'INSERT INTO $fresh (id, date, party, vehicleNo, amount, type) '
      'SELECT id, date, party, NULL, amount, type FROM $moneyTable',
    );
  } else {
    // Schema 10 kept one name in `vehicleNo`. A saved party's name that is not
    // also a saved vehicle was a party (from schema 9); the rest are vehicles.
    const isParty =
        'EXISTS (SELECT 1 FROM $partiesTable p '
        'WHERE p.name = m.vehicleNo COLLATE NOCASE) '
        'AND NOT EXISTS (SELECT 1 FROM $vehiclesTable v '
        'WHERE v.vehicleNo = m.vehicleNo COLLATE NOCASE)';
    await db.execute(
      'INSERT INTO $fresh (id, date, party, vehicleNo, amount, type) '
      'SELECT id, date, '
      'CASE WHEN $isParty THEN vehicleNo END, '
      'CASE WHEN NOT ($isParty) THEN vehicleNo END, '
      'amount, type FROM $moneyTable m',
    );
  }
  await db.execute('DROP TABLE $moneyTable');
  await db.execute('ALTER TABLE $fresh RENAME TO $moneyTable');
}

const _dieselSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    vehicleNo TEXT NOT NULL,
    litres REAL NOT NULL,
    price REAL NOT NULL,
    CHECK (litres > 0 AND price > 0)
''';

const _entryColumns = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    party TEXT NOT NULL,
    brandId INTEGER NOT NULL,
    brandName TEXT NOT NULL,
    cftPerVehicle REAL NOT NULL,
    round REAL NOT NULL,
    vehicleNo TEXT,
    totalCFT REAL NOT NULL,
    amount REAL NOT NULL
''';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static AppDatabase? _instance;

  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;
    final dbPath = p.join(await getDatabasesPath(), 'stock.db');
    final db = await openDatabase(
      dbPath,
      version: 12,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            username TEXT PRIMARY KEY,
            passwordHash TEXT NOT NULL,
            businessName TEXT,
            ownerAge INTEGER,
            ownerGender TEXT,
            pinHash TEXT,
            autoLockMinutes INTEGER,
            biometricEnabled INTEGER NOT NULL DEFAULT 0,
            themeMode TEXT,
            profilePicPath TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE brands (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            purchaseRate REAL NOT NULL,
            saleRate REAL NOT NULL
          )
        ''');
        await db.execute('CREATE TABLE $purchasesTable ($_entryColumns)');
        await db.execute('CREATE TABLE $salesTable ($_entryColumns)');
        await db.execute('CREATE TABLE $partiesTable ($_partiesSchema)');
        await _createAndSeedVehicles(db);
        await db.execute('CREATE TABLE $moneyTable ($_moneySchema)');
        await db.execute('CREATE TABLE $dieselTable ($_dieselSchema)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $partiesTable ($_partiesSchema)',
          );
        }
        if (oldVersion < 3) {
          // Brands used a single ratePerCft; split into purchaseRate/saleRate,
          // carrying the old value into both so existing brands keep working.
          await db.execute(
            'ALTER TABLE brands ADD COLUMN purchaseRate REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE brands ADD COLUMN saleRate REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'UPDATE brands SET purchaseRate = ratePerCft, saleRate = ratePerCft',
          );
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE users ADD COLUMN businessName TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN ownerAge INTEGER');
          await db.execute('ALTER TABLE users ADD COLUMN ownerGender TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE users ADD COLUMN pinHash TEXT');
          await db.execute(
            'ALTER TABLE users ADD COLUMN autoLockMinutes INTEGER',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN biometricEnabled INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE users ADD COLUMN themeMode TEXT');
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE users ADD COLUMN profilePicPath TEXT');
        }
        if (oldVersion < 8) {
          await _createAndSeedVehicles(db);
        }
        if (oldVersion < 9) {
          await db.execute('CREATE TABLE $moneyTable ($_moneySchema)');
        } else if (oldVersion < 11) {
          await _rebuildMoneyTable(db, oldVersion);
        }
        if (oldVersion < 12) {
          await db.execute('CREATE TABLE $dieselTable ($_dieselSchema)');
        }
      },
    );
    _instance = AppDatabase._(db);
    return _instance!;
  }
}
