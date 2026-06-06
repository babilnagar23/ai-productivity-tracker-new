import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class ChartOption {
  final String id;
  final String name;
  final String requiredMetric;

  const ChartOption({required this.id, required this.name, this.requiredMetric = ''});
}

const _allCharts = [
  ChartOption(id: 'weekly_productivity', name: 'Weekly Productivity Graph'),
  ChartOption(id: 'monthly_productivity', name: 'Monthly Productivity Graph'),
  ChartOption(id: 'habit_completion', name: 'Habit Completion Progress Bars'),
  ChartOption(id: 'sleep_vs_productivity', name: 'Sleep vs Productivity', requiredMetric: 'sleepHours'),
  ChartOption(id: 'mobile_vs_productivity', name: 'Mobile Usage vs Productivity', requiredMetric: 'mobileUsage'),
  ChartOption(id: 'exercise_vs_productivity', name: 'Exercise vs Productivity', requiredMetric: 'exerciseTime'),
  ChartOption(id: 'study_hours_bar', name: 'Study Hours Bar Chart'),
  ChartOption(id: 'score_heatmap', name: 'Score Heatmap Calendar'),
];

class ChartEditScreen extends StatefulWidget {
  final List<String> availableMetrics;
  const ChartEditScreen({super.key, this.availableMetrics = const []});

  @override
  State<ChartEditScreen> createState() => _ChartEditScreenState();
}

class _ChartEditScreenState extends State<ChartEditScreen> {
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('selected_charts');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      setState(() => _selected = Set<String>.from(list.cast<String>()));
    } else {
      // Default selection
      setState(() => _selected = {'weekly_productivity', 'habit_completion'});
    }
  }

  Future<void> _apply() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_charts', jsonEncode(_selected.toList()));
    await prefs.setBool('charts_selection_done', true);
    if (mounted) Navigator.pop(context, _selected.toList());
  }

  List<ChartOption> get _availableCharts {
    return _allCharts.where((c) {
      if (c.requiredMetric.isEmpty) return true;
      return widget.availableMetrics.contains(c.requiredMetric);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final charts = _availableCharts;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Customise Charts', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: charts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final chart = charts[i];
                final isSelected = _selected.contains(chart.id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) { _selected.remove(chart.id); }
                    else { _selected.add(chart.id); }
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? AppColors.blue : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppColors.blue : Colors.transparent,
                            border: Border.all(color: isSelected ? AppColors.blue : AppColors.textMuted, width: 2),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(chart.name, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              // Mini preview
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.cardElevated,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('Preview', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Apply', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
