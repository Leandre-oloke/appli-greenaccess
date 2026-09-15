import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenaccess/ui/ui.dart';

/// Smoke test du thème (design system « Organic Fintech »).
///
/// L'ancien smoke test pompait `GreenAccessApp` en entier : dès le premier
/// `build()`, `routerProvider` construit `authViewModelProvider` (donc
/// `AuthRepository`, qui touche `FirebaseAuth.instance`/`FirebaseFirestore
/// .instance`) et `GreenAccessApp.initState` démarre l'écoute FCM
/// (`FirebaseMessaging.onMessage`) — trois plugins Firebase réels. Les mocker
/// proprement en test VM (canaux Pigeon, spécifiques à chaque version de
/// `firebase_core`/`firebase_auth`/`firebase_messaging`) est fragile et hors
/// de la portée d'un test unitaire ; un boot complet de l'app avec Firebase
/// réel relève d'un test `integration_test` sur device/émulateur.
///
/// Ce test couvre à la place ce qui est déterministe et propre à ce dépôt :
/// que `AppTheme` (clair et sombre) se construit et se rend sans exception.
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('AppTheme.${brightness.name} se rend sans exception',
        (WidgetTester tester) async {
      final theme = brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          appBar: const GaAppBar(title: 'GreenAccess'),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GaCard(child: const Text('Design system')),
                const SizedBox(height: GaSpacing.md),
                GaPrimaryButton(label: 'Continuer', onPressed: () {}),
                const SizedBox(height: GaSpacing.md),
                const GaScoreGauge(score: 72, animate: false),
              ],
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('GreenAccess'), findsOneWidget);
    });
  }
}
