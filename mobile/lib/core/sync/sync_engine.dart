import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_helper.dart';
import '../api/api_client.dart';
import '../storage/secure_storage.dart';

class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;
  SyncEngine._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isSyncing = false;

  void Function(bool isSyncing)? onSyncStatusChanged;
  void Function()? onSyncSuccess;
  void Function(String error)? onSyncFailed;

  Future<void> queuePendingMutation(String entityType, String action, Map<String, dynamic> payload) async {
    final mutationId = const Uuid().v4();
    
    await _dbHelper.insert('pending_mutations', {
      'id': mutationId,
      'entityType': entityType,
      'action': action,
      'payloadJson': jsonEncode(payload),
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });

    debugPrint('[SyncEngine] Queued mutation: $action $entityType');
    
    // Attempt to sync immediately
    syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;

    final activeUserId = await SecureStorageService.getActiveUserId();
    if (activeUserId == null) {
      debugPrint('[SyncEngine] Aborting sync: No active user set in storage.');
      return;
    }

    if (DatabaseHelper.currentUserId != activeUserId) {
      debugPrint('[SyncEngine] CRITICAL: Aborting sync. Storage user ($activeUserId) does not match DB user (${DatabaseHelper.currentUserId}).');
      return;
    }

    _isSyncing = true;
    onSyncStatusChanged?.call(true);

    try {
      // 1. Fetch last sync time
      final lastSyncTimeStr = await SecureStorageService.getFlag('last_sync_time_$activeUserId');

      // 2. Fetch all local records with syncStatus = 'pending'
      final pendingTodos = await _dbHelper.query('todos_cache', where: "syncStatus = 'pending'");
      final pendingRoutines = await _dbHelper.query('routines_cache', where: "syncStatus = 'pending'");
      final pendingFocus = await _dbHelper.query('focus_sessions_cache', where: "syncStatus = 'pending'");
      final pendingCalendar = await _dbHelper.query('calendar_events_cache', where: "syncStatus = 'pending'");
      final pendingNotifications = await _dbHelper.query('notifications_cache', where: "syncStatus = 'pending'");

      // Format records for server payload
      final List<Map<String, dynamic>> tasksPayload = pendingTodos.map((t) {
        return {
          'client_uuid': t['localId'],
          'title': t['title'],
          'description': t['description'],
          'due_date': t['dueDate'],
          'completed': t['completed'] == 1,
          'completed_at': t['completedAt'],
          'deleted_at': t['deletedAt'],
          'deletedFlag': t['deletedFlag'],
          'updated_at': t['updatedAt'] ?? t['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      final List<Map<String, dynamic>> routinesPayload = pendingRoutines.map((r) {
        return {
          'client_uuid': r['localId'],
          'date': r['date'],
          'study_completed': r['studyCompleted'] == 1,
          'exercise_completed': r['exerciseCompleted'] == 1,
          'ml_completed': r['mlCompleted'] == 1,
          'study_hours': r['studyHours'],
          'sleep_time': r['sleepTime'],
          'wake_time': r['wakeTime'],
          'mobile_usage': r['mobileUsage'],
          'notes': r['notes'],
          'productivity_score': r['productivityScore'],
          'core_checklists': jsonDecode(r['coreChecklistsJson'] ?? '{}'),
          'core_metrics': jsonDecode(r['coreMetricsJson'] ?? '{}'),
          'custom_logs': jsonDecode(r['customLogsJson'] ?? '[]'),
          'deleted_at': r['deletedAt'],
          'deletedFlag': r['deletedFlag'],
          'updated_at': r['updatedAt'] ?? r['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      final List<Map<String, dynamic>> focusPayload = pendingFocus.map((f) {
        return {
          'client_uuid': f['localId'],
          'session_type': f['sessionType'],
          'label': f['label'],
          'start_time': f['startTime'],
          'end_time': f['endTime'],
          'duration_minutes': f['durationMinutes'],
          'completed': f['completed'] == 1,
          'laps_json': jsonDecode(f['lapsJson'] ?? '[]'),
          'deleted_at': f['deletedAt'],
          'deletedFlag': f['deletedFlag'],
          'updated_at': f['updatedAt'] ?? f['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      final List<Map<String, dynamic>> calendarPayload = pendingCalendar.map((c) {
        return {
          'client_uuid': c['localId'],
          'title': c['title'],
          'description': c['description'],
          'start_time': c['startTime'],
          'end_time': c['endTime'],
          'all_day': c['allDay'] == 1,
          'color': c['color'] ?? 'blue',
          'category': c['category'] ?? 'personal',
          'location': c['location'] ?? '',
          'googleEventId': c['googleEventId'],
          'completed': c['completed'] == 1,
          'deleted_at': c['deletedAt'],
          'deletedFlag': c['deletedFlag'],
          'updated_at': c['updatedAt'] ?? c['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      final List<Map<String, dynamic>> notificationsPayload = pendingNotifications.map((n) {
        return {
          'client_uuid': n['localId'],
          'type': n['type'],
          'title': n['title'],
          'body': n['body'],
          'payload_json': jsonDecode(n['payloadJson'] ?? '{}'),
          'scheduled_for': n['scheduledFor'],
          'delivered_at': n['deliveredAt'],
          'read_at': n['readAt'],
          'dismissed_at': n['dismissedAt'],
          'deleted_at': n['deletedAt'],
          'deletedFlag': n['deletedFlag'],
          'updated_at': n['updatedAt'] ?? n['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      // 3. Post to batch sync endpoint
      final response = await apiClient.dio.post('/sync/batch', data: {
        'last_sync_time': lastSyncTimeStr,
        'tasks': tasksPayload,
        'routines': routinesPayload,
        'focus_sessions': focusPayload,
        'calendar_events': calendarPayload,
        'notifications': notificationsPayload,
      });

      final responseData = response.data as Map<String, dynamic>;

      // 4. Process response & merge updates
      if (responseData['success'] == true) {
        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          // Process Tasks Response
          final tasksResult = responseData['tasks'] as Map<String, dynamic>;
          final tasksSyncedIds = List<String>.from(tasksResult['synced_ids'] ?? []);
          final tasksConflicts = List<dynamic>.from(tasksResult['conflicts'] ?? []);
          final tasksUpdates = List<dynamic>.from(tasksResult['server_updates'] ?? []);

          for (final localId in tasksSyncedIds) {
            final checkRows = await txn.query('todos_cache', where: 'localId = ?', whereArgs: [localId]);
            if (checkRows.isNotEmpty && checkRows.first['deletedFlag'] == 1) {
              await txn.delete('todos_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              await txn.update('todos_cache', {'syncStatus': 'synced'}, where: 'localId = ?', whereArgs: [localId]);
            }
          }

          for (final update in tasksUpdates) {
            final localId = update['client_uuid'] as String;
            final deletedAt = update['deleted_at'];
            if (deletedAt != null) {
              await txn.delete('todos_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              final dueVal = update['due_date'] ?? update['dueDate'];
              final compVal = update['completed_at'] ?? update['completedAt'];
              final row = {
                'localId': localId,
                'serverId': update['id'],
                'syncStatus': 'synced',
                'title': update['title'] ?? '',
                'description': update['description'] ?? '',
                'dueDate': dueVal,
                'completed': (update['completed'] == true || update['completed'] == 1) ? 1 : 0,
                'completedAt': compVal,
                'createdAt': update['created_at'],
                'updatedAt': update['updated_at'],
                'deletedFlag': 0,
              };
              await txn.insert('todos_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }

          for (final conflict in tasksConflicts) {
            final localId = conflict['client_uuid'] as String;
            final serverRecord = conflict['server_record'] as Map<String, dynamic>;
            final deletedAt = serverRecord['deleted_at'];
            if (deletedAt != null) {
              await txn.delete('todos_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              final dueVal = serverRecord['due_date'] ?? serverRecord['dueDate'];
              final compVal = serverRecord['completed_at'] ?? serverRecord['completedAt'];
              final row = {
                'localId': localId,
                'serverId': serverRecord['id'],
                'syncStatus': 'synced',
                'title': serverRecord['title'] ?? '',
                'description': serverRecord['description'] ?? '',
                'dueDate': dueVal,
                'completed': (serverRecord['completed'] == true || serverRecord['completed'] == 1) ? 1 : 0,
                'completedAt': compVal,
                'createdAt': serverRecord['created_at'],
                'updatedAt': serverRecord['updated_at'],
                'deletedFlag': 0,
              };
              await txn.insert('todos_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }

          // Process Routines Response
          final routinesResult = responseData['routines'] as Map<String, dynamic>;
          final routinesSyncedIds = List<String>.from(routinesResult['synced_ids'] ?? []);
          final routinesConflicts = List<dynamic>.from(routinesResult['conflicts'] ?? []);
          final routinesUpdates = List<dynamic>.from(routinesResult['server_updates'] ?? []);

          for (final localId in routinesSyncedIds) {
            final checkRows = await txn.query('routines_cache', where: 'localId = ?', whereArgs: [localId]);
            if (checkRows.isNotEmpty && checkRows.first['deletedFlag'] == 1) {
              await txn.delete('routines_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              await txn.update('routines_cache', {'syncStatus': 'synced'}, where: 'localId = ?', whereArgs: [localId]);
            }
          }

          for (final update in routinesUpdates) {
            final localId = update['client_uuid'] as String?;
            if (localId == null) continue;
            final deletedAt = update['deleted_at'];
            if (deletedAt != null) {
              await txn.delete('routines_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              final row = {
                'localId': localId,
                'serverId': update['id'],
                'syncStatus': 'synced',
                'date': update['date'],
                'studyCompleted': (update['study_completed'] == true || update['study_completed'] == 1) ? 1 : 0,
                'exerciseCompleted': (update['exercise_completed'] == true || update['exercise_completed'] == 1) ? 1 : 0,
                'mlCompleted': (update['ml_completed'] == true || update['ml_completed'] == 1) ? 1 : 0,
                'studyHours': update['study_hours'] ?? 0.0,
                'sleepTime': update['sleep_time'] ?? '23:00',
                'wakeTime': update['wake_time'] ?? '07:00',
                'mobileUsage': update['mobile_usage'] ?? 0.0,
                'notes': update['notes'] ?? '',
                'productivityScore': update['productivity_score'] ?? 0,
                'coreChecklistsJson': jsonEncode(update['core_checklists'] ?? {}),
                'coreMetricsJson': jsonEncode(update['core_metrics'] ?? {}),
                'customLogsJson': jsonEncode(update['custom_logs'] ?? []),
                'createdAt': update['created_at'],
                'deletedFlag': 0,
              };
              await txn.insert('routines_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }

          for (final conflict in routinesConflicts) {
            final localId = conflict['client_uuid'] as String;
            final serverRecord = conflict['server_record'] as Map<String, dynamic>;
            final deletedAt = serverRecord['deleted_at'];
            if (deletedAt != null) {
              await txn.delete('routines_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              final row = {
                'localId': localId,
                'serverId': serverRecord['id'],
                'syncStatus': 'synced',
                'date': serverRecord['date'],
                'studyCompleted': (serverRecord['study_completed'] == true || serverRecord['study_completed'] == 1) ? 1 : 0,
                'exerciseCompleted': (serverRecord['exercise_completed'] == true || serverRecord['exercise_completed'] == 1) ? 1 : 0,
                'mlCompleted': (serverRecord['ml_completed'] == true || serverRecord['ml_completed'] == 1) ? 1 : 0,
                'studyHours': serverRecord['study_hours'] ?? 0.0,
                'sleepTime': serverRecord['sleep_time'] ?? '23:00',
                'wakeTime': serverRecord['wake_time'] ?? '07:00',
                'mobileUsage': serverRecord['mobile_usage'] ?? 0.0,
                'notes': serverRecord['notes'] ?? '',
                'productivityScore': serverRecord['productivity_score'] ?? 0,
                'coreChecklistsJson': jsonEncode(serverRecord['core_checklists'] ?? {}),
                'coreMetricsJson': jsonEncode(serverRecord['core_metrics'] ?? {}),
                'customLogsJson': jsonEncode(serverRecord['custom_logs'] ?? []),
                'createdAt': serverRecord['created_at'],
                'deletedFlag': 0,
              };
              await txn.insert('routines_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }

          // Process Focus Sessions Response
          final focusResult = responseData['focus_sessions'] as Map<String, dynamic>;
          final focusSyncedIds = List<String>.from(focusResult['synced_ids'] ?? []);
          final focusUpdates = List<dynamic>.from(focusResult['server_updates'] ?? []);

          for (final localId in focusSyncedIds) {
            final checkRows = await txn.query('focus_sessions_cache', where: 'localId = ?', whereArgs: [localId]);
            if (checkRows.isNotEmpty && checkRows.first['deletedFlag'] == 1) {
              await txn.delete('focus_sessions_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              await txn.update('focus_sessions_cache', {'syncStatus': 'synced'}, where: 'localId = ?', whereArgs: [localId]);
            }
          }

          for (final update in focusUpdates) {
            final localId = update['client_uuid'] as String;
            final deletedAt = update['deleted_at'];
            if (deletedAt != null) {
              await txn.delete('focus_sessions_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              final row = {
                'localId': localId,
                'serverId': update['id'],
                'syncStatus': 'synced',
                'sessionType': update['session_type'] ?? 'timer',
                'label': update['label'] ?? 'Focus Session',
                'startTime': update['start_time'],
                'endTime': update['end_time'],
                'durationMinutes': update['duration_minutes'] ?? 0,
                'completed': (update['completed'] == true || update['completed'] == 1) ? 1 : 0,
                'lapsJson': jsonEncode(update['laps_json'] ?? []),
                'createdAt': update['created_at'],
                'updatedAt': update['updated_at'],
                'deletedFlag': 0,
              };
              await txn.insert('focus_sessions_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }

          // Process Calendar Events Response
          final calendarResult = responseData['calendar_events'] as Map<String, dynamic>;
          final calendarSyncedIds = List<String>.from(calendarResult['synced_ids'] ?? []);
          final calendarUpdates = List<dynamic>.from(calendarResult['server_updates'] ?? []);

          for (final localId in calendarSyncedIds) {
            final checkRows = await txn.query('calendar_events_cache', where: 'localId = ?', whereArgs: [localId]);
            if (checkRows.isNotEmpty && checkRows.first['deletedFlag'] == 1) {
              await txn.delete('calendar_events_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              await txn.update('calendar_events_cache', {'syncStatus': 'synced'}, where: 'localId = ?', whereArgs: [localId]);
            }
          }

          for (final update in calendarUpdates) {
            final localId = update['client_uuid'] as String?;
            if (localId == null) continue;
            final deletedAt = update['deleted_at'];
            if (deletedAt != null) {
              await txn.delete('calendar_events_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              final row = {
                'localId': localId,
                'serverId': update['id'],
                'syncStatus': 'synced',
                'title': update['title'] ?? '',
                'description': update['description'] ?? '',
                'startTime': update['start_time'],
                'endTime': update['end_time'],
                'allDay': (update['all_day'] == true || update['all_day'] == 1) ? 1 : 0,
                'googleEventId': update['googleEventId'] ?? '',
                'syncedToGoogle': (update['syncedToGoogle'] == true || update['syncedToGoogle'] == 1) ? 1 : 0,
                'createdAt': update['created_at'],
                'updatedAt': update['updated_at'],
                'deletedFlag': 0,
              };
              await txn.insert('calendar_events_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }

          // Process Notifications Response
          final notificationsResult = responseData['notifications'] as Map<String, dynamic>;
          final notificationsSyncedIds = List<String>.from(notificationsResult['synced_ids'] ?? []);
          final notificationsUpdates = List<dynamic>.from(notificationsResult['server_updates'] ?? []);

          for (final localId in notificationsSyncedIds) {
            final checkRows = await txn.query('notifications_cache', where: 'localId = ?', whereArgs: [localId]);
            if (checkRows.isNotEmpty && checkRows.first['deletedFlag'] == 1) {
              await txn.delete('notifications_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              await txn.update('notifications_cache', {'syncStatus': 'synced'}, where: 'localId = ?', whereArgs: [localId]);
            }
          }

          for (final update in notificationsUpdates) {
            final localId = update['client_uuid'] as String;
            final deletedAt = update['deleted_at'];
            if (deletedAt != null) {
              await txn.delete('notifications_cache', where: 'localId = ?', whereArgs: [localId]);
            } else {
              final row = {
                'localId': localId,
                'serverId': update['id'],
                'syncStatus': 'synced',
                'type': update['type'] ?? 'todo',
                'title': update['title'] ?? '',
                'body': update['body'] ?? '',
                'payloadJson': jsonEncode(update['payload_json'] ?? {}),
                'scheduledFor': update['scheduled_for'],
                'deliveredAt': update['delivered_at'],
                'readAt': update['read_at'],
                'dismissedAt': update['dismissed_at'],
                'createdAt': update['created_at'],
                'updatedAt': update['updated_at'],
                'deletedFlag': 0,
              };
              await txn.insert('notifications_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        });

        final newSyncTime = responseData['sync_time'] ?? DateTime.now().toIso8601String();
        await SecureStorageService.saveFlag('last_sync_time_$activeUserId', newSyncTime);

        // Clean up traditional pending mutations since they're fully processed
        await _dbHelper.delete('pending_mutations', '1 = 1', []);

        onSyncSuccess?.call();
      } else {
        onSyncFailed?.call('Sync response success = false');
      }
    } on DioException catch (e) {
      debugPrint('[SyncEngine] Dio sync error: ${e.message}');
      onSyncFailed?.call(e.message ?? e.toString());
    } catch (e) {
      debugPrint('[SyncEngine] General sync error: $e');
      onSyncFailed?.call(e.toString());
    } finally {
      _isSyncing = false;
      onSyncStatusChanged?.call(false);
    }
  }
}
