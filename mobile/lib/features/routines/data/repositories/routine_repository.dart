import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_engine.dart';
import '../models/routine_model.dart';
import 'package:uuid/uuid.dart';

class RoutineRepository {
  final Dio _dio = apiClient.dio;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncEngine _syncEngine = SyncEngine();

  Future<List<RoutineModel>> getRoutines() async {
    final rows = await _dbHelper.query('routines_cache', orderBy: 'date DESC, createdAt DESC');
    
    final seenDates = <String>{};
    final routines = <RoutineModel>[];
    
    for (final r in rows) {
      final map = Map<String, dynamic>.from(r);
      map['coreChecklists'] = jsonDecode(map['coreChecklistsJson'] ?? '{}');
      map['coreMetrics'] = jsonDecode(map['coreMetricsJson'] ?? '{}');
      map['customLogs'] = jsonDecode(map['customLogsJson'] ?? '[]');
      final routine = RoutineModel.fromJson(map);
      
      if (!seenDates.contains(routine.date)) {
        seenDates.add(routine.date);
        routines.add(routine);
      } else {
        // Silently clean up older duplicates from the local database
        _dbHelper.delete('routines_cache', 'localId = ?', [routine.id]);
      }
    }

    _syncEngine.syncNow();
    return routines;
  }

  Map<String, dynamic> _toDbFormat(RoutineModel routine) {
    final map = routine.toJson();
    map['syncStatus'] = routine.syncStatus;
    map['coreChecklistsJson'] = jsonEncode(map['core_checklists'] ?? {});
    map['coreMetricsJson'] = jsonEncode(map['core_metrics'] ?? {});
    map['customLogsJson'] = jsonEncode(map['custom_logs'] ?? []);
    map['studyCompleted'] = map['study_completed'] == true ? 1 : 0;
    map['exerciseCompleted'] = map['exercise_completed'] == true ? 1 : 0;
    map['mlCompleted'] = map['ml_completed'] == true ? 1 : 0;
    map['studyHours'] = map['study_hours'];
    map['sleepTime'] = map['sleep_time'];
    map['wakeTime'] = map['wake_time'];
    map['mobileUsage'] = map['mobile_usage'];
    map['productivityScore'] = map['productivity_score'];
    
    // Remove fields not in SQLite table
    map.remove('core_checklists');
    map.remove('core_metrics');
    map.remove('custom_logs');
    map.remove('id');
    map.remove('study_completed');
    map.remove('exercise_completed');
    map.remove('ml_completed');
    map.remove('study_hours');
    map.remove('sleep_time');
    map.remove('wake_time');
    map.remove('mobile_usage');
    map.remove('productivity_score');
    map.remove('client_uuid');
    
    return map;
  }

  Future<RoutineModel> createRoutine(RoutineModel routine) async {
    final localId = const Uuid().v4();
    final newRoutine = routine.copyWith(id: localId, syncStatus: 'pending');
    
    await _dbHelper.insert('routines_cache', _toDbFormat(newRoutine));
    await _syncEngine.queuePendingMutation('routine', 'create', newRoutine.toJson());
    
    return newRoutine;
  }

  Future<RoutineModel> updateRoutine(String id, RoutineModel routine) async {
    final updated = routine.copyWith(syncStatus: 'pending');
    await _dbHelper.update('routines_cache', _toDbFormat(updated), 'localId = ?', [id]);
    await _syncEngine.queuePendingMutation('routine', 'update', updated.toJson());
    return updated;
  }

  Future<void> deleteRoutine(String id) async {
    final rows = await _dbHelper.query('routines_cache', where: 'localId = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final map = Map<String, dynamic>.from(rows.first);
      map['coreChecklists'] = jsonDecode(map['coreChecklistsJson'] ?? '{}');
      map['coreMetrics'] = jsonDecode(map['coreMetricsJson'] ?? '{}');
      map['customLogs'] = jsonDecode(map['customLogsJson'] ?? '[]');
      final routine = RoutineModel.fromJson(map);
      await _syncEngine.queuePendingMutation('routine', 'delete', routine.toJson());
      await _dbHelper.delete('routines_cache', 'localId = ?', [id]);
    }
  }

  Future<RoutineModel?> getRoutineByDate(String date) async {
    final routines = await getRoutines();
    try {
      return routines.firstWhere((r) => r.date == date);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getCustomConfig() async {
    final response = await _dio.get(ApiEndpoints.customConfig);
    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  Future<void> updateCustomConfig(Map<String, dynamic> config) async {
    await _dio.patch(ApiEndpoints.customConfig, data: config);
  }
}
