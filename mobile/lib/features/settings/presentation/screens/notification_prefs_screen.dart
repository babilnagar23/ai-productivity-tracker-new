import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends ConsumerState<NotificationPrefsScreen> {
  bool _dailySummary = true;
  bool _eventReminders = true;
  bool _aiSuggestions = true;
  bool _streakWarning = true;
  int _reminderMinutes = 15;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await apiClient.dio.get(ApiEndpoints.calendarNotificationSettings);
      final body = response.data as Map<String, dynamic>;
      // Backend wraps fields under 'settings' key
      final data = body['settings'] as Map<String, dynamic>? ?? body;
      setState(() {
        _dailySummary = data['daily_summary'] as bool? ?? true;
        _eventReminders = data['event_reminders'] as bool? ?? true;
        _aiSuggestions = data['ai_suggestions'] as bool? ?? true;
        _reminderMinutes = data['event_reminders_minutes'] as int? ?? 15;
      });
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    setState(() => _streakWarning = prefs.getBool('streak_warning') ?? true);
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await apiClient.dio.patch(ApiEndpoints.calendarNotificationSettings, data: {
        'daily_summary': _dailySummary,
        'event_reminders': _eventReminders,
        'ai_suggestions': _aiSuggestions,
        'event_reminders_minutes': _reminderMinutes,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('streak_warning', _streakWarning);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Notification Preferences', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: Text('Save', style: GoogleFonts.inter(color: AppColors.blue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Daily Reminders'),
          _switchTile('Daily Summary', 'Get a daily productivity summary', _dailySummary, (v) => setState(() => _dailySummary = v)),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _reminderTime);
              if (picked != null) setState(() => _reminderTime = picked);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Reminder Time', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15))),
                  Text(_reminderTime.format(context), style: GoogleFonts.inter(color: AppColors.blue, fontSize: 14, fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _sectionHeader('Calendar Alerts'),
          _switchTile('Event Reminders', 'Get notified before events', _eventReminders, (v) => setState(() => _eventReminders = v)),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Minutes before', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15))),
                DropdownButton<int>(
                  value: _reminderMinutes,
                  dropdownColor: AppColors.card,
                  underline: const SizedBox.shrink(),
                  style: GoogleFonts.inter(color: AppColors.blue, fontSize: 14, fontWeight: FontWeight.w600),
                  items: [5, 10, 15, 30].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _reminderMinutes = v); },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionHeader('AI Insights'),
          _switchTile('AI Suggestions', 'Receive personalised AI tips', _aiSuggestions, (v) => setState(() => _aiSuggestions = v)),
          const SizedBox(height: 16),

          _sectionHeader('Streak'),
          _switchTile('Streak Warning', 'Alert when streak is at risk', _streakWarning, (v) => setState(() => _streakWarning = v)),
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

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15)),
                Text(subtitle, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.blue, activeTrackColor: AppColors.blue.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}
