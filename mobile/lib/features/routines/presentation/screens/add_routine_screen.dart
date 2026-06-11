import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/routine_model.dart';
import '../../data/repositories/routine_repository.dart';
import '../providers/routines_provider.dart';

class AddRoutineScreen extends ConsumerStatefulWidget {
  final String? routineId;
  final DateTime? initialDate;
  const AddRoutineScreen({super.key, this.routineId, this.initialDate});

  @override
  ConsumerState<AddRoutineScreen> createState() => _AddRoutineScreenState();
}

class _AddRoutineScreenState extends ConsumerState<AddRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);

  // Dynamic from custom config
  List<Map<String, dynamic>> _checklists = [];
  List<Map<String, dynamic>> _metrics = [];

  // State maps: checklist id → bool, metric id → TextEditingController
  Map<String, bool> _checklistState = {};
  Map<String, TextEditingController> _metricControllers = {};

  bool _isLoading = false;
  bool _isEditing = false;
  RoutineModel? _existingRoutine;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await ref.read(customConfigProvider.future);
      final cls = (config['coreChecklists'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final mts = (config['coreMetrics'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final checkState = <String, bool>{};
      for (final c in cls) {
        checkState[c['id'] as String] = false;
      }
      final metricCtrl = <String, TextEditingController>{};
      for (final m in mts) {
        metricCtrl[m['id'] as String] = TextEditingController(text: '0');
      }

      setState(() {
        _checklists = cls;
        _metrics = mts;
        _checklistState = checkState;
        _metricControllers = metricCtrl;
      });

      if (widget.routineId != null) {
        await _loadExisting();
      }
    } catch (e) {
      debugPrint("Error loading customization config: $e");
      _checklists = [];
      _metrics = [];
      _checklistState = {};
      _metricControllers = {};
      if (widget.routineId != null) {
        await _loadExisting();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExisting() async {
    try {
      final routines = await RoutineRepository().getRoutines();
      _existingRoutine = routines.firstWhere((r) => r.id == widget.routineId);
      _populate(_existingRoutine!);
      if (mounted) setState(() => _isEditing = true);
    } catch (_) {}
  }

  void _populate(RoutineModel r) {
    _selectedDate = DateTime.parse(r.date);

    for (final c in _checklists) {
      final id = c['id'] as String;

      _checklistState[id] = r.coreChecklists[id] ??
          (id == 'study'
              ? r.studyCompleted
              : id == 'exercise'
                  ? r.exerciseCompleted
                  : id == 'ml'
                      ? r.mlCompleted
                      : false);
    }

    final savedMetrics = r.coreMetrics;

    for (final m in _metrics) {
      final id = m['id'] as String;
      final val = savedMetrics[id];

      if (val != null) {
        _metricControllers[id]?.text = val.toString();
      }
    }

    _notesCtrl.text = r.notes;

    final sleep = r.sleepTime.split(':');
    final wake = r.wakeTime.split(':');

    if (sleep.length >= 2) {
      _sleepTime = TimeOfDay(
        hour: int.tryParse(sleep[0]) ?? 23,
        minute: int.tryParse(sleep[1]) ?? 0,
      );
    }
    if (wake.length >= 2) {
      _wakeTime = TimeOfDay(
        hour: int.tryParse(wake[0]) ?? 7,
        minute: int.tryParse(wake[1]) ?? 0,
      );
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final ctrl in _metricControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  int _calcScore() {
    if (_checklists.isEmpty) return 0;
    final completed = _checklistState.values.where((v) => v).length;
    return ((completed / _checklists.length) * 100).round().clamp(0, 100);
  }

  Map<String, bool> _buildCoreChecklists() {
    final map = <String, bool>{};

    for (final c in _checklists) {
      final id = c['id'] as String;
      map[id] = _checklistState[id] ?? false;
    }

    return map;
  }

  Map<String, dynamic> _buildCoreMetrics() {
    final map = <String, dynamic>{};
    for (final m in _metrics) {
      final id = m['id'] as String;
      map[id] = double.tryParse(_metricControllers[id]?.text ?? '0') ?? 0.0;
    }
    return map;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final Map<String, bool> coreChecklists = _buildCoreChecklists();
    final coreMetrics = _buildCoreMetrics();

    // Legacy fields for backward compat
    final studyCompleted = _checklistState['study'] ?? false;
    final exerciseCompleted = _checklistState['exercise'] ?? false;
    final mlCompleted = _checklistState['ml'] ?? false;
    final studyHours =
        double.tryParse(_metricControllers['studyHours']?.text ?? '0') ?? 0.0;
    final mobileUsage =
        double.tryParse(_metricControllers['mobileUsage']?.text ?? '0') ?? 0.0;

    final routine = RoutineModel(
      id: _existingRoutine?.id ?? '',
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      studyCompleted: studyCompleted,
      exerciseCompleted: exerciseCompleted,
      mlCompleted: mlCompleted,
      studyHours: studyHours,
      sleepTime:
          '${_sleepTime.hour.toString().padLeft(2, '0')}:${_sleepTime.minute.toString().padLeft(2, '0')}',
      wakeTime:
          '${_wakeTime.hour.toString().padLeft(2, '0')}:${_wakeTime.minute.toString().padLeft(2, '0')}',
      mobileUsage: mobileUsage,
      notes: _notesCtrl.text,
      productivityScore: _calcScore(),
      coreChecklists: coreChecklists,
      coreMetrics: coreMetrics,
    );

    try {
      if (_isEditing && _existingRoutine?.id != null) {
        await RoutineRepository().updateRoutine(_existingRoutine!.id, routine);
      } else {
        await RoutineRepository().createRoutine(routine);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Routine updated!' : 'Routine saved!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        debugPrint('SAVE ERROR: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.blue,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isSleep) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isSleep ? _sleepTime : _wakeTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.blue,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isSleep) {
          _sleepTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          _isEditing ? 'Edit Log' : 'Log Today',
          style: GoogleFonts.inter(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.blue))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Score card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Projected Score',
                                style: GoogleFonts.inter(
                                    color: Colors.white70, fontSize: 12)),
                            Text(
                              '${_calcScore()}/100',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.bolt_rounded,
                            color: Colors.white38, size: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date
                  const _SectionLabel('Date'),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: AppColors.blue, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy')
                                .format(_selectedDate),
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dynamic Habits
                  const _SectionLabel('Habits Completed'),
                  if (_checklists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No habits configured. Add habits in Customisation.',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                    )
                  else
                    ..._checklists.map((c) {
                      final id = c['id'] as String;
                      final title = c['title'] as String? ?? id;
                      final done = _checklistState[id] ?? false;
                      return _HabitToggle(
                        label: title,
                        value: done,
                        onChanged: (v) => setState(() {
                          _checklistState[id] = v;
                        }),
                      );
                    }),
                  const SizedBox(height: 20),

                  // Dynamic Metrics
                  const _SectionLabel('Metrics'),
                  if (_metrics.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No metrics configured. Add metrics in Customisation.',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _metrics.map((m) {
                        final id = m['id'] as String;
                        final title = m['title'] as String? ?? id;
                        final unit = m['unit'] as String? ?? '';
                        final ctrl = _metricControllers[id] ??
                            TextEditingController(text: '0');
                        return SizedBox(
                          width: (MediaQuery.of(context).size.width - 44) / 2,
                          child: _MetricField(
                            controller: ctrl,
                            label: title,
                            unit: unit,
                            onChanged: (_) => setState(() {}),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),

                  // Sleep schedule
                  const _SectionLabel('Sleep Schedule'),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeTile(
                          label: 'Sleep at',
                          time: _sleepTime.format(context),
                          icon: Icons.bedtime_rounded,
                          color: AppColors.purple,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeTile(
                          label: 'Wake at',
                          time: _wakeTime.format(context),
                          icon: Icons.wb_sunny_rounded,
                          color: AppColors.warning,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Notes
                  const _SectionLabel('Notes'),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    style: GoogleFonts.inter(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'How was your day? Any observations...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.blue)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(
                        _isEditing ? 'Update Log' : 'Save Log',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _HabitToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HabitToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              value ? AppColors.blue.withValues(alpha: 0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value
                  ? AppColors.blue.withValues(alpha: 0.4)
                  : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                value
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: value ? AppColors.blue : AppColors.textMuted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color:
                      value ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: value ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final ValueChanged<String> onChanged;

  const _MetricField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        suffix: Text(
          unit,
          style: GoogleFonts.inter(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
        labelStyle:
            GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.blue)),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (double.tryParse(v) == null) return 'Enter a number';
        return null;
      },
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Text(time,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
