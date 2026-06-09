import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../models/todo_model.dart';

class TodoRepository {
  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) return results;

      final items = data['data'];
      if (items is List) return items;

      final todos = data['todos'];
      if (todos is List) return todos;
    }

    return <dynamic>[];
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return <String, dynamic>{};
  }

  Future<List<TodoModel>> fetchTodos() async {
    final response = await apiClient.dio.get(
      ApiEndpoints.todos,
    );

    final raw = _extractList(response.data);

    final todos = raw
        .whereType<Map>()
        .map((e) => TodoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    todos.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return todos;
  }

  Future<TodoModel> createTodo(TodoModel todo) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.todos,
      data: todo.toJson(),
    );

    final data = _extractMap(response.data);
    return TodoModel.fromJson(data);
  }

  Future<TodoModel> updateTodo(TodoModel todo) async {
    if (todo.id == null) {
      throw Exception('Todo ID is required for update.');
    }

    final response = await apiClient.dio.patch(
      ApiEndpoints.todoDetail(todo.id!),
      data: todo.toJson(),
    );

    final data = _extractMap(response.data);
    return TodoModel.fromJson(data);
  }

  Future<void> deleteTodo(int id) async {
    await apiClient.dio.delete(
      ApiEndpoints.todoDetail(id),
    );
  }
}