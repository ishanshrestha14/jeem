import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until a Drift-backed StreamProvider has delivered its first
/// value. Never use pumpAndSettle() on these screens: their `loading:` branch
/// renders an indeterminate CircularProgressIndicator, which animates forever,
/// so pumpAndSettle blocks for its full 10-minute timeout and then fails.
Future<void> pumpUntilData(WidgetTester tester, {int maxFrames = 40}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

/// Drift's [StreamQueryStore] schedules a zero-duration cleanup Timer when a
/// query stream is cancelled, which happens when the ProviderScope disposes
/// at the end of a test. flutter_test asserts no Timer is left pending once
/// the widget tree is torn down, so call this at the end of any test that
/// pumped a Drift-backed StreamProvider: it swaps in an empty widget (forcing
/// disposal now, while we can still pump) and pumps once more so the cleanup
/// Timer fires before the test framework's own teardown checks run.
Future<void> disposeAndDrainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
