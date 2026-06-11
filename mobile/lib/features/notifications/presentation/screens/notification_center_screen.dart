import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_helper.dart';

class _AppNotification {
  final String id;
  final String category;
  final String title;
  final String body;
  final DateTime time;
  bool read;

  _AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'category': category, 'title': title,
    'body': body, 'time': time.toIso8601String(), 'read': read,
  };

  factory _AppNotification.fromJson(Map<String, dynamic> j) => _AppNotification(
    id: j['localId'] as String? ?? j['client_uuid'] as String? ?? '',
    category: j['type'] as String? ?? 'system',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    time: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : DateTime.now(),
    read: j['readAt'] != null,
  );
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<_AppNotification> _notifications = [];
  int _selectedTab = 0;
  final _tabs = ['All', 'Reminders', 'AI Insights', 'Streak', 'Achievements'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final dbHelper = DatabaseHelper();
    final rows = await dbHelper.query('notifications_cache', orderBy: 'createdAt DESC');
    setState(() {
      _notifications = rows.map((e) => _AppNotification.fromJson(e)).toList();
    });
  }

  Future<void> _saveNotifications() async {
    // In a full implementation, you'd mark read/dismissed in SQLite and trigger sync.
    // For now we'll just update SQLite locally.
    final dbHelper = DatabaseHelper();
    for (final n in _notifications) {
      if (n.read) {
        await dbHelper.update('notifications_cache', {'readAt': DateTime.now().toIso8601String()}, 'localId = ?', [n.id]);
      }
    }
  }

  List<_AppNotification> get _filtered {
    if (_selectedTab == 0) return _notifications;
    final cats = ['', 'reminder', 'ai_insight', 'streak', 'achievement'];
    return _notifications.where((n) => n.category == cats[_selectedTab]).toList();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'reminder': return AppColors.warning;
      case 'ai_insight': return AppColors.purple;
      case 'streak': return const Color(0xFFF97316);
      case 'achievement': return AppColors.success;
      default: return AppColors.blue;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'reminder': return Icons.alarm_rounded;
      case 'ai_insight': return Icons.psychology_outlined;
      case 'streak': return Icons.local_fire_department_rounded;
      case 'achievement': return Icons.emoji_events_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter tabs
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = _selectedTab == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.blue : AppColors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: sel ? AppColors.blue : AppColors.border),
                    ),
                    child: Text(_tabs[i], style: GoogleFonts.inter(
                      color: sel ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_outlined, size: 56, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text('All caught up!', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                        Text('No notifications.', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = filtered[i];
                      return Dismissible(
                        key: Key(n.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) async {
                          setState(() => _notifications.removeWhere((x) => x.id == n.id));
                          await DatabaseHelper().delete('notifications_cache', 'localId = ?', [n.id]);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => n.read = true);
                            _saveNotifications();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _categoryColor(n.category).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_categoryIcon(n.category), color: _categoryColor(n.category), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.title, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(n.body, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(_timeAgo(n.time), style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                if (!n.read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
