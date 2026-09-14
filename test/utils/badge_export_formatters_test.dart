// Tests unitaires des formateurs d'export de badges (J5.16, CDC §5) —
// fonctions pures (aucun accès Firestore), même esprit que
// export_formatters_test.dart (J3.5) pour l'export RGPD.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/badge_model.dart';
import 'package:greenaccess/utils/badge_export_formatters.dart';

List<BadgeModel> _badges() => [
      BadgeModel(
        id: 'assure_climat',
        nom: 'Assuré Climat',
        description: 'Vous avez souscrit à votre première assurance climatique.',
        imageUrl: '',
        type: 'assurance',
        dateObtention: DateTime(2025, 3, 12),
        openbadgeUrl: 'https://badges.greenaccess.test/assertions/alice-assure_climat',
      ),
      BadgeModel(
        id: 'cours_x',
        nom: 'Expert Vert — cours_x',
        description: 'Quiz réussi à 100%.',
        imageUrl: '',
        type: 'formation',
        dateObtention: DateTime(2025, 2, 1),
      ),
      // Badge non obtenu (verrouillé) : ne doit apparaître dans aucun export.
      const BadgeModel(
        id: 'finance_vert',
        nom: 'Financé Vert',
        description: 'Votre demande a été approuvée.',
        imageUrl: '',
        type: 'financement',
      ),
    ];

void main() {
  group('buildBadgesJson', () {
    test('inclut uniquement les badges obtenus, avec openbadge_url quand disponible', () {
      final json = jsonDecode(buildBadgesJson(_badges())) as Map<String, dynamic>;
      final badges = json['badges'] as List;

      expect(badges, hasLength(2));
      final assureClimat = badges.firstWhere((b) => b['id'] == 'assure_climat');
      expect(assureClimat['nom'], 'Assuré Climat');
      expect(assureClimat['openbadge_url'],
          'https://badges.greenaccess.test/assertions/alice-assure_climat');
      expect(badges.any((b) => b['id'] == 'finance_vert'), isFalse);
    });

    test('liste vide sans badge obtenu (pas d\'erreur)', () {
      final json = jsonDecode(buildBadgesJson(const [])) as Map<String, dynamic>;
      expect(json['badges'], isEmpty);
    });
  });

  group('buildBadgesPdf', () {
    test('produit un PDF non vide avec l\'en-tête standard %PDF-', () async {
      final bytes = await buildBadgesPdf(_badges());
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('reste valide même sans aucun badge obtenu', () async {
      final bytes = await buildBadgesPdf(const []);
      expect(bytes, isNotEmpty);
    });
  });
}
