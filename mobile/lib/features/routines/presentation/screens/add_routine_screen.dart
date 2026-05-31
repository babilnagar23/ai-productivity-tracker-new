import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/routine_model.dart';
import '../../data/repositories/routine_repository.dart';

class AddRoutineScreen extends ConsumerStatefulWidget {
  final int? routineId;
  const AddRoutineScreen({super.key, this.routineId});

  @override
  ConsumerState<AddRoutineScreen> createState() => _AddRoutineScreenState();
}

class _AddRoutineScreenState extends ConsumerState<AddRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _studyHoursCtrl = TextEditingController(text: '0');
  final _mobileCtrl = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  bool _studyCompleted = false;
  bool _exerciseCompleted = false;
  bool _mlCompleted = false;
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);

  bool _isLoading = false;
  bool _isEditing = false;
  RoutineModel? _existingRoutine;

  @override
  void initState() {
    super.initState();
    if (widget.routineId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    try {
      final routines = await RoutineRepository().getRoutines();
      _existingRoutine = routines.firstWhere((r) => r.id == widget.routineId);
      _populate(_existingRoutine!);
      setState(() { _isEditing = true; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _populate(RoutineModel r) {
    _selectedDate = DateTime.parse(r.date);
    _studyCompleted = r.studyCompleted;
    _exerciseCompleted = r.exerciseCompleted;
    _mlCompleted = r.mlCompleted;
    _studyHoursCtrl.text = r.studyHours.toString();
    _mobileCtrl.text = r.mobileUsage.toString();
    _notesCtrl.text = r.notes;
    final sleep = r.sleepTime.split(':');
    final wake = r.wakeTime.split(':');
    _sleepTime = TimeOfDay(hour: int.parse(sleep[0]), minute: int.parse(sleep[1]));
    _wakeTime = TimeOfDay(hour: int.parse(wake[0]), minute: int.parse(wake[1]));
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _studyHoursCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  int _calcScore() {
    int score = 0;
    if (_studyCompleted) score += 30;
    if (_exerciseCompleted) score += 25;
    if (_mlCompleted) score += 20;
    final hours = double.tryParse(_studyHoursCtrl.text) ?? 0;
    if (hours >= 4) { score += 15; }
    else if (hours >= 2) { score += 8; }
    final mobile = double.tryParse(_mobileCtrl.text) ?? 0;
    if (mobile <= 1) { score += 10; }
    else if (mobile <= 2) { score += 5; }
    return score.clamp(0, 100);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final routine = RoutineModel(
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      studyCompleted: _studyCompleted,
      exerciseCompleted: _exerciseCompleted,
      mlCompleted: _mlCompleted,
      studyHours: double.tryParse(_studyHoursCtrl.text) ?? 0,
      sleepTime: '${_sleepTime.hour.toString().padLeft(2, '0')}:${_sleepTime.minute.toString().padLeft(2, '0')}',
      wakeTime: '${_wakeTime.hour.toString().padLeft(2, '0')}:${_wakeTime.minute.toString().padLeft(2, '0')}',
      mobileUsage: double.tryParse(_mobileCtrl.text) ?? 0,
      notes: _notesCtrl.text,
      productivityScore: _calcScore(),
    );

    try {
      if (_isEditing && _existingRoutine?.id != null) {
        await RoutineRepository().updateRoutine(_existingRoutine!.id!, routine);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
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
          colorScheme: const ColorScheme.dark(
            primary: AppColors.purple,
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
          colorScheme: const ColorScheme.dark(
            primary: AppColors.purple,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isSleep) { _sleepTime = picked; }
        else { _wakeTime = picked; }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Routine' : 'Log Today'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Projected score card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Projected Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              '${_calcScore()}/100',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.bolt_rounded, color: Colors.white54, size: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date picker
                  const _SectionLabel('Date'),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppColors.purple, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Habits checklist
                  const _SectionLabel('Habits Completed'),
                  _HabitToggle(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.blue,
                    label: 'Study / Learning',
                    value: _studyCompleted,
                    onChanged: (v) => setState(() { _studyCompleted = v; }),
                  ),
                  _HabitToggle(
                    icon: Icons.fitness_center_rounded,
                    color: AppColors.success,
                    label: 'Exercise / Workout',
                    value: _exerciseCompleted,
                    onChanged: (v) => setState(() { _exerciseCompleted = v; }),
                  ),
                  _HabitToggle(
                    icon: Icons.psychology_rounded,
                    color: AppColors.purple,
                    label: 'ML / Deep Work',
                    value: _mlCompleted,
                    onChanged: (v) => setState(() { _mlCompleted = v; }),
                  ),
                  const SizedBox(height: 20),

                  // Metrics
                  const _SectionLabel('Metrics'),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricField(
                          controller: _studyHoursCtrl,
                          label: 'Study Hours',
                          icon: Icons.access_time_rounded,
                          color: AppColors.blue,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricField(
                          controller: _mobileCtrl,
                          label: 'Mobile Usage (h)',
                          icon: Icons.smartphone_rounded,
                          color: AppColors.warning,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sleep / Wake times
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
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'How was your day? Any observations...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.save_rounded, color: Colors.white),
                        label: Text(
                          _isEditing ? 'Update Routine' : 'Save Routine',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
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
      child: Text(text, style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      )),
    );
  }
}

class _HabitToggle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HabitToggle({
    required this.icon,
    required this.color,
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
          color: value ? color.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? color.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(
              color: value ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: value ? FontWeight.w700 : FontWeight.normal,
            ))),
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: value ? color : AppColors.textMuted,
              size: 22,
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
  final IconData icon;
  final Color color;
  final ValueChanged<String> onChanged;

  const _MetricField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 18),
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

  const _TimeTile({required this.label, required this.time, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
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
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Text(time, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
