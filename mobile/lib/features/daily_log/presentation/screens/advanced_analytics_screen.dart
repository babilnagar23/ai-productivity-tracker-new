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

class _AdvancedAnalyticsScreenState extends ConsumerState<AdvancedAnalyticsScreen> {
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

    if (!mounted) return;

    setState(() {
      _chartsConfigured = done;
      if (raw != null) {
        final decoded = (jsonDecode(raw) as List<dynamic>).cast<String>();
        _selectedCharts = decoded.where(_validChartIds().contains).toList();
      }
    });
  }

  Set<String> _validChartIds() {
    return {
      'weekly_productivity',
      'monthly_productivity',
      'habit_completion',
      'study_hours_bar',
    };
  }

  Future<void> _openChartEdit(List<String> availableMetrics) async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChartEditScreen(
          availableMetrics: availableMetrics,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _selectedCharts = result.where(_validChartIds().contains).toList();
        _chartsConfigured = true;
        _showCharts = true;
      });
    }
  }

  void _showExportSheet(List<RoutineModel> routines) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff050505),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Data',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _exportTile(Icons.upload_rounded, 'Export as PDF', () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF export coming soon')),
              );
            }),
            _exportTile(Icons.table_chart_outlined, 'Export as CSV', () {
              Navigator.pop(ctx);
              _exportCsv(routines);
            }),
            _exportTile(Icons.description_outlined, 'Export as Word Table', () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Word export coming soon')),
              );
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
          color: const Color.fromARGB(255, 9, 73, 237),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFFFFF) , size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(List<RoutineModel> routines) async {
    final buf = StringBuffer();
    buf.writeln('Date,Score,Sleep,Wake');
    for (final r in routines) {
      buf.writeln('${r.date},${r.productivityScore},${r.sleepTime},${r.wakeTime}');
    }
    await SharePlus.instance.share(
      ShareParams(
        text: buf.toString(),
        subject: 'Productivity Tracker Data Export',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(analyticsRoutinesProvider);
    final statsAsync = ref.watch(analyticsStatsProvider);
    final configAsync = ref.watch(customConfigProvider);

    final configChecklists =
        (configAsync.asData?.value['coreChecklists'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final configMetrics =
        (configAsync.asData?.value['coreMetrics'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final availableMetrics = configMetrics
        .map((m) => (m['id'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        title: Text(
          'Analytics Dashboard',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          routinesAsync.when(
            data: (r) => IconButton(
              icon: const Icon(
                Icons.ios_share_rounded,
                color: Color.fromARGB(255, 227, 217, 217),
                size: 22,
              ),
              onPressed: () => _showExportSheet(r),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color.fromARGB(255, 227, 204, 204),
              size: 22,
            ),
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
          child: CircularProgressIndicator(color: Color.fromARGB(255, 0, 0, 0)),
        ),
        error: (e, _) => Center(
          child: Text(
            '$e',
            style: GoogleFonts.inter(color: AppColors.error),
          ),
        ),
        data: (routines) => _buildBody(
          routines,
          statsAsync,
          configChecklists,
          configMetrics,
          availableMetrics,
        ),
      ),
    );
  }

  Widget _buildBody(
    List<RoutineModel> routines,
    AsyncValue<Map<String, dynamic>> statsAsync,
    List<Map<String, dynamic>> configChecklists,
    List<Map<String, dynamic>> configMetrics,
    List<String> availableMetrics,
  ) {
    final stats =
        statsAsync.asData?.value['stats'] as Map<String, dynamic>? ?? {};

    final totalDays = stats['totalLogs'] ?? routines.length;
    final streak = stats['currentStreak'] ?? 0;
    final avgScore = stats['avgScore'] ??
        (routines.isEmpty
            ? 0
            : (routines.map((r) => r.productivityScore).reduce((a, b) => a + b) /
                    routines.length)
                .round());
    final bestScore = routines.isEmpty
        ? 0
        : routines.map((r) => r.productivityScore).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ToggleBtn(
                  label: 'Table View',
                  selected: !_showCharts,
                  onTap: () => setState(() => _showCharts = false),
                ),
              ),
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
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_showCharts)
          _buildTableView(routines, configChecklists, configMetrics)
        else
          _buildChartsView(
            routines,
            availableMetrics,
            configChecklists,
            configMetrics,
          ),
      ],
    );
  }

  Widget _buildTableView(
    List<RoutineModel> routines,
    List<Map<String, dynamic>> configChecklists,
    List<Map<String, dynamic>> configMetrics,
  ) {
    if (routines.isEmpty) {
      return Center(
        child: Text(
          'No data yet',
          style: GoogleFonts.inter(color: AppColors.textMuted),
        ),
      );
    }

    final sorted = [...routines]
      ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));

    final recent = sorted.length > 14 ? sorted.sublist(0, 14) : sorted;

    final fallbackChecklists = <Map<String, dynamic>>[
      {'id': 'study', 'title': 'Study'},
      {'id': 'exercise', 'title': 'Exercise'},
      {'id': 'ml', 'title': 'Deep Work'},
    ];

    final fallbackMetrics = <Map<String, dynamic>>[
      {'id': 'studyHours', 'title': 'Study Hours'},
      {'id': 'mobileUsage', 'title': 'Mobile Usage'},
    ];

    final checklistsToShow =
        configChecklists.isNotEmpty ? configChecklists : fallbackChecklists;
    final metricsToShow =
        configMetrics.isNotEmpty ? configMetrics : fallbackMetrics;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 52,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 72,
        horizontalMargin: 10,
        columnSpacing: 10,
        headingRowColor: const WidgetStatePropertyAll(Color.fromARGB(255, 23, 22, 26)),
        dataRowColor: const WidgetStatePropertyAll(Color.fromARGB(255, 19, 21, 27)),
        border: TableBorder.all(
          color: const Color.fromARGB(0, 255, 255, 255),
          borderRadius: BorderRadius.circular(12),
        ),
        columns: [
          DataColumn(
            label: _tableHeaderCell('Metric', width: 116),
          ),
          ...recent.map((r) => DataColumn(
                label: _tableHeaderCell(_formatDateLabel(r.date), width: 60),
              )),
        ],
        rows: [
          ...checklistsToShow.map((habit) {
            final id = (habit['id'] as String?) ?? '';
            final title = (habit['title'] as String?) ?? id;

            return DataRow(
              cells: [
                DataCell(
                  _tableLabel(
                    title,
                    width: 116,
                    alignLeft: true,
                  ),
                ),
                ...recent.map((r) {
                  final checklists = r.coreChecklists.isNotEmpty
                      ? r.coreChecklists
                      : _legacyChecklists(r);

                  final done = checklists[id] == true;

                  return DataCell(
                    Center(
                      child: Icon(
                        done ? Icons.check_rounded : Icons.close_rounded,
                        color: done ? AppColors.success : AppColors.error,
                        size: 16,
                      ),
                    ),
                  );
                }),
              ],
            );
          }),

          ...metricsToShow.map((metric) {
            final id = (metric['id'] as String?) ?? '';
            final title = (metric['title'] as String?) ?? id;

            return DataRow(
              cells: [
                DataCell(
                  _tableLabel(
                    title,
                    width: 116,
                    alignLeft: true,
                  ),
                ),
                ...recent.map((r) {
                  final metricsMap = r.coreMetrics.isNotEmpty
                      ? r.coreMetrics
                      : _legacyMetrics(r);

                  final value = metricsMap[id];
                  final display = value == null ? '—' : '$value';

                  return DataCell(
                    _tableLabel(
                      display,
                      width: 60,
                      alignLeft: false,
                      small: true,
                    ),
                  );
                }),
              ],
            );
          }),

          DataRow(
            cells: [
              DataCell(
                _tableLabel(
                  'Productivity',
                  width: 116,
                  alignLeft: true,
                ),
              ),
              ...recent.map(
                (r) => DataCell(
                  _tableLabel(
                    '${r.productivityScore}',
                    width: 60,
                    alignLeft: false,
                    small: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String label, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _tableLabel(
    String text, {
    required double width,
    required bool alignLeft,
    bool small = false,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: GoogleFonts.inter(
          color: small ? AppColors.textSecondary : AppColors.textPrimary,
          fontSize: small ? 12 : 13,
          fontWeight: small ? FontWeight.w600 : FontWeight.w700,
          height: 1.15,
        ),
      ),
    );
  }

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
            Text(
              'No charts selected',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _openChartEdit(availableMetrics),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Customise Charts',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                  color: const Color.fromRGBO(34, 39, 52, 1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      color: Color.fromARGB(255, 81, 89, 88),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Edit Charts',
                      style: GoogleFonts.inter(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        fontSize: 13,
                      ),
                    ),
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
            child: _WeeklyLineChart(routines: recent7),
          ),
        if (_selectedCharts.contains('monthly_productivity'))
          _ChartCard(
            title: 'Monthly Productivity',
            child: _WeeklyLineChart(routines: recent30),
          ),
        if (_selectedCharts.contains('habit_completion'))
          _ChartCard(
            title: 'Habit Completion',
            child: _HabitBars(
              routines: routines,
              configChecklists: configChecklists,
            ),
          ),
        if (_selectedCharts.contains('study_hours_bar') &&
            availableMetrics.contains('studyHours'))
          _ChartCard(
            title: 'Study Hours',
            child: _MetricBarsChart(
              routines: recent7,
              metricId: 'studyHours',
            ),
          ),
      ],
    );
  }

  static Map<String, bool> _legacyChecklists(RoutineModel r) {
    final m = <String, bool>{};
    if (r.studyCompleted) m['study'] = true;
    if (r.exerciseCompleted) m['exercise'] = true;
    if (r.mlCompleted) m['ml'] = true;
    return m;
  }

  static Map<String, dynamic> _legacyMetrics(RoutineModel r) {
    final m = <String, dynamic>{};
    if (r.studyHours > 0) m['studyHours'] = r.studyHours;
    if (r.mobileUsage > 0) m['mobileUsage'] = r.mobileUsage;
    return m;
  }
}

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

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color.fromARGB(255, 2, 96, 96) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.child,
  });

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
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WeeklyLineChart extends StatelessWidget {
  final List<RoutineModel> routines;
  const _WeeklyLineChart({required this.routines});

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) {
      return SizedBox(
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
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= routines.length) {
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
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: const Color.fromARGB(255, 144, 181, 255),
              isCurved: true,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color.fromARGB(255, 149, 175, 252).withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitBars extends StatelessWidget {
  final List<RoutineModel> routines;
  final List<Map<String, dynamic>> configChecklists;

  const _HabitBars({
    required this.routines,
    required this.configChecklists,
  });

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

    final colors = [
      const Color.fromARGB(255, 255, 255, 255),
      AppColors.success,
      const Color.fromARGB(255, 124, 121, 151),
      AppColors.warning,
      AppColors.cyan,
    ];

    final total = routines.length;

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

  const _Bar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
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

class _MetricBarsChart extends StatelessWidget {
  final List<RoutineModel> routines;
  final String metricId;

  const _MetricBarsChart({
    required this.routines,
    required this.metricId,
  });

  double _getValue(RoutineModel r) {
    if (r.coreMetrics.containsKey(metricId)) {
      return (r.coreMetrics[metricId] as num?)?.toDouble() ?? 0;
    }
    if (metricId == 'studyHours') return r.studyHours;
    if (metricId == 'mobileUsage') return r.mobileUsage;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) return const SizedBox(height: 120);

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= routines.length) {
                    return const SizedBox.shrink();
                  }
                  final d = routines[i].date;
                  return Text(
                    d.length >= 10 ? d.substring(8) : d,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
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
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: _getValue(e.value),
                      color: const Color.fromARGB(255, 113, 225, 167),
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

DateTime _parseDate(String date) {
  return DateTime.tryParse(date) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatDateLabel(String date) {
  final dt = _parseDate(date);
  if (dt.millisecondsSinceEpoch == 0) return date;
  return '${dt.day.toString().padLeft(1, '0')} ${_monthShort(dt.month)}';
}

String _monthShort(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}