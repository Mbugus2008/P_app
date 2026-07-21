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
      version: 24,
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
        Date_Created TEXT,
        Time_Created TEXT,
        Time_Sent TEXT,
        Time_Collected TEXT,
        Time_Delivered TEXT,
        Description TEXT,
        Details TEXT,
        Payment_Received_By TEXT,
        Created_By TEXT,
        Received_By_ID TEXT,
        Received_By_Phone TEXT,
        Receiver_Code TEXT,
        App_Version TEXT,
        Parcel_Value REAL,
        Payment_Date TEXT,
        Payment_Time TEXT,
        Payment_Method TEXT,
        Mpesa_Code TEXT,
        Is_Synced INTEGER DEFAULT 0,
        Receipt_Printed INTEGER DEFAULT 0,
        Device_ID TEXT
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
        Name TEXT,
        Phone_No TEXT
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
        Sync_Status TEXT,
        Device_ID TEXT
      )
    ''');
    // Note: Removed Created_At and Ref_No as they are not in the Parcel model
    //await _seedSampleParcels(db);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_parcels_date_sent ON $_tableName(Date_sent)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_batches_date ON $_batchesTableName(Date)',
    );
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

    if (oldVersion < 13) {
      for (final column in const [
        'Time_Created',
        'Time_Sent',
        'Time_Collected',
        'Time_Delivered',
      ]) {
        try {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN $column TEXT');
        } catch (_) {
          // Column may already exist on some installs.
        }
      }
    }

    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN Details TEXT');
      } catch (_) {
        // Column may already exist on some installs.
      }
    }

    if (oldVersion < 15) {
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_parcels_date_sent ON $_tableName(Date_sent)',
        );
      } catch (_) {}
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_batches_date ON $_batchesTableName(Date)',
        );
      } catch (_) {}
    }

    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN Device_ID TEXT');
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $_batchesTableName ADD COLUMN Device_ID TEXT',
        );
      } catch (_) {}
    }

    if (oldVersion < 17) {
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Payment_Received_By TEXT',
        );
      } catch (_) {
        // Column may already exist on some installs.
      }
    }

    if (oldVersion < 18) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN Created_By TEXT');
      } catch (_) {
        // Column may already exist on some installs.
      }
    }

    if (oldVersion < 19) {
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Received_By_ID TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Received_By_Phone TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Receiver_Code TEXT',
        );
      } catch (_) {}
    }

    if (oldVersion < 20) {
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Date_Created TEXT',
        );
      } catch (_) {}
    }

    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN App_Version TEXT');
      } catch (_) {}
    }

    if (oldVersion < 22) {
      try {
        await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN Parcel_Value REAL',
        );
      } catch (_) {}
    }

    if (oldVersion < 24) {
      try {
        await db.execute(
          'ALTER TABLE $_locationsTableName ADD COLUMN Phone_No TEXT',
        );
      } catch (_) {}
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

  /// Returns all parcel Document_Nos referenced in any batch.
  Future<Set<String>> getAllBatchParcelDocNos() async {
    final db = await database;
    final rows = await db.query(
      _batchesTableName,
      columns: ['Parcel_Document_Nos'],
    );
    final docNos = <String>{};
    for (final row in rows) {
      final raw = (row['Parcel_Document_Nos'] ?? '').toString();
      if (raw.isEmpty) continue;
      // Batch doc nos are stored as comma-separated or JSON list
      for (final doc in raw.split(',')) {
        final trimmed = doc.trim().toUpperCase();
        if (trimmed.isNotEmpty) docNos.add(trimmed);
      }
    }
    return docNos;
  }

  /// Deletes synced parcels not present in the pulled set (deleted on BC).
  Future<int> deleteOrphanParcels(Set<String> pulledDocNos) async {
    if (pulledDocNos.isEmpty) return 0;
    final db = await database;
    // Protect parcels referenced in any batch — never delete those
    final batchDocs = await getAllBatchParcelDocNos();
    // Delete synced parcels whose Document_No is NOT in pulledDocNos
    final all = await db.query(
      _tableName,
      columns: ['Document_No'],
      where: 'Is_Synced = 1',
    );
    final toDelete = <String>[];
    for (final row in all) {
      final doc = (row['Document_No'] ?? '').toString().trim().toUpperCase();
      if (doc.isNotEmpty &&
          !pulledDocNos.contains(doc) &&
          !batchDocs.contains(doc)) {
        toDelete.add(doc);
      }
    }
    if (toDelete.isEmpty) return 0;
    final placeholders = List.filled(toDelete.length, '?').join(', ');
    return await db.delete(
      _tableName,
      where: "Document_No IN ($placeholders)",
      whereArgs: toDelete,
    );
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

  Future<int> deleteBatch(String batchNo) async {
    final db = await database;
    return await db.delete(
      _batchesTableName,
      where: 'Batch_No = ?',
      whereArgs: [batchNo],
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
          "Status IN ('inTransit','In Transist','Intransit','In_Transit','In_Transist') AND (To_Location COLLATE NOCASE IN ($placeholders) OR Destination COLLATE NOCASE IN ($placeholders))",
      whereArgs: [...args, ...args],
      orderBy: 'Created_At DESC',
    );
    return rows.map((row) => Batches.fromDbMap(row)).toList();
  }

  /// Batches dispatched FROM the user's location (outgoing).
  Future<List<Batches>> getDispatchedBatchesForLocation(
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
          "Status IN ('inTransit','In Transist','Intransit','In_Transit','In_Transist') AND (From_Location COLLATE NOCASE IN ($placeholders) OR Source COLLATE NOCASE IN ($placeholders))",
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
          "Status IN ('received','Waiting Collection','Waiting_Collection','waiting_collection','Delivered','Received','delivered') AND To_Location COLLATE NOCASE IN ($placeholders)",
      whereArgs: candidates.toList(),
      orderBy: 'Date_Delivered DESC',
    );
    return rows.map((row) => Parcel.fromDbMap(row)).toList();
  }

  // ==================== Report Queries ====================

  String _dateWhereClause(String dateField, {DateTime? from, DateTime? to}) {
    final conditions = <String>[];
    if (from != null) {
      conditions.add(
        "$dateField >= '${from.toIso8601String().split('T').first}'",
      );
    }
    if (to != null) {
      final nextDay =
          to.add(const Duration(days: 1)).toIso8601String().split('T').first;
      conditions.add("$dateField < '$nextDay'");
    }
    return conditions.isEmpty ? '1=1' : conditions.join(' AND ');
  }

  String _deviceWhereClause(String deviceId) {
    if (deviceId.isEmpty) return '1=1';
    return "Device_ID = '$deviceId'";
  }

  /// Status Breakdown: count + total revenue grouped by status
  Future<List<Map<String, dynamic>>> getStatusBreakdown({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT Status, COUNT(*) as count, COALESCE(SUM(Amount_Paid), 0) as total_amount
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY Status
      ORDER BY COUNT(*) DESC
    ''');
  }

  /// Daily Volume: count + total revenue grouped by date
  Future<List<Map<String, dynamic>>> getDailyVolume({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT substr(Date_sent, 1, 10) as date, COUNT(*) as count,
             COALESCE(SUM(Amount_Paid), 0) as total_amount
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY date
      ORDER BY date DESC
    ''');
  }

  /// Revenue breakdown by period (daily summary focused on Amount_Paid)
  Future<List<Map<String, dynamic>>> getRevenueBreakdown({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT substr(Date_sent, 1, 10) as date,
             COUNT(*) as count,
             COALESCE(SUM(Amount_Paid), 0) as total_amount,
             COALESCE(SUM(CASE WHEN Paid = 1 THEN Amount_Paid ELSE 0 END), 0) as paid_amount,
             COALESCE(SUM(CASE WHEN Paid = 0 THEN Amount_Paid ELSE 0 END), 0) as unpaid_amount
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY date
      ORDER BY date DESC
    ''');
  }

  /// Route Performance: count + total revenue grouped by From-Location and To-Location
  Future<List<Map<String, dynamic>>> getRoutePerformance({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT From_Location as source, To_Location as destination,
             COUNT(*) as count, COALESCE(SUM(Amount_Paid), 0) as total_amount
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY source, destination
      ORDER BY count DESC
    ''');
  }

  /// Driver Workload: count + total revenue grouped by driver
  Future<List<Map<String, dynamic>>> getDriverWorkload({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT Driver, COUNT(*) as count, COALESCE(SUM(Amount_Paid), 0) as total_amount
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY Driver
      ORDER BY count DESC
    ''');
  }

  /// Vehicle Workload: count + total revenue grouped by vehicle
  Future<List<Map<String, dynamic>>> getVehicleWorkload({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT Vehicle, COUNT(*) as count, COALESCE(SUM(Amount_Paid), 0) as total_amount
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY Vehicle
      ORDER BY count DESC
    ''');
  }

  /// Payment Method Breakdown: count + total revenue grouped by Payment_Method
  Future<List<Map<String, dynamic>>> getPaymentMethodBreakdown({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT COALESCE(NULLIF(Payment_Method, ''), 'pending') as method,
             COUNT(*) as count,
             COALESCE(SUM(Amount_Paid), 0) as total_amount,
             SUM(CASE WHEN Paid = 1 THEN 1 ELSE 0 END) as paid_count,
             SUM(CASE WHEN Paid = 0 THEN 1 ELSE 0 END) as unpaid_count
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY method
      ORDER BY count DESC
    ''');
  }

  /// My Collections: payment breakdown for the logged-in agent
  Future<List<Map<String, dynamic>>> getMyCollections({
    DateTime? from,
    DateTime? to,
    required String deviceId,
    required String agentCode,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    return db.rawQuery(
      '''
      SELECT COALESCE(NULLIF(Payment_Method, ''), 'pending') as method,
             COUNT(*) as count,
             COALESCE(SUM(Amount_Paid), 0) as total_amount,
             SUM(CASE WHEN Paid = 1 THEN 1 ELSE 0 END) as paid_count,
             SUM(CASE WHEN Paid = 0 THEN 1 ELSE 0 END) as unpaid_count
      FROM $_tableName
      WHERE $dateWhere
        AND Payment_Received_By = ?
      GROUP BY method
      ORDER BY count DESC
    ''',
      [agentCode],
    );
  }

  /// My Parcels: all parcels created by me OR sent to my location
  Future<Map<String, dynamic>> getMyCollectedParcels({
    DateTime? from,
    DateTime? to,
    required String agentCode,
    required List<String> locations,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final candidates = locations.where((l) => l.trim().isNotEmpty).toSet();
    if (candidates.isEmpty)
      return {'detail': [], 'myCreated': [], 'fromOthers': []};
    final placeholders = candidates.map((_) => '?').join(', ');
    final locationArgs = candidates.toList();

    // All parcels from my location OR collected by me
    final detail = await db.rawQuery(
      '''
      SELECT From_Location as "from",
             Document_No as docNo,
             Sender_Name as sender,
             Receiver_Name as receiver,
             Amount_Paid as amount,
             COALESCE(NULLIF(Payment_Method, ''), 'Pending') as method,
             Status as status,
             CASE WHEN From_Location COLLATE NOCASE IN ($placeholders) THEN 'Mine' ELSE 'Incoming' END as origin
      FROM $_tableName
      WHERE $dateWhere
        AND (From_Location COLLATE NOCASE IN ($placeholders) OR Payment_Received_By = ?)
      ORDER BY Date_sent DESC
    ''',
      [...locationArgs, ...locationArgs, agentCode],
    );

    // Summary 1: Cash and M-Pesa for parcels from my location
    final myCreated = await db.rawQuery('''
      SELECT 
        COALESCE(NULLIF(Payment_Method, ''), 'Pending') as method,
        COUNT(*) as count,
        COALESCE(SUM(Amount_Paid), 0) as total
      FROM $_tableName
      WHERE $dateWhere AND From_Location COLLATE NOCASE IN ($placeholders)
      GROUP BY method
      ORDER BY count DESC
    ''', locationArgs);

    // Summary 2: Cash and M-Pesa collected from other locations
    final fromOthers = await db.rawQuery(
      '''
      SELECT 
        COALESCE(NULLIF(Payment_Method, ''), 'Pending') as method,
        COUNT(*) as count,
        COALESCE(SUM(Amount_Paid), 0) as total
      FROM $_tableName
      WHERE $dateWhere
        AND Payment_Received_By = ?
        AND From_Location COLLATE NOCASE NOT IN ($placeholders)
      GROUP BY method
      ORDER BY count DESC
    ''',
      [agentCode, ...locationArgs],
    );

    return {'detail': detail, 'myCreated': myCreated, 'fromOthers': fromOthers};
  }

  /// Batch Performance: batch stats grouped by status
  Future<List<Map<String, dynamic>>> getBatchPerformance({
    DateTime? from,
    DateTime? to,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT Status, COUNT(*) as count,
             COALESCE(SUM(Parcel_Count), 0) as total_parcels,
             COALESCE(SUM(Total_Amount), 0) as total_amount
      FROM $_batchesTableName
      WHERE $dateWhere AND $deviceWhere
      GROUP BY Status
      ORDER BY count DESC
    ''');
  }

  /// Activity Log: recent parcel status changes as an audit trail
  Future<List<Map<String, dynamic>>> getActivityLog({
    DateTime? from,
    DateTime? to,
    int limit = 200,
    required String deviceId,
  }) async {
    final db = await database;
    final dateWhere = _dateWhereClause('Date_sent', from: from, to: to);
    final deviceWhere = _deviceWhereClause(deviceId);
    return db.rawQuery('''
      SELECT Document_No, Date_sent, Status, Sender_Name, Receiver_Name,
             From_Location, To_Location, Driver, Amount_Paid, Payment_Method,
             Time_Created, Time_Sent, Date_Collected, Date_Delivered
      FROM $_tableName
      WHERE $dateWhere AND $deviceWhere
      ORDER BY Date_sent DESC
      LIMIT $limit
    ''');
  }
}
