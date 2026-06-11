import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../models/todo_model.dart';
import 'package:uuid/uuid.dart';

class TodoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncEngine _syncEngine = SyncEngine();


  Future<List<TodoModel>> fetchTodos() async {
    // Return local data immediately where deletedFlag = 0
    final rows = await _dbHelper.query(
      'todos_cache',
      where: 'deletedFlag = 0',
      orderBy: 'dueDate ASC',
    );
    final todos = rows.map((r) => TodoModel.fromJson(r)).toList();
    
    // Trigger background sync
    _syncEngine.syncNow();
    
    return todos;
  }

  Map<String, dynamic> _toDbFormat(TodoModel todo, {int deletedFlag = 0}) {
    final map = todo.toJson();
    map['completed'] = todo.completed ? 1 : 0;
    
    // Remove fields not in SQLite table
    map.remove('client_uuid');
    map.remove('due_date');
    map.remove('completed_at');
    map.remove('id');
    
    // Add fields that match the SQLite schema
    map['dueDate'] = todo.dueDate.toIso8601String();
    if (todo.completedAt != null) {
      map['completedAt'] = todo.completedAt!.toIso8601String();
    }
    map['createdAt'] = todo.createdAt?.toIso8601String();
    map['updatedAt'] = todo.updatedAt?.toIso8601String();
    map['syncStatus'] = todo.syncStatus;
    map['deletedFlag'] = deletedFlag;
    
    return map;
  }

  Future<TodoModel> createTodo(TodoModel todo) async {
    final localId = const Uuid().v4();
    final newTodo = todo.copyWith(id: localId, syncStatus: 'pending', createdAt: DateTime.now());
    
    await _dbHelper.insert('todos_cache', _toDbFormat(newTodo));
    await _syncEngine.queuePendingMutation('todo', 'create', newTodo.toJson());
    
    return newTodo;
  }

  Future<TodoModel> updateTodo(TodoModel todo) async {
    final updated = todo.copyWith(syncStatus: 'pending', updatedAt: DateTime.now());
    await _dbHelper.update('todos_cache', _toDbFormat(updated), 'localId = ?', [todo.id]);
    await _syncEngine.queuePendingMutation('todo', 'update', updated.toJson());
    return updated;
  }

  Future<void> deleteTodo(String id) async {
    final rows = await _dbHelper.query('todos_cache', where: 'localId = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final todo = TodoModel.fromJson(rows.first);
      // Soft delete in local DB
      await _dbHelper.update(
        'todos_cache',
        {'deletedFlag': 1, 'syncStatus': 'pending', 'deletedAt': DateTime.now().toIso8601String()},
        'localId = ?',
        [id],
      );
      // Queue delete mutation
      await _syncEngine.queuePendingMutation('todo', 'delete', todo.toJson());
    }
  }
}