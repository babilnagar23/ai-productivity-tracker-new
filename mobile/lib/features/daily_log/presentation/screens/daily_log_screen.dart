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
    final configAsync = ref.watch(customConfigProvider);

    // Extract config lists for label resolution — available even while routines load
    final configChecklists = (configAsync.asData?.value['coreChecklists'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final configMetrics = (configAsync.asData?.value['coreMetrics'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Daily Log',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () => context.push('/daily-log/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () => context.push('/daily-log/customize'),
          ),
          IconButton(
            icon:
                const Icon(Icons.add_rounded, color: AppColors.blue, size: 24),
            onPressed: () async {
              await context.push('/daily-log/add');
              ref.invalidate(routinesProvider);
            },
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.blue)),
        error: (e, _) => _ErrorView(
            message: '$e', onRetry: () => ref.invalidate(routinesProvider)),
        data: (routines) {
          if (routines.isEmpty) {
            return _EmptyState(onAdd: () async {
              await context.push('/daily-log/add');
              ref.invalidate(routinesProvider);
            });
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(routinesProvider);
              ref.invalidate(customConfigProvider);
            },
            color: AppColors.blue,
            backgroundColor: AppColors.card,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: routines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _LogCard(
                routine: routines[i],
                configChecklists: configChecklists,
                configMetrics: configMetrics,
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
        title: Text('Delete Entry',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this log?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: GoogleFonts.inter(color: AppColors.error))),
        ],
      ),
    );
  }
}

/// --------------------------------------------------------------------------
/// _LogCard
/// --------------------------------------------------------------------------
class _LogCard extends StatelessWidget {
  final RoutineModel routine;

  /// Active habits from user's customisation config.
  /// Used to resolve habit titles from their stored IDs.
  final List<Map<String, dynamic>> configChecklists;

  /// Active metrics from user's customisation config.
  /// Used to resolve metric labels from their stored IDs.
  final List<Map<String, dynamic>> configMetrics;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LogCard({
    required this.routine,
    required this.configChecklists,
    required this.configMetrics,
    required this.onEdit,
    required this.onDelete,
  });

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return 'Today';
      }
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        return 'Yesterday';
      }
      return DateFormat('EEEE, MMM d').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Resolve a habit title from config by its stored key/id.
  /// Falls back to prettified generic names for legacy built-in IDs.
  String _habitTitle(String id) {
    for (final c in configChecklists) {
      if ((c['id'] as String?) == id) {
        return (c['title'] as String?) ?? id;
      }
    }
    // Legacy / built-in id fallback
    const legacy = {'study': 'Study', 'exercise': 'Exercise', 'ml': 'Deep Work', 'reading': 'Reading'};
    return legacy[id] ?? id;
  }

  /// Resolve a metric label from config by its stored key/id.
  String _metricLabel(String id) {
    for (final m in configMetrics) {
      if ((m['id'] as String?) == id) {
        return (m['title'] as String?) ?? id;
      }
    }
    const legacy = {'studyHours': 'Study Hrs', 'mobileUsage': 'Mobile Hrs'};
    return legacy[id] ?? id;
  }

  /// For new logs: returns coreChecklists directly.
  /// For legacy logs (empty coreChecklists): synthesises from boolean fields
  /// so old entries still display meaningful chips without crashing.
  Map<String, bool> _resolvedChecklists() {
    if (routine.coreChecklists.isNotEmpty) {
      return routine.coreChecklists;
    }
    // Legacy synthesis — Option A
    final synth = <String, bool>{};
    if (routine.studyCompleted) synth['study'] = true;
    if (routine.exerciseCompleted) synth['exercise'] = true;
    if (routine.mlCompleted) synth['ml'] = true;
    return synth;
  }

  /// For new logs: returns coreMetrics directly.
  /// For legacy logs (empty coreMetrics): synthesises from scalar fields.
  Map<String, dynamic> _resolvedMetrics() {
    if (routine.coreMetrics.isNotEmpty) return routine.coreMetrics;
    final synth = <String, dynamic>{};
    if (routine.studyHours > 0) synth['studyHours'] = routine.studyHours;
    if (routine.mobileUsage > 0) synth['mobileUsage'] = routine.mobileUsage;
    return synth;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(routine.productivityScore);
    final checklists = _resolvedChecklists();
    final metrics = _resolvedMetrics();

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
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(_formatDate(routine.date),
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${routine.productivityScore}',
                    style: GoogleFonts.inter(
                        color: scoreColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Progress bar ──────────────────────────────────────────
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

          // ── Habit chips — fully dynamic, config-label resolved ────
          if (checklists.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: checklists.entries.map((e) {
                final done = e.value;

                final title = _habitTitle(e.key);
                // Truncate very long titles to fit chip neatly
                final short =
                    title.length > 16 ? '${title.substring(0, 16)}…' : title;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: done
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color:
                            done ? AppColors.success : AppColors.textMuted,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        short,
                        style: GoogleFonts.inter(
                          color: done
                              ? AppColors.success
                              : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 10),

          // ── Metrics row — dynamic from coreMetrics ────────────────
          if (metrics.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: metrics.entries
                  .where((e) {
                    final v = e.value;
                    return (v is num && v > 0);
                  })
                  .map((e) {
                    final label = _metricLabel(e.key);
                    final shortLabel =
                        label.length > 12 ? '${label.substring(0, 12)}…' : label;
                    final val = e.value;
                    return Text('$val $shortLabel',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 12));
                  })
                  .toList(),
            ),

          if (routine.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(routine.notes,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 10),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),

          // ── Footer ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.bedtime_outlined,
                  color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text('${routine.sleepTime} → ${routine.wakeTime}',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_outlined,
                    color: AppColors.textMuted, size: 18),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined,
              size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No logs yet',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Start tracking your daily habits',
              style:
                  GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Log Today',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700)),
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
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(message,
                style: GoogleFonts.inter(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: GoogleFonts.inter(color: AppColors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}
