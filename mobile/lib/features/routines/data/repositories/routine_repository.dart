import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/storage/secure_storage.dart';
import '../models/routine_model.dart';
import 'package:uuid/uuid.dart';

class RoutineRepository {
  final Dio _dio = apiClient.dio;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncEngine _syncEngine = SyncEngine();

  Future<List<RoutineModel>> getRoutines() async {
    final rows = await _dbHelper.query(
      'routines_cache',
      where: 'deletedFlag = 0',
      orderBy: 'date DESC, createdAt DESC',
    );
    
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

  Map<String, dynamic> _toDbFormat(RoutineModel routine, {int deletedFlag = 0}) {
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
    map['deletedFlag'] = deletedFlag;
    
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
      
      // Soft delete in local DB
      await _dbHelper.update(
        'routines_cache',
        {'deletedFlag': 1, 'syncStatus': 'pending', 'deletedAt': DateTime.now().toIso8601String()},
        'localId = ?',
        [id],
      );
      // Queue delete mutation
      await _syncEngine.queuePendingMutation('routine', 'delete', routine.toJson());
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
    try {
      final response = await _dio.get(ApiEndpoints.customConfig);
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;
      await SecureStorageService.saveFlag('custom_config', jsonEncode(data));
      return data;
    } catch (e) {
      final cached = await SecureStorageService.getFlag('custom_config');
      if (cached != null) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
      return {
        'coreChecklists': [
          {'key': 'study_completed', 'label': 'Study session completed'},
          {'key': 'exercise_completed', 'label': 'Exercise completed'},
          {'key': 'ml_completed', 'label': 'ML/Coding completed'},
        ],
        'coreMetrics': [
          {'key': 'study_hours', 'label': 'Study Hours', 'type': 'number'},
          {'key': 'sleep_time', 'label': 'Sleep Time', 'type': 'time'},
          {'key': 'wake_time', 'label': 'Wake Time', 'type': 'time'},
          {'key': 'mobile_usage', 'label': 'Mobile Usage', 'type': 'number'},
        ],
      };
    }
  }

  Future<void> updateCustomConfig(Map<String, dynamic> config) async {
    await SecureStorageService.saveFlag('custom_config', jsonEncode(config));
    try {
      await _dio.patch(ApiEndpoints.customConfig, data: config);
    } catch (e) {
      // Offline support: config is saved locally, queue mutation for backend sync
      await _syncEngine.queuePendingMutation('custom_config', 'update', config);
    }
  }
}
