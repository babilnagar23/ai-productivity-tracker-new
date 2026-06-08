import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/profile_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    
DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) {
    return value.isUtc ? value.toLocal() : value;
  }
  if (value is String && value.isNotEmpty) {
    final dt = DateTime.tryParse(value);
    if (dt != null) {
      return dt.isUtc ? dt.toLocal() : dt;
    }
  }
  return DateTime.now();
}

List<Map<String, dynamic>> _extractEvents(dynamic data) {
  if (data is! Map<String, dynamic>) return [];
  final raw = (data['data'] as List<dynamic>?) ??
      (data['events'] as List<dynamic>?) ??
      const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    ..sort((a, b) => _parseDateTime(a['start'] ?? a['start_time'])
        .compareTo(_parseDateTime(b['start'] ?? b['start_time'])));
}

String _formatDashboardEventTime(Map<String, dynamic> event) {
  final dt = _parseDateTime(event['start'] ?? event['start_time']).toLocal();
  return DateFormat('hh:mm a').format(dt);
}

String _formatDashboardEventDateTime(Map<String, dynamic> event) {
  final dt = _parseDateTime(event['start'] ?? event['start_time']).toLocal();
  return DateFormat('dd MMM • hh:mm a').format(dt);
}

final dashboardTodayEventsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final now = DateTime.now();
    final response = await apiClient.dio.get(
      ApiEndpoints.calendarEvents,
      queryParameters: {
        'start': _startOfDay(now).toIso8601String(),
        'end': _endOfDay(now).toIso8601String(),
      },
    );
    return _extractEvents(response.data);
  } catch (_) {
    return [];
  }
});

final dashboardUpcomingEventsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final now = DateTime.now();
    final response = await apiClient.dio.get(
      ApiEndpoints.calendarEvents,
      queryParameters: {
        'start': _endOfDay(now)
            .add(const Duration(milliseconds: 1))
            .toIso8601String(),
        'end': _endOfDay(now.add(const Duration(days: 7))).toIso8601String(),
      },
    );
    return _extractEvents(response.data);
  } catch (_) {
    return [];
  }
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final authNotifier = ref.read(authStateProvider.notifier);
    final user = ref.watch(authStateProvider).user;
    final todayEventsAsync = ref.watch(dashboardTodayEventsProvider);
    final upcomingEventsAsync = ref.watch(dashboardUpcomingEventsProvider);

    final xp = user?.xp ?? 0;
    final level = authNotifier.level;
    final nextXp = authNotifier.nextLevelXp;
    final xpProgress = authNotifier.xpProgress;
    final streak = user?.streak ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardTodayEventsProvider);
          ref.invalidate(dashboardUpcomingEventsProvider);
        },
        color: AppColors.blue,
        backgroundColor: AppColors.card,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.bg,
              pinned: true,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      context.push('/settings/profile');
                    },
                    child: ProfileAvatar(
                      avatarKey: user?.avatar,
                      initials: user?.initials ?? '?',
                      size: 32,
                      showEditBadge: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Welcome back, ${user?.displayName ?? 'User'}',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: AppColors.textPrimary),
                      onPressed: () => context.push('/notifications'),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '$streak Days Streak',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Level $level: $xp/$nextXp XP',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      backgroundColor: const Color(0x14FFFFFF),
                      valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus Mode Command Center',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => context.push('/focus'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 19, 154, 159),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Start Focus',
                              style: GoogleFonts.inter(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _PresetChip(
                                label: '25m Pomodoro',
                                onTap: () => context.push('/focus?duration=25'),
                              ),
                              const SizedBox(width: 8),
                              _PresetChip(
                                label: '60m Flow',
                                onTap: () => context.push('/focus?duration=60'),
                              ),
                              const SizedBox(width: 8),
                              _PresetChip(
                                label: '90m Deep Work',
                                onTap: () => context.push('/focus?duration=90'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's Schedule",
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/calendar'),
                              child: Text(
                                'Open Calendar',
                                style: GoogleFonts.inter(
                                  color: AppColors.blue,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        todayEventsAsync.when(
                          loading: () => const SizedBox(
                            height: 40,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                          error: (_, __) => Text(
                            'Could not load today’s events',
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                          ),
                          data: (events) {
                            if (events.isEmpty) {
                              return GestureDetector(
                                onTap: () => context.go('/calendar'),
                                child: Text(
                                  'No events today. Tap to add one.',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }

                            final shown = events.take(5).toList();

                            return Column(
                              children: [
                                ...shown.map((event) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 6),
                                          decoration: const BoxDecoration(
                                            color: AppColors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '${_formatDashboardEventTime(event)}: ${event['title'] ?? ''}',
                                            style: GoogleFonts.inter(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (events.length > 5)
                                  GestureDetector(
                                    onTap: () => context.go('/calendar'),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '+ ${events.length - 5} more',
                                        style: GoogleFonts.inter(
                                          color: AppColors.blue,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Upcoming Schedules',
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/calendar'),
                              child: Text(
                                'View All',
                                style: GoogleFonts.inter(
                                  color: AppColors.blue,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        upcomingEventsAsync.when(
                          loading: () => const SizedBox(
                            height: 40,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                          error: (_, __) => Text(
                            'Could not load upcoming events',
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                          ),
                          data: (events) {
                            if (events.isEmpty) {
                              return Text(
                                'No upcoming schedules for the next 7 days.',
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                              );
                            }

                            final shown = events.take(5).toList();

                            return Column(
                              children: [
                                ...shown.map((event) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 6),
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '${_formatDashboardEventDateTime(event)}: ${event['title'] ?? ''}',
                                            style: GoogleFonts.inter(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (events.length > 5)
                                  GestureDetector(
                                    onTap: () => context.go('/calendar'),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '+ ${events.length - 5} more upcoming',
                                        style: GoogleFonts.inter(
                                          color: AppColors.blue,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: [
                      _QuickAction(
                        icon: Icons.edit_note_rounded,
                        label: 'Log Today',
                        color: AppColors.blue,
                        onTap: () => context.push('/daily-log/add'),
                      ),
                      _QuickAction(
                        icon: Icons.psychology_outlined,
                        label: 'Ask AI',
                        color: AppColors.purple,
                        onTap: () => context.go('/ai-coach'),
                      ),
                      _QuickAction(
                        icon: Icons.calendar_today_rounded,
                        label: 'Calendar',
                        color: AppColors.success,
                        onTap: () => context.go('/calendar'),
                      ),
                      _QuickAction(
                        icon: Icons.school_outlined,
                        label: 'Study Plan',
                        color: AppColors.warning,
                        onTap: () => context.go('/ai-coach'),
                      ),
                      _QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: 'Analytics',
                        color: AppColors.cyan,
                        onTap: () => context.push('/daily-log/analytics'),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
