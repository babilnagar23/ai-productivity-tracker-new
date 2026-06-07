import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';

// -----------------------------------------------------------------------------
// Models / helpers
// -----------------------------------------------------------------------------

enum CalendarViewMode { month, week, day }

class CalendarEventItem {
  final int id;
  final String? googleEventId;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String colorKey;
  final String category;
  final String location;
  final List<String> attendees;
  final List<dynamic> recurrence;
  final List<dynamic> reminders;
  final bool syncedToGoogle;
  final bool isAiGenerated;
  final bool completed;
  final DateTime createdAt;

  CalendarEventItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.googleEventId,
    this.description = '',
    this.allDay = false,
    this.colorKey = 'blue',
    this.category = 'personal',
    this.location = '',
    this.attendees = const [],
    this.recurrence = const [],
    this.reminders = const [10],
    this.syncedToGoogle = false,
    this.isAiGenerated = false,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CalendarEventItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
      return DateTime.now();
    }

    final attendeesRaw = json['attendees'];
    final remindersRaw = json['reminders'];
    final recurrenceRaw = json['recurrence'];

    return CalendarEventItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      googleEventId: json['googleEventId'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      start: parseDate(json['start']),
      end: parseDate(json['end']),
      allDay: json['allDay'] as bool? ?? false,
      colorKey:
          json['colorKey'] as String? ?? json['color'] as String? ?? 'blue',
      category: json['category'] as String? ?? 'personal',
      location: json['location'] as String? ?? '',
      attendees: attendeesRaw is List
          ? attendeesRaw.map((e) => e.toString()).toList()
          : const [],
      recurrence: recurrenceRaw is List ? recurrenceRaw : const [],
      reminders: remindersRaw is List ? remindersRaw : const [10],
      syncedToGoogle: json['syncedToGoogle'] as bool? ?? false,
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CalendarEventItem copyWith({
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    String? colorKey,
    String? category,
    String? location,
    List<String>? attendees,
    List<dynamic>? recurrence,
    List<dynamic>? reminders,
    bool? syncedToGoogle,
    bool? isAiGenerated,
    bool? completed,
  }) {
    return CalendarEventItem(
      id: id,
      googleEventId: googleEventId,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
      colorKey: colorKey ?? this.colorKey,
      category: category ?? this.category,
      location: location ?? this.location,
      attendees: attendees ?? this.attendees,
      recurrence: recurrence ?? this.recurrence,
      reminders: reminders ?? this.reminders,
      syncedToGoogle: syncedToGoogle ?? this.syncedToGoogle,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      completed: completed ?? this.completed,
      createdAt: createdAt,
    );
  }
}

class CalendarDateRange {
  final DateTime start;
  final DateTime end;
  const CalendarDateRange(this.start, this.end);

  String get key => '${start.toIso8601String()}|${end.toIso8601String()}';
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
DateTime _startOfWeek(DateTime d) =>
    _startOfDay(d.subtract(Duration(days: d.weekday - 1)));
DateTime _endOfWeek(DateTime d) =>
    _endOfDay(_startOfWeek(d).add(const Duration(days: 6)));
DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _endOfMonth(DateTime d) => _endOfDay(DateTime(d.year, d.month + 1, 0));

String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

Color _eventColor(String key) {
  switch (key) {
    case 'purple':
      return AppColors.purple;
    case 'green':
      return AppColors.success;
    case 'pink':
      return AppColors.error;
    case 'orange':
      return AppColors.warning;
    case 'cyan':
      return AppColors.blue;
    case 'red':
      return AppColors.error;
    case 'blue':
    default:
      return AppColors.blue;
  }
}

String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);
String _formatDate(DateTime dt) => DateFormat('EEE, MMM d, yyyy').format(dt);

// -----------------------------------------------------------------------------
// Providers
// -----------------------------------------------------------------------------

final calendarStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await apiClient.dio.get(ApiEndpoints.calendarStatus);
    return response.data as Map<String, dynamic>;
  } catch (_) {
    return {'connected': false};
  }
});

final calendarEventsRangeProvider =
    FutureProvider.family<List<CalendarEventItem>, String>(
        (ref, rangeKey) async {
  try {
    final parts = rangeKey.split('|');
    final start = DateTime.parse(parts.first);
    final end = DateTime.parse(parts.last);
    final response = await apiClient.dio.get(
      ApiEndpoints.calendarEvents,
      queryParameters: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    );

    final body = response.data as Map<String, dynamic>;
    final raw = (body['events'] as List<dynamic>?) ??
        (body['data'] as List<dynamic>?) ??
        const [];
    final events = raw
        .whereType<Map>()
        .map((e) => CalendarEventItem.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return events;
  } catch (_) {
    return [];
  }
});

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month;
  bool _fabExpanded = false;
  bool _isFetchingGoogle = false;

  CalendarDateRange get _visibleRange {
    switch (_viewMode) {
      case CalendarViewMode.day:
        return CalendarDateRange(
            _startOfDay(_selectedDay), _endOfDay(_selectedDay));
      case CalendarViewMode.week:
        return CalendarDateRange(
            _startOfWeek(_focusedDay), _endOfWeek(_focusedDay));
      case CalendarViewMode.month:
        return CalendarDateRange(
            _startOfMonth(_focusedDay), _endOfMonth(_focusedDay));
    }
  }

  CalendarDateRange get _selectedDayRange =>
      CalendarDateRange(_startOfDay(_selectedDay), _endOfDay(_selectedDay));

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(calendarStatusProvider);
    final rangeAsync =
        ref.watch(calendarEventsRangeProvider(_visibleRange.key));
    final selectedDayAsync =
        ref.watch(calendarEventsRangeProvider(_selectedDayRange.key));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'Calendar',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _buildViewModeButton(),
          IconButton(
            icon:
                const Icon(Icons.settings_outlined, color: AppColors.textMuted),
            onPressed: _openCalendarSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.blue,
        backgroundColor: AppColors.card,
        onRefresh: _refreshAll,
        child: rangeAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.blue)),
          error: (e, _) => Center(
            child: Text('$e', style: GoogleFonts.inter(color: AppColors.error)),
          ),
          data: (rangeEvents) {
            final eventsByDay = _groupEventsByDay(rangeEvents);
            final visibleSelectedDayEvents = selectedDayAsync.maybeWhen(
              data: (v) => v,
              orElse: () => const <CalendarEventItem>[],
            );

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCalendarShell(eventsByDay),
                    const SizedBox(height: 16),
                    _buildTimelineHeader(),
                    const SizedBox(height: 10),
                    _buildProductivityTimeline(visibleSelectedDayEvents),
                    const SizedBox(height: 16),
                    statusAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => _buildGoogleCalendarCard(false, null),
                      data: (status) => _buildGoogleCalendarCard(
                        status['connected'] as bool? ?? false,
                        status,
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: _buildFab(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewModeButton() {
    final label = switch (_viewMode) {
      CalendarViewMode.month => 'Month',
      CalendarViewMode.week => 'Week',
      CalendarViewMode.day => 'Day',
    };

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<CalendarViewMode>(
        initialValue: _viewMode,
        color: AppColors.card,
        onSelected: (mode) {
          setState(() {
            _viewMode = mode;
            if (mode != CalendarViewMode.day) {
              _focusedDay = _selectedDay;
            }
          });
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: CalendarViewMode.month,
            child: Text('Month',
                style: GoogleFonts.inter(color: AppColors.textPrimary)),
          ),
          PopupMenuItem(
            value: CalendarViewMode.week,
            child: Text('Week',
                style: GoogleFonts.inter(color: AppColors.textPrimary)),
          ),
          PopupMenuItem(
            value: CalendarViewMode.day,
            child: Text('Day',
                style: GoogleFonts.inter(color: AppColors.textPrimary)),
          ),
        ],
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarShell(Map<String, List<CalendarEventItem>> eventsByDay) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => setState(() {
                    _focusedDay = switch (_viewMode) {
                      CalendarViewMode.month =>
                        DateTime(_focusedDay.year, _focusedDay.month - 1, 1),
                      CalendarViewMode.week =>
                        _focusedDay.subtract(const Duration(days: 7)),
                      CalendarViewMode.day =>
                        _selectedDay.subtract(const Duration(days: 1)),
                    };
                    if (_viewMode == CalendarViewMode.day) {
                      _selectedDay = _focusedDay;
                    }
                  }),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _viewMode == CalendarViewMode.day
                          ? _formatDate(_selectedDay)
                          : DateFormat('MMMM yyyy').format(_focusedDay),
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => setState(() {
                    _focusedDay = switch (_viewMode) {
                      CalendarViewMode.month =>
                        DateTime(_focusedDay.year, _focusedDay.month + 1, 1),
                      CalendarViewMode.week =>
                        _focusedDay.add(const Duration(days: 7)),
                      CalendarViewMode.day =>
                        _selectedDay.add(const Duration(days: 1)),
                    };
                    if (_viewMode == CalendarViewMode.day) {
                      _selectedDay = _focusedDay;
                    }
                  }),
                ),
              ],
            ),
            if (_viewMode != CalendarViewMode.day)
              TableCalendar<CalendarEventItem>(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                calendarFormat: _viewMode == CalendarViewMode.month
                    ? CalendarFormat.month
                    : CalendarFormat.week,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                  CalendarFormat.week: 'Week',
                },
                headerVisible: false,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                    _viewMode = CalendarViewMode.day;
                  });
                },
                onPageChanged: (focused) =>
                    setState(() => _focusedDay = focused),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  defaultTextStyle:
                      GoogleFonts.inter(color: AppColors.textPrimary),
                  weekendTextStyle:
                      GoogleFonts.inter(color: AppColors.textSecondary),
                  todayDecoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.26),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: GoogleFonts.inter(
                      color: AppColors.blue, fontWeight: FontWeight.w700),
                  selectedDecoration: const BoxDecoration(
                      color: AppColors.blue, shape: BoxShape.circle),
                  selectedTextStyle: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  markerMargin: const EdgeInsets.only(top: 6),
                  markersMaxCount: 3,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12),
                  weekendStyle: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12),
                ),
                eventLoader: (day) => eventsByDay[_dayKey(day)] ?? const [],
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (ctx, day, events) {
                    if (events.isEmpty) return null;
                    final count = events.length;
                    final colors = events
                        .take(3)
                        .map((e) => _eventColor(e.colorKey))
                        .toList();
                    if (count <= 1) {
                      return Positioned(
                        bottom: 4,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.success, shape: BoxShape.circle),
                        ),
                      );
                    }
                    return Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: colors
                            .map((c) => Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                      color: c, shape: BoxShape.circle),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
              )
            else
              _buildDayView(eventsByDay[_dayKey(_selectedDay)] ?? const []),
          ],
        ),
      ),
    );
  }

  Widget _buildDayView(List<CalendarEventItem> dayEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            _miniChip('${dayEvents.length} events'),
            const SizedBox(width: 8),
            _miniChip(_selectedDay.weekday == DateTime.saturday ||
                    _selectedDay.weekday == DateTime.sunday
                ? 'Weekend'
                : 'Workday'),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  setState(() => _viewMode = CalendarViewMode.week),
              child: Text('Back to week',
                  style: GoogleFonts.inter(color: AppColors.blue)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDaySummary(dayEvents),
      ],
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTimelineHeader() {
    final title = _viewMode == CalendarViewMode.day
        ? "${DateFormat('MMMM d').format(_selectedDay)} • Productivity Timeline"
        : "Today's Productivity Timeline";

    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildProductivityTimeline(List<CalendarEventItem> selectedDayEvents) {
    if (selectedDayEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'No events for this day',
          style: GoogleFonts.inter(color: AppColors.textMuted),
        ),
      );
    }

    final sorted = [...selectedDayEvents]
      ..sort((a, b) => a.start.compareTo(b.start));
    const startHour = 6;
    const endHour = 22;
    const slotWidth = 84.0;
    const totalWidth = (endHour - startHour + 1) * slotWidth;

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Stack(
            children: [
              Positioned.fill(
                top: 22,
                child: Row(
                  children: List.generate(endHour - startHour + 1, (index) {
                    final hour = startHour + index;
                    return SizedBox(
                      width: slotWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              hour == 12
                                  ? '12 PM'
                                  : hour < 12
                                      ? '$hour AM'
                                      : '${hour - 12} PM',
                              style: GoogleFonts.inter(
                                  color: AppColors.textMuted, fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              for (final event in sorted)
                _TimelineBlock(
                  event: event,
                  startHour: startHour,
                  endHour: endHour,
                  slotWidth: slotWidth,
                  onTap: () => _showEventDetail(event),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySummary(List<CalendarEventItem> events) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text('No events on this day',
            style: GoogleFonts.inter(color: AppColors.textMuted)),
      );
    }

    final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));
    return Column(
      children: sorted.map((event) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EventCard(
            event: event,
            onTap: () => _showEventDetail(event),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoogleCalendarCard(
      bool connected, Map<String, dynamic>? status) {
    final googleEmail = status?['googleEmail'] as String? ?? '';
    final lastSynced = status?['lastSynced'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: AppColors.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Calendar Integration',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected
                          ? (googleEmail.isNotEmpty
                              ? googleEmail
                              : 'Connected to Google Calendar')
                          : 'Connect your Google Calendar account',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    if (connected && lastSynced != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Last sync: $lastSynced',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              if (connected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Synced',
                    style: GoogleFonts.inter(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _connectGoogleCalendar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Connect',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFetchingGoogle ? null : _fetchGoogleEvents,
                    icon: _isFetchingGoogle
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.blue),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text('Sync Now',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _refreshAll,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Refresh',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          _FabOption(
              icon: Icons.task_alt_rounded,
              label: 'New Task',
              onTap: () {
                setState(() => _fabExpanded = false);
                _openEventEditor();
              }),
          _FabOption(
              icon: Icons.event_rounded,
              label: 'New Event',
              onTap: () {
                setState(() => _fabExpanded = false);
                _openEventEditor(initialDate: _selectedDay);
              }),
          _FabOption(
              icon: Icons.notifications_active_rounded,
              label: 'Reminder',
              onTap: () {
                setState(() => _fabExpanded = false);
                _openEventEditor(initialCategory: 'reminder');
              }),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () => setState(() => _fabExpanded = !_fabExpanded),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: AppColors.blue, shape: BoxShape.circle),
            child: Icon(_fabExpanded ? Icons.close_rounded : Icons.add_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Future<void> _connectGoogleCalendar() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.calendarAuthUrl);
      final data = response.data as Map<String, dynamic>;
      final url = data['authUrl'] as String? ??
          data['auth_url'] as String? ??
          data['url'] as String?;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _fetchGoogleEvents() async {
    setState(() => _isFetchingGoogle = true);
    try {
      await apiClient.dio.post('/calendar/fetch-google');
      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google events synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingGoogle = false);
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(calendarStatusProvider);
    ref.invalidate(calendarEventsRangeProvider(_visibleRange.key));
    ref.invalidate(calendarEventsRangeProvider(_selectedDayRange.key));
    await Future.wait([
      ref.read(calendarStatusProvider.future),
      ref.read(calendarEventsRangeProvider(_visibleRange.key).future),
      ref.read(calendarEventsRangeProvider(_selectedDayRange.key).future),
    ]);
  }

  Map<String, List<CalendarEventItem>> _groupEventsByDay(
      List<CalendarEventItem> events) {
    final map = <String, List<CalendarEventItem>>{};
    for (final e in events) {
      final key = _dayKey(e.start);
      map.putIfAbsent(key, () => []).add(e);
      if (e.allDay) {
        map.putIfAbsent(_dayKey(e.end), () => []).add(e);
      }
    }
    return map;
  }

  void _openCalendarSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calendar Options',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync_rounded, color: AppColors.blue),
              title: Text('Fetch Google Calendar events',
                  style: GoogleFonts.inter(color: AppColors.textPrimary)),
              subtitle: Text('Pull the latest synced events into the app',
                  style: GoogleFonts.inter(color: AppColors.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _fetchGoogleEvents();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.refresh_rounded, color: AppColors.blue),
              title: Text('Refresh current view',
                  style: GoogleFonts.inter(color: AppColors.textPrimary)),
              subtitle: Text('Reload calendar and timeline data',
                  style: GoogleFonts.inter(color: AppColors.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _refreshAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEventDetail(CalendarEventItem event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _detailRow(
                  'Description',
                  event.description.isEmpty
                      ? 'No description'
                      : event.description),
              _detailRow(
                  'Start Time',
                  event.allDay
                      ? 'All day'
                      : '${_formatDate(event.start)} • ${_formatTime(event.start)}'),
              _detailRow(
                  'End Time',
                  event.allDay
                      ? 'All day'
                      : '${_formatDate(event.end)} • ${_formatTime(event.end)}'),
              _detailRow('Category', event.category),
              _detailRow('Color', event.colorKey),
              _detailRow(
                  'Reminder',
                  event.reminders.isNotEmpty
                      ? event.reminders.join(', ')
                      : 'None'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openEventEditor(initialEvent: event);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: Text('Edit',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _deleteEvent(event);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text('Delete',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!event.syncedToGoogle)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _syncSingleEventToGoogle(event);
                    },
                    icon: const Icon(Icons.sync_rounded),
                    label: Text('Sync to Google',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: AppColors.blue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _syncSingleEventToGoogle(CalendarEventItem event) async {
    try {
      await apiClient.dio.post(
        ApiEndpoints.calendarEvents,
        data: {
          'title': event.title,
          'description': event.description,
          'start': event.start.toIso8601String(),
          'end': event.end.toIso8601String(),
          'allDay': event.allDay,
          'category': event.category,
          'color': event.colorKey,
          'location': event.location,
          'attendees': event.attendees,
          'recurrence': event.recurrence,
          'reminders': event.reminders,
          'syncToGoogle': true,
        },
      );
      await _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteEvent(CalendarEventItem event) async {
    try {
      await apiClient.dio.delete('${ApiEndpoints.calendarEvents}/${event.id}');
      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _openEventEditor(
      {CalendarEventItem? initialEvent,
      DateTime? initialDate,
      String? initialCategory}) async {
    final titleCtrl = TextEditingController(text: initialEvent?.title ?? '');
    final descCtrl =
        TextEditingController(text: initialEvent?.description ?? '');
    final locationCtrl =
        TextEditingController(text: initialEvent?.location ?? '');

    DateTime selectedDate = initialEvent?.start ?? initialDate ?? _selectedDay;
    TimeOfDay startTime = TimeOfDay.fromDateTime(
        initialEvent?.start ?? DateTime.now().add(const Duration(hours: 1)));
    TimeOfDay endTime = TimeOfDay.fromDateTime(
        initialEvent?.end ?? DateTime.now().add(const Duration(hours: 2)));
    bool allDay = initialEvent?.allDay ?? false;
    bool syncToGoogle = initialEvent?.syncedToGoogle ?? false;
    String category = initialEvent?.category ?? initialCategory ?? 'personal';
    String colorKey = initialEvent?.colorKey ?? 'blue';
    int reminderMinutes = (initialEvent?.reminders.isNotEmpty ?? false)
        ? (initialEvent!.reminders.first as num).toInt()
        : 10;

    final colorChoices = ['blue', 'purple', 'green', 'pink', 'orange', 'cyan'];
    final reminderChoices = [0, 5, 10, 15, 30, 60];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.blue,
                      surface: AppColors.surface,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setModalState(() => selectedDate = picked);
            }

            Future<void> pickTime(bool isStart) async {
              final picked = await showTimePicker(
                context: ctx,
                initialTime: isStart ? startTime : endTime,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.blue,
                      surface: AppColors.surface,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setModalState(() {
                  if (isStart) {
                    startTime = picked;
                  } else {
                    endTime = picked;
                  }
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            initialEvent == null
                                ? 'New Task / Event'
                                : 'Edit Event',
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _editorField(titleCtrl, 'Title'),
                    const SizedBox(height: 10),
                    _editorField(descCtrl, 'Description (optional)',
                        maxLines: 3),
                    const SizedBox(height: 10),
                    _editorField(locationCtrl, 'Location (optional)'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.calendar_month_rounded,
                            label: 'Date',
                            value:
                                DateFormat('MMM d, yyyy').format(selectedDate),
                            onTap: pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.access_time_rounded,
                            label: 'Start',
                            value: allDay ? 'All day' : startTime.format(ctx),
                            onTap: allDay ? null : () => pickTime(true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.timelapse_rounded,
                            label: 'End',
                            value: allDay ? 'All day' : endTime.format(ctx),
                            onTap: allDay ? null : () => pickTime(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.label_rounded,
                            label: 'Category',
                            value: category,
                            onTap: () async {
                              final chosen = await _showChoiceSheet<String>(
                                ctx,
                                title: 'Category',
                                choices: const [
                                  'study',
                                  'work',
                                  'exercise',
                                  'break',
                                  'personal',
                                  'reminder'
                                ],
                              );
                              if (chosen != null) {
                                setModalState(() => category = chosen);
                              } 
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Color',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colorChoices.map((c) {
                        final selected = c == colorKey;
                        return GestureDetector(
                          onTap: () => setModalState(() => colorKey = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _eventColor(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _eventColor(c).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile.adaptive(
                            value: allDay,
                            onChanged: (v) => setModalState(() => allDay = v),
                            contentPadding: EdgeInsets.zero,
                            title: Text('All day',
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary)),
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile.adaptive(
                            value: syncToGoogle,
                            onChanged: (v) =>
                                setModalState(() => syncToGoogle = v),
                            contentPadding: EdgeInsets.zero,
                            title: Text('Sync to Google',
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Reminder',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reminderChoices.map((m) {
                        final selected = reminderMinutes == m;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(m == 0 ? 'No reminder' : '$m min'),
                          labelStyle: GoogleFonts.inter(
                            color:
                                selected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: AppColors.blue,
                          backgroundColor: AppColors.cardElevated,
                          onSelected: (_) =>
                              setModalState(() => reminderMinutes = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty) return;

                          final startDateTime = allDay
                              ? DateTime(selectedDate.year, selectedDate.month,
                                  selectedDate.day)
                              : DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  startTime.hour,
                                  startTime.minute,
                                );
                          final endDateTime = allDay
                              ? DateTime(selectedDate.year, selectedDate.month,
                                  selectedDate.day, 23, 59, 59)
                              : DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  endTime.hour,
                                  endTime.minute,
                                );

                          final payload = {
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'start': startDateTime.toIso8601String(),
                            'end': endDateTime.toIso8601String(),
                            'allDay': allDay,
                            'category': category,
                            'color': colorKey,
                            'location': locationCtrl.text.trim(),
                            'attendees': const [],
                            'recurrence': const [],
                            'reminders': [reminderMinutes],
                            'syncToGoogle': syncToGoogle,
                            'isAiGenerated': false,
                          };

                          try {
                            if (initialEvent == null) {
                              await apiClient.dio.post(
                                  ApiEndpoints.calendarEvents,
                                  data: payload);
                            } else {
                              await apiClient.dio.put(
                                  '${ApiEndpoints.calendarEvents}/${initialEvent.id}',
                                  data: payload);
                            }
                            if (!mounted) return;

                            Navigator.pop(context);
                            await _refreshAll();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Save failed: $e'),
                                    backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          initialEvent == null ? 'Save Event' : 'Update Event',
                          style: GoogleFonts.inter(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editorField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue),
        ),
      ),
    );
  }

  Future<T?> _showChoiceSheet<T>(BuildContext context,
      {required String title, required List<T> choices}) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...choices.map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.toString(),
                          style:
                              GoogleFonts.inter(color: AppColors.textPrimary)),
                      onTap: () => Navigator.pop(ctx, item),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  final CalendarEventItem event;
  final double slotWidth;
  final int startHour;
  final int endHour;
  final VoidCallback onTap;

  const _TimelineBlock({
    required this.event,
    required this.slotWidth,
    required this.startHour,
    required this.endHour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(
        event.start.year, event.start.month, event.start.day, startHour);
    final dayEnd =
        DateTime(event.start.year, event.start.month, event.start.day, endHour);
    final start = event.start.isBefore(dayStart) ? dayStart : event.start;
    final end = event.end.isAfter(dayEnd) ? dayEnd : event.end;
    final totalMinutes = (end.difference(start)).inMinutes.clamp(30, 9999);
    final leftMinutes = (start.difference(dayStart)).inMinutes.clamp(0, 9999);

    final left = (leftMinutes / 60.0) * slotWidth;
    final width = ((totalMinutes / 60.0) * slotWidth).clamp(90.0, 260.0);
    final top = event.allDay ? 40.0 : 62.0;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _eventColor(event.colorKey).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _eventColor(event.colorKey).withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: _eventColor(event.colorKey).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.allDay
                    ? 'All day'
                    : '${_formatTime(event.start)} • ${_formatTime(event.end)}',
                style:
                    GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Text(
                event.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: _eventColor(event.colorKey),
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEventItem event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = _eventColor(event.colorKey);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (event.syncedToGoogle)
                        const Icon(Icons.cloud_done_rounded,
                            color: AppColors.success, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.allDay
                        ? 'All day'
                        : '${_formatTime(event.start)} – ${_formatTime(event.end)}',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.blue, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );

    if (onTap == null) return tile;
    return GestureDetector(onTap: onTap, child: tile);
  }
}

class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FabOption(
      {required this.icon, required this.label, required this.onTap});

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
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(width: 10),
            Icon(icon, color: AppColors.blue, size: 20),
          ],
        ),
      ),
    );
  }
}
