import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/todo_settings.dart';

class TodoCustomizationScreen extends ConsumerWidget {
  const TodoCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(todoCompletionStyleProvider);
    final notifier = ref.read(todoCompletionStyleProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          'Todo Customization',
          style: TextStyle(
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<TodoCompletionStyle>(
                value: TodoCompletionStyle.checkmark,
                groupValue: style,
                onChanged: (value) {
                  if (value != null) notifier.setStyle(value);
                },
                title: const Text('Checkmark Mode'),
                subtitle: const Text('Circle tick changes when completed'),
              ),
              RadioListTile<TodoCompletionStyle>(
                value: TodoCompletionStyle.strikethrough,
                groupValue: style,
                onChanged: (value) {
                  if (value != null) notifier.setStyle(value);
                },
                title: const Text('Strikethrough Mode'),
                subtitle: const Text('Completed task gets a line through text'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
