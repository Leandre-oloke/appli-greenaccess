import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Bannière animée qui s'affiche en bas de l'écran quand l'appareil est hors-ligne.
/// À insérer comme overlay dans le Shell principal.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _isOffline = false;
  late final AnimationController _anim;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    // Vérifie l'état initial
    Connectivity().checkConnectivity().then(_handleResult);

    // Écoute les changements
    _sub = Connectivity().onConnectivityChanged.listen(_handleResult);
  }

  void _handleResult(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        (results.length == 1 && results.first == ConnectivityResult.none);
    if (offline != _isOffline) {
      setState(() => _isOffline = offline);
      if (offline) {
        _anim.forward();
      } else {
        _anim.reverse();
      }
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slide,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, -2)),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Hors-ligne — les données affichées peuvent être obsolètes',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
