import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/utils/formatting.dart';

/// S-030's "Last performed: 2 days ago". Calendar days apart, not elapsed
/// hours — a session at 11pm last night is "Yesterday" at 1am, which is how
/// anyone reading it would describe it.
void main() {
  final now = DateTime(2026, 8, 25, 13, 0);

  test('today', () {
    expect(relativeDay(DateTime(2026, 8, 25, 1, 0), now: now), 'Today');
  });

  test('last night reads as yesterday even a few hours later', () {
    expect(relativeDay(DateTime(2026, 8, 24, 23, 30), now: now), 'Yesterday');
  });

  test('two days ago', () {
    expect(relativeDay(DateTime(2026, 8, 23, 1, 55), now: now), '2 days ago');
  });

  test('within the last month counts days', () {
    expect(relativeDay(DateTime(2026, 7, 27), now: now), '29 days ago');
  });

  test('older than a month falls back to the date', () {
    expect(relativeDay(DateTime(2026, 5, 2), now: now), '2 May 2026');
  });

  test('a future date reads as today rather than negative days', () {
    // Clock skew or an edited session should never render "-1 days ago".
    expect(relativeDay(DateTime(2026, 8, 26), now: now), 'Today');
  });
}
