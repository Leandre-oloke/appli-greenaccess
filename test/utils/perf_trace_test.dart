// Tests unitaires de tracedOperation (J6.6, CDC §7.1 · T10) — best-effort :
// sans Firebase initialisé (le cas de tous les tests de ce dépôt),
// FirebasePerformance.instance lève à la construction de la trace ; ce test
// vérifie que ce cas est bien absorbé et que l'opération elle-même
// s'exécute et propage son résultat/ses erreurs normalement.
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/utils/perf_trace.dart';

void main() {
  test('exécute et renvoie le résultat de l\'opération même sans Firebase initialisé', () async {
    final result = await tracedOperation('test_trace', () async => 42);
    expect(result, 42);
  });

  test('propage l\'exception de l\'opération plutôt que de l\'avaler', () async {
    await expectLater(
      tracedOperation('test_trace', () async => throw Exception('échec attendu')),
      throwsException,
    );
  });
}
