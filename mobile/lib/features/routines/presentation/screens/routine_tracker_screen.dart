import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/routine_model.dart';
import '../../data/repositories/routine_repository.dart';
import '../providers/routines_provider.dart';

class RoutineTrackerScreen extends ConsumerWidget {
  const RoutineTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/routines/add'),
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.purple)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('$e', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(routinesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (routines) {
          if (routines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rounded, color: AppColors.textMuted, size: 64),
                  const SizedBox(height: 16),
                  Text('No routines logged yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Start tracking your daily habits', style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/routines/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Log Today'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(routinesProvider),
            color: AppColors.purple,
            backgroundColor: AppColors.surface,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: routines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _RoutineCard(
                routine: routines[i],
                onEdit: () async {
                  await context.push('/routines/edit/${routines[i].id}');
                  ref.invalidate(routinesProvider);
                },
                onDelete: () async {
                  final confirmed = await _confirmDelete(context);
                  if (confirmed == true && routines[i].id != null) {
                    await RoutineRepository().deleteRoutine(routines[i].id!);
                    ref.invalidate(routinesProvider);
                  }
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/routines/add');
          ref.invalidate(routinesProvider);
        },
        backgroundColor: AppColors.purple,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Log Today', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Entry', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to delete this log?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final RoutineModel routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineCard({required this.routine, required this.onEdit, required this.onDelete});

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(routine.productivityScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${routine.productivityScore}',
                  style: TextStyle(color: scoreColor, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(routine.date),
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      '${routine.studyHours}h study • ${routine.mobileUsage}h mobile',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: AppColors.textPrimary)),
                    ],
                  )),
                  PopupMenuItem(value: 'delete', child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
                    ],
                  )),
                ],
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: routine.productivityScore / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(scoreColor),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _HabitChip(label: 'Study', done: routine.studyCompleted),
              _HabitChip(label: 'Exercise', done: routine.exerciseCompleted),
              _HabitChip(label: 'ML', done: routine.mlCompleted),
            ],
          ),
          if (routine.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              routine.notes,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
      if (date.year == now.year && date.month == now.month && date.day == now.day - 1) return 'Yesterday';
      return DateFormat('EEEE, MMM d').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _HabitChip extends StatelessWidget {
  final String label;
  final bool done;
  const _HabitChip({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done ? AppColors.success.withValues(alpha: 0.12) : AppColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: done ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? AppColors.success : AppColors.textMuted,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: done ? AppColors.success : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
