import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/todo_model.dart';
import '../../providers/todo_provider.dart';
import '../../widgets/todo_tile.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosState = ref.watch(todoProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          'Tasks',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () => context.push('/todos/history'),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            onPressed: () => context.push('/todos/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/todos/add'),
        child: const Icon(Icons.add),
      ),
      body: todosState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        data: (todos) {
          if (todos.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(todoProvider.notifier).loadTodos(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      'No Todos Yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final today = DateUtils.dateOnly(now);
          final tomorrow = today.add(const Duration(days: 1));

          final todayTodos = todos
              .where((t) => DateUtils.isSameDay(t.dueDate, today))
              .toList();

          final tomorrowTodos = todos
              .where((t) => DateUtils.isSameDay(t.dueDate, tomorrow))
              .toList();

          final upcomingTodos = todos
              .where((t) =>
                  t.dueDate.isAfter(tomorrow) && !t.completed)
              .toList();

          final completedTodos =
              todos.where((t) => t.completed).toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(todoProvider.notifier).loadTodos(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader('Today'),
                if (todayTodos.isEmpty)
                  const _EmptyText('No to do list item for today')
                else
                  ...todayTodos.map(
                    (todo) => TodoTile(
                      todo: todo,
                      onTap: () => context.push('/todos/edit', extra: todo),
                      onToggle: () =>
                          ref.read(todoProvider.notifier).toggleComplete(todo),
                      onDelete: () =>
                          ref.read(todoProvider.notifier).deleteTodo(todo),
                    ),
                  ),
                const SizedBox(height: 12),

                _sectionHeader('Tomorrow'),
                if (tomorrowTodos.isEmpty)
                  const _EmptyText('Nothing planned for tomorrow')
                else
                  ...tomorrowTodos.map(
                    (todo) => TodoTile(
                      todo: todo,
                      onTap: () => context.push('/todos/edit', extra: todo),
                      onToggle: () =>
                          ref.read(todoProvider.notifier).toggleComplete(todo),
                      onDelete: () =>
                          ref.read(todoProvider.notifier).deleteTodo(todo),
                    ),
                  ),
                const SizedBox(height: 12),

                _sectionHeader('Upcoming'),
                if (upcomingTodos.isEmpty)
                  const _EmptyText('No upcoming tasks')
                else
                  ...upcomingTodos.map(
                    (todo) => TodoTile(
                      todo: todo,
                      onTap: () => context.push('/todos/edit', extra: todo),
                      onToggle: () =>
                          ref.read(todoProvider.notifier).toggleComplete(todo),
                      onDelete: () =>
                          ref.read(todoProvider.notifier).deleteTodo(todo),
                    ),
                  ),
                const SizedBox(height: 12),

                _sectionHeader('Completed'),
                if (completedTodos.isEmpty)
                  const _EmptyText('No completed tasks yet')
                else
                  ...completedTodos.map(
                    (todo) => TodoTile(
                      todo: todo,
                      onTap: () => context.push('/todos/edit', extra: todo),
                      onToggle: () =>
                          ref.read(todoProvider.notifier).toggleComplete(todo),
                      onDelete: () =>
                          ref.read(todoProvider.notifier).deleteTodo(todo),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),
    );
  }
}