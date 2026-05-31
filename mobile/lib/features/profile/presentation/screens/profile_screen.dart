import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + info
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.purple.withValues(alpha: 0.3), blurRadius: 20),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user?.initials ?? '?',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatPill(
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.warning,
                      value: '${user?.streak ?? 0}',
                      label: 'Streak',
                    ),
                    const SizedBox(width: 12),
                    _StatPill(
                      icon: Icons.star_rounded,
                      color: AppColors.purple,
                      value: '${user?.xp ?? 0}',
                      label: 'XP',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Settings sections
          const _SectionHeader('App'),
          _SettingsTile(
            icon: Icons.bar_chart_rounded,
            label: 'Analytics',
            onTap: () => context.go('/analytics'),
          ),
          _SettingsTile(
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            onTap: () => context.go('/calendar'),
          ),
          const SizedBox(height: 16),

          const _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            label: 'Change Password',
            onTap: () => context.push('/forgot-password'),
          ),
          const SizedBox(height: 16),

          const _SectionHeader('About'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Version 1.0.0',
            onTap: null,
            trailing: Text('1.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(height: 32),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Logout', style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text(
                      'Are you sure you want to log out?',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Logout', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authStateProvider.notifier).logout();
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            ),
            trailing ?? (onTap != null
                ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18)
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatPill({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
