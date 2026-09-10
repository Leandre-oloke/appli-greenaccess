import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  int _tabIndex(String path) {
    if (path.startsWith(AppRoutes.adminFormations))  return 1;
    if (path.startsWith(AppRoutes.adminUsers))       return 2;
    if (path.startsWith(AppRoutes.adminDemandes))    return 3;
    if (path.startsWith(AppRoutes.adminContrats))    return 4;
    if (path.startsWith(AppRoutes.adminPartenaires)) return 5;
    if (path.startsWith(AppRoutes.adminAnalytics))   return 6;
    if (path.startsWith(AppRoutes.adminSettings))    return 7;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(AppRoutes.adminDashboard);
      case 1: context.go(AppRoutes.adminFormations);
      case 2: context.go(AppRoutes.adminUsers);
      case 3: context.go(AppRoutes.adminDemandes);
      case 4: context.go(AppRoutes.adminContrats);
      case 5: context.go(AppRoutes.adminPartenaires);
      case 6: context.go(AppRoutes.adminAnalytics);
      case 7: context.go(AppRoutes.adminSettings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex(path),
        onTap: (i) => _onTap(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Colors.white,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),    activeIcon: Icon(Icons.dashboard),    label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.school_outlined),       activeIcon: Icon(Icons.school),       label: 'Formations'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outlined),       activeIcon: Icon(Icons.people),       label: 'Utilisateurs'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined),   activeIcon: Icon(Icons.assignment),   label: 'Demandes'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined),       activeIcon: Icon(Icons.shield),       label: 'Contrats'),
          BottomNavigationBarItem(icon: Icon(Icons.handshake_outlined),    activeIcon: Icon(Icons.handshake),    label: 'Partenaires'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),    activeIcon: Icon(Icons.bar_chart),    label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined),     activeIcon: Icon(Icons.settings),     label: 'Réglages'),
        ],
      ),
    );
  }
}
