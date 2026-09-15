// Tests widgets des composants du design system ajoutés pour la refonte
// frontend (Phase 3, étape « Design System ») : GaListTile, GaStatusTimeline,
// GaFilterBar, GaFormCard, GaErrorView.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/ui/ui.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('GaListTile', () {
    testWidgets('affiche titre, sous-titre et déclenche onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(GaListTile(
        title: 'Gérer les formations',
        subtitle: 'Ajouter, modifier, supprimer des cours',
        leadingIcon: Icons.school_outlined,
        onTap: () => tapped = true,
      )));

      expect(find.text('Gérer les formations'), findsOneWidget);
      expect(find.text('Ajouter, modifier, supprimer des cours'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(GaListTile));
      expect(tapped, isTrue);
    });

    testWidgets('sans onTap, pas de chevron trailing par défaut', (tester) async {
      await tester.pumpWidget(_wrap(const GaListTile(title: 'Info')));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('GaStatusTimeline', () {
    testWidgets('affiche toutes les étapes avec leurs libellés', (tester) async {
      await tester.pumpWidget(_wrap(const GaStatusTimeline(steps: [
        GaTimelineStep(label: 'Soumis', state: GaTimelineStepState.done),
        GaTimelineStep(label: 'En examen', state: GaTimelineStepState.current),
        GaTimelineStep(label: 'Décision', state: GaTimelineStepState.pending),
      ])));

      expect(find.text('Soumis'), findsOneWidget);
      expect(find.text('En examen'), findsOneWidget);
      expect(find.text('Décision'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('GaFilterBar', () {
    testWidgets('champ de recherche déclenche onChanged', (tester) async {
      String? lastValue;
      await tester.pumpWidget(_wrap(GaFilterBar(
        onChanged: (v) => lastValue = v,
      )));

      await tester.enterText(find.byType(TextField), 'compost');
      expect(lastValue, 'compost');
    });

    testWidgets('chips de filtre déclenchent onFilterSelected', (tester) async {
      String? selected;
      await tester.pumpWidget(_wrap(GaFilterBar(
        filters: const ['Tous', 'Agriculture', 'Énergie'],
        selectedFilter: 'Tous',
        onFilterSelected: (v) => selected = v,
      )));

      expect(find.text('Agriculture'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Énergie'));
      expect(selected, 'Énergie');
    });

    testWidgets('sans filtres, aucun ChoiceChip rendu', (tester) async {
      await tester.pumpWidget(_wrap(const GaFilterBar()));
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('GaFormCard', () {
    testWidgets('affiche le titre et les champs enfants espacés', (tester) async {
      await tester.pumpWidget(_wrap(const GaFormCard(
        title: 'Votre activité',
        children: [Text('Champ 1'), Text('Champ 2')],
      )));

      expect(find.text('Votre activité'), findsOneWidget);
      expect(find.text('Champ 1'), findsOneWidget);
      expect(find.text('Champ 2'), findsOneWidget);
    });
  });

  group('GaErrorView', () {
    testWidgets('traduit une FirebaseAuthException et affiche Réessayer', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(GaErrorView(
        error: Exception('boom'),
        onRetry: () => retried = true,
      )));

      expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(retried, isTrue);
    });

    testWidgets('sans onRetry, pas de bouton affiché', (tester) async {
      await tester.pumpWidget(_wrap(GaErrorView(error: Exception('boom'))));
      expect(find.text('Réessayer'), findsNothing);
    });
  });
}
