import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yut_flutter/main.dart';
import 'package:yut_flutter/domain/game_controller.dart';

void main() {
  testWidgets('Directly pump GameScreen and check for layout crashes', (WidgetTester tester) async {
    // Directly pump GameScreen wrapped in provider
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => GameController(isComputerPlaying: true),
          child: const Scaffold(body: GameScreen()),
        ),
      ),
    );

    // Pump to execute layout and rendering
    await tester.pump(const Duration(milliseconds: 500));

    // Assert that the start state text is displayed, confirming a successful build
    expect(find.text("Player 1's Turn"), findsOneWidget);
  });
}
