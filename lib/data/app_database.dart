// Low-level SQLite wrapper: schema + a single opened Database instance.
// Nothing above this file talks to sqflite directly — repositories.dart is
// the only consumer, so the storage engine can be swapped later by
// reimplementing that one file.
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const purchasesTable = 'purchases';
const salesTable = 'sales';
const partiesTable = 'parties';

const _partiesSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT
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
      version: 7,
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
          await db.execute(
            'ALTER TABLE users ADD COLUMN profilePicPath TEXT',
          );
        }
      },
    );
    _instance = AppDatabase._(db);
    return _instance!;
  }
}
