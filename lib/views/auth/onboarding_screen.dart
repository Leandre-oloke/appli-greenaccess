import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.account_balance_outlined,
      accentColor: Color(0xFF2D7D46),
      title: 'Finance verte pour l\'Afrique',
      body: 'Accédez à des micro-crédits et investissements verts adaptés à votre activité. '
          'Score Climat ESG pour valider votre éligibilité et obtenir les meilleures conditions.',
    ),
    _Slide(
      icon: Icons.school_outlined,
      accentColor: Color(0xFF1565C0),
      title: 'Éducation climatique gamifiée',
      body: 'Suivez des formations courtes sur la résilience climatique, '
          'l\'agroforesterie, l\'énergie solaire. Gagnez des badges certifiés OpenBadge et '
          'améliorez votre score ESG.',
    ),
    _Slide(
      icon: Icons.shield_outlined,
      accentColor: Color(0xFF6A1B9A),
      title: 'Assurance climatique inclusive',
      body: 'Protégez votre activité contre les aléas climatiques (sécheresse, inondation). '
          'Indices paramétriques, déclenchement automatique, couverture adaptée '
          'aux petits producteurs d\'Afrique de l\'Ouest.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_shown', true);
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Barre de statut transparente pour laisser l'image remonter sous la notch.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Arrière-plan : image commune aux 3 slides ──────────────────────
          Image.asset(
            'assets/images/onboarding_bg.jpg',
            fit: BoxFit.cover,
          ),

          // ── Overlay dégradé : renforce la lisibilité du contenu en bas ────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Color(0x33000000), // légèrement sombre en haut
                  Color(0x55000000),
                  Color(0xBB000000), // plus dense au milieu-bas
                  Color(0xF0000000), // presque opaque tout en bas
                ],
              ),
            ),
          ),

          // ── Contenu ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Bouton Passer
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Passer',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Slides
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                  ),
                ),

                // Points de pagination
                _Dots(count: _slides.length, current: _page),
                const SizedBox(height: 28),

                // Bouton principal
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_page < _slides.length - 1) {
                        _ctrl.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finish();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _slides[_page].accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _page == _slides.length - 1 ? 'Commencer' : 'Suivant',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
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
  final Color accentColor;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.body,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône avec halo coloré
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: slide.accentColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: slide.accentColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Icon(slide.icon, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 20),

          // Titre
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),

          // Corps
          Text(
            slide.body,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.80),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == current ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == current ? Colors.white : Colors.white30,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
