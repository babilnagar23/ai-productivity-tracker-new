import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/data/repositories/routine_repository.dart';

final calendarRoutinesProvider = FutureProvider<List<RoutineModel>>((ref) async {
  return RoutineRepository().getRoutines();
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(calendarRoutinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.purple)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
        data: (routines) {
          // Build a map from date string -> routine
          final routineMap = {for (final r in routines) r.date: r};

          RoutineModel? selectedRoutine;
          if (_selectedDay != null) {
            final key = DateFormat('yyyy-MM-dd').format(_selectedDay!);
            selectedRoutine = routineMap[key];
          }

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onPageChanged: (focused) => setState(() => _focusedDay = focused),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
                  weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
                  todayDecoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.purple,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  markerDecoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  markersMaxCount: 1,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                  leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  weekendStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                eventLoader: (day) {
                  final key = DateFormat('yyyy-MM-dd').format(day);
                  return routineMap.containsKey(key) ? [routineMap[key]!] : [];
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (ctx, day, events) {
                    if (events.isEmpty) return null;
                    final routine = events.first as RoutineModel;
                    Color dotColor;
                    if (routine.productivityScore >= 80) { dotColor = AppColors.success; }
                    else if (routine.productivityScore >= 50) { dotColor = AppColors.warning; }
                    else { dotColor = AppColors.error; }
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: _selectedDay == null
                    ? const _CalendarHint()
                    : selectedRoutine == null
                        ? _NoEntryView(date: _selectedDay!)
                        : _RoutineDetail(routine: selectedRoutine),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalendarHint extends StatelessWidget {
  const _CalendarHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, color: AppColors.textMuted, size: 36),
          SizedBox(height: 12),
          Text('Tap a date to see details', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _NoEntryView extends StatelessWidget {
  final DateTime date;
  const _NoEntryView({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy_rounded, color: AppColors.textMuted, size: 36),
          const SizedBox(height: 12),
          Text(
            'No entry for ${DateFormat('MMMM d, yyyy').format(date)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RoutineDetail extends StatelessWidget {
  final RoutineModel routine;
  const _RoutineDetail({required this.routine});

  Color get _scoreColor {
    if (routine.productivityScore >= 80) return AppColors.success;
    if (routine.productivityScore >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${routine.productivityScore}/100',
                  style: TextStyle(color: _scoreColor, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.parse(routine.date)),
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: routine.productivityScore / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(_scoreColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 20),
          _DetailRow(icon: Icons.menu_book_rounded, color: AppColors.blue,
              label: 'Study', value: '${routine.studyHours}h • ${routine.studyCompleted ? "Completed" : "Not completed"}'),
          _DetailRow(icon: Icons.fitness_center_rounded, color: AppColors.success,
              label: 'Exercise', value: routine.exerciseCompleted ? 'Completed ✓' : 'Not completed'),
          _DetailRow(icon: Icons.psychology_rounded, color: AppColors.purple,
              label: 'ML / Deep Work', value: routine.mlCompleted ? 'Completed ✓' : 'Not completed'),
          _DetailRow(icon: Icons.smartphone_rounded, color: AppColors.warning,
              label: 'Mobile Usage', value: '${routine.mobileUsage}h'),
          _DetailRow(icon: Icons.bedtime_rounded, color: AppColors.cyan,
              label: 'Sleep → Wake', value: '${routine.sleepTime} → ${routine.wakeTime}'),
          if (routine.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(routine.notes, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
