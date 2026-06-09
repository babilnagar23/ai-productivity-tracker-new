import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/todo_model.dart';
import '../models/todo_settings.dart';

class TodoTile extends ConsumerWidget {
  final TodoModel todo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const TodoTile({
    super.key,
    required this.todo,
    required this.onTap,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(todoCompletionStyleProvider);
    final completed = todo.completed;

    final textStyle = GoogleFonts.inter(
      color: completed ? AppColors.textMuted : AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      decoration: completed && style == TodoCompletionStyle.strikethrough
          ? TextDecoration.lineThrough
          : TextDecoration.none,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: completed ? AppColors.success : AppColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(todo.title, style: textStyle),
                    if (todo.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        todo.description,
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
