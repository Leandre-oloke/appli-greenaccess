import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greenaccess/main.dart';

void main() {
  testWidgets('GreenAccessApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GreenAccessApp()));
    expect(tester.takeException(), isNull);
  });
}
