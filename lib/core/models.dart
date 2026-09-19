// Plain data models with Map serialization only (no sqflite/Flutter types
// leaking in), so a future backend (JSON over HTTP) can reuse these as-is.

class Brand {
  final int? id;
  final String name;
  final double purchaseRate;
  final double saleRate;

  const Brand({
    this.id,
    required this.name,
    required this.purchaseRate,
    required this.saleRate,
  });

  Brand copyWith({
    int? id,
    String? name,
    double? purchaseRate,
    double? saleRate,
  }) => Brand(
    id: id ?? this.id,
    name: name ?? this.name,
    purchaseRate: purchaseRate ?? this.purchaseRate,
    saleRate: saleRate ?? this.saleRate,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'purchaseRate': purchaseRate,
    'saleRate': saleRate,
  };

  factory Brand.fromMap(Map<String, Object?> map) => Brand(
    id: map['id'] as int?,
    name: map['name'] as String,
    purchaseRate: (map['purchaseRate'] as num).toDouble(),
    saleRate: (map['saleRate'] as num).toDouble(),
  );
}

class Party {
  final int? id;
  final String name;
  final String? phone;

  const Party({this.id, required this.name, this.phone});

  Party copyWith({int? id, String? name, String? phone}) => Party(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
  );

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'phone': phone};

  factory Party.fromMap(Map<String, Object?> map) => Party(
    id: map['id'] as int?,
    name: map['name'] as String,
    phone: map['phone'] as String?,
  );
}

/// A fixed vehicle and how much it carries per trip. Typing that CFT on a
/// Purchase/Sale fills in this vehicle's number.
class Vehicle {
  final int? id;
  final String vehicleNo;
  final double cft;

  const Vehicle({this.id, required this.vehicleNo, required this.cft});

  Vehicle copyWith({int? id, String? vehicleNo, double? cft}) => Vehicle(
    id: id ?? this.id,
    vehicleNo: vehicleNo ?? this.vehicleNo,
    cft: cft ?? this.cft,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'vehicleNo': vehicleNo,
    'cft': cft,
  };

  factory Vehicle.fromMap(Map<String, Object?> map) => Vehicle(
    id: map['id'] as int?,
    vehicleNo: map['vehicleNo'] as String,
    cft: (map['cft'] as num).toDouble(),
  );
}

/// Which way money moved.
enum MoneyType {
  debit,
  credit;

  String get label => this == debit ? 'Debit' : 'Credit';
}

/// Who a Debit/Credit entry is for — chosen by the user for each entry.
enum MoneyTarget {
  party,
  vehicle;

  String get label => this == party ? 'Party' : 'Vehicle';
}

/// A Debit or Credit entry — money, no goods. Each entry is for either a party
/// or a vehicle (exactly one of [party] / [vehicleNo] is set). Both types share
/// the same fields (date, who, rupees); [type] tells them apart. Kept apart
/// from Purchase/Sale, so it never touches stock, totals or profit.
class MoneyEntry {
  final int? id;
  final String date; // ISO yyyy-MM-dd
  final String? party;
  final String? vehicleNo;
  final double amount;
  final MoneyType type;

  const MoneyEntry({
    this.id,
    required this.date,
    this.party,
    this.vehicleNo,
    required this.amount,
    required this.type,
  }) : assert(
         (party == null) != (vehicleNo == null),
         'An entry is for a party or a vehicle: exactly one',
       );

  MoneyTarget get target =>
      vehicleNo != null ? MoneyTarget.vehicle : MoneyTarget.party;

  /// The party name or vehicle number this entry is for.
  String get name => (vehicleNo ?? party)!;

  /// Passing [party] makes it a party entry; passing [vehicleNo] makes it a
  /// vehicle entry (the other is cleared). Passing neither keeps who it is for.
  MoneyEntry copyWith({
    int? id,
    String? date,
    String? party,
    String? vehicleNo,
    double? amount,
    MoneyType? type,
  }) {
    final changesTarget = party != null || vehicleNo != null;
    return MoneyEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      party: changesTarget ? party : this.party,
      vehicleNo: changesTarget ? vehicleNo : this.vehicleNo,
      amount: amount ?? this.amount,
      type: type ?? this.type,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'date': date,
    'party': party,
    'vehicleNo': vehicleNo,
    'amount': amount,
    'type': type.name,
  };

  factory MoneyEntry.fromMap(Map<String, Object?> map) => MoneyEntry(
    id: map['id'] as int?,
    date: map['date'] as String,
    party: map['party'] as String?,
    vehicleNo: map['vehicleNo'] as String?,
    amount: (map['amount'] as num).toDouble(),
    type: MoneyType.values.byName(map['type'] as String),
  );
}

/// One diesel fill-up for a vehicle: [litres] at [price] rupees a litre. The
/// total is litres × price, worked out when needed and never stored. Kept
/// apart from Purchase/Sale, so it never touches stock, totals or profit.
class DieselEntry {
  final int? id;
  final String date; // ISO yyyy-MM-dd
  final String vehicleNo;
  final double litres;
  final double price; // rupees per litre

  const DieselEntry({
    this.id,
    required this.date,
    required this.vehicleNo,
    required this.litres,
    required this.price,
  });

  /// What [litres] at [price] come to, in whole rupees. Rounded per entry so a
  /// report's rows always add up to its grand total.
  static double totalFor(double litres, double price) =>
      (litres * price).roundToDouble();

  double get total => totalFor(litres, price);

  DieselEntry copyWith({
    int? id,
    String? date,
    String? vehicleNo,
    double? litres,
    double? price,
  }) => DieselEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    vehicleNo: vehicleNo ?? this.vehicleNo,
    litres: litres ?? this.litres,
    price: price ?? this.price,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'date': date,
    'vehicleNo': vehicleNo,
    'litres': litres,
    'price': price,
  };

  factory DieselEntry.fromMap(Map<String, Object?> map) => DieselEntry(
    id: map['id'] as int?,
    date: map['date'] as String,
    vehicleNo: map['vehicleNo'] as String,
    litres: (map['litres'] as num).toDouble(),
    price: (map['price'] as num).toDouble(),
  );
}

/// Shared shape for both Purchase and Sale entries — same fields, same
/// calculation rules. Which table it lives in is decided by the repository,
/// not by this model, so the UI/list/form code can be reused for both.
class Entry {
  final int? id;
  final String date; // ISO yyyy-MM-dd
  final String party;
  final int brandId;
  final String brandName; // denormalized at save time for display/history
  final double cftPerVehicle;
  final double round;
  final String? vehicleNo;
  final double totalCFT;
  final double amount;

  const Entry({
    this.id,
    required this.date,
    required this.party,
    required this.brandId,
    required this.brandName,
    required this.cftPerVehicle,
    required this.round,
    this.vehicleNo,
    required this.totalCFT,
    required this.amount,
  });

  /// The per-cft price this entry was saved at (amount ÷ totalCFT). Derived,
  /// so a per-entry price change needs no extra stored column.
  double get ratePerCft => totalCFT > 0 ? amount / totalCFT : 0;

  Entry copyWith({
    int? id,
    String? date,
    String? party,
    int? brandId,
    String? brandName,
    double? cftPerVehicle,
    double? round,
    String? vehicleNo,
    double? totalCFT,
    double? amount,
  }) => Entry(
    id: id ?? this.id,
    date: date ?? this.date,
    party: party ?? this.party,
    brandId: brandId ?? this.brandId,
    brandName: brandName ?? this.brandName,
    cftPerVehicle: cftPerVehicle ?? this.cftPerVehicle,
    round: round ?? this.round,
    vehicleNo: vehicleNo ?? this.vehicleNo,
    totalCFT: totalCFT ?? this.totalCFT,
    amount: amount ?? this.amount,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'date': date,
    'party': party,
    'brandId': brandId,
    'brandName': brandName,
    'cftPerVehicle': cftPerVehicle,
    'round': round,
    'vehicleNo': vehicleNo,
    'totalCFT': totalCFT,
    'amount': amount,
  };

  factory Entry.fromMap(Map<String, Object?> map) => Entry(
    id: map['id'] as int?,
    date: map['date'] as String,
    party: map['party'] as String,
    brandId: map['brandId'] as int,
    brandName: map['brandName'] as String,
    cftPerVehicle: (map['cftPerVehicle'] as num).toDouble(),
    round: (map['round'] as num).toDouble(),
    vehicleNo: map['vehicleNo'] as String?,
    totalCFT: (map['totalCFT'] as num).toDouble(),
    amount: (map['amount'] as num).toDouble(),
  );
}

class AppUser {
  final String username;
  final String passwordHash;
  final String? businessName;
  final int? ownerAge;
  final String? ownerGender;
  final String? pinHash;
  // Minutes of background time before the lock screen is shown; 0 = lock
  // immediately on any resume. Null (no PIN set) means locking is off.
  final int? autoLockMinutes;
  final bool biometricEnabled;
  // 'light', 'dark', or 'system' (null treated as 'system').
  final String? themeMode;
  // Absolute path to the saved profile photo file, or null if none set.
  final String? profilePicPath;

  const AppUser({
    required this.username,
    required this.passwordHash,
    this.businessName,
    this.ownerAge,
    this.ownerGender,
    this.pinHash,
    this.autoLockMinutes,
    this.biometricEnabled = false,
    this.themeMode,
    this.profilePicPath,
  });

  /// [clearPin] wipes pinHash/autoLockMinutes/biometricEnabled back to
  /// "no lock configured" — copyWith's usual `?? this.field` pattern can't
  /// express turning a field back to null, so this is the explicit escape
  /// hatch used only by "disable PIN lock".
  AppUser copyWith({
    String? username,
    String? passwordHash,
    String? businessName,
    int? ownerAge,
    String? ownerGender,
    String? pinHash,
    int? autoLockMinutes,
    bool? biometricEnabled,
    String? themeMode,
    String? profilePicPath,
    bool clearPin = false,
    bool clearProfilePic = false,
  }) => AppUser(
    username: username ?? this.username,
    passwordHash: passwordHash ?? this.passwordHash,
    businessName: businessName ?? this.businessName,
    ownerAge: ownerAge ?? this.ownerAge,
    ownerGender: ownerGender ?? this.ownerGender,
    pinHash: clearPin ? null : (pinHash ?? this.pinHash),
    autoLockMinutes: clearPin
        ? null
        : (autoLockMinutes ?? this.autoLockMinutes),
    biometricEnabled: clearPin
        ? false
        : (biometricEnabled ?? this.biometricEnabled),
    themeMode: themeMode ?? this.themeMode,
    profilePicPath: clearProfilePic
        ? null
        : (profilePicPath ?? this.profilePicPath),
  );

  Map<String, Object?> toMap() => {
    'username': username,
    'passwordHash': passwordHash,
    'businessName': businessName,
    'ownerAge': ownerAge,
    'ownerGender': ownerGender,
    'pinHash': pinHash,
    'autoLockMinutes': autoLockMinutes,
    'biometricEnabled': biometricEnabled ? 1 : 0,
    'themeMode': themeMode,
    'profilePicPath': profilePicPath,
  };

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
    username: map['username'] as String,
    passwordHash: map['passwordHash'] as String,
    businessName: map['businessName'] as String?,
    ownerAge: map['ownerAge'] as int?,
    ownerGender: map['ownerGender'] as String?,
    pinHash: map['pinHash'] as String?,
    autoLockMinutes: map['autoLockMinutes'] as int?,
    biometricEnabled: (map['biometricEnabled'] as int?) == 1,
    themeMode: map['themeMode'] as String?,
    profilePicPath: map['profilePicPath'] as String?,
  );
}
