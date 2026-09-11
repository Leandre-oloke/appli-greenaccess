import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenaccess/core/providers/prefs_provider.dart';
import 'package:greenaccess/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/firebase_test_setup.dart';

void main() {
  setUpAll(() async {
    // GreenAccessApp construit authViewModelProvider (donc AuthRepository, qui
    // accède à FirebaseAuth.instance / FirebaseFirestore.instance) dès son
    // premier build — il faut un Firebase Core initialisé, même factice.
    await setupFirebaseForTests();
  });

  testWidgets('GreenAccessApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const GreenAccessApp(),
    ));

    expect(tester.takeException(), isNull);
  });
}
