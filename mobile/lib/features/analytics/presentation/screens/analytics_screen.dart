import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await apiClient.dio.get(ApiEndpoints.analyticsFull);
  return response.data as Map<String, dynamic>;
});

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
            analyticsAsync.when(
              loading: () => const _LoadingSection(height: 100),
              error: (e, _) => _ErrorSection(message: '$e'),
              data: (data) {
                final stats = _asMap(data['stats']);
                return _SummaryRow(stats: stats);
              },
            ),
            const SizedBox(height: 20),
            const _SectionTitle(
              title: 'Logs by Date',
              icon: Icons.table_chart_rounded,
            ),
            analyticsAsync.when(
              loading: () => const _LoadingSection(height: 260),
              error: (e, _) => _ErrorSection(message: '$e'),
              data: (data) {
                final config = _asMap(data['config']);

                return weeklyAsync.when(
                  loading: () => const _LoadingSection(height: 260),
                  error: (e, _) => _ErrorSection(message: '$e'),
                  data: (routines) => _AnalyticsTable(
                    routines: _normalizeRoutines(routines),
                    config: config,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            analyticsAsync.when(
              loading: () => const _LoadingSection(height: 150),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) {
                final stats = _asMap(data['stats']);
                final rates = _asMap(stats['checklistRates']);
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
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            value: '$avgScore',
            label: 'Avg Score',
            icon: Icons.bolt_rounded,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            value: '$totalDays',
            label: 'Days Logged',
            icon: Icons.calendar_today_rounded,
            color: AppColors.blue,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

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
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Table View ────────────────────────────────────────────────────────────────

class _AnalyticsTable extends StatelessWidget {
  final List<Map<String, dynamic>> routines;
  final Map<String, dynamic> config;

  const _AnalyticsTable({
    required this.routines,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) {
      return const _EmptyState(message: 'No analytics data available yet');
    }

    final recent = [
      ...routines
    ]..sort((a, b) => _parseDate(_pick(a, ['date', 'createdAt', 'created_at']))
        .compareTo(_parseDate(_pick(b, ['date', 'createdAt', 'created_at']))));

    final visible =
        recent.length > 14 ? recent.sublist(recent.length - 14) : recent;

    final checklistDefs = _asListOfMap(config['coreChecklists']);
    final metricDefs = _asListOfMap(config['coreMetrics']);

    final rows = <DataRow>[
      _buildProductivityRow(visible),
      ...metricDefs.map((m) {
        final id = (m['id'] as String?) ?? '';
        final title = (m['title'] as String?) ?? id;
        return _buildMetricRow(title, id, visible);
      }),
      ...checklistDefs.map((c) {
        final id = (c['id'] as String?) ?? '';
        final title = (c['title'] as String?) ?? id;
        return _buildChecklistRow(title, id, visible);
      }),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: const WidgetStatePropertyAll(AppColors.card),
          horizontalMargin: 12,
          columnSpacing: 18,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columns: [
            const DataColumn(
              label: Text(
                'Metric',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...visible.map((r) {
              final label = _formatDateLabel(
                _pick(r, ['date', 'createdAt', 'created_at']),
              );
              return DataColumn(
                label: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
          ],
          rows: rows,
        ),
      ),
    );
  }

  DataRow _buildProductivityRow(List<Map<String, dynamic>> rows) {
    return DataRow(
      cells: [
        const DataCell(
          Text(
            'Productivity',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...rows.map((r) {
          final value = _numValue(
            r,
            [
              'productivityScore',
              'productivity_score',
            ],
          );
          return DataCell(
            Center(
              child: Text(
                _formatNum(value ?? 0 ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  DataRow _buildMetricRow(
    String title,
    String id,
    List<Map<String, dynamic>> rows,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...rows.map((r) {
          final value = _numValue(r, _metricAliases(id));
          return DataCell(
            Center(
              child: Text(
                value == null ? '—' : _formatNum(value),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  DataRow _buildChecklistRow(
    String title,
    String id,
    List<Map<String, dynamic>> rows,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...rows.map((r) {
          final value = _boolValue(r, id);
          final text = value == null ? '—' : (value ? '✓' : '✕');
          final color = value == null
              ? AppColors.textMuted
              : (value ? AppColors.success : AppColors.error);

          return DataCell(
            Center(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Habit Rates ───────────────────────────────────────────────────────────────

class _HabitRates extends StatelessWidget {
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
          const Text(
            'Habit Completion Rates',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(entries.length, (i) {
            final entry = entries[i];
            final info = _asMap(entry.value);
            final title = info['title'] as String? ?? entry.key;
            final rate = (info['rate'] as num?)?.toDouble() ?? 0.0;
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RateBar(label: title, value: rate / 100, color: color),
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

  const _RateBar({
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.purple, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
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
        child: CircularProgressIndicator(color: AppColors.purple),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textMuted),
        ),
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
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> _asListOfMap(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

List<Map<String, dynamic>> _normalizeRoutines(List<dynamic> routines) {
  final items = routines
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  items.sort((a, b) => _parseDate(_pick(a, ['date', 'createdAt', 'created_at']))
      .compareTo(_parseDate(_pick(b, ['date', 'createdAt', 'created_at']))));

  return items;
}

dynamic _pick(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key) && map[key] != null) {
      return map[key];
    }
  }
  return null;
}

DateTime _parseDate(dynamic value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatDateLabel(dynamic value) {
  final dt = _parseDate(value);
  if (dt.millisecondsSinceEpoch == 0) return '—';
  return DateFormat('dd MMM').format(dt);
}

List<String> _metricAliases(String id) {
  switch (id) {
    case 'studyHours':
      return const ['studyHours', 'study_hours'];
    case 'mobileUsage':
      return const ['mobileUsage', 'mobile_usage'];
    case 'waterIntake':
      return const ['waterIntake', 'water_intake'];
    case 'productivityScore':
      return const ['productivityScore', 'productivity_score'];
    default:
      return [id, _toSnakeCase(id)];
  }
}

String _toSnakeCase(String value) {
  return value
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
      .toLowerCase();
}

num? _numValue(Map<String, dynamic> routine, List<String> keys) {
  for (final key in keys) {
    final value = routine[key];
    if (value == null) continue;
    if (value is num) return value;
    final parsed = num.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

bool? _boolValue(Map<String, dynamic> routine, String id) {
  final nestedMaps = [
    _asMap(routine['core_checklists']),
    _asMap(routine['coreChecklists']),
  ];

  for (final map in nestedMaps) {
    if (map.containsKey(id)) {
      final value = map[id];
      if (value is bool) return value;
      if (value != null) return value.toString().toLowerCase() == 'true';
    }
  }

  final candidates = <String>[
    '${id}Completed',
    '${id}_completed',
    '${id}completed',
  ];

  for (final key in candidates) {
    if (routine.containsKey(key)) {
      final value = routine[key];
      if (value is bool) return value;
      if (value != null) return value.toString().toLowerCase() == 'true';
    }
  }

  return null;
}

String _formatNum(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
