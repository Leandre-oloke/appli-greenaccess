import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/connectivity_banner.dart';
import '../../ui/theme/ga_theme_extensions.dart';

/// Coquille de navigation principale (5 onglets).
///
/// Utilise `NavigationBar` (Material 3) plutôt que l'ancien
/// `BottomNavigationBar` : le thème du design system (`AppTheme.
/// navigationBarTheme`) est déjà entièrement défini sur les tokens
/// (surface/indicateur/typo) mais n'était jusqu'ici jamais consommé — les
/// couleurs venaient d'`AppColors` codées en dur ici. Aucun changement de
/// route : `navigationShell.goBranch(...)` est strictement identique.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: 'Formation',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_outlined),
      selectedIcon: Icon(Icons.account_balance),
      label: 'Financement',
    ),
    NavigationDestination(
      icon: Icon(Icons.shield_outlined),
      selectedIcon: Icon(Icons.shield),
      label: 'Assurance',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ConnectivityBanner(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(boxShadow: context.gaShadows.e1),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              // Si on tape l'onglet déjà actif → retour à l'écran racine de la branche
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: _destinations,
          ),
        ),
      ),
    );
  }
}
