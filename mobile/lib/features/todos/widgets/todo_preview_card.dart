import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/todo_provider.dart';
import 'todo_tile.dart';

class TodoPreviewCard extends ConsumerWidget {
  const TodoPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosState = ref.watch(todoProvider);
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: todosState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(
          e.toString(),
          style: TextStyle(color: AppColors.textSecondary),
        ),
        data: (todos) {
          final todayTodos = todos
              .where(
                (t) => DateUtils.isSameDay(t.dueDate, today),
              )
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'To Do List',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 22,
                        ),
                        color: AppColors.success,
                        tooltip: 'Add Todo',
                        onPressed: () {
                          context.push('/todos/add');
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          context.push('/todos');
                        },
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.purple,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (todayTodos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No to do list item for today',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                ...todayTodos.take(5).map(
                      (todo) => TodoTile(
                        todo: todo,
                        onTap: () => context.push('/todos/edit', extra: todo),
                        onToggle: () => ref
                            .read(todoProvider.notifier)
                            .toggleComplete(todo),
                        onDelete: () =>
                            ref.read(todoProvider.notifier).deleteTodo(todo),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}
