import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static String? _activeUserId;

  static String? get currentUserId => _activeUserId;

  static Future<void> switchUser(String userId) async {
    if (_activeUserId == userId && _database != null) return;
    
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    _activeUserId = userId;
    _database = await _instance._initDatabase(userId);
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _activeUserId = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_activeUserId == null) {
      throw Exception('DatabaseHelper: No active user set. Call switchUser(userId) before accessing the database.');
    }
    _database = await _initDatabase(_activeUserId!);
    return _database!;
  }

  Future<Database> _initDatabase(String userId) async {
    final dbName = 'ai_productivity_tracker_user_$userId.db';

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        dbName,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } 
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, dbName);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // pending_mutations
    await db.execute('''
      CREATE TABLE pending_mutations (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        action TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0
      )
    ''');

    // todos_cache
    await db.execute('''
      CREATE TABLE todos_cache (
        localId TEXT PRIMARY KEY,
        serverId INTEGER,
        syncStatus TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        dueDate TEXT NOT NULL,
        completed INTEGER DEFAULT 0,
        completedAt TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        userId TEXT,
        deletedFlag INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');

    // routines_cache
    await db.execute('''
      CREATE TABLE routines_cache (
        localId TEXT PRIMARY KEY,
        serverId INTEGER,
        syncStatus TEXT NOT NULL,
        date TEXT NOT NULL,
        studyCompleted INTEGER DEFAULT 0,
        exerciseCompleted INTEGER DEFAULT 0,
        mlCompleted INTEGER DEFAULT 0,
        studyHours REAL DEFAULT 0.0,
        sleepTime TEXT DEFAULT '23:00',
        wakeTime TEXT DEFAULT '07:00',
        mobileUsage REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        productivityScore INTEGER DEFAULT 0,
        coreChecklistsJson TEXT DEFAULT '{}',
        coreMetricsJson TEXT DEFAULT '{}',
        customLogsJson TEXT DEFAULT '[]',
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        userId TEXT,
        deletedFlag INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');

    // focus_sessions_cache
    await db.execute('''
      CREATE TABLE focus_sessions_cache (
        localId TEXT PRIMARY KEY,
        serverId INTEGER,
        syncStatus TEXT NOT NULL,
        sessionType TEXT NOT NULL,
        label TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        durationMinutes INTEGER NOT NULL,
        completed INTEGER DEFAULT 0,
        lapsJson TEXT DEFAULT '[]',
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        userId TEXT,
        deletedFlag INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');

    // calendar_events_cache
    await db.execute('''
      CREATE TABLE calendar_events_cache (
        localId TEXT PRIMARY KEY,
        serverId INTEGER,
        syncStatus TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        allDay INTEGER DEFAULT 0,
        googleEventId TEXT,
        syncedToGoogle INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        userId TEXT,
        deletedFlag INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');

    // notifications_cache
    await db.execute('''
      CREATE TABLE notifications_cache (
        localId TEXT PRIMARY KEY,
        serverId INTEGER,
        syncStatus TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        payloadJson TEXT DEFAULT '{}',
        scheduledFor TEXT,
        deliveredAt TEXT,
        readAt TEXT,
        dismissedAt TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        userId TEXT,
        deletedFlag INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');

    // achievements_cache
    await db.execute('''
      CREATE TABLE achievements_cache (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        earned INTEGER DEFAULT 0,
        earnedText TEXT,
        progressText TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT,
        deletedFlag INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');

    // analytics_snapshots_cache
    await db.execute('''
      CREATE TABLE analytics_snapshots_cache (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        snapshotType TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        createdAt TEXT,
        updatedAt TEXT,
        syncStatus TEXT,
        deletedFlag INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS achievements_cache (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          name TEXT NOT NULL,
          icon TEXT,
          color TEXT,
          earned INTEGER DEFAULT 0,
          earnedText TEXT,
          progressText TEXT,
          createdAt TEXT,
          updatedAt TEXT,
          syncStatus TEXT,
          deletedFlag INTEGER DEFAULT 0,
          deviceId TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS analytics_snapshots_cache (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          snapshotType TEXT NOT NULL,
          payloadJson TEXT NOT NULL,
          createdAt TEXT,
          updatedAt TEXT,
          syncStatus TEXT,
          deletedFlag INTEGER DEFAULT 0,
          deviceId TEXT
        )
      ''');

      try { await db.execute("ALTER TABLE todos_cache ADD COLUMN userId TEXT;"); } catch(_) {}
      try { await db.execute("ALTER TABLE todos_cache ADD COLUMN deletedFlag INTEGER DEFAULT 0;"); } catch(_) {}
      try { await db.execute("ALTER TABLE todos_cache ADD COLUMN deviceId TEXT;"); } catch(_) {}

      try { await db.execute("ALTER TABLE routines_cache ADD COLUMN userId TEXT;"); } catch(_) {}
      try { await db.execute("ALTER TABLE routines_cache ADD COLUMN deletedFlag INTEGER DEFAULT 0;"); } catch(_) {}
      try { await db.execute("ALTER TABLE routines_cache ADD COLUMN deviceId TEXT;"); } catch(_) {}

      try { await db.execute("ALTER TABLE focus_sessions_cache ADD COLUMN userId TEXT;"); } catch(_) {}
      try { await db.execute("ALTER TABLE focus_sessions_cache ADD COLUMN deletedFlag INTEGER DEFAULT 0;"); } catch(_) {}
      try { await db.execute("ALTER TABLE focus_sessions_cache ADD COLUMN deviceId TEXT;"); } catch(_) {}

      try { await db.execute("ALTER TABLE calendar_events_cache ADD COLUMN userId TEXT;"); } catch(_) {}
      try { await db.execute("ALTER TABLE calendar_events_cache ADD COLUMN deletedFlag INTEGER DEFAULT 0;"); } catch(_) {}
      try { await db.execute("ALTER TABLE calendar_events_cache ADD COLUMN deviceId TEXT;"); } catch(_) {}

      try { await db.execute("ALTER TABLE notifications_cache ADD COLUMN userId TEXT;"); } catch(_) {}
      try { await db.execute("ALTER TABLE notifications_cache ADD COLUMN deletedFlag INTEGER DEFAULT 0;"); } catch(_) {}
      try { await db.execute("ALTER TABLE notifications_cache ADD COLUMN deviceId TEXT;"); } catch(_) {}
    }

    if (oldVersion < 3) {
      try { await db.execute("ALTER TABLE calendar_events_cache ADD COLUMN syncedToGoogle INTEGER DEFAULT 0;"); } catch(_) {}
    }
  }

  // --- Helper Methods ---
  
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> data, String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, data, where: whereClause, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: whereClause, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy, int? limit}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

}
