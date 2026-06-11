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

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        'ai_productivity_tracker.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _onCreate,
        ),
      );
    } 
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, 'ai_productivity_tracker.db');

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
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
        deletedAt TEXT
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
        deletedAt TEXT
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
        deletedAt TEXT
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
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT
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
        deletedAt TEXT
      )
    ''');
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
