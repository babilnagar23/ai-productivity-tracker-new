import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../routines/data/repositories/routine_repository.dart';

// ── Template definitions ──────────────────────────────────────────────────────

class _Template {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<Map<String, String>> checklists;
  final List<Map<String, String>> metrics;

  const _Template({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.checklists,
    required this.metrics,
  });
}

final _templates = [
  _Template(
    id: 'student',
    name: 'Student',
    description: 'Study sessions, reading, assignments, sleep tracking',
    icon: Icons.school_outlined,
    color: AppColors.blue,
    checklists: [
      {
        'id': 'study',
        'title': 'Core study session',
        'description': 'Main focus agenda'
      },
      {
        'id': 'reading',
        'title': 'Reading completed',
        'description': 'Books / articles'
      },
    ],
    metrics: [
      {'id': 'studyHours', 'title': 'Study Duration ', 'unit': 'Hrs'},
      {'id': 'mobileUsage', 'title': 'Mobile Usage ', 'unit': 'Hrs'},
      {'id': 'waterIntake', 'title': 'Water Intake', 'unit': 'L'},
    ],
  ),
  _Template(
    id: 'competitive_exam',
    name: 'Competitive Exam',
    description: 'Mock tests, revision blocks, concept mastery',
    icon: Icons.emoji_events_outlined,
    color: AppColors.purple,
    checklists: [
      {
        'id': 'study',
        'title': 'Study session completed',
        'description': 'Scheduled study block'
      },
      {
        'id': 'revision',
        'title': 'Revision completed',
        'description': 'Revisit older topics'
      },
      {
        'id': 'mockTest',
        'title': 'Mock test done',
        'description': 'Practice test completed'
      },
    ],
    metrics: [
      {'id': 'studyHours', 'title': 'Study Duration ', 'unit': 'Hrs'},
      {'id': 'waterIntake', 'title': 'Water Intake', 'unit': 'L'},
    ],
  ),
  _Template(
    id: 'fitness',
    name: 'Fitness',
    description: 'Workouts, water intake, steps, rest days',
    icon: Icons.fitness_center_rounded,
    color: AppColors.success,
    checklists: [
      {
        'id': 'exercise',
        'title': 'Workout completed',
        'description': 'Training session done'
      },
      {
        'id': 'diet',
        'title': 'Diet followed',
        'description': 'Nutrition goals met'
      },
      {
        'id': 'recovery',
        'title': 'Recovery done',
        'description': 'Rest / stretch session'
      },
    ],
    metrics: [
      {'id': 'workoutDuration', 'title': 'Workout Duration ', 'unit': 'Hrs'},
      {'id': 'waterIntake', 'title': 'Water Intake', 'unit': 'L'},
    ],
  ),
  _Template(
    id: 'developer',
    name: 'Developer',
    description: 'Coding sessions, PR reviews, learning, standups',
    icon: Icons.code_rounded,
    color: AppColors.warning,
    checklists: [
      {
        'id': 'coding',
        'title': 'Coding session done',
        'description': 'Feature / bug / review'
      },
      {
        'id': 'learning',
        'title': 'Learning block done',
        'description': 'Docs / course / research'
      },
      {
        'id': 'exercise',
        'title': 'Exercise completed',
        'description': 'Physical activity'
      },
    ],
    metrics: [
      {'id': 'laptopUsage', 'title': 'Laptop Usage ', 'unit': 'Hrs'},
    ],
  ),
  _Template(
    id: 'working',
    name: 'Working',
    description: 'Deep work blocks, meetings, breaks, energy tracking',
    icon: Icons.work_outline_rounded,
    color: AppColors.cyan,
    checklists: [
      {
        'id': 'deepWork',
        'title': 'Deep work block done',
        'description': 'Focused work session'
      },
      {
        'id': 'meetings',
        'title': 'Meetings handled',
        'description': 'All scheduled calls done'
      },
      {
        'id': 'exercise',
        'title': 'Exercise completed',
        'description': 'Physical activity'
      },
    ],
    metrics: [
      {'id': 'laptopUsage', 'title': 'Laptop Usage ', 'unit': 'Hrs'},
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class TemplateSelectScreen extends ConsumerStatefulWidget {
  const TemplateSelectScreen({super.key});

  @override
  ConsumerState<TemplateSelectScreen> createState() =>
      _TemplateSelectScreenState();
}

class _TemplateSelectScreenState extends ConsumerState<TemplateSelectScreen> {
  int _selectedIndex = -1;
  bool _isLoading = false;

  Future<void> _getStarted() async {
    if (_selectedIndex < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a template to continue')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final template = _templates[_selectedIndex];

    try {
      final repo = RoutineRepository();
      await repo.updateCustomConfig({
        'coreChecklists': template.checklists,
        'coreMetrics': template.metrics,
        'deletedHistory': [],
      });
      await SecureStorageService.saveFlag('first_login_done', 'true');
      // Update the in-memory provider so the router redirect sees it immediately
      ref.read(firstLoginDoneProvider.notifier).state = true;
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Text(
                    'Choose Your Template',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Personalise your habit tracking to match your lifestyle',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Template list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = _templates[index];
                  final isSelected = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.cardElevated
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.blue : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: t.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(t.icon, color: t.color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  t.description,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _getStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedIndex >= 0
                        ? AppColors.blue
                        : AppColors.cardElevated,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Get Started',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
