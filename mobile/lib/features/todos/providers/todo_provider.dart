import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/todo_repository.dart';
import '../models/todo_model.dart';

final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});

final todoProvider =
    StateNotifierProvider<TodoNotifier, AsyncValue<List<TodoModel>>>((ref) {
  final notifier = TodoNotifier(ref.read(todoRepositoryProvider));
  // ignore: discarded_futures
  notifier.loadTodos();
  return notifier;
});

class TodoNotifier extends StateNotifier<AsyncValue<List<TodoModel>>> {
  final TodoRepository repository;

  TodoNotifier(this.repository) : super(const AsyncLoading());

  List<TodoModel> _currentList() {
    return state.maybeWhen(
      data: (list) => list,
      orElse: () => <TodoModel>[],
    );
  }

  Future<void> loadTodos() async {
    try {
      final todos = await repository.fetchTodos();
      state = AsyncData(todos);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => loadTodos();

  Future<void> addTodo(TodoModel todo) async {
    final created = await repository.createTodo(todo);
    final current = _currentList();
    state = AsyncData([...current, created]);
  }

  Future<void> updateTodo(TodoModel todo) async {
    final updated = await repository.updateTodo(todo);
    final current = _currentList();

    state = AsyncData(
      current.map((e) => e.id == updated.id ? updated : e).toList(),
    );
  }

  Future<void> deleteTodo(TodoModel todo) async {
    if (todo.id.isEmpty) return;

    await repository.deleteTodo(todo.id);
    final current = _currentList();

    state = AsyncData(
      current.where((e) => e.id != todo.id).toList(),
    );
  }

  Future<void> toggleComplete(TodoModel todo) async {
    final updated = todo.copyWith(
      completed: !todo.completed,
      completedAt: !todo.completed ? DateTime.now() : null,
    );

    final serverTodo = await repository.updateTodo(updated);
    final current = _currentList();

    state = AsyncData(
      current.map((e) => e.id == serverTodo.id ? serverTodo : e).toList(),
    );
  }
}