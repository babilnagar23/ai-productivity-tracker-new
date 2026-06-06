import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/data/repositories/routine_repository.dart';

final achievementsRoutinesProvider = FutureProvider<List<RoutineModel>>((ref) async {
  return RoutineRepository().getRoutines();
});

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  String _levelTitle(int level) {
    if (level >= 25) return 'Master';
    if (level >= 20) return 'Expert';
    if (level >= 15) return 'Consistent';
    if (level >= 10) return 'Focused';
    if (level >= 5) return 'Learner';
    return 'Beginner';
  }

  String _nextReward(int level) {
    if (level < 5) return 'Custom Theme';
    if (level < 10) return 'Analytics Package';
    if (level < 15) return 'AI Reports';
    if (level < 20) return 'Focus Themes';
    return 'All Unlocked';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authStateProvider.notifier);
    final user = ref.watch(authStateProvider).user;
    final routinesAsync = ref.watch(achievementsRoutinesProvider);
    final xp = user?.xp ?? 0;
    final level = authNotifier.level;
    final nextXp = authNotifier.nextLevelXp;
    final xpProgress = authNotifier.xpProgress;
    final streak = user?.streak ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Achievements', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
        error: (e, _) => Center(child: Text('$e', style: GoogleFonts.inter(color: AppColors.error))),
        data: (routines) {
          final totalStudyHours = routines.fold(0.0, (sum, r) => sum + r.studyHours);
          final bestDay = routines.isEmpty ? null : routines.reduce((a, b) => a.productivityScore > b.productivityScore ? a : b);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // XP Level Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('Level $level: ${_levelTitle(level)}',
                        style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(160, 160),
                            painter: _XpArcPainter(progress: xpProgress),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$xp', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                              Text('$nextXp XP', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
                              Text('$level', style: GoogleFonts.inter(color: AppColors.blue.withValues(alpha: 0.3), fontSize: 48, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Next Reward: ${_nextReward(level)}',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Badges
              Text('Badges & Trophies', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _BadgeCard(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.warning,
                    name: '7 Day Streak',
                    earned: streak >= 7,
                    earnedText: 'Completed! • 100 XP',
                    progressText: '$streak/7 days',
                  ),
                  _BadgeCard(
                    icon: Icons.whatshot_rounded,
                    color: AppColors.error,
                    name: '30 Day Streak',
                    earned: streak >= 30,
                    earnedText: 'Completed! • 500 XP',
                    progressText: '$streak/30 days',
                  ),
                  _BadgeCard(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.blue,
                    name: '100 Hours Studied',
                    earned: totalStudyHours >= 100,
                    earnedText: 'Completed! • 1000 XP',
                    progressText: '${totalStudyHours.toInt()}/100 hrs',
                  ),
                  _BadgeCard(
                    icon: Icons.psychology_rounded,
                    color: AppColors.purple,
                    name: 'Deep Work Master',
                    earned: totalStudyHours >= 50,
                    earnedText: 'Completed! • 500 XP',
                    progressText: '${totalStudyHours.toInt()}/50 hrs',
                  ),
                  _BadgeCard(
                    icon: Icons.assignment_turned_in_rounded,
                    color: AppColors.success,
                    name: 'First Log',
                    earned: routines.isNotEmpty,
                    earnedText: 'Completed! • 50 XP',
                    progressText: '0/1 logs',
                  ),
                  const _BadgeCard(
                    icon: Icons.star_rounded,
                    color: AppColors.warning,
                    name: 'Perfect Week',
                    earned: false,
                    earnedText: 'Completed! • 200 XP',
                    progressText: '7 days ≥80 score',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Milestones
              Text('Milestones Timeline', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    if (routines.isNotEmpty)
                      _MilestoneTile(
                        date: routines.last.date,
                        icon: Icons.flag_rounded,
                        color: AppColors.success,
                        text: 'Started your productivity journey',
                      ),
                    if (streak >= 7)
                      const _MilestoneTile(date: '', icon: Icons.local_fire_department_rounded, color: AppColors.warning, text: 'Reached 7-day streak'),
                    if (totalStudyHours >= 10)
                      const _MilestoneTile(date: '', icon: Icons.menu_book_rounded, color: AppColors.blue, text: 'Completed 10 study hours'),
                    if (routines.isEmpty)
                      Center(child: Text('No milestones yet', style: GoogleFonts.inter(color: AppColors.textMuted))),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Personal Records
              Text('Personal Records', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 28),
                          const SizedBox(height: 6),
                          Text('Longest Streak', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                          Text('$streak Days', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppColors.blue, size: 28),
                          const SizedBox(height: 6),
                          Text('Most Productive Day', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                          Text(bestDay != null ? '${bestDay.date} (${bestDay.productivityScore}pts)' : 'N/A',
                              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _XpArcPainter extends CustomPainter {
  final double progress;
  _XpArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    final trackPaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..shader = const LinearGradient(colors: [AppColors.blue, AppColors.purple]).createShader(
          Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_XpArcPainter old) => old.progress != progress;
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final bool earned;
  final String earnedText;
  final String progressText;

  const _BadgeCard({
    required this.icon, required this.color, required this.name,
    required this.earned, required this.earnedText, required this.progressText,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: earned ? color.withValues(alpha: 0.2) : AppColors.textMuted.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: earned ? color : AppColors.textMuted.withValues(alpha: 0.3), size: 28),
              ),
              if (!earned)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: GoogleFonts.inter(
              color: earned ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(earned ? earnedText : progressText,
              style: GoogleFonts.inter(
                  color: earned ? AppColors.success : AppColors.textMuted,
                  fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  final String date;
  final IconData icon;
  final Color color;
  final String text;
  const _MilestoneTile({required this.date, required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(date.length >= 10 ? date.substring(5) : date,
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14))),
        ],
      ),
    );
  }
}
