import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_app/features/mind/screens/mood_selection_screen.dart';

void main() {
  testWidgets('renders the fixed mood options for Mind Me', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MoodSelectionScreen(),
      ),
    );

    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('Anxious'), findsOneWidget);
    expect(find.text('Tired'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('reveals the intensity slider after mood selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MoodSelectionScreen(),
      ),
    );

    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();

    expect(find.text('Mood intensity'), findsOneWidget);
    expect(find.text('5/10'), findsOneWidget);
  });
}
