import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:me_app/core/services/theme_service.dart';
import 'package:me_app/features/mind/screens/mood_selection_screen.dart';

void main() {
  Widget buildTestApp() {
    return ChangeNotifierProvider<ThemeService>.value(
      value: ThemeService.instance,
      child: const MaterialApp(
        home: MoodSelectionScreen(),
      ),
    );
  }

  testWidgets('renders the fixed mood options for Mind Me', (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('Grateful'), findsOneWidget);
    expect(find.text('Focused'), findsOneWidget);
    expect(find.text('Anxious'), findsOneWidget);
    expect(find.text('Stressed'), findsOneWidget);
    expect(find.text('Sad'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('reveals the intensity slider after mood selection', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();

    expect(find.text('Mood intensity'), findsOneWidget);
    expect(find.text('5/10'), findsOneWidget);
  });

  testWidgets('reveals the custom mood input and requires text', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.scrollUntilVisible(
      find.text('Custom').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(find.text('Describe your mood...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Reflective');
    await tester.pumpAndSettle();

    expect(find.text('Mood intensity'), findsOneWidget);
  });
}
