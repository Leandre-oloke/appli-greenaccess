import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routes.dart';
import '../../ui/ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  double _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.savings_rounded,
      title: 'Finance verte pour l\'Afrique',
      body:
          'Micro-crédits et investissements verts adaptés à votre activité. Votre '
          'Score Climat ESG valide votre éligibilité et vos conditions.',
    ),
    _Slide(
      icon: Icons.school_rounded,
      title: 'Éducation climatique gamifiée',
      body:
          'Formations courtes sur la résilience, l\'agroforesterie, le solaire. '
          'Gagnez des badges certifiés et améliorez votre score.',
    ),
    _Slide(
      icon: Icons.shield_moon_rounded,
      title: 'Assurance climatique inclusive',
      body:
          'Protégez votre activité contre la sécheresse et l\'inondation. Indices '
          'paramétriques, déclenchement automatique, couverture pour petits producteurs.',
    ),
  ];

  int get _current => _page.round();

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_shown', true);
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _page = _ctrl.page ?? 0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final isLast = _current == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Parallax de l'image de fond
          Transform.scale(
            scale: 1.12,
            child: Transform.translate(
              offset: Offset(-_page * 24, 0),
              child: Image.asset('assets/images/onboarding_bg.jpg',
                  fit: BoxFit.cover),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 0.72, 1.0],
                colors: [
                  Color(0x22000000),
                  Color(0x55000000),
                  Color(0xCC0F1A14),
                  Color(0xF20F1A14),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text('Passer',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                  ),
                ),
                GaDotsIndicator(
                  count: _slides.length,
                  index: _current,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: GaSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: GaSpacing.xl),
                  child: GaPrimaryButton(
                    label: isLast ? 'Commencer' : 'Suivant',
                    icon: isLast ? Icons.arrow_forward_rounded : null,
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _ctrl.nextPage(
                          duration: GaMotion.slow,
                          curve: GaMotion.emphasized,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: GaSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.title, required this.body});
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final tokens = GaColors.of(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GaSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: tokens.forestBright.withValues(alpha: 0.22),
              borderRadius: GaRadii.brLg,
              border: Border.all(
                  color: tokens.forestBright.withValues(alpha: 0.65), width: 1.5),
            ),
            child: Icon(slide.icon, size: 38, color: Colors.white),
          ).animate().fadeIn(duration: GaMotion.base).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                curve: GaMotion.emphasized,
              ),
          const SizedBox(height: GaSpacing.lg),
          Text(
            slide.title,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(color: Colors.white, height: 1.2),
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: GaSpacing.md),
          Text(
            slide.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.55,
                ),
          ).animate().fadeIn(delay: 160.ms),
          const SizedBox(height: GaSpacing.xxl),
        ],
      ),
    );
  }
}
