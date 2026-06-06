import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../routines/data/repositories/routine_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _calendarConnected = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadCalendarStatus();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true);
  }

  Future<void> _loadCalendarStatus() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.calendarStatus);
      setState(() => _calendarConnected = response.data['connected'] as bool? ?? false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User header
          GestureDetector(
            onTap: () => context.push('/settings/profile'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.blue, AppColors.purple]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(user?.initials ?? '?',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? 'User',
                            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(user?.email ?? '',
                            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.blue),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Edit Profile', style: GoogleFonts.inter(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _sectionHeader('ACCOUNT'),
          _tile(Icons.person_outline_rounded, 'Edit Profile', () => context.push('/settings/profile')),
          _tile(Icons.emoji_events_outlined, 'Achievements', () => context.push('/settings/achievements')),
          _tile(Icons.notifications_outlined, 'Notification Preferences', () => context.push('/settings/notifications')),
          _tile(Icons.lock_outline_rounded, 'Change Password', () => context.push('/forgot-password')),
          const SizedBox(height: 16),

          _sectionHeader('APP'),
          _tile(Icons.tune_rounded, 'Habit & Metric Customisation', () => context.push('/daily-log/customize')),
          _tile(Icons.bar_chart_rounded, 'Analytics', () => context.push('/daily-log/analytics')),
          const SizedBox(height: 16),

          _sectionHeader('CONNECTED SERVICES'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, color: AppColors.blue, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Google Calendar', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15)),
                      Text(_calendarConnected ? 'Connected' : 'Not connected',
                          style: GoogleFonts.inter(color: _calendarConnected ? AppColors.success : AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _calendarConnected,
                  onChanged: (v) async {
                    if (v) {
                      try {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final response = await apiClient.dio.get(ApiEndpoints.calendarAuthUrl);
                        // Backend returns { authUrl: "..." }
                        final url = response.data['authUrl'] as String?
                            ?? response.data['auth_url'] as String?
                            ?? response.data['url'] as String?;
                        if (url != null) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Opening Google Calendar auth...')),
                          );
                        }
                      } catch (_) {}
                    }
                  },
                  activeThumbColor: AppColors.blue,
                  activeTrackColor: AppColors.blue.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionHeader('PREFERENCES'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.dark_mode_outlined, color: AppColors.textMuted, size: 22),
                      const SizedBox(width: 12),
                      // ignore: prefer_const_constructors
                      Expanded(child: Text('Dark Mode', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 15))),
                      const Switch(value: true, onChanged: null, activeThumbColor: AppColors.textMuted),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                // ignore: prefer_const_constructors
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Notifications', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15))),
                      Switch(
                        value: _notificationsEnabled,
                        onChanged: (v) async {
                          setState(() => _notificationsEnabled = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('notifications_enabled', v);
                        },
                        activeThumbColor: AppColors.blue,
                        activeTrackColor: AppColors.blue.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionHeader('SECURITY & ACCOUNT'),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showExportSheet(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.blue),
                foregroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text('Export Data', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Data', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _exportTile(ctx, Icons.upload_rounded, 'Export as PDF', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF export coming soon')))),
            _exportTile(ctx, Icons.table_chart_outlined, 'Export as CSV', () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final routines = await RoutineRepository().getRoutines();
              final buf = StringBuffer();
              buf.writeln('Date,Study,Exercise,Deep Work,Study Hrs,Mobile Hrs,Score');
              for (final r in routines) {
                buf.writeln('${r.date},${r.studyCompleted},${r.exerciseCompleted},${r.mlCompleted},${r.studyHours},${r.mobileUsage},${r.productivityScore}');
              }
              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('CSV ready to share')));
            }),
            _exportTile(ctx, Icons.description_outlined, 'Export as Word Table', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Word export coming soon')))),
          ],
        ),
      ),
    );
  }

  Widget _exportTile(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { Navigator.pop(ctx); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, color: AppColors.blue, size: 22),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15)),
        ]),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Logout', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Logout', style: GoogleFonts.inter(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }
}
