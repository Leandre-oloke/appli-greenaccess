// Tests unitaires de CoursRepository — jusqu'ici uniquement exercée
// indirectement via des fakes dans formation_viewmodel_test.dart. Couvre ici
// les déclencheurs de badges liés à d'autres modules (Assurance, J5.13 ;
// Financement, J5.15), les deux suivant le même pattern idempotent.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/cours_repository.dart';

void main() {
  group('CoursRepository — triggerFinanceVertBadge (J5.15)', () {
    test('délivre le badge Financé Vert', () async {
      final db = FakeFirebaseFirestore();
      final repo = CoursRepository(firestore: db);

      await repo.triggerFinanceVertBadge('alice');

      final badgeSnap =
          await db.collection('users').doc('alice').collection('badges').doc('finance_vert').get();
      expect(badgeSnap.exists, isTrue);
      expect(badgeSnap.data()?['type'], 'financement');
      expect(badgeSnap.data()?['nom'], contains('Financé Vert'));
      expect(badgeSnap.data()?['date_obtention'], isNotNull);
    });

    test('un second déclenchement ne recrée pas le badge (idempotent)', () async {
      final db = FakeFirebaseFirestore();
      final repo = CoursRepository(firestore: db);

      await repo.triggerFinanceVertBadge('bob');
      await repo.triggerFinanceVertBadge('bob');

      final badgesSnap = await db.collection('users').doc('bob').collection('badges').get();
      expect(badgesSnap.docs, hasLength(1));
    });
  });

  group('CoursRepository — triggerAssureClimatBadge (J5.13)', () {
    test('délivre le badge Assuré Climat', () async {
      final db = FakeFirebaseFirestore();
      final repo = CoursRepository(firestore: db);

      await repo.triggerAssureClimatBadge('carol');

      final badgeSnap =
          await db.collection('users').doc('carol').collection('badges').doc('assure_climat').get();
      expect(badgeSnap.exists, isTrue);
      expect(badgeSnap.data()?['type'], 'assurance');
    });
  });
}
