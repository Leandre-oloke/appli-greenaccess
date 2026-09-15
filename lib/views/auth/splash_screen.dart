import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/prefs_provider.dart';
import '../../routes.dart';
import '../../ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final isAuth = ref.read(authViewModelProvider).isAuthenticated;
    if (isAuth) {
      context.go(AppRoutes.dashboard);
      return;
    }
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getBool('onboarding_shown') ?? false;
    context.go(seen ? AppRoutes.login : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tokens = GaColors.of(brightness);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: GaGradients.of(brightness).header),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'brand-mark',
                child: Container(
                  padding: const EdgeInsets.all(GaSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.eco_rounded, size: 72, color: Colors.white),
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    duration: GaMotion.expressive,
                    curve: GaMotion.emphasized,
                  )
                  .fadeIn(duration: GaMotion.slow)
                  .shimmer(
                    delay: GaMotion.slow,
                    duration: 1200.ms,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
              const SizedBox(height: GaSpacing.xl),
              Text(
                'GreenAccess',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: GaMotion.slow)
                  .slideY(begin: 0.4, end: 0, curve: GaMotion.standard),
              const SizedBox(height: GaSpacing.xs),
              Text(
                'Finance verte · Climat · Assurance',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ).animate().fadeIn(delay: 420.ms, duration: GaMotion.slow),
              const SizedBox(height: GaSpacing.xxxl),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(tokens.forestBright),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
