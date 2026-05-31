import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Full analytics: { success, stats: { totalLogs, avgScore, bestScore,
///   currentStreak, checklistRates, scoreBreakdown, avgSleepHour },
///   behavioral: { habitHeatmap, studyVsMobile }, data: [...] }
final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await apiClient.dio.get(ApiEndpoints.analyticsFull);
  return response.data as Map<String, dynamic>;
});

/// Weekly analytics: { success, data: [ RoutineSerializer... ] }
final weeklyProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await apiClient.dio.get(ApiEndpoints.analyticsWeekly);
  final body = response.data as Map<String, dynamic>;
  return body['data'] as List<dynamic>? ?? [];
});

// ── Screen ────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final weeklyAsync = ref.watch(weeklyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(analyticsProvider);
              ref.invalidate(weeklyProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsProvider);
          ref.invalidate(weeklyProvider);
        },
        color: AppColors.purple,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary stats
            analyticsAsync.when(
              loading: () => const _LoadingSection(height: 100),
              error: (e, _) => _ErrorSection(message: '$e'),
              data: (data) {
                final stats =
                    data['stats'] as Map<String, dynamic>? ?? {};
                return _SummaryRow(stats: stats);
              },
            ),
            const SizedBox(height: 20),

            // Weekly productivity chart
            const _ChartHeader(
                title: 'Weekly Productivity',
                icon: Icons.bar_chart_rounded),
            weeklyAsync.when(
              loading: () => const _LoadingSection(height: 200),
              error: (e, _) => _ErrorSection(message: '$e'),
              data: (routines) => _WeeklyChart(routines: routines),
            ),
            const SizedBox(height: 20),

            // Study vs Mobile
            const _ChartHeader(
                title: 'Study vs Mobile Usage',
                icon: Icons.compare_arrows_rounded),
            weeklyAsync.when(
              loading: () => const _LoadingSection(height: 200),
              error: (_, __) => const SizedBox.shrink(),
              data: (routines) => _StudyMobileChart(routines: routines),
            ),
            const SizedBox(height: 20),

            // Habit completion rates
            analyticsAsync.when(
              loading: () => const _LoadingSection(height: 150),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                final stats =
                    data['stats'] as Map<String, dynamic>? ?? {};
                final rates = stats['checklistRates']
                    as Map<String, dynamic>? ?? {};
                return _HabitRates(rates: rates);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Summary Row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final streak = stats['currentStreak'] ?? 0;
    final avgScore = stats['avgScore'] ?? 0;
    final totalDays = stats['totalLogs'] ?? 0;

    return Row(
      children: [
        Expanded(
            child: _StatBox(
                value: '$streak',
                label: 'Streak',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox(
                value: '$avgScore',
                label: 'Avg Score',
                icon: Icons.bolt_rounded,
                color: AppColors.purple)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox(
                value: '$totalDays',
                label: 'Days Logged',
                icon: Icons.calendar_today_rounded,
                color: AppColors.blue)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatBox(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Weekly Bar Chart ──────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<dynamic> routines;
  const _WeeklyChart({required this.routines});

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const _EmptyChart();

    final recent = routines.length > 7
        ? routines.sublist(routines.length - 7)
        : routines;

    final scores = recent
        .map((r) => ((r as Map<String, dynamic>)['productivityScore'] as num?)
                ?.toDouble() ??
            0.0)
        .toList();

    final labels = recent.map((r) {
      final date = (r as Map<String, dynamic>)['date'] as String? ?? '';
      return date.length >= 10 ? date.substring(5) : date; // MM-DD
    }).toList();

    final maxY = scores.isEmpty
        ? 100.0
        : (scores.reduce((a, b) => a > b ? a : b) + 10).clamp(0, 100).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(labels[i],
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 9));
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(
              scores.length,
              (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: scores[i],
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.gradientStart,
                            AppColors.gradientEnd
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 18,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  )),
        ),
      ),
    );
  }
}

// ── Study vs Mobile Line Chart ────────────────────────────────────────────────

class _StudyMobileChart extends StatelessWidget {
  final List<dynamic> routines;
  const _StudyMobileChart({required this.routines});

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const _EmptyChart();

    final recent = routines.length > 7
        ? routines.sublist(routines.length - 7)
        : routines;

    final studyHours = recent
        .map((r) =>
            ((r as Map<String, dynamic>)['studyHours'] as num?)?.toDouble() ??
            0.0)
        .toList();
    final mobileHours = recent
        .map((r) =>
            ((r as Map<String, dynamic>)['mobileUsage'] as num?)?.toDouble() ??
            0.0)
        .toList();
    final labels = recent.map((r) {
      final date = (r as Map<String, dynamic>)['date'] as String? ?? '';
      return date.length >= 10 ? date.substring(5) : date;
    }).toList();

    final spots1 = List.generate(
        studyHours.length, (i) => FlSpot(i.toDouble(), studyHours[i]));
    final spots2 = List.generate(
        mobileHours.length, (i) => FlSpot(i.toDouble(), mobileHours[i]));

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _Legend(color: AppColors.blue, label: 'Study'),
              SizedBox(width: 16),
              _Legend(color: AppColors.warning, label: 'Mobile'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(labels[i],
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 9));
                  },
                )),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}h',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10)),
                )),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots1,
                  color: AppColors.blue,
                  isCurved: true,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.blue.withValues(alpha: 0.08)),
                ),
                LineChartBarData(
                  spots: spots2,
                  color: AppColors.warning,
                  isCurved: true,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.warning.withValues(alpha: 0.08)),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

// ── Habit Rates ───────────────────────────────────────────────────────────────

class _HabitRates extends StatelessWidget {
  /// checklistRates: { "study": { title, completed, total, rate }, ... }
  final Map<String, dynamic> rates;
  const _HabitRates({required this.rates});

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) return const SizedBox.shrink();

    final entries = rates.entries.toList();

    final colors = [AppColors.blue, AppColors.success, AppColors.purple];

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
          const Text('Habit Completion Rates',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...List.generate(entries.length, (i) {
            final entry = entries[i];
            final info = entry.value as Map<String, dynamic>? ?? {};
            final title = info['title'] as String? ?? entry.key;
            final rate = (info['rate'] as num?)?.toDouble() ?? 0.0;
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RateBar(
                  label: title, value: rate / 100, color: color),
            );
          }),
        ],
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _RateBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            Text('${(value * 100).toInt()}%',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value.clamp(0, 1),
          backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 3,
            color: color,
            margin: const EdgeInsets.only(right: 4)),
        Text(label,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ChartHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.purple, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  final double height;
  const _LoadingSection({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
          child: CircularProgressIndicator(color: AppColors.purple)),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text('No data available yet',
            style: TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final String message;
  const _ErrorSection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Text(message,
          style: const TextStyle(color: AppColors.error, fontSize: 13)),
    );
  }
}
