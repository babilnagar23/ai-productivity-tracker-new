import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _Tab(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
    _Tab(icon: Icons.checklist_rounded, label: 'Routines', path: '/routines'),
    _Tab(icon: Icons.auto_awesome_rounded, label: 'AI', path: '/ai'),
    _Tab(icon: Icons.bar_chart_rounded, label: 'Analytics', path: '/analytics'),
    _Tab(icon: Icons.calendar_month_rounded, label: 'Calendar', path: '/calendar'),
  ];

  int _indexFromLocation(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => context.go(_tabs[index].path),
          items: _tabs.map((tab) => BottomNavigationBarItem(
            icon: Icon(tab.icon),
            label: tab.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String path;
  const _Tab({required this.icon, required this.label, required this.path});
}
