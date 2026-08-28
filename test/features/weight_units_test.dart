import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/utils/weight_units.dart';

/// T-026 — the app stores each session in the unit it was logged in and never
/// rewrites it, so every cross-session comparison has to convert first.
void main() {
  test('leaves a value alone when the units match', () {
    expect(convertWeight(60, from: 'kg', to: 'kg'), 60);
    expect(convertWeight(135, from: 'lb', to: 'lb'), 135);
  });

  test('converts pounds to kilograms', () {
    expect(convertWeight(100, from: 'lb', to: 'kg'), closeTo(45.359237, 1e-9));
  });

  test('converts kilograms to pounds', () {
    expect(convertWeight(45.359237, from: 'kg', to: 'lb'), closeTo(100, 1e-9));
  });

  test('a round trip returns the original value', () {
    // Multiply one way and divide the other, rather than two separately
    // rounded constants — otherwise kg -> lb -> kg drifts.
    final there = convertWeight(82.5, from: 'kg', to: 'lb');
    expect(convertWeight(there, from: 'lb', to: 'kg'), closeTo(82.5, 1e-9));
  });

  test('passes an unrecognised unit through unchanged', () {
    // `weightUnit` is a free-text column with a 'kg' default, so a value we do
    // not know is possible. Guessing would corrupt the number; leaving it is
    // at worst as wrong as today.
    expect(convertWeight(60, from: 'stone', to: 'kg'), 60);
    expect(convertWeight(60, from: 'kg', to: 'stone'), 60);
  });
}
