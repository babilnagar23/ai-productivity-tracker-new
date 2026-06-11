import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum CalendarViewMode { month, week, day }

class CalendarEventItem {
  final String id;
  final int? serverId;
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
  final String syncStatus;
  final bool isAiGenerated;
  final bool completed;
  final DateTime createdAt;

  CalendarEventItem({
    required this.id,
    this.serverId,
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
    this.syncStatus = 'synced',
    this.isAiGenerated = false,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CalendarEventItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) {
        return v.isUtc ? v.toLocal() : v;
      }
      if (v is String && v.isNotEmpty) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) {
          return parsed.isUtc ? parsed.toLocal() : parsed;
        }
      }
      return DateTime.now();
    }

    return CalendarEventItem(
      id: json['localId']?.toString() ?? json['client_uuid']?.toString() ?? (json['id']?.toString() ?? ''),
      serverId: json['serverId'] as int? ?? (json['id'] is int ? json['id'] as int : null),
      googleEventId: json['googleEventId'] as String? ?? json['google_event_id'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      start: parseDate(json['start'] ?? json['startTime'] ?? json['start_time']),
      end: parseDate(json['end'] ?? json['endTime'] ?? json['end_time']),
      allDay: (json['allDay'] == true || json['allDay'] == 1 || json['all_day'] == true || json['all_day'] == 1),
      colorKey: json['colorKey'] as String? ?? json['color'] as String? ?? 'blue',
      category: json['category'] as String? ?? 'personal',
      location: json['location'] as String? ?? '',
      attendees: (json['attendees'] as List?)?.map((e) => e.toString()).toList() ?? [],
      recurrence: json['recurrence'] as List? ?? [],
      reminders: json['reminders'] as List? ?? [10],
      syncedToGoogle: (json['syncedToGoogle'] == true || json['syncedToGoogle'] == 1 || json['synced_to_google'] == true || json['synced_to_google'] == 1),
      syncStatus: json['syncStatus'] as String? ?? 'synced',
      isAiGenerated: (json['isAiGenerated'] == true || json['isAiGenerated'] == 1),
      completed: (json['completed'] == true || json['completed'] == 1),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now() : DateTime.now()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
DateTime _startOfWeek(DateTime d) =>
    _startOfDay(d.subtract(Duration(days: d.weekday - 1)));
DateTime _endOfWeek(DateTime d) =>
    _endOfDay(_startOfWeek(d).add(const Duration(days: 6)));
DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _endOfMonth(DateTime d) => _endOfDay(DateTime(d.year, d.month + 1, 0));
String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toLocal());
String _fmtTime(DateTime dt) => DateFormat('h:mm a').format(dt);
String _fmtDate(DateTime dt) => DateFormat('EEE, MMM d, yyyy').format(dt);

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
    default:
      return AppColors.blue;
  }
}

class _DateRange {
  final DateTime start, end;
  const _DateRange(this.start, this.end);
  String get key => '${start.toIso8601String()}|${end.toIso8601String()}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final calendarStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final r = await apiClient.dio.get(ApiEndpoints.calendarStatus);
    return r.data as Map<String, dynamic>;
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

    final dbHelper = DatabaseHelper();
    final rows = await dbHelper.query(
      'calendar_events_cache',
      where: 'deletedFlag = 0',
    );

    final List<CalendarEventItem> localEvents = [];
    for (final r in rows) {
      final item = CalendarEventItem.fromJson(r);
      if (item.start.isBefore(end) && item.end.isAfter(start)) {
        localEvents.add(item);
      }
    }

    localEvents.sort((a, b) => a.start.compareTo(b.start));

    // Trigger background sync
    SyncEngine().syncNow();

    return localEvents;
  } catch (e) {
    debugPrint('[CalendarProvider] Error: $e');
    return [];
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

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
  bool _isSyncing = false;

  _DateRange get _visibleRange {
    switch (_viewMode) {
      case CalendarViewMode.day:
        return _DateRange(_startOfDay(_selectedDay), _endOfDay(_selectedDay));
      case CalendarViewMode.week:
        return _DateRange(_startOfWeek(_focusedDay), _endOfWeek(_focusedDay));
      case CalendarViewMode.month:
        return _DateRange(_startOfMonth(_focusedDay), _endOfMonth(_focusedDay));
    }
  }

  _DateRange get _selectedRange =>
      _DateRange(_startOfDay(_selectedDay), _endOfDay(_selectedDay));

  Future<void> _refresh() async {
    if (!mounted) return;
    ref.invalidate(calendarStatusProvider);
    ref.invalidate(calendarEventsRangeProvider(_visibleRange.key));
    ref.invalidate(calendarEventsRangeProvider(_selectedRange.key));
  }

  Map<String, List<CalendarEventItem>> _groupByDay(
      List<CalendarEventItem> events) {
    final map = <String, List<CalendarEventItem>>{};
    for (final e in events) {
      map.putIfAbsent(_dayKey(e.start.toLocal()), () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(calendarStatusProvider);
    final rangeAsync =
        ref.watch(calendarEventsRangeProvider(_visibleRange.key));
    final dayAsync = ref.watch(calendarEventsRangeProvider(_selectedRange.key));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Calendar',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          _viewModeButton(),
          IconButton(
            icon:
                Icon(Icons.settings_outlined, color: AppColors.textMuted),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color.fromARGB(255, 23, 144, 149),
        backgroundColor: AppColors.card,
        onRefresh: _refresh,
        child: rangeAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.blue)),
          error: (e, _) => Center(
              child:
                  Text('$e', style: TextStyle(color: AppColors.error))),
          data: (rangeEvents) {
            final byDay = _groupByDay(rangeEvents);
            final dayEvents = dayAsync.asData?.value ?? [];
            return Stack(children: [
              ListView(padding: const EdgeInsets.all(16), children: [
                _calendarWidget(byDay),
                const SizedBox(height: 16),
                Text("Today's Productivity Timeline",
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _timeline(dayEvents),
                const SizedBox(height: 16),
                statusAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => _googleCard(false, null),
                  data: (s) => _googleCard(s['connected'] as bool? ?? false, s),
                ),
                const SizedBox(height: 100),
              ]),
              Positioned(right: 16, bottom: 24, child: _fab()),
            ]);
          },
        ),
      ),
    );
  }

  // ── View-mode pill button ──────────────────────────────────────────────────
  Widget _viewModeButton() {
    final label = switch (_viewMode) {
      CalendarViewMode.month => 'Month',
      CalendarViewMode.week => 'Week',
      CalendarViewMode.day => 'Day',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<CalendarViewMode>(
        color: AppColors.card,
        initialValue: _viewMode,
        onSelected: (mode) => setState(() {
          _viewMode = mode;
          if (mode != CalendarViewMode.day) _focusedDay = _selectedDay;
        }),
        itemBuilder: (_) => [
          _modeItem('Month', CalendarViewMode.month),
          _modeItem('Week', CalendarViewMode.week),
          _modeItem('Day', CalendarViewMode.day),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Icon(Icons.arrow_drop_down_rounded,
                color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<CalendarViewMode> _modeItem(
          String label, CalendarViewMode mode) =>
      PopupMenuItem(
          value: mode,
          child: Text(label,
              style: GoogleFonts.inter(color: AppColors.textPrimary)));

  // ── Calendar widget ────────────────────────────────────────────────────────
  Widget _calendarWidget(Map<String, List<CalendarEventItem>> byDay) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // nav header
          Row(children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded,
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
                    ? _fmtDate(_selectedDay)
                    : DateFormat('MMMM yyyy').format(_focusedDay),
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17),
                overflow: TextOverflow.ellipsis,
              )),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
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
          ]),
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
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
                _viewMode = CalendarViewMode.day;
              }),
              onPageChanged: (focused) => setState(() => _focusedDay = focused),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle:
                    GoogleFonts.inter(color: AppColors.textPrimary),
                weekendTextStyle:
                    GoogleFonts.inter(color: AppColors.textSecondary),
                todayDecoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.25),
                    shape: BoxShape.circle),
                todayTextStyle: GoogleFonts.inter(
                    color: AppColors.blue, fontWeight: FontWeight.w700),
                selectedDecoration: BoxDecoration(
                    color: AppColors.blue, shape: BoxShape.circle),
                selectedTextStyle: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w700),
                markersMaxCount: 3,
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle:
                    GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                weekendStyle:
                    GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
              ),
              eventLoader: (day) => byDay[_dayKey(day)] ?? [],
              calendarBuilders: CalendarBuilders(
                markerBuilder: (_, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: events
                          .take(3)
                          .map((e) => Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: _eventColor(e.colorKey),
                                    shape: BoxShape.circle),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            )
          else
            _dayView(byDay[_dayKey(_selectedDay)] ?? []),
        ]),
      ),
    );
  }

  Widget _dayView(List<CalendarEventItem> events) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        _chip('${events.length} events'),
        const SizedBox(width: 8),
        _chip(_selectedDay.weekday >= 6 ? 'Weekend' : 'Workday'),
        const Spacer(),
        TextButton(
            onPressed: () => setState(() => _viewMode = CalendarViewMode.week),
            child: Text('Back to week',
                style: GoogleFonts.inter(color: AppColors.blue))),
      ]),
      const SizedBox(height: 8),
      if (events.isEmpty)
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No events on this day',
                style: GoogleFonts.inter(color: AppColors.textMuted)))
      else
        ...events.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EventCard(event: e, onTap: () => _showEventDetail(e)),
            )),
    ]);
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border)),
        child: Text(text,
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  // ── Timeline ───────────────────────────────────────────────────────────────
  Widget _timeline(List<CalendarEventItem> events) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Text('No events for this day',
            style: GoogleFonts.inter(color: AppColors.textMuted)),
      );
    }
    final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate right column width for IntrinsicHeight to work properly with wrapped text
          // 75 (left) + 16 (gap) + 14 (middle) + 16 (gap) = 121
          final rightWidth = constraints.maxWidth - 121;
          
          return Column(
            children: List.generate(sorted.length, (index) {
              final event = sorted[index];
          final isLast = index == sorted.length - 1;
          final localStart = event.start.toLocal();
          final localEnd = event.end.toLocal();
          final color = _eventColor(event.colorKey);

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Time range
                SizedBox(
                  width: 75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtTime(localStart),
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtTime(localEnd),
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Middle Column: Timeline node and vertical line
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: isLast
                          ? const SizedBox.shrink()
                          : Container(
                              width: 2,
                              color: AppColors.border,
                            ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Right Column: Event Details Card
                SizedBox(
                  width: rightWidth,
                  child: GestureDetector(
                    onTap: () => _showEventDetail(event),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (event.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              event.description,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      );
    },
      ),
    );
  }

  // ── Google Calendar card ───────────────────────────────────────────────────
  Widget _googleCard(bool connected, Map<String, dynamic>? status) {
    final lastSynced = status?['lastSynced'] as String?;
    final email = status?['googleEmail'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.calendar_month_rounded,
                  color: AppColors.blue, size: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Google Calendar Integration',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(
                    connected
                        ? (email.isNotEmpty ? email : 'Connected')
                        : 'Connect your Google Calendar',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12)),
                if (connected && lastSynced != null)
                  Text('Last sync: $lastSynced',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 11)),
              ])),
          if (connected)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('Synced',
                    style: GoogleFonts.inter(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)))
          else
            ElevatedButton(
                onPressed: _connectGoogle,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero),
                child: Text('Connect',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600))),
        ]),
        if (connected) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
              onPressed: _isSyncing ? null : _syncNow,
              icon: _isSyncing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.blue))
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text('Sync Now',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Refresh',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 23, 144, 149),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
          ]),
        ],
      ]),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _fab() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_fabExpanded) ...[
              _FabOption(
                  icon: Icons.task_alt_rounded,
                  label: 'New Task',
                  onTap: () {
                    setState(() => _fabExpanded = false);
                    _openEditor();
                  }),
              _FabOption(
                  icon: Icons.event_rounded,
                  label: 'New Event',
                  onTap: () {
                    setState(() => _fabExpanded = false);
                    _openEditor(date: _selectedDay);
                  }),
              _FabOption(
                  icon: Icons.fitness_center_rounded,
                  label: 'Workout',
                  onTap: () {
                    setState(() => _fabExpanded = false);
                    _openEditor(category: 'exercise');
                  }),
              _FabOption(
                  icon: Icons.notifications_active_rounded,
                  label: 'Reminder',
                  onTap: () {
                    setState(() => _fabExpanded = false);
                    _openEditor(category: 'reminder');
                  }),
              _FabOption(
                  icon: Icons.school_outlined,
                  label: 'Study Session',
                  onTap: () {
                    setState(() => _fabExpanded = false);
                    _openEditor(category: 'study');
                  }),
              const SizedBox(height: 8),
            ],
            GestureDetector(
              onTap: () => setState(() => _fabExpanded = !_fabExpanded),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppColors.blue, shape: BoxShape.circle),
                child: Icon(
                    _fabExpanded ? Icons.close_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 28),
              ),
            ),
          ]);

  // ── Google connect / sync ──────────────────────────────────────────────────
  Future<void> _connectGoogle() async {
    try {
      final r = await apiClient.dio.get(ApiEndpoints.calendarAuthUrl);
      final data = r.data as Map<String, dynamic>;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      await apiClient.dio.post(ApiEndpoints.calendarSync);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Synced successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── Settings sheet ─────────────────────────────────────────────────────────
  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Calendar Options',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.sync_rounded, color: AppColors.blue),
            title: Text('Sync now',
                style: GoogleFonts.inter(color: AppColors.textPrimary)),
            onTap: () {
              // Close sheet first, then sync — prevents context issues
              Navigator.of(ctx).pop();
              _syncNow();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.refresh_rounded, color: AppColors.blue),
            title: Text('Refresh view',
                style: GoogleFonts.inter(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.of(ctx).pop();
              _refresh();
            },
          ),
        ]),
      ),
    );
  }

  // ── Event detail sheet ─────────────────────────────────────────────────────
  // KEY FIX: All navigation inside sheets uses the sheet's own context (ctx),
  // never the outer screen context. Async work only runs after sheet is closed.
  Future<void> _showEventDetail(CalendarEventItem event) async {
    final localStart = event.start.toLocal();
    final localEnd = event.end.toLocal();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: Text(event.title,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700))),
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
              // Use Navigator.of(ctx) — the sheet's navigator, not the screen's
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ]),
          const SizedBox(height: 8),
          _detailRow('Description',
              event.description.isEmpty ? 'No description' : event.description),
          _detailRow(
              'Time',
              event.allDay
                  ? 'All day'
                  : '${_fmtDate(localStart)} • ${_fmtTime(localStart)} – ${_fmtTime(localEnd)}'),
          _detailRow('Category', event.category),
          if (event.location.isNotEmpty) _detailRow('Location', event.location),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
              // ✅ FIX: pop the sheet first using ctx, THEN open editor from screen context
              onPressed: () {
                Navigator.of(ctx).pop();
                // Post-frame so the sheet is fully dismissed before we push anything
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _openEditor(existing: event);
                });
              },
              icon: const Icon(Icons.edit_rounded),
              label: Text('Edit',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: ElevatedButton.icon(
              // ✅ FIX: pop sheet first, then delete from screen context
              onPressed: () {
                Navigator.of(ctx).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _confirmAndDelete(event);
                });
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('Delete',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Future<void> _confirmAndDelete(CalendarEventItem event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete Event',
            style: GoogleFonts.inter(color: AppColors.textPrimary)),
        content: Text('Delete "${event.title}"?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Delete',
                  style: GoogleFonts.inter(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.update(
        'calendar_events_cache',
        {
          'deletedFlag': 1,
          'syncStatus': 'pending',
          'deletedAt': DateTime.now().toIso8601String(),
        },
        'localId = ?',
        [event.id],
      );

      final apiPayload = {
        'localId': event.id,
        'client_uuid': event.id,
        if (event.serverId != null) 'serverId': event.serverId,
        'title': event.title,
      };

      await SyncEngine().queuePendingMutation('calendar_event', 'delete', apiPayload);

      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Event deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: AppColors.error));
    }
  }

  // ── Add/Edit event editor ──────────────────────────────────────────────────
  // ✅ KEY FIX: The editor is a separate method. It NEVER uses outer `context`
  // inside the builder. The save button uses sheetCtx to pop, then refreshes
  // via the screen's state (which is accessed through `this`, not context).
  Future<void> _openEditor({
    CalendarEventItem? existing,
    DateTime? date,
    String? category,
  }) async {
    // All mutable state lives outside the builder so StatefulBuilder can mutate it
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');

    DateTime selDate = existing?.start ?? date ?? _selectedDay;
    TimeOfDay startTOD = TimeOfDay.fromDateTime(
        existing?.start ?? DateTime.now().add(const Duration(hours: 1)));
    TimeOfDay endTOD = TimeOfDay.fromDateTime(
        existing?.end ?? DateTime.now().add(const Duration(hours: 2)));
    bool allDay = existing?.allDay ?? false;
    bool syncGoogle = existing?.syncedToGoogle ?? false;
    String selCategory = existing?.category ?? category ?? 'personal';
    String selColor = existing?.colorKey ?? 'blue';
    int reminder = (existing?.reminders.isNotEmpty ?? false)
        ? (existing!.reminders.first as num).toInt()
        : 10;

    final colors = ['blue', 'purple', 'green', 'pink', 'orange', 'cyan'];
    final reminders = [0, 5, 10, 15, 30, 60];
    final categories = [
      'study',
      'work',
      'exercise',
      'break',
      'personal',
      'reminder',
      'meeting'
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      // ✅ Use StatefulBuilder so we can call setModalState without touching outer setState
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: sheetCtx,
              initialDate: selDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.dark(
                          primary: AppColors.blue,
                          surface: AppColors.surface,
                          onSurface: AppColors.textPrimary)),
                  child: child!),
            );
            if (picked != null) setModalState(() => selDate = picked);
          }

          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
              context: sheetCtx,
              initialTime: isStart ? startTOD : endTOD,
              builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.dark(
                          primary: AppColors.blue,
                          surface: AppColors.surface,
                          onSurface: AppColors.textPrimary)),
                  child: child!),
            );
            if (picked != null) {
              setModalState(() {
                if (isStart) {
                  startTOD = picked;
                } else {
                  endTOD = picked;
                }
              });
            }
          }

          Future<void> saveEvent() async {
            if (titleCtrl.text.trim().isEmpty) return;

            final startDT = allDay
                ? DateTime(selDate.year, selDate.month, selDate.day)
                : DateTime(selDate.year, selDate.month, selDate.day,
                    startTOD.hour, startTOD.minute);
            final endDT = allDay
                ? DateTime(selDate.year, selDate.month, selDate.day, 23, 59, 59)
                : DateTime(selDate.year, selDate.month, selDate.day,
                    endTOD.hour, endTOD.minute);



            try {
              final localId = existing?.id ?? const Uuid().v4();
              final isNew = existing == null;

              final localRow = {
                'localId': localId,
                if (existing?.serverId != null) 'serverId': existing!.serverId,
                'syncStatus': 'pending',
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'startTime': startDT.toIso8601String(),
                'endTime': endDT.toIso8601String(),
                'allDay': allDay ? 1 : 0,
                'googleEventId': existing?.googleEventId ?? '',
                'createdAt': existing?.createdAt.toIso8601String() ?? DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
                'syncedToGoogle': syncGoogle ? 1 : 0,
                'deletedFlag': 0,
              };

              final dbHelper = DatabaseHelper();
              await dbHelper.insert('calendar_events_cache', localRow);

              final apiPayload = {
                'localId': localId,
                'client_uuid': localId,
                if (existing?.serverId != null) 'serverId': existing!.serverId,
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'start_time': startDT.toIso8601String(),
                'end_time': endDT.toIso8601String(),
                'all_day': allDay,
                'color': selColor,
                'category': selCategory,
                'location': locationCtrl.text.trim(),
                'syncedToGoogle': syncGoogle,
                'syncToGoogle': syncGoogle,
                'completed': false,
              };

              await SyncEngine().queuePendingMutation(
                'calendar_event',
                isNew ? 'create' : 'update',
                apiPayload,
              );

              // ✅ FIX: Pop the sheet using sheetCtx BEFORE any screen-level work
              if (!sheetCtx.mounted) return;
              Navigator.of(sheetCtx).pop();
              final messenger = ScaffoldMessenger.of(sheetCtx);

              // ✅ FIX: Refresh via screen state, gated by mounted check on the SCREEN
              if (!mounted) return;

              await _refresh();

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    existing == null ? 'Event created!' : 'Event updated!',
                  ),
                ),
              );
            } catch (e) {
              if (!sheetCtx.mounted) return;
              ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
                  content: Text('Save failed: $e'),
                  backgroundColor: AppColors.error));
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(existing == null ? 'New Event' : 'Edit Event',
                          style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700))),
                  // ✅ FIX: Use Navigator.of(sheetCtx), not context
                  IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.textMuted),
                      onPressed: () => Navigator.of(sheetCtx).pop()),
                ]),
                const SizedBox(height: 12),
                _field(titleCtrl, 'Title *'),
                const SizedBox(height: 10),
                _field(descCtrl, 'Description (optional)', maxLines: 3),
                const SizedBox(height: 10),
                _field(locationCtrl, 'Location (optional)'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _tile(Icons.calendar_month_rounded, 'Date',
                          DateFormat('MMM d, yyyy').format(selDate), pickDate)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tile(
                          Icons.access_time_rounded,
                          'Start',
                          allDay ? 'All day' : startTOD.format(sheetCtx),
                          () => pickTime(true))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _tile(
                          Icons.timelapse_rounded,
                          'End',
                          allDay ? 'All day' : endTOD.format(sheetCtx),
                          () => pickTime(false))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: GestureDetector(
                    onTap: () async {
                      final chosen = await showModalBottomSheet<String>(
                        context: sheetCtx,
                        backgroundColor: AppColors.card,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24))),
                        builder: (c) => ListView(
                            padding: const EdgeInsets.all(16),
                            shrinkWrap: true,
                            children: categories
                                .map((cat) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(cat,
                                          style: GoogleFonts.inter(
                                              color: AppColors.textPrimary)),
                                      onTap: () => Navigator.of(c).pop(cat),
                                    ))
                                .toList()),
                      );
                      if (chosen != null) {
                        setModalState(() {
                          selCategory = chosen;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.label_rounded,
                                  color: AppColors.blue, size: 18),
                              const SizedBox(width: 8),
                              Text('Category',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textMuted, fontSize: 11))
                            ]),
                            const SizedBox(height: 6),
                            Text(selCategory,
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),
                Text('Color',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colors
                      .map((c) => GestureDetector(
                            onTap: () => setModalState(() => selColor = c),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  color: _eventColor(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: c == selColor
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2.5)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: SwitchListTile.adaptive(
                    value: allDay,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => allDay = v),
                    title: Text('All day',
                        style: GoogleFonts.inter(color: AppColors.textPrimary)),
                  )),
                  Expanded(
                      child: SwitchListTile.adaptive(
                    value: syncGoogle,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => syncGoogle = v),
                    title: Text('Sync',
                        style: GoogleFonts.inter(color: AppColors.textPrimary)),
                  )),
                ]),
                const SizedBox(height: 6),
                Text('Reminder',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reminders
                      .map((m) => ChoiceChip(
                            selected: reminder == m,
                            label: Text(m == 0 ? 'None' : '$m min'),
                            selectedColor: AppColors.blue,
                            backgroundColor: AppColors.cardElevated,
                            labelStyle: GoogleFonts.inter(
                                color: reminder == m
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600),
                            onSelected: (_) =>
                                setModalState(() => reminder = m),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saveEvent,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(
                        existing == null ? 'Save Event' : 'Update Event',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                ),
              ],
            )),
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: AppColors.textPrimary),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.cardElevated,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.blue))),
      );

  Widget _tile(IconData icon, String label, String value, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: AppColors.blue, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11))
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────



class _EventCard extends StatelessWidget {
  final CalendarEventItem event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final localStart = event.start.toLocal();
    final localEnd = event.end.toLocal();
    final c = _eventColor(event.colorKey);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(event.title,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    event.allDay
                        ? 'All day'
                        : '${_fmtTime(localStart)} – ${_fmtTime(localEnd)}',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12)),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ])),
          if (event.syncedToGoogle && event.syncStatus == 'synced')
            Icon(Icons.cloud_done_rounded,
                color: AppColors.success, size: 18),
        ]),
      ),
    );
  }
}

class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FabOption(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(width: 10),
            Icon(icon, color: AppColors.blue, size: 20),
          ]),
        ),
      );
}
