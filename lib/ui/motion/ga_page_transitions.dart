import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transitions de page du design system, utilisées par `routes.dart`.
abstract final class GaPageTransitions {
  /// Fondu court — comportement historique (`_fadePage`), défaut partout.
  static CustomTransitionPage<void> fade(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 120),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  static CustomTransitionPage<void> _shared(
    GoRouterState state,
    Widget child,
    SharedAxisTransitionType type,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: type,
        fillColor: Colors.transparent,
        child: child,
      ),
    );
  }

  static CustomTransitionPage<void> sharedAxisH(
          GoRouterState s, Widget c) =>
      _shared(s, c, SharedAxisTransitionType.horizontal);

  static CustomTransitionPage<void> sharedAxisV(
          GoRouterState s, Widget c) =>
      _shared(s, c, SharedAxisTransitionType.vertical);

  static CustomTransitionPage<void> fadeThrough(GoRouterState s, Widget c) {
    return CustomTransitionPage<void>(
      key: s.pageKey,
      child: c,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Colors.transparent,
        child: child,
      ),
    );
  }
}
