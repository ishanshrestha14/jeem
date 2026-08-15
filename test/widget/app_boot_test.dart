import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/app/app.dart';
import 'package:gymflow/core/theme/semantic_colors.dart';

void main() {
  testWidgets('app boots into a dark theme and shows the Workouts title',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GymFlowApp()));
    await tester.pumpAndSettle();

    expect(find.text('Workouts'), findsOneWidget);

    final context = tester.element(find.text('Workouts'));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<SemanticColors>(), isNotNull);
  });
}
