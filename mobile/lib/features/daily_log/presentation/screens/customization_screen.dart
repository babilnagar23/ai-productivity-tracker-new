import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../routines/data/repositories/routine_repository.dart';
import '../../../routines/presentation/providers/routines_provider.dart';

class CustomizationScreen extends ConsumerStatefulWidget {
  const CustomizationScreen({super.key});

  @override
  ConsumerState<CustomizationScreen> createState() =>
      _CustomizationScreenState();
}

class _CustomizationScreenState extends ConsumerState<CustomizationScreen> {
  List<Map<String, dynamic>> _checklists = [];
  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _deletedHistory = [];
  bool _loaded = false;

  void _initFromConfig(Map<String, dynamic> config) {
    if (_loaded) return;
    _loaded = true;
    final cl = config['coreChecklists'] as List<dynamic>? ?? [];
    final mt = config['coreMetrics'] as List<dynamic>? ?? [];
    final dh = config['deletedHistory'] as List<dynamic>? ?? [];
    _checklists = cl.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _metrics = mt.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _deletedHistory =
        dh.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _save() async {
    try {
      await RoutineRepository().updateCustomConfig({
        'coreChecklists': _checklists,
        'coreMetrics': _metrics,
        'deletedHistory': _deletedHistory,
      });
      ref.invalidate(customConfigProvider);
      ref.invalidate(routinesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Saved!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _deleteChecklist(int index) {
    setState(() {
      _deletedHistory.add({..._checklists[index], 'type': 'checklist'});
      _checklists.removeAt(index);
    });
    _save();
  }

  void _deleteMetric(int index) {
    setState(() {
      _deletedHistory.add({..._metrics[index], 'type': 'metric'});
      _metrics.removeAt(index);
    });
    _save();
  }

  void _showHabitSheet({Map<String, dynamic>? existing, int? index}) {
    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'Add New Habit' : 'Edit Habit',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _inputField(titleCtrl, 'Title'),
            const SizedBox(height: 12),
            _inputField(descCtrl, 'Description'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isEmpty) return;
                  setState(() {
                    final item = {
                      'id': existing?['id'] ?? const Uuid().v4(),
                      'title': titleCtrl.text,
                      'description': descCtrl.text,
                    };
                    if (index != null) {
                      _checklists[index] = item;
                    } else {
                      _checklists.add(item);
                    }
                  });
                  _save();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text('Save',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetricSheet({Map<String, dynamic>? existing, int? index}) {
    final titleCtrl = TextEditingController(
      text: existing?['title'] as String? ?? '',
    );

    final unitCtrl = TextEditingController(
      text: existing?['unit'] as String? ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'Add Metric' : 'Edit Metric',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _inputField(titleCtrl, 'Title (e.g. Study Duration (Hrs))'),
            const SizedBox(height: 12),
            _inputField(unitCtrl, 'Unit (hrs, mins, pages, L)'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isEmpty) return;
                  setState(() {
                    final item = {
                      'id': existing?['id'] ?? const Uuid().v4(),
                      'title': titleCtrl.text,
                      'unit': unitCtrl.text,
                    };
                    if (index != null) {
                      _metrics[index] = item;
                    } else {
                      _metrics.add(item);
                    }
                  });
                  _save();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text('Save',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
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
            borderSide: BorderSide(color: AppColors.blue)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(customConfigProvider);
    return configAsync.when(
      loading: () => Scaffold(
          backgroundColor: AppColors.bg,
          body:
              Center(child: CircularProgressIndicator(color: AppColors.blue))),
      error: (e, _) => Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(
              child: Text('$e',
                  style: GoogleFonts.inter(color: AppColors.error)))),
      data: (config) {
        _initFromConfig(config);
        return _buildBody();
      },
    );
  }

  Widget _buildBody() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Habit & Metric Customisation',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Active Habits'),
          ..._checklists.asMap().entries.map((e) => _HabitCard(
                item: e.value,
                onEdit: () => _showHabitSheet(existing: e.value, index: e.key),
                onDelete: () => _deleteChecklist(e.key),
              )),
          _addButton('Add New Habit', () => _showHabitSheet()),
          const SizedBox(height: 24),
          _sectionHeader('Numerical Metrics'),
          ..._metrics.asMap().entries.map((e) => _MetricCard(
                item: e.value,
                onEdit: () => _showMetricSheet(existing: e.value, index: e.key),
                onDelete: () => _deleteMetric(e.key),
              )),
          _addButton('Add New Metric', () => _showMetricSheet()),
          const SizedBox(height: 24),
          _sectionHeader('Recovery Bin'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recently Deleted',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 14)),
              GestureDetector(
                onTap: _showRecoveryBin,
                child: Text('View (${_deletedHistory.length} items)',
                    style:
                        GoogleFonts.inter(color: AppColors.blue, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.blue.withValues(alpha: 0.5),
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: AppColors.blue, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showRecoveryBin() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Recovery Bin',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          if (_deletedHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No deleted items',
                  style: GoogleFonts.inter(color: AppColors.textMuted)),
            )
          else
            ..._deletedHistory.asMap().entries.map((e) => ListTile(
                  title: Text(e.value['title'] as String? ?? '',
                      style: GoogleFonts.inter(color: AppColors.textPrimary)),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        final item = Map<String, dynamic>.from(e.value);
                        final type = item.remove('type') as String?;
                        if (type == 'metric') {
                          _metrics.add(item);
                        } else {
                          _checklists.add(item);
                        }
                        _deletedHistory.removeAt(e.key);
                      });
                      _save();
                      Navigator.pop(ctx);
                    },
                    child: Text('Restore',
                        style: GoogleFonts.inter(color: AppColors.blue)),
                  ),
                )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _HabitCard(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] as String? ?? '',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                if ((item['description'] as String? ?? '').isNotEmpty)
                  Text(item['description'] as String,
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: AppColors.blue, size: 20),
              onPressed: onEdit),
          IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 20),
              onPressed: onDelete),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MetricCard(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bar_chart_rounded,
                color: AppColors.cyan, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item['title'] as String? ?? '',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: AppColors.blue, size: 20),
              onPressed: onEdit),
          IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 20),
              onPressed: onDelete),
        ],
      ),
    );
  }
}
