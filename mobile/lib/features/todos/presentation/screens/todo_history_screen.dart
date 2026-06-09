import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/todo_model.dart';
import '../../providers/todo_provider.dart';
import '../../widgets/todo_tile.dart';

class TodoHistoryScreen extends ConsumerWidget {
  const TodoHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosState = ref.watch(todoProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          'Todo History',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: todosState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        data: (todos) {
          if (todos.isEmpty) {
            return Center(
              child: Text(
                'No history yet',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final grouped = <String, List<TodoModel>>{};
          for (final todo in todos) {
            final key =
                '${todo.dueDate.year}-${todo.dueDate.month.toString().padLeft(2, '0')}-${todo.dueDate.day.toString().padLeft(2, '0')}';
            grouped.putIfAbsent(key, () => []);
            grouped[key]!.add(todo);
          }

          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (_, index) {
              final key = sortedKeys[index];
              final items = grouped[key] ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...items.map(
                      (todo) => TodoTile(
                        todo: todo,
                        onTap: () {},
                        onToggle: () {
                          ref.read(todoProvider.notifier).toggleComplete(todo);
                        },
                        onDelete: () {
                          ref.read(todoProvider.notifier).deleteTodo(todo);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}