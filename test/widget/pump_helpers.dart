import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/widgets/app_keypad.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';

/// Pumps frames until a Drift-backed StreamProvider has delivered its first
/// value. Never use pumpAndSettle() on these screens: their `loading:` branch
/// renders an indeterminate CircularProgressIndicator, which animates forever,
/// so pumpAndSettle blocks for its full 10-minute timeout and then fails.
///
/// [until]: pass a [Finder] for real expected content (e.g.
/// `find.text('Legs A')`) instead of relying on the default
/// spinner-is-gone check when the pump follows a `Navigator.push`/pop. The
/// default check races navigation: right after `tester.tap()` triggers a
/// push, the *old* screen is still on screen and has no
/// CircularProgressIndicator either, so the default condition can be
/// trivially (and wrongly) satisfied before the destination route has even
/// been built, let alone loaded its data. Waiting on real content sidesteps
/// that race entirely.
Future<void> pumpUntilData(
  WidgetTester tester, {
  Finder? until,
  int maxFrames = 40,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (until != null) {
      if (until.evaluate().isNotEmpty) return;
    } else if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }
}

/// Drift's [StreamQueryStore] schedules a zero-duration cleanup Timer when a
/// query stream is cancelled, which happens when the ProviderScope disposes
/// at the end of a test. flutter_test asserts no Timer is left pending once
/// the widget tree is torn down, so call this at the end of any test that
/// pumped a Drift-backed StreamProvider: it swaps in an empty widget (forcing
/// disposal now, while we can still pump) and pumps once more so the cleanup
/// Timer fires before the test framework's own teardown checks run.
///
/// [container]: pass the harness's `ProviderContainer` for any test that
/// mounts `ActiveSessionScreen` (Task 14 on). `restTickerProvider` is a
/// `StreamProvider.autoDispose` backed by an unbounded
/// `while (true) { await Future.delayed(500ms); yield ...; }` generator —
/// once a test has completed a set with a non-zero rest, `RestBar` watches
/// it and it's live for the rest of the test. Merely unmounting the widget
/// tree (the `pumpWidget(shrink)` above) does not retroactively cancel its
/// already-scheduled `Future.delayed` Timer: that Timer fires regardless,
/// and cancellation is only noticed by the generator at its next `yield`,
/// by which point it has often already re-armed a further Timer. Confirmed
/// by direct reproduction (see the Task 14 report): explicitly invalidating
/// the provider *and* pumping fake time well past its 500ms period is what
/// actually drains it; passing `container` opts into that. Omitting it is
/// safe for screens/tests that never touch `restTickerProvider` — invoking
/// `invalidate` on a provider that was never read is a no-op.
Future<void> disposeAndDrainTimers(
  WidgetTester tester, {
  ProviderContainer? container,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  if (container != null) {
    container.invalidate(restTickerProvider);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
  }
}

/// Mirror of [pumpUntilData] for a disappearance: pumps until [finder] matches
/// nothing, or gives up so the caller's own `expect` reports the failure with
/// a useful message rather than a bare timeout.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    if (finder.evaluate().isEmpty) return;
    await tester.pump(step);
  }
}

/// Taps [finder] after scrolling it into view.
///
/// Since T-012 the session list carries the Add exercises / More block below
/// the last card (S-006), so on the 800x600 test surface a set row is not
/// necessarily above the fold. A bare `tester.tap` on an off-screen widget
/// warns and misses rather than failing outright, which surfaces later as a
/// confusing assertion about state that never changed.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

/// Enters [value] into a set field the way a user now does: tap the field to
/// raise the in-app keypad, then tap its keys.
///
/// `tester.enterText` cannot be used on these fields any more — T-003 made
/// them `readOnly` so the OS keyboard stays down, and `enterText` drives the
/// platform text input, which a read-only field ignores.
Future<void> typeOnKeypad(
  WidgetTester tester,
  Finder field,
  String value,
) async {
  // Scrolled into view first: since T-012 the session list carries the
  // Add exercises / More block below the last card (S-006), so on the
  // 800x600 test surface a set field is not necessarily above the fold.
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.tap(field);
  await tester.pumpAndSettle();
  for (final character in value.split('')) {
    final key = find.descendant(
      of: find.byType(AppKeypad),
      matching: find.text(character),
    );
    expect(key, findsOneWidget, reason: 'keypad should offer "$character"');
    await tester.tap(key);
    await tester.pump();
  }
}
