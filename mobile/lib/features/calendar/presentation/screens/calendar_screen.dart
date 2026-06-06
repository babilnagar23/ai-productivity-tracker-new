import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/data/repositories/routine_repository.dart';

final calendarRoutinesProvider = FutureProvider<List<RoutineModel>>((ref) async {
  return RoutineRepository().getRoutines();
});

final calendarStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await apiClient.dio.get(ApiEndpoints.calendarStatus);
    return response.data as Map<String, dynamic>;
  } catch (_) {
    return {'connected': false};
  }
});

final calendarEventsProvider = FutureProvider.family<List<dynamic>, String>((ref, date) async {
  try {
    final response = await apiClient.dio.get(ApiEndpoints.calendarEvents, queryParameters: {'date': date});
    final body = response.data as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? body['events'] as List<dynamic>? ?? [];
  } catch (_) {
    return [];
  }
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _fabExpanded = false;

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(calendarRoutinesProvider);
    final statusAsync = ref.watch(calendarStatusProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final eventsAsync = ref.watch(calendarEventsProvider(todayStr));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Calendar', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          PopupMenuButton<CalendarFormat>(
            initialValue: _calendarFormat,
            onSelected: (f) => setState(() => _calendarFormat = f),
            color: AppColors.card,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(_calendarFormat == CalendarFormat.month ? 'Month' : 'Week',
                      style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13)),
                  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(value: CalendarFormat.month, child: Text('Month', style: GoogleFonts.inter(color: AppColors.textPrimary))),
              PopupMenuItem(value: CalendarFormat.week, child: Text('Week', style: GoogleFonts.inter(color: AppColors.textPrimary))),
            ],
          ),
          IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.textMuted), onPressed: () {}),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
        error: (e, _) => Center(child: Text('$e', style: GoogleFonts.inter(color: AppColors.error))),
        data: (routines) {
          final routineMap = {for (final r in routines) r.date: r};
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Calendar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() { _selectedDay = selected; _focusedDay = focused; });
                      },
                      onFormatChanged: (f) => setState(() => _calendarFormat = f),
                      onPageChanged: (focused) => setState(() => _focusedDay = focused),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        defaultTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
                        weekendTextStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                        todayDecoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.inter(color: AppColors.blue, fontWeight: FontWeight.w700),
                        selectedDecoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                        selectedTextStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                        leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                        rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                        weekendStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
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
                            child: Container(width: 6, height: 6,
                                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Today's productivity timeline
                  Text("Today's Productivity Timeline",
                      style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  eventsAsync.when(
                    loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppColors.blue))),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (events) => events.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                            child: Text('No events today', style: GoogleFonts.inter(color: AppColors.textMuted)),
                          )
                        : SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: events.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final e = events[i] as Map<String, dynamic>;
                                return Container(
                                  width: 120,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e['title'] as String? ?? 'Event',
                                          style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const Spacer(),
                                      Text(e['start_time'] as String? ?? '',
                                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Google Calendar integration
                  statusAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => _buildGoogleCalendarCard(false, null),
                    data: (status) => _buildGoogleCalendarCard(
                      status['connected'] as bool? ?? false,
                      status,
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),

              // FAB
              Positioned(
                bottom: 24,
                right: 16,
                child: _buildFab(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoogleCalendarCard(bool connected, Map<String, dynamic>? status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_rounded, color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Google Calendar Integration',
                    style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                if (connected && status?['last_sync'] != null)
                  Text('Last sync: ${status!['last_sync']}',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Synced', style: GoogleFonts.inter(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
            )
          else
            ElevatedButton(
              onPressed: _connectGoogleCalendar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: Text('Connect', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Future<void> _connectGoogleCalendar() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.calendarAuthUrl);
      // Backend returns { authUrl: "..." }
      final url = response.data['authUrl'] as String?
          ?? response.data['auth_url'] as String?
          ?? response.data['url'] as String?;
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          _FabOption(icon: Icons.task_alt_rounded, label: 'New Task', onTap: () { setState(() => _fabExpanded = false); _showAddEventModal('Task'); }),
          _FabOption(icon: Icons.school_outlined, label: 'Study Session', onTap: () { setState(() => _fabExpanded = false); _showAddEventModal('Study Session'); }),
          _FabOption(icon: Icons.fitness_center_rounded, label: 'Workout', onTap: () { setState(() => _fabExpanded = false); _showAddEventModal('Workout'); }),
          _FabOption(icon: Icons.alarm_rounded, label: 'Reminder', onTap: () { setState(() => _fabExpanded = false); _showAddEventModal('Reminder'); }),
          _FabOption(icon: Icons.event_rounded, label: 'Event', onTap: () { setState(() => _fabExpanded = false); _showAddEventModal('Event'); }),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () => setState(() => _fabExpanded = !_fabExpanded),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
            child: Icon(_fabExpanded ? Icons.close_rounded : Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  void _showAddEventModal(String type) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New $type', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _inputField(titleCtrl, 'Title'),
            const SizedBox(height: 10),
            _inputField(descCtrl, 'Description (optional)'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  try {
                    final now = DateTime.now();
                    // Default: event starts in 1 hour, lasts 1 hour
                    final start = now.add(const Duration(hours: 1));
                    final end = start.add(const Duration(hours: 1));
                    await apiClient.dio.post(ApiEndpoints.calendarEvents, data: {
                      'title': titleCtrl.text,
                      'description': descCtrl.text,
                      'start': start.toIso8601String(),
                      'end': end.toIso8601String(),
                      'category': type.toLowerCase().replaceAll(' ', '_'),
                    });
                    if (mounted) {
                      navigator.pop();
                      ref.invalidate(calendarEventsProvider(DateFormat('yyyy-MM-dd').format(DateTime.now())));
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.inter(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.blue)),
      ),
    );
  }
}

class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FabOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(width: 10),
            Icon(icon, color: AppColors.blue, size: 20),
          ],
        ),
      ),
    );
  }
}
