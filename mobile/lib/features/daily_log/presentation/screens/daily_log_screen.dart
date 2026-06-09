import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/presentation/providers/routines_provider.dart';

class DailyLogScreen extends ConsumerStatefulWidget {
  const DailyLogScreen({super.key});

  @override
  ConsumerState<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends ConsumerState<DailyLogScreen> {
  static final DateTime _minMonth = DateTime(2015, 1, 1);
  static final DateTime _maxMonth = DateTime(2035, 12, 1);

  late final PageController _monthController;
  late DateTime _selectedDate;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _monthController =
        PageController(initialPage: _monthIndexForDate(_focusedMonth));
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(routinesProvider);
    final configAsync = ref.watch(customConfigProvider);

    final routines = routinesAsync.asData?.value ?? const <RoutineModel>[];
    final config = configAsync.asData?.value ?? <String, dynamic>{};

    final configChecklists = _readConfigList(config['coreChecklists']);
    final configMetrics = _readConfigList(config['coreMetrics']);
    final selectedRoutine = _routineForDate(routines, _selectedDate);
    final selectedChecklists = _resolvedChecklists(selectedRoutine);

    final selectedCompletedCount =
        selectedChecklists.values.where((v) => v).length;
    final selectedTotalCount = configChecklists.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/daily-log/add');
          ref.invalidate(routinesProvider);
        },
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(routinesProvider);
            ref.invalidate(customConfigProvider);
          },
          color: AppColors.blue,
          backgroundColor: AppColors.card,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _TopBar(
                onCustomize: () => context.push('/daily-log/customize'),
                onStats: () => context.push('/daily-log/analytics'),
                onAdd: () async {
                  await context.push('/daily-log/add');
                  ref.invalidate(routinesProvider);
                },
              ),
              const SizedBox(height: 18),
              _MonthHeader(
                monthLabel: DateFormat('MMMM yyyy').format(_focusedMonth),
                onPrevious: () => _jumpMonth(-1),
                onNext: () => _jumpMonth(1),
                onToday: _jumpToToday,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 414,
                child: PageView.builder(
                  controller: _monthController,
                  itemCount: _monthCount,
                  onPageChanged: (page) {
                    final month = _monthForIndex(page);
                    setState(() {
                      _focusedMonth = month;
                      _selectedDate = _clampDateToMonth(_selectedDate, month);
                    });
                  },
                  itemBuilder: (context, index) {
                    final month = _monthForIndex(index);
                    return _MonthCalendar(
                      month: month,
                      selectedDate: _selectedDate,
                      routines: routines,
                      onDaySelected: (date) {
                        setState(() {
                          _selectedDate = date;
                          _focusedMonth = DateTime(date.year, date.month, 1);
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _SelectedDaySummary(
                selectedDate: _selectedDate,
                selectedRoutine: selectedRoutine,
                completedCount: selectedCompletedCount,
                totalCount: selectedTotalCount,
                hasConfig: configChecklists.isNotEmpty,
              ),
              const SizedBox(height: 18),
              if (configChecklists.isEmpty)
                _EmptyConfigState(
                  onCustomize: () => context.push('/daily-log/customize'),
                )
              else
                _HabitSection(
                  checklists: configChecklists,
                  selectedRoutine: selectedRoutine,
                  selectedChecklists: selectedChecklists,
                  onTapHabit: () async {
                    if (selectedRoutine != null) {
                      await context.push(
                        '/daily-log/edit/${selectedRoutine.id}',
                      );
                    } else {
                      await context.push('/daily-log/add');
                    }

                    ref.invalidate(routinesProvider);
                  },
                ),
              const SizedBox(height: 22),
              _MetricsSection(
                routine: selectedRoutine,
                metrics: configMetrics,
              ),
              const SizedBox(height: 22),
              _NotesSection(
                routine: selectedRoutine,
                onTap: () {
                  if (selectedRoutine != null) {
                    context.push(
                      '/daily-log/edit/${selectedRoutine.id}',
                    );
                  }
                },
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Month navigation
  // ───────────────────────────────────────────────────────────────────────────

  int get _monthCount {
    final startIndex = _monthIndexForDate(_minMonth);
    final endIndex = _monthIndexForDate(_maxMonth);
    return endIndex - startIndex + 1;
  }

  int _monthIndexForDate(DateTime date) {
    return (date.year - _minMonth.year) * 12 + (date.month - _minMonth.month);
  }

  DateTime _monthForIndex(int index) {
    return DateTime(_minMonth.year, _minMonth.month + index, 1);
  }

  void _jumpMonth(int delta) {
    final target = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    final page = _monthIndexForDate(target);
    if (page < 0 || page >= _monthCount) return;

    _monthController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _jumpToToday() {
    final todayMonth = DateTime.now();
    final month = DateTime(todayMonth.year, todayMonth.month, 1);
    final page = _monthIndexForDate(month);
    if (page < 0 || page >= _monthCount) return;

    _monthController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );

    setState(() {
      _focusedMonth = month;
      _selectedDate =
          DateTime(todayMonth.year, todayMonth.month, todayMonth.day);
    });
  }

  DateTime _clampDateToMonth(DateTime date, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final safeDay = date.day > lastDay ? lastDay : date.day;
    return DateTime(month.year, month.month, safeDay);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Data helpers
  // ───────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _readConfigList(dynamic raw) {
    final list = (raw as List<dynamic>?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  RoutineModel? _routineForDate(List<RoutineModel> routines, DateTime day) {
    for (final routine in routines) {
      final date = _safeParseDate(routine.date);
      if (_sameDay(date, day)) return routine;
    }
    return null;
  }

  DateTime _safeParseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Map<String, bool> _resolvedChecklists(RoutineModel? routine) {
    if (routine == null) return {};
    if (routine.coreChecklists.isNotEmpty) return routine.coreChecklists;

    final legacy = <String, bool>{};
    if (routine.studyCompleted) legacy['study'] = true;
    if (routine.exerciseCompleted) legacy['exercise'] = true;
    if (routine.mlCompleted) legacy['ml'] = true;
    return legacy;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onCustomize;
  final VoidCallback onStats;
  final VoidCallback onAdd;

  const _TopBar({
    required this.onCustomize,
    required this.onStats,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.success,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Daily Log',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onStats,
          icon: const Icon(
            Icons.bar_chart_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
        IconButton(
          onPressed: onCustomize,
          icon: const Icon(
            Icons.tune_rounded,
            color: AppColors.success,
            size: 22,
          ),
        ),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(
            Icons.add_rounded,
            color: AppColors.blue,
            size: 24,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month header + picker
// ─────────────────────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthHeader({
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SectionTitle(text: 'Routine'),
        const Spacer(),
        TextButton(
          onPressed: onToday,
          child: Text(
            'Today',
            style: GoogleFonts.inter(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          monthLabel,
          style: GoogleFonts.inter(
            color: AppColors.success,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final List<RoutineModel> routines;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthCalendar({
    required this.month,
    required this.selectedDate,
    required this.routines,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(child: _WeekdayLabel(text: 'MO')),
              Expanded(child: _WeekdayLabel(text: 'TU')),
              Expanded(child: _WeekdayLabel(text: 'WE')),
              Expanded(child: _WeekdayLabel(text: 'TH')),
              Expanded(child: _WeekdayLabel(text: 'FR')),
              Expanded(child: _WeekdayLabel(text: 'SA')),
              Expanded(child: _WeekdayLabel(text: 'SU')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index < leadingEmpty ||
                    index >= leadingEmpty + daysInMonth) {
                  return const SizedBox.shrink();
                }

                final day = index - leadingEmpty + 1;
                final date = DateTime(month.year, month.month, day);

                final selected = _sameDay(date, selectedDate);
                final hasLog = _hasRoutineForDate(date);
                final isToday = _sameDay(date, today);

                final enabledOpacity = hasLog ? 1.0 : 0.42;
                final backgroundColor = selected
                    ? AppColors.cardElevated
                    : AppColors.card.withValues(alpha: hasLog ? 1.0 : 0.55);

                final borderColor = selected
                    ? AppColors.success
                    : hasLog
                        ? AppColors.border
                        : AppColors.border.withValues(alpha: 0.5);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onDaySelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Opacity(
                      opacity: enabledOpacity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: GoogleFonts.inter(
                              color: selected
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (hasLog)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            )
                          else if (isToday)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.blue,
                              ),
                            )
                          else
                            const SizedBox(height: 7),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _hasRoutineForDate(DateTime day) {
    for (final routine in routines) {
      try {
        final date = DateTime.parse(routine.date);
        if (_sameDay(date, day)) return true;
      } catch (_) {
        // ignore invalid dates
      }
    }
    return false;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;

  const _WeekdayLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected day summary
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedDaySummary extends StatelessWidget {
  final DateTime selectedDate;
  final RoutineModel? selectedRoutine;
  final int completedCount;
  final int totalCount;
  final bool hasConfig;

  const _SelectedDaySummary({
    required this.selectedDate,
    required this.selectedRoutine,
    required this.completedCount,
    required this.totalCount,
    required this.hasConfig,
  });

  @override
  Widget build(BuildContext context) {
    final hasLog = selectedRoutine != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasLog ? AppColors.card : AppColors.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasLog
              ? AppColors.border
              : AppColors.border.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasLog
                  ? AppColors.success.withValues(alpha: 0.14)
                  : AppColors.textMuted.withValues(alpha: 0.12),
            ),
            child: Icon(
              hasLog
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: hasLog ? AppColors.success : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !hasConfig
                      ? 'Open customization to add active habits.'
                      : hasLog
                          ? '$completedCount of ${totalCount == 0 ? 0 : totalCount} habits completed'
                          : 'No log saved for this day yet.',
                  style: GoogleFonts.inter(
                    color: hasLog ? AppColors.success : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic habit section
// ─────────────────────────────────────────────────────────────────────────────

class _HabitSection extends StatelessWidget {
  final List<Map<String, dynamic>> checklists;
  final RoutineModel? selectedRoutine;
  final Map<String, bool> selectedChecklists;
  final VoidCallback onTapHabit;

  const _HabitSection({
    required this.checklists,
    required this.selectedRoutine,
    required this.selectedChecklists,
    required this.onTapHabit,
  });

  @override
  Widget build(BuildContext context) {
    final hasLog = selectedRoutine != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(text: 'Active Habits'),
        const SizedBox(height: 12),
        ...checklists.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          final id = (item['id'] as String?) ?? 'habit_$index';
          final title = (item['title'] as String?) ?? id;
          final done = selectedChecklists[id] ?? false;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HabitCard(
              title: title,
              done: done,
              hasLog: hasLog,
              index: index,
              onTap: onTapHabit,
            ),
          );
        }),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  final String title;
  final bool done;
  final bool hasLog;
  final int index;
  final VoidCallback onTap;

  const _HabitCard({
    required this.title,
    required this.done,
    required this.hasLog,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final faded = !hasLog || !done;
    final accent = _accentForIndex(index);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: hasLog ? (done ? 1.0 : 0.48) : 0.36,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: faded
                  ? AppColors.card.withValues(alpha: 0.65)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: done
                    ? AppColors.success.withValues(alpha: 0.25)
                    : AppColors.border.withValues(alpha: 0.65),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.success
                        : accent.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: done ? AppColors.textPrimary : AppColors.textMuted,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (done)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentForIndex(int index) {
    const palette = [
      Color(0xFF1D4ED8),
      Color(0xFFF59E0B),
      Color(0xFF7C3AED),
      Color(0xFF06B6D4),
      Color(0xFFEF4444),
      Color(0xFF10B981),
    ];
    return palette[index % palette.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyConfigState extends StatelessWidget {
  final VoidCallback onCustomize;

  const _EmptyConfigState({required this.onCustomize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No active habits configured',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add or restore habits from the customization screen and they will appear here automatically.',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onCustomize,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              elevation: 0,
            ),
            child: Text(
              'Open Customization',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  final RoutineModel? routine;
  final List<Map<String, dynamic>> metrics;

  const _MetricsSection({
    required this.routine,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(text: 'Metrics'),
        const SizedBox(height: 12),
        ...metrics.map((metric) {
          final id = metric['id']?.toString() ?? '';

          final title = metric['title']?.toString() ?? 'Metric';

          final value = routine?.coreMetrics[id]?.toString() ?? '0';

          final unit = metric['unit']?.toString() ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MetricCard(
              title: title,
              value: value,
              unit: unit,
              onTap: () {
                if (routine != null) {
                  context.push('/daily-log/edit/${routine!.id}');
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: GoogleFonts.inter(
                      color: AppColors.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final RoutineModel? routine;
  final VoidCallback? onTap;

  const _NotesSection({
    required this.routine,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final notes = routine?.notes.trim() ?? '';

    if (notes.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(text: 'Notes'),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Text(
              notes,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
