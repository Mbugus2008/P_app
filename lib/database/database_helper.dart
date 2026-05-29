import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_location.dart';
import '../models/app_user.dart';
import '../models/app_vehicle.dart';
import '../models/batches.dart';
import '../models/parcel_model.dart';
import '../utilities/password_crypto.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String _tableName = 'parcels';
  static const String _usersTableName = 'users';
  static const String _locationsTableName = 'locations';
  static const String _vehiclesTableName = 'vehicles';
  static const String _batchesTableName = 'batches';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'parcels_database.db');
    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        Document_No TEXT PRIMARY KEY,
        Batch_No TEXT,
        Date_sent TEXT NOT NULL,
        Sender_Name TEXT NOT NULL,
        Sender_ID TEXT,
        Sender_Phone TEXT NOT NULL,
        From_Location TEXT NOT NULL, 
        To_Location TEXT NOT NULL,
        Receiver_Name TEXT NOT NULL,
        Receiver_ID TEXT,
        Receiver_Phone TEXT NOT NULL,
        Status TEXT NOT NULL,
        Driver TEXT NOT NULL,
        Vehicle TEXT NOT NULL,
        WhoToPay TEXT NOT NULL, 
        Amount_Paid REAL NOT NULL,
        Paid INTEGER NOT NULL,
        Date_Collected TEXT,
        Date_Delivered TEXT,
        Out_For_Delivery_Time TEXT,
        Date_Returned TEXT,
        Description TEXT,
        Payment_Method TEXT,
        Mpesa_Code TEXT,
        Is_Synced INTEGER DEFAULT 0,
        Receipt_Printed INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE $_usersTableName (
        Agent_Code TEXT PRIMARY KEY,
        Name TEXT,
        Mobile_No TEXT,
        Password TEXT,
        Location TEXT,
        Account_Type TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $_locationsTableName (
        Code TEXT PRIMARY KEY,
        Name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $_vehiclesTableName (
        Code TEXT PRIMARY KEY,
        Vehicle_Number TEXT,
        Vehicle_Type TEXT,
        Category TEXT,
        Status TEXT,
        Fleet_No TEXT,
        Start_Date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $_batchesTableName (
        Batch_No TEXT PRIMARY KEY,
        Date TEXT,
        User TEXT,
        User_Agent_Code TEXT,
        User_Name TEXT,
        Status TEXT,
        Parcel_Document_Nos TEXT,
        Parcel_Count INTEGER,
        Total_Amount REAL,
        Source TEXT,
        Destination TEXT,
        From_Location TEXT,
        To_Location TEXT,
        Vehicle TEXT,
        Driver TEXT,
        Dispatch_DateTime TEXT,
        Received_DateTime TEXT,
        Created_At TEXT,
        Updated_At TEXT,
        Is_Synced INTEGER,
        Sync_Status TEXT
      )
    ''');
    // Note: Removed Created_At and Ref_No as they are not in the Parcel model
    //await _seedSampleParcels(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_usersTableName (
          Agent_Code TEXT PRIMARY KEY,
          Name TEXT,
          Mobile_No TEXT,
          Password TEXT,
          Location TEXT,
          Account_Type TEXT
        )
      ''');
    }

    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE $_usersTableName ADD COLUMN Location TEXT',
        );
      } catch (_) {
        // Column already exists on some installs.
      }
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_locationsTableName (
          Code TEXT PRIMARY KEY,
          Name TEXT
        )
      ''');
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN Batch_No TEXT');
      } catch (_) {
        // Column already exists on some installs.
      }
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_vehiclesTableName (
          Code TEXT PRIMARY KEY,
          Vehicle_Number TEXT,
          Vehicle_Type TEXT,
          Category TEXT,
          Status TEXT,
          Fleet_No TEXT,
          Start_Date TEXT
        )
      ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_batchesTableName (
          Batch_No TEXT PRIMARY KEY,
          Date TEXT,
          User TEXT,
          User_Agent_Code TEXT,
          User_Name TEXT,
          Status TEXT,
          Parcel_Document_Nos TEXT,
          Parcel_Count INTEGER,
          Total_Amount REAL,
          Source TEXT,
          Destination TEXT,
          From_Location TEXT,
          To_Location TEXT,
          Vehicle TEXT,
          Driver TEXT,
          Dispatch_DateTime TEXT,
          Received_DateTime TEXT,
          Created_At TEXT,
          Updated_At TEXT,
          Is_Synced INTEGER,
          Sync_Status TEXT
        )
      ''');
    }

    if (oldVersion < 8) {
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Payment_Method TEXT',
        );
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN Mpesa_Code TEXT');
      } catch (_) {}
    }

    if (oldVersion < 9) {
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Is_Synced INTEGER DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Receipt_Printed INTEGER DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 11) {
      // Defensive migration: some installs were left without this column.
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Receipt_Printed INTEGER DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 12) {
      try {
        await db.execute(
          'ALTER TABLE $_usersTableName ADD COLUMN Account_Type TEXT',
        );
      } catch (_) {
        // Column may already exist on some installs.
      }
    }
  }

  // Future<void> _seedSampleParcels(Database db) async {
  //   final now = DateTime.now();
  //   const origins = <String>[
  //     'Nairobi',
  //     'Mombasa',
  //     'Kisumu',
  //     'Nakuru',
  //     'Eldoret',
  //   ];
  //   const destinations = <String>[
  //     'Mombasa',
  //     'Nairobi',
  //     'Kampala',
  //     'Dar es Salaam',
  //     'Kigali',
  //   ];
  //   const drivers = <String>['Kamau', 'Achieng', 'Otieno', 'Mwangi', 'Karanja'];
  //   const vehicles = <String>[
  //     'KBA 123X',
  //     'KBB 456Y',
  //     'KBC 789Z',
  //     'KBD 234A',
  //     'KBE 567B',
  //   ];
  //   const statusLabels = <ParcelStatus, String>{
  //     ParcelStatus.pending: 'Pending',
  //     ParcelStatus.inTransit: 'In Transit',
  //     ParcelStatus.received: 'Received',
  //     ParcelStatus.collected: 'Collected',
  //   };

  //   final samples = List<Parcel>.generate(20, (index) {
  //     final status = ParcelStatus.values[index % ParcelStatus.values.length];
  //     final sentDate = now.subtract(Duration(days: index * 2));
  //     final outForDelivery =
  //         status == ParcelStatus.inTransit ||
  //                 status == ParcelStatus.received ||
  //                 status == ParcelStatus.collected
  //             ? sentDate.add(const Duration(hours: 8))
  //             : null;
  //     final deliveredDate =
  //         (status == ParcelStatus.received || status == ParcelStatus.collected)
  //             ? sentDate.add(const Duration(days: 1))
  //             : null;
  //     final collectedDate =
  //         status == ParcelStatus.collected
  //             ? sentDate.add(const Duration(days: 2))
  //             : null;
  //     final whoPays = index.isEven ? WhoToPay.Sender : WhoToPay.Receiver;

  //     return Parcel(
  //       Document_No: 'SAMPLE-${(index + 1).toString().padLeft(3, '0')}',
  //       Date_sent: sentDate,
  //       Sender_Name: 'Sender ${index + 1}',
  //       Sender_ID: 'SID${(index + 1).toString().padLeft(4, '0')}',
  //       Sender_Phone: '070${(index + 1234567).toString().padLeft(7, '0')}',
  //       From: origins[index % origins.length],
  //       To: destinations[index % destinations.length],
  //       Receiver_Name: 'Receiver ${index + 1}',
  //       Receiver_ID: 'RID${(index + 1).toString().padLeft(4, '0')}',
  //       Receiver_Phone: '079${(index + 7654321).toString().padLeft(7, '0')}',
  //       Status: status,
  //       Driver: drivers[index % drivers.length],
  //       Vehicle: vehicles[index % vehicles.length],
  //       Who_to_Pay: whoPays,
  //       Amount_Paid: (1500 + index * 75).toDouble(),
  //       Paid: status == ParcelStatus.collected || index % 4 == 0,
  //       Date_Delivered: deliveredDate,
  //       Date_Collected: collectedDate,
  //       Out_For_Delivery_Time: outForDelivery,
  //       Notes: 'Demo parcel ${(index + 1)} (${statusLabels[status]}).',
  //     );
  //   });

  //   final batch = db.batch();
  //   for (final parcel in samples) {
  //     batch.insert(
  //       _tableName,
  //       parcel.toDbMap(),
  //       conflictAlgorithm: ConflictAlgorithm.replace,
  //     );
  //   }
  //   await batch.commit(noResult: true);
  // }
  // // --- CRUD Operations ---

  /// Inserts a parcel into the database.
  /// Returns the id of the last inserted row.
  Future<int> insertParcel(Parcel parcel) async {
    final db = await database;
    return await db.insert(
      _tableName,
      parcel.toDbMap(),
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Replace if Document_No already exists
    );
  }

  /// Retrieves a single parcel by its Document_No.
  /// Returns the Parcel if found, otherwise null.
  Future<Parcel?> getParcel(String documentNo) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'Document_No = ?',
      whereArgs: [documentNo],
    );

    if (maps.isNotEmpty) {
      return Parcel.fromDbMap(maps.first);
    }
    return null;
  }

  /// Retrieves all parcels from the database.
  /// Returns a list of Parcels.
  Future<List<Parcel>> getAllParcels() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);

    return List.generate(maps.length, (i) {
      return Parcel.fromDbMap(maps[i]);
    });
  }

  Future<int> getNextDocumentSerial(String prefix) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      columns: ['Document_No'],
      where: 'Document_No LIKE ?',
      whereArgs: ['$prefix%'],
    );

    var maxSerial = 0;
    for (final row in rows) {
      final docNo = (row['Document_No'] ?? '').toString();
      if (!docNo.startsWith(prefix)) continue;

      var serialPart = docNo.substring(prefix.length).trim();
      if (serialPart.startsWith('-')) {
        serialPart = serialPart.substring(1);
      }
      final serial = int.tryParse(serialPart) ?? 0;
      if (serial > maxSerial) {
        maxSerial = serial;
      }
    }

    return maxSerial + 1;
  }

  /// Updates an existing parcel in the database.
  /// Returns the number of rows affected.
  Future<int> updateParcel(Parcel parcel) async {
    final db = await database;
    return await db.update(
      _tableName,
      parcel.toDbMap(),
      where: 'Document_No = ?',
      whereArgs: [parcel.Document_No],
    );
  }

  /// Deletes a parcel from the database by its Document_No.
  /// Returns the number of rows affected.
  Future<int> deleteParcel(String documentNo) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'Document_No = ?',
      whereArgs: [documentNo],
    );
  }

  Future<List<Parcel>> getUnsyncedParcels() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where:
          "Is_Synced = 0 AND LOWER(Status) IN ('intransit','received','collected')",
    );
    return rows.map((row) => Parcel.fromDbMap(row)).toList();
  }

  /// Document numbers of parcels with local changes not yet pushed to the
  /// backend. Used to protect them from being overwritten by a pull.
  Future<Set<String>> getUnsyncedParcelDocumentNos() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      columns: ['Document_No'],
      where: 'Is_Synced = 0',
    );
    return rows
        .map((r) => (r['Document_No'] ?? '').toString().trim().toUpperCase())
        .where((d) => d.isNotEmpty)
        .toSet();
  }

  Future<void> upsertParcels(List<Parcel> parcels) async {
    if (parcels.isEmpty) return;

    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final parcel in parcels) {
        if ((parcel.Document_No ?? '').trim().isEmpty) continue;
        batch.insert(
          _tableName,
          parcel.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceUsers(List<AppUser> users) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_usersTableName);
      final batch = txn.batch();
      for (final user in users) {
        if (user.agentCode.trim().isEmpty) continue;
        batch.insert(
          _usersTableName,
          _userToSecureDbMap(user),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertUser(AppUser user) async {
    final db = await database;
    await db.insert(
      _usersTableName,
      _userToSecureDbMap(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getUsersCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_usersTableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> replaceLocations(List<AppLocation> locations) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_locationsTableName);
      final batch = txn.batch();
      for (final location in locations) {
        if (location.code.trim().isEmpty) continue;
        batch.insert(
          _locationsTableName,
          location.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<AppLocation>> getAllLocations() async {
    final db = await database;
    final rows = await db.query(_locationsTableName, orderBy: 'Name ASC');
    return rows.map((row) => AppLocation.fromDbMap(row)).toList();
  }

  Future<int> getLocationsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_locationsTableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> replaceVehicles(List<AppVehicle> vehicles) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_vehiclesTableName);
      final batch = txn.batch();
      for (final vehicle in vehicles) {
        if (vehicle.code.trim().isEmpty) continue;
        batch.insert(
          _vehiclesTableName,
          vehicle.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<AppVehicle>> getAllVehicles() async {
    final db = await database;
    final rows = await db.query(_vehiclesTableName, orderBy: 'Code ASC');
    return rows.map((row) => AppVehicle.fromDbMap(row)).toList();
  }

  Future<int> getVehiclesCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_vehiclesTableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<AppUser?> getUserForLogin({
    required String identifier,
    required String password,
  }) async {
    final db = await database;
    final cleanIdentifier = identifier.trim();
    final cleanPassword = password.trim();

    final rows = await db.query(
      _usersTableName,
      where: 'Agent_Code = ? COLLATE NOCASE OR Mobile_No = ?',
      whereArgs: [cleanIdentifier, cleanIdentifier],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final row = rows.first;
    final storedPassword = (row['Password'] ?? '').toString();
    final isValid = PasswordCrypto.verifyPassword(
      password: cleanPassword,
      storedPassword: storedPassword,
    );

    if (!isValid) return null;

    // One-time migration of legacy plain-text passwords on successful login.
    if (!PasswordCrypto.isHashedPassword(storedPassword)) {
      await updateUserPassword(
        agentCode: (row['Agent_Code'] ?? '').toString(),
        password: cleanPassword,
      );
    }

    return AppUser.fromDbMap(row);
  }

  Future<AppUser?> getUserByIdentifier(String identifier) async {
    final db = await database;
    final cleanIdentifier = identifier.trim();
    final rows = await db.query(
      _usersTableName,
      where: 'Agent_Code = ? COLLATE NOCASE OR Mobile_No = ?',
      whereArgs: [cleanIdentifier, cleanIdentifier],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return AppUser.fromDbMap(rows.first);
  }

  Future<int> updateUserPassword({
    required String agentCode,
    required String password,
  }) async {
    final db = await database;
    return db.update(
      _usersTableName,
      {'Password': PasswordCrypto.hashIfNeeded(password)},
      where: 'Agent_Code = ?',
      whereArgs: [agentCode.trim()],
    );
  }

  Map<String, dynamic> _userToSecureDbMap(AppUser user) {
    final map = user.toDbMap();
    map['Password'] = PasswordCrypto.hashIfNeeded(
      (map['Password'] ?? '').toString(),
    );
    return map;
  }

  // --- Batch Operations ---

  Future<Batches?> getPendingBatchByRoute(String from, String to) async {
    final db = await database;
    final rows = await db.query(
      _batchesTableName,
      where:
          "Status = 'pending' AND (From_Location = ? COLLATE NOCASE OR Source = ? COLLATE NOCASE) AND (To_Location = ? COLLATE NOCASE OR Destination = ? COLLATE NOCASE)",
      whereArgs: [from, from, to, to],
      orderBy: 'Created_At DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Batches.fromDbMap(rows.first);
  }

  Future<List<Batches>> getPendingBatches() async {
    final db = await database;
    final rows = await db.query(
      _batchesTableName,
      where: "Status = 'pending'",
      orderBy: 'Created_At DESC',
    );
    return rows.map((row) => Batches.fromDbMap(row)).toList();
  }

  Future<int> insertBatch(Batches batch) async {
    final db = await database;
    return await db.insert(
      _batchesTableName,
      batch.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateBatch(Batches batch) async {
    final db = await database;
    return await db.update(
      _batchesTableName,
      batch.toDbMap(),
      where: 'Batch_No = ?',
      whereArgs: [batch.batchNo],
    );
  }

  Future<Batches?> getBatch(String batchNo) async {
    final db = await database;
    final rows = await db.query(
      _batchesTableName,
      where: 'Batch_No = ?',
      whereArgs: [batchNo],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Batches.fromDbMap(rows.first);
  }

  Future<List<Batches>> getAllBatches() async {
    final db = await database;
    final rows = await db.query(_batchesTableName, orderBy: 'Created_At DESC');
    return rows.map((row) => Batches.fromDbMap(row)).toList();
  }

  Future<List<Batches>> getUnsyncedBatches() async {
    final db = await database;
    final rows = await db.query(
      _batchesTableName,
      where:
          "Is_Synced = 0 AND LOWER(Status) IN ('intransit','received','collected')",
    );
    return rows.map((row) => Batches.fromDbMap(row)).toList();
  }

  /// Batch numbers with local changes not yet pushed to the backend. Used to
  /// protect them from being overwritten by a pull.
  Future<Set<String>> getUnsyncedBatchNos() async {
    final db = await database;
    final rows = await db.query(
      _batchesTableName,
      columns: ['Batch_No'],
      where: 'Is_Synced = 0',
    );
    return rows
        .map((r) => (r['Batch_No'] ?? '').toString().trim().toUpperCase())
        .where((b) => b.isNotEmpty)
        .toSet();
  }

  Future<void> upsertBatches(List<Batches> batches) async {
    if (batches.isEmpty) return;

    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final item in batches) {
        if ((item.batchNo ?? '').trim().isEmpty) continue;
        batch.insert(
          _batchesTableName,
          item.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Batches>> getInTransitBatchesForLocation(
    List<String> locations,
  ) async {
    final candidates =
        locations.map((l) => l.trim()).where((l) => l.isNotEmpty).toSet();
    if (candidates.isEmpty) return <Batches>[];

    final db = await database;
    final placeholders = List.filled(candidates.length, '?').join(', ');
    final args = candidates.toList();
    final rows = await db.query(
      _batchesTableName,
      where:
          "Status = 'inTransit' AND (To_Location COLLATE NOCASE IN ($placeholders) OR Destination COLLATE NOCASE IN ($placeholders))",
      whereArgs: [...args, ...args],
      orderBy: 'Created_At DESC',
    );
    return rows.map((row) => Batches.fromDbMap(row)).toList();
  }

  Future<List<Parcel>> getReceivedParcelsForLocation(
    List<String> locations,
  ) async {
    final candidates =
        locations.map((l) => l.trim()).where((l) => l.isNotEmpty).toSet();
    if (candidates.isEmpty) return <Parcel>[];

    final db = await database;
    final placeholders = List.filled(candidates.length, '?').join(', ');
    final rows = await db.query(
      _tableName,
      where:
          "Status = 'received' AND To_Location COLLATE NOCASE IN ($placeholders)",
      whereArgs: candidates.toList(),
      orderBy: 'Date_Delivered DESC',
    );
    return rows.map((row) => Parcel.fromDbMap(row)).toList();
  }
}
