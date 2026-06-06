import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/data/repositories/routine_repository.dart';
import '../../../routines/presentation/providers/routines_provider.dart';

class DailyLogScreen extends ConsumerWidget {
  const DailyLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Daily Log', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.textSecondary, size: 22),
            onPressed: () => context.push('/daily-log/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 22),
            onPressed: () => context.push('/daily-log/customize'),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.blue, size: 24),
            onPressed: () async {
              await context.push('/daily-log/add');
              ref.invalidate(routinesProvider);
            },
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
        error: (e, _) => _ErrorView(message: '$e', onRetry: () => ref.invalidate(routinesProvider)),
        data: (routines) {
          if (routines.isEmpty) {
            return _EmptyState(onAdd: () async {
              await context.push('/daily-log/add');
              ref.invalidate(routinesProvider);
            });
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(routinesProvider),
            color: AppColors.blue,
            backgroundColor: AppColors.card,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: routines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _LogCard(
                routine: routines[i],
                onEdit: () async {
                  await context.push('/daily-log/edit/${routines[i].id}');
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
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete Entry', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this log?', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: GoogleFonts.inter(color: AppColors.error))),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final RoutineModel routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LogCard({required this.routine, required this.onEdit, required this.onDelete});

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
      if (date.year == now.year && date.month == now.month && date.day == now.day - 1) return 'Yesterday';
      return DateFormat('EEEE, MMM d').format(date);
    } catch (_) { return dateStr; }
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(routine.productivityScore);
    final checklists = routine.coreChecklists;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(_formatDate(routine.date),
                    style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${routine.productivityScore}',
                    style: GoogleFonts.inter(color: scoreColor, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: routine.productivityScore / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(scoreColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),

          // Habit chips
          if (checklists.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: checklists.entries.map((e) {
                final info = e.value as Map<String, dynamic>? ?? {};
                final title = info['title'] as String? ?? e.key;
                final done = info['completed'] as bool? ?? false;
                final short = title.length > 12 ? '${title.substring(0, 12)}…' : title;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: done ? AppColors.success.withValues(alpha: 0.12) : AppColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: done ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: done ? AppColors.success : AppColors.textMuted, size: 12),
                      const SizedBox(width: 4),
                      Text(short, style: GoogleFonts.inter(
                          color: done ? AppColors.success : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Wrap(
              spacing: 6,
              children: [
                _HabitChip(label: 'Study', done: routine.studyCompleted),
                _HabitChip(label: 'Exercise', done: routine.exerciseCompleted),
                _HabitChip(label: 'Deep Work', done: routine.mlCompleted),
              ],
            ),

          const SizedBox(height: 10),

          // Metrics row
          Wrap(
            spacing: 8,
            children: [
              if (routine.studyHours > 0)
                Text('${routine.studyHours}h Study', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              if (routine.mobileUsage > 0)
                Text('${routine.mobileUsage}h Mobile', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox.shrink(),
            ],
          ),

          if (routine.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(routine.notes,
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 10),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),

          // Footer
          Row(
            children: [
              const Icon(Icons.bedtime_outlined, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text('${routine.sleepTime} → ${routine.wakeTime}',
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: done ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: done ? AppColors.success : AppColors.textMuted, size: 12),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(
              color: done ? AppColors.success : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No logs yet', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Start tracking your daily habits', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Log Today', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(message, style: GoogleFonts.inter(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text('Retry', style: GoogleFonts.inter(color: AppColors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}
