import 'package:flutter_test/flutter_test.dart';
import 'package:yut_flutter/main.dart';

void main() {
  testWidgets('Smoke test: verify start game button is present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const YutApp());

    // Verify that our title screen contains the Start Game button.
    expect(find.text('START GAME'), findsOneWidget);
  });
}
