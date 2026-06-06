import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/data/repositories/routine_repository.dart';
import '../../../routines/presentation/providers/routines_provider.dart';

final dashboardRoutinesProvider = FutureProvider<List<RoutineModel>>((ref) async {
  return RoutineRepository().getRoutines();
});

final dashboardAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await apiClient.dio.get(ApiEndpoints.analyticsFull);
    return response.data as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

final dashboardEventsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await apiClient.dio.get(
      ApiEndpoints.calendarEvents,
      queryParameters: {'date': today},
    );
    final body = response.data as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? body['events'] as List<dynamic>? ?? [];
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
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _avatarBase64 = prefs.getString('user_avatar');
    });
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = ref.read(authStateProvider.notifier);
    final user = ref.watch(authStateProvider).user;
    final routinesAsync = ref.watch(dashboardRoutinesProvider);
    ref.watch(dashboardAnalyticsProvider); // preload
    final eventsAsync = ref.watch(dashboardEventsProvider);
    final configAsync = ref.watch(customConfigProvider);

    final configMetrics = (configAsync.asData?.value['coreMetrics'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final xp = user?.xp ?? 0;
    final level = authNotifier.level;
    final nextXp = authNotifier.nextLevelXp;
    final xpProgress = authNotifier.xpProgress;
    final streak = user?.streak ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardRoutinesProvider);
          ref.invalidate(dashboardAnalyticsProvider);
          ref.invalidate(dashboardEventsProvider);
          await _loadAvatar();
        },
        color: AppColors.blue,
        backgroundColor: AppColors.card,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: AppColors.bg,
              pinned: true,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await context.push('/settings/profile');
                      await _loadAvatar();
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: _avatarBase64 != null
                                ? Image.memory(
                                    base64Decode(_avatarBase64!),
                                    fit: BoxFit.cover,
                                    width: 32,
                                    height: 32,
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppColors.blue, AppColors.purple],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        user?.initials ?? '?',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Welcome back, ${user?.displayName ?? 'User'}',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
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
                  // Streak + XP bar
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

                  // Focus Mode Command Center
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
                              backgroundColor: AppColors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'Start Focus',
                              style: GoogleFonts.inter(
                                color: Colors.white,
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

                  // Productivity Overview 2x2 grid
                  routinesAsync.when(
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (routines) => _ProductivityGrid(
                      routines: routines,
                      configMetrics: configMetrics,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Today's Schedule
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
                        eventsAsync.when(
                          loading: () => const SizedBox(
                            height: 40,
                            child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
                          ),
                          error: (_, __) => Text(
                            'Could not load events',
                            style: GoogleFonts.inter(color: AppColors.textMuted),
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
                                ...shown.map((e) {
                                  final ev = e as Map<String, dynamic>;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${ev['start_time'] ?? ''} - ${ev['end_time'] ?? ''}: ${ev['title'] ?? ''}',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                }),
                                if (events.length > 5)
                                  GestureDetector(
                                    onTap: () => context.go('/calendar'),
                                    child: Text(
                                      '+ ${events.length - 5} more',
                                      style: GoogleFonts.inter(
                                        color: AppColors.blue,
                                        fontSize: 13,
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

                  // Quick Actions
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

class _ProductivityGrid extends StatelessWidget {
  final List<RoutineModel> routines;
  final List<Map<String, dynamic>> configMetrics;
  const _ProductivityGrid({
    required this.routines,
    required this.configMetrics,
  });

  double _avg(List<RoutineModel> list) {
    if (list.isEmpty) return 0;
    return list.map((r) => r.productivityScore).reduce((a, b) => a + b) / list.length;
  }

  double _getMetricValue(RoutineModel r, String id) {
    if (r.coreMetrics.containsKey(id)) {
      return (r.coreMetrics[id] as num?)?.toDouble() ?? 0.0;
    }
    if (id == 'studyHours') return r.studyHours;
    if (id == 'mobileUsage') return r.mobileUsage;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last7 = routines.where((r) {
      try {
        return DateTime.parse(r.date).isAfter(now.subtract(const Duration(days: 7)));
      } catch (_) {
        return false;
      }
    }).toList();
    final last30 = routines.where((r) {
      try {
        return DateTime.parse(r.date).isAfter(now.subtract(const Duration(days: 30)));
      } catch (_) {
        return false;
      }
    }).toList();
    final prevWeek = routines.where((r) {
      try {
        final d = DateTime.parse(r.date);
        return d.isAfter(now.subtract(const Duration(days: 14))) &&
            d.isBefore(now.subtract(const Duration(days: 7)));
      } catch (_) {
        return false;
      }
    }).toList();

    final dailyScore = last7.isNotEmpty ? last7.last.productivityScore : 0;
    final weeklyAvg = _avg(last7).round();
    final monthlyAvg = _avg(last30).round();
    final prevWeekAvg = _avg(prevWeek);
    final weekDiff = prevWeekAvg > 0 ? ((weeklyAvg - prevWeekAvg) / prevWeekAvg * 100).round() : 0;

    // Determine primary metric ID and label dynamically
    String primaryMetricId = 'studyHours';
    String primaryMetricLabel = 'Deep Work Hours';

    if (configMetrics.isNotEmpty) {
      final hasStudyHours = configMetrics.any((m) => m['id'] == 'studyHours');
      if (hasStudyHours) {
        primaryMetricId = 'studyHours';
        final metric = configMetrics.firstWhere((m) => m['id'] == 'studyHours');
        primaryMetricLabel = (metric['title'] as String?) ?? 'Deep Work Hours';
      } else {
        primaryMetricId = configMetrics.first['id'] as String? ?? 'studyHours';
        primaryMetricLabel = (configMetrics.first['title'] as String?) ?? 'Deep Work Hours';
      }
    }

    final primaryMetricValue = last7.fold(
      0.0,
      (sum, r) => sum + _getMetricValue(r, primaryMetricId),
    );

    final sparklineSpots = last7.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.productivityScore.toDouble()))
        .toList();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: [
        _StatCard(
          label: 'Daily Score',
          value: '$dailyScore',
          chart: sparklineSpots.length >= 2 ? _MiniLineChart(spots: sparklineSpots) : null,
        ),
        _StatCard(
          label: 'Weekly Score',
          value: '$weeklyAvg',
          sub: weekDiff >= 0 ? '+$weekDiff%' : '$weekDiff%',
          subColor: weekDiff >= 0 ? AppColors.success : AppColors.error,
        ),
        _StatCard(
          label: 'Monthly Trend',
          value: '$monthlyAvg',
          chart: last30.length >= 2
              ? _MiniLineChart(
                  spots: last30
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.productivityScore.toDouble()))
                      .toList(),
                )
              : null,
        ),
        _StatCard(
          label: primaryMetricLabel,
          value: primaryMetricLabel.toLowerCase().contains('hour') ||
                  primaryMetricLabel.toLowerCase().contains('hrs') ||
                  primaryMetricId == 'studyHours'
              ? '${primaryMetricValue.toInt()}h ${((primaryMetricValue % 1) * 60).toInt()}m'
              : primaryMetricValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
          chart: last7.length >= 2
              ? _MiniBarChart(values: last7.map((r) => _getMetricValue(r, primaryMetricId)).toList())
              : null,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final Widget? chart;

  const _StatCard({
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
    this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              style: GoogleFonts.inter(
                color: subColor ?? AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          if (chart != null) ...[
            const Spacer(),
            SizedBox(height: 36, child: chart!),
          ],
        ],
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  const _MiniLineChart({required this.spots});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: AppColors.blue,
            isCurved: true,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.blue.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<double> values;
  const _MiniBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: values
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value,
                    color: AppColors.blue,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
            )
            .toList(),
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