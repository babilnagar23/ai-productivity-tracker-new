import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/data/repositories/routine_repository.dart';
import '../../../routines/presentation/providers/routines_provider.dart';
import 'chart_edit_screen.dart';

final analyticsRoutinesProvider =
    FutureProvider<List<RoutineModel>>((ref) async {
  return RoutineRepository().getRoutines();
});

final analyticsStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await apiClient.dio.get(ApiEndpoints.analyticsFull);
  return response.data as Map<String, dynamic>;
});

class AdvancedAnalyticsScreen extends ConsumerStatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  ConsumerState<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState
    extends ConsumerState<AdvancedAnalyticsScreen> {
  bool _showCharts = false;
  List<String> _selectedCharts = [];
  bool _chartsConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadChartPrefs();
  }

  Future<void> _loadChartPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('charts_selection_done') ?? false;
    final raw = prefs.getString('selected_charts');
    setState(() {
      _chartsConfigured = done;
      if (raw != null) {
        _selectedCharts = List<String>.from(jsonDecode(raw) as List);
      }
    });
  }

  Future<void> _openChartEdit(List<String> availableMetrics) async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
          builder: (_) => ChartEditScreen(availableMetrics: availableMetrics)),
    );
    if (result != null) {
      setState(() {
        _selectedCharts = result;
        _chartsConfigured = true;
      });
    }
  }

  void _showExportSheet(List<RoutineModel> routines) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Data',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _exportTile(Icons.upload_rounded, 'Export as PDF', () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export coming soon')));
            }),
            _exportTile(Icons.table_chart_outlined, 'Export as CSV', () {
              Navigator.pop(ctx);
              _exportCsv(routines);
            }),
            _exportTile(Icons.description_outlined, 'Export as Word Table', () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Word export coming soon')));
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _exportTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(List<RoutineModel> routines) async {
    final buf = StringBuffer();
    buf.writeln('Date,Score,Sleep,Wake');
    for (final r in routines) {
      buf.writeln(
          '${r.date},${r.productivityScore},${r.sleepTime},${r.wakeTime}');
    }
    await Share.share(buf.toString(),
        subject: 'Productivity Tracker Data Export');
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(analyticsRoutinesProvider);
    final statsAsync = ref.watch(analyticsStatsProvider);
    // Watch shared config provider so charts refresh when habits/metrics change
    final configAsync = ref.watch(customConfigProvider);

    final configChecklists =
        (configAsync.asData?.value['coreChecklists'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    final configMetrics =
        (configAsync.asData?.value['coreMetrics'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Analytics Dashboard',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          routinesAsync.when(
            data: (r) => IconButton(
              icon: const Icon(Icons.ios_share_rounded,
                  color: AppColors.textSecondary, size: 22),
              onPressed: () => _showExportSheet(r),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () {
              ref.invalidate(analyticsRoutinesProvider);
              ref.invalidate(analyticsStatsProvider);
              ref.invalidate(customConfigProvider);
            },
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.blue)),
        error: (e, _) => Center(
            child:
                Text('$e', style: GoogleFonts.inter(color: AppColors.error))),
        data: (routines) =>
            _buildBody(routines, statsAsync, configChecklists, configMetrics),
      ),
    );
  }

  Widget _buildBody(
    List<RoutineModel> routines,
    AsyncValue<Map<String, dynamic>> statsAsync,
    List<Map<String, dynamic>> configChecklists,
    List<Map<String, dynamic>> configMetrics,
  ) {
    final stats =
        statsAsync.asData?.value['stats'] as Map<String, dynamic>? ?? {};
    final totalDays = stats['totalLogs'] ?? routines.length;
    final streak = stats['currentStreak'] ?? 0;
    final avgScore = stats['avgScore'] ??
        (routines.isEmpty
            ? 0
            : (routines
                        .map((r) => r.productivityScore)
                        .reduce((a, b) => a + b) /
                    routines.length)
                .round());
    final bestScore = routines.isEmpty
        ? 0
        : routines
            .map((r) => r.productivityScore)
            .reduce((a, b) => a > b ? a : b);

    // Build availableMetrics from user's config metric IDs so ChartEditScreen
    // can filter which chart options are relevant.
    final availableMetrics =
        configMetrics.map((m) => m['id'] as String).toList();
    // Always include mobileUsage for the scatter chart if present
    if (routines.any((r) =>
        r.coreMetrics.containsKey('mobileUsage') &&
        (r.coreMetrics['mobileUsage'] as num? ?? 0) > 0)) {
      if (!availableMetrics.contains('mobileUsage'))
        availableMetrics.add('mobileUsage');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview cards
        SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _OverviewCard(label: 'Total Days Logged', value: '$totalDays'),
              _OverviewCard(label: 'Current Streak', value: '$streak Days'),
              _OverviewCard(label: 'Avg Score', value: '$avgScore/100'),
              _OverviewCard(label: 'Best Score', value: '$bestScore/100'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // View toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                  child: _ToggleBtn(
                      label: 'Table View',
                      selected: !_showCharts,
                      onTap: () => setState(() => _showCharts = false))),
              Expanded(
                  child: _ToggleBtn(
                      label: 'Charts View',
                      selected: _showCharts,
                      onTap: () {
                        if (!_chartsConfigured) {
                          _openChartEdit(availableMetrics);
                        } else {
                          setState(() => _showCharts = true);
                        }
                      })),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!_showCharts)
          _buildTableView(routines, configChecklists, configMetrics)
        else
          _buildChartsView(
              routines, availableMetrics, configChecklists, configMetrics),
      ],
    );
  }

  // ── Table View ────────────────────────────────────────────────────────────

  Widget _buildTableView(
    List<RoutineModel> routines,
    List<Map<String, dynamic>> configChecklists,
    List<Map<String, dynamic>> configMetrics,
  ) {
    if (routines.isEmpty) {
      return Center(
          child: Text('No data yet',
              style: GoogleFonts.inter(color: AppColors.textMuted)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.cardElevated),
        dataRowColor: WidgetStateProperty.all(AppColors.card),
        border: TableBorder.all(
            color: AppColors.border, borderRadius: BorderRadius.circular(12)),
        columns: [
          _col('Date'),
          // Dynamic habit columns
          ...configChecklists.map((c) {
            final title = (c['title'] as String?) ?? 'Habit';
            // Shorten long titles for table header
            final short =
                title.length > 14 ? '${title.substring(0, 14)}…' : title;
            return _col('$short ✓');
          }),
          // Dynamic metric columns
          ...configMetrics.map((m) {
            final title = (m['title'] as String?) ?? 'Metric';
            final short =
                title.length > 12 ? '${title.substring(0, 12)}…' : title;
            return _col(short);
          }),
          _col('Score'),
        ],
        rows: routines.map((r) {
          // For legacy records use synthesized checklists
          final checklists = r.coreChecklists.isNotEmpty
              ? r.coreChecklists
              : _legacyChecklists(r);

          return DataRow(cells: [
            DataCell(Text(
              r.date.length >= 10 ? r.date.substring(5) : r.date,
              style:
                  GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
            )),
            // Habit completion cells
            ...configChecklists.map((c) {
              final id = c['id'] as String;
              final done = checklists[id] ?? false;
              return DataCell(Icon(
                done ? Icons.check_rounded : Icons.close_rounded,
                color: done ? AppColors.success : AppColors.error,
                size: 16,
              ));
            }),
            // Metric value cells
            ...configMetrics.map((m) {
              final id = m['id'] as String;
              final metricsMap =
                  r.coreMetrics.isNotEmpty ? r.coreMetrics : _legacyMetrics(r);
              final val = metricsMap[id] ?? 0;
              return DataCell(Text(
                '$val',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 13),
              ));
            }),
            DataCell(_ScoreBadge(score: r.productivityScore)),
          ]);
        }).toList(),
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 0.3)),
      );

  // ── Charts View ───────────────────────────────────────────────────────────

  Widget _buildChartsView(
    List<RoutineModel> routines,
    List<String> availableMetrics,
    List<Map<String, dynamic>> configChecklists,
    List<Map<String, dynamic>> configMetrics,
  ) {
    if (!_chartsConfigured || _selectedCharts.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text('No charts selected',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _openChartEdit(availableMetrics),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text('Customise Charts',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final recent7 =
        routines.length > 7 ? routines.sublist(routines.length - 7) : routines;
    final recent30 = routines.length > 30
        ? routines.sublist(routines.length - 30)
        : routines;

    // First metric ID for the bar chart (falls back to 'studyHours')
    final firstMetricId = configMetrics.isNotEmpty
        ? configMetrics.first['id'] as String
        : 'studyHours';
    final firstMetricTitle = configMetrics.isNotEmpty
        ? (configMetrics.first['title'] as String? ?? firstMetricId)
        : 'Study Hours';

    // Find mobileUsage metric id in config (may differ from legacy 'mobileUsage')
    final mobileMetricId = configMetrics.firstWhere(
      (m) => (m['id'] as String).toLowerCase().contains('mobile'),
      orElse: () => {'id': 'mobileUsage'},
    )['id'] as String;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => _openChartEdit(availableMetrics),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined,
                        color: AppColors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text('Edit Charts',
                        style: GoogleFonts.inter(
                            color: AppColors.blue, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_selectedCharts.contains('weekly_productivity'))
          _ChartCard(
              title: 'Weekly Productivity',
              child: _WeeklyLineChart(routines: recent7)),

        if (_selectedCharts.contains('monthly_productivity'))
          _ChartCard(
              title: 'Monthly Productivity',
              child: _WeeklyLineChart(routines: recent30)),

        // Dynamic habit completion — from user's config habits
        if (_selectedCharts.contains('habit_completion'))
          _ChartCard(
            title: 'Habit Completion',
            child: _HabitBars(
                routines: routines, configChecklists: configChecklists),
          ),

        // Scatter chart — check if mobile metric exists in data
        if (_selectedCharts.contains('mobile_vs_productivity') &&
            availableMetrics.contains(mobileMetricId))
          _ChartCard(
            title: 'Mobile Usage vs Productivity',
            child: _ScatterChart(
              routines: routines,
              xGetter: (r) =>
                  (r.coreMetrics[mobileMetricId] as num?)?.toDouble() ??
                  r.mobileUsage,
              xLabel: 'Mobile (hrs)',
            ),
          ),

        // First metric bar chart — dynamic metric id
        if (_selectedCharts.contains('study_hours_bar'))
          _ChartCard(
            title: firstMetricTitle,
            child: _MetricBarsChart(routines: recent7, metricId: firstMetricId),
          ),
      ],
    );
  }

  // ── Legacy helpers ────────────────────────────────────────────────────────

  /// Synthesise a coreChecklists-style map from legacy boolean fields.
  static Map<String, bool> _legacyChecklists(RoutineModel r) {
    final m = <String, bool>{};
    if (r.studyCompleted) m['study'] = true;
    if (r.exerciseCompleted) m['exercise'] = true;
    if (r.mlCompleted) m['ml'] = true;
    return m;
  }

  /// Synthesise a coreMetrics-style map from legacy scalar fields.
  static Map<String, dynamic> _legacyMetrics(RoutineModel r) {
    final m = <String, dynamic>{};
    if (r.studyHours > 0) m['studyHours'] = r.studyHours;
    if (r.mobileUsage > 0) m['mobileUsage'] = r.mobileUsage;
    return m;
  }
}

// ── Overview Card ─────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  const _OverviewCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle Button ─────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.inter(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      ),
    );
  }
}

// ── Score Badge ───────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$score',
          style: GoogleFonts.inter(
              color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Chart Card ────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Line Chart ────────────────────────────────────────────────────────────

class _WeeklyLineChart extends StatelessWidget {
  final List<RoutineModel> routines;
  const _WeeklyLineChart({required this.routines});

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final spots = routines
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            e.value.productivityScore.toDouble(),
          ),
        )
        .toList();
    return SizedBox(
      height: 160,
      child: LineChart(LineChartData(
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i >= routines.length) {
                      return const SizedBox.shrink();
                    }

                    final d = routines[i].date;
                    return Text(
                      d.length >= 10 ? d.substring(5) : d,
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    );
                  })),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 10)))),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: AppColors.blue,
            isCurved: true,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: AppColors.blue.withValues(alpha: 0.08)),
          )
        ],
      )),
    );
  }
}

// ── Habit Completion Bars — DYNAMIC from config ───────────────────────────

class _HabitBars extends StatelessWidget {
  final List<RoutineModel> routines;

  /// The active habits from user's customisation config.
  final List<Map<String, dynamic>> configChecklists;

  const _HabitBars({required this.routines, required this.configChecklists});

  static Map<String, bool> _resolveChecklists(RoutineModel r) {
    if (r.coreChecklists.isNotEmpty) return r.coreChecklists;
    final m = <String, bool>{};
    if (r.studyCompleted) m['study'] = true;
    if (r.exerciseCompleted) m['exercise'] = true;
    if (r.mlCompleted) m['ml'] = true;
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const SizedBox.shrink();

    // Fallback colours cycling through palette
    const colors = [
      AppColors.blue,
      AppColors.success,
      AppColors.purple,
      AppColors.warning,
      AppColors.cyan,
    ];

    final total = routines.length;

    // If no config habits, fall back to showing legacy study/exercise/ml
    final habitsToShow = configChecklists.isNotEmpty
        ? configChecklists
        : [
            {'id': 'study', 'title': 'Study'},
            {'id': 'exercise', 'title': 'Exercise'},
            {'id': 'ml', 'title': 'Deep Work'},
          ];

    return Column(
      children: habitsToShow.asMap().entries.map((entry) {
        final idx = entry.key;
        final habit = entry.value;
        final id = habit['id'] as String;
        final title = (habit['title'] as String?) ?? id;
        final shortTitle =
            title.length > 20 ? '${title.substring(0, 20)}…' : title;
        final color = colors[idx % colors.length];

        final rate =
            routines.where((r) => _resolveChecklists(r)[id] == true).length /
                total;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Bar(label: shortTitle, value: rate, color: color),
        );
      }).toList(),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Bar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13)),
            Text('${(value * 100).toInt()}%',
                style: GoogleFonts.inter(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ── Scatter Chart ─────────────────────────────────────────────────────────

class _ScatterChart extends StatelessWidget {
  final List<RoutineModel> routines;
  final double Function(RoutineModel) xGetter;
  final String xLabel;
  const _ScatterChart(
      {required this.routines, required this.xGetter, required this.xLabel});

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const SizedBox(height: 120);
    final spots = routines
        .map((r) => ScatterSpot(xGetter(r), r.productivityScore.toDouble()))
        .toList();
    return SizedBox(
      height: 160,
      child: ScatterChart(ScatterChartData(
        scatterSpots: spots,
        scatterTouchData: ScatterTouchData(enabled: false),
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 9)))),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 10)))),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      )),
    );
  }
}

// ── Metric Bar Chart — DYNAMIC metric id ─────────────────────────────────

/// Replaces the old hardcoded _StudyBarsChart. Reads any metric by id from
/// coreMetrics map, falling back to legacy scalar fields for old records.
class _MetricBarsChart extends StatelessWidget {
  final List<RoutineModel> routines;

  /// The metric id to plot (e.g. 'studyHours', a UUID, 'waterIntake', etc.)
  final String metricId;

  const _MetricBarsChart({required this.routines, required this.metricId});

  double _getValue(RoutineModel r) {
    if (r.coreMetrics.containsKey(metricId)) {
      return (r.coreMetrics[metricId] as num?)?.toDouble() ?? 0;
    }
    // Legacy fallbacks
    if (metricId == 'studyHours') return r.studyHours;
    if (metricId == 'mobileUsage') return r.mobileUsage;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const SizedBox(height: 120);
    return SizedBox(
      height: 140,
      child: BarChart(BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= routines.length)
                      return const SizedBox.shrink();
                    final d = routines[i].date;
                    return Text(d.length >= 10 ? d.substring(8) : d,
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 9));
                  })),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: routines
            .asMap()
            .entries
            .map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: _getValue(e.value),
                      color: AppColors.blue,
                      width: 14,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    )
                  ],
                ))
            .toList(),
      )),
    );
  }
}
