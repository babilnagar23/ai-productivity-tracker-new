import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;
  SyncEngine._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isSyncing = false;

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

    debugPrint('[SyncEngine] Queued mutation: \$action \$entityType');
    
    // Attempt to sync immediately
    syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = await _dbHelper.query('pending_mutations', orderBy: 'createdAt ASC');
      
      for (final mutation in pending) {
        final id = mutation['id'] as String;
        final entityType = mutation['entityType'] as String;
        final action = mutation['action'] as String;
        final payload = jsonDecode(mutation['payloadJson'] as String) as Map<String, dynamic>;
        final retryCount = (mutation['retryCount'] as int?) ?? 0;

        bool success = false;

        try {
          if (entityType == 'todo') {
            success = await _syncTodo(action, payload);
          } else if (entityType == 'routine') {
            success = await _syncRoutine(action, payload);
          } else if (entityType == 'focus_session') {
            success = await _syncFocusSession(action, payload);
          }

          if (success) {
            await _dbHelper.delete('pending_mutations', 'id = ?', [id]);
            debugPrint('[SyncEngine] Synced mutation $id');
          }
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          if (status != null && status >= 400 && status < 500 && status != 408 && status != 429) {
            debugPrint('[SyncEngine] Permanent error $status for mutation $id. Dropping mutation.');
            await _dbHelper.delete('pending_mutations', 'id = ?', [id]);
          } else {
            debugPrint('[SyncEngine] Network/temporary error syncing mutation $id: ${e.message}');
            await _dbHelper.update('pending_mutations', {'retryCount': retryCount + 1}, 'id = ?', [id]);
            // Stop syncing current batch if network error
            break;
          }
        } catch (e) {
          debugPrint('[SyncEngine] Unknown error syncing mutation $id: $e');
          await _dbHelper.update('pending_mutations', {'retryCount': retryCount + 1}, 'id = ?', [id]);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncTodo(String action, Map<String, dynamic> payload) async {
    final localId = payload['localId'] as String;
    
    if (action == 'create') {
      final resp = await apiClient.dio.post(ApiEndpoints.todos, data: payload);
      final serverId = resp.data['id'] ?? resp.data['data']?['id'];
      
      // Update cache
      await _dbHelper.update('todos_cache', {
        'serverId': serverId,
        'syncStatus': 'synced',
      }, 'localId = ?', [localId]);
      
      return true;
    } else if (action == 'update') {
      final serverId = payload['serverId'];
      if (serverId == null) return false; // Needs to wait for create to finish
      
      await apiClient.dio.patch(ApiEndpoints.todoDetail(serverId), data: payload);
      await _dbHelper.update('todos_cache', {'syncStatus': 'synced'}, 'localId = ?', [localId]);
      return true;
    } else if (action == 'delete') {
      final serverId = payload['serverId'];
      if (serverId != null) {
        await apiClient.dio.delete(ApiEndpoints.todoDetail(serverId));
      }
      await _dbHelper.delete('todos_cache', 'localId = ?', [localId]);
      return true;
    }
    return false;
  }

  Future<bool> _syncRoutine(String action, Map<String, dynamic> payload) async {
    final localId = payload['localId'] as String;

    if (action == 'create') {
      try {
        final resp = await apiClient.dio.post(ApiEndpoints.routines, data: payload);
        final serverId = resp.data['id'] ?? resp.data['data']?['id'];

        await _dbHelper.update('routines_cache', {
          'serverId': serverId,
          'syncStatus': 'synced',
        }, 'localId = ?', [localId]);
        return true;
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          final responseData = e.response?.data;
          dynamic existingId;
          if (responseData is Map) {
            existingId = responseData['existingId'];
          }
          if (existingId != null) {
            await _dbHelper.update('routines_cache', {
              'serverId': existingId,
              'syncStatus': 'synced',
            }, 'localId = ?', [localId]);
            debugPrint('[SyncEngine] Resolved 409 Conflict for routine: existingId = $existingId');
            return true;
          }
        }
        rethrow;
      }
    } else if (action == 'update') {
      final serverId = payload['serverId'];
      if (serverId == null) return false;

      await apiClient.dio.patch(ApiEndpoints.routineDetail(serverId), data: payload);
      await _dbHelper.update('routines_cache', {'syncStatus': 'synced'}, 'localId = ?', [localId]);
      return true;
    }
    return false;
  }

  Future<bool> _syncFocusSession(String action, Map<String, dynamic> payload) async {
    final localId = payload['localId'] as String;
    
    if (action == 'create') {
      final resp = await apiClient.dio.post('/focus-sessions/', data: payload);
      final serverId = resp.data['id'] ?? resp.data['data']?['id'];
      
      await _dbHelper.update('focus_sessions_cache', {
        'serverId': serverId,
        'syncStatus': 'synced',
      }, 'localId = ?', [localId]);
      return true;
    }
    return false;
  }
}
