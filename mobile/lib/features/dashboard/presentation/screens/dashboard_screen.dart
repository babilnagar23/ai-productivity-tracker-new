import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../routines/data/models/routine_model.dart';
import '../../../routines/data/repositories/routine_repository.dart';
import '../../../../shared/widgets/gradient_card.dart';

final todayRoutineProvider = FutureProvider<RoutineModel?>((ref) async {
  final repo = RoutineRepository();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final routines = await repo.getRoutines();
  try {
    return routines.firstWhere((r) => r.date == today);
  } catch (_) {
    return null;
  }
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.user;
    final todayAsync = ref.watch(todayRoutineProvider);
    final now = DateTime.now();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todayRoutineProvider),
        color: AppColors.purple,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: AppColors.surface,
              pinned: true,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        user?.initials ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${user?.displayName ?? 'User'} 👋',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(now),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_outline_rounded),
                  onPressed: () => context.push('/profile'),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Streak + XP row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppColors.warning,
                          value: '${user?.streak ?? 0}',
                          label: 'Day Streak',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.star_rounded,
                          iconColor: AppColors.purple,
                          value: '${user?.xp ?? 0}',
                          label: 'Total XP',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Today's productivity card
                  todayAsync.when(
                    loading: () => const _LoadingCard(),
                    error: (_, __) => const _ErrorCard(),
                    data: (routine) => _TodayCard(routine: routine),
                  ),
                  const SizedBox(height: 16),

                  // Quick actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _QuickAction(
                        icon: Icons.add_task_rounded,
                        label: 'Log Today',
                        color: AppColors.purple,
                        onTap: () => context.push('/routines/add'),
                      ),
                      _QuickAction(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Ask AI',
                        color: AppColors.blue,
                        onTap: () => context.go('/ai'),
                      ),
                      _QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: 'Analytics',
                        color: AppColors.cyan,
                        onTap: () => context.go('/analytics'),
                      ),
                      _QuickAction(
                        icon: Icons.calendar_month_rounded,
                        label: 'Calendar',
                        color: AppColors.success,
                        onTap: () => context.go('/calendar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Recent routines header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Logs',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/routines'),
                        child: const Text('View all', style: TextStyle(color: AppColors.purple, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  todayAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (routine) => routine != null
                        ? _RecentLogTile(routine: routine)
                        : Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
                                SizedBox(width: 10),
                                Text(
                                  'No log for today yet. Tap "Log Today" above.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final RoutineModel? routine;
  const _TodayCard({this.routine});

  @override
  Widget build(BuildContext context) {
    if (routine == null) {
      return GradientCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Today\'s Progress', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'No entry yet',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('Log your day to track progress', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/routines/add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.purple,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Log Today', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Today\'s Progress', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${routine!.productivityScore}',
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('/100', style: TextStyle(color: Colors.white60, fontSize: 18)),
              ),
            ],
          ),
          const Text('Productivity Score', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: routine!.productivityScore / 100,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _CheckBadge(done: routine!.studyCompleted, label: 'Study'),
              const SizedBox(width: 8),
              _CheckBadge(done: routine!.exerciseCompleted, label: 'Exercise'),
              const SizedBox(width: 8),
              _CheckBadge(done: routine!.mlCompleted, label: 'ML'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  final bool done;
  final String label;
  const _CheckBadge({required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done ? Colors.white24 : Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RecentLogTile extends StatelessWidget {
  final RoutineModel routine;
  const _RecentLogTile({required this.routine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.checklist_rounded, color: AppColors.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score: ${routine.productivityScore}/100',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                Text(
                  routine.date,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${routine.studyHours}h study',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator(color: AppColors.purple)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: Text('Could not load today\'s data', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
