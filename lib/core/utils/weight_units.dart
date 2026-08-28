/// T-026 — weight-unit conversion, applied at read time only.
///
/// A session records the unit it was logged in and keeps it forever: that is
/// the true record of what happened, and rewriting history to one unit would
/// destroy it. What converts is every *comparison or aggregation across
/// sessions* — records, `Previous`, and weekly volume — on the way out.
library;

/// Exact by definition (international avoirdupois pound).
const double kgPerPound = 0.45359237;

/// [value], expressed in [from], restated in [to].
///
/// Multiplies one way and divides the other rather than carrying two rounded
/// constants, so a kg -> lb -> kg round trip returns what it started with.
///
/// An unrecognised unit passes the value through unchanged. `weightUnit` is a
/// free-text column defaulting to `'kg'`, so an unknown value is reachable;
/// guessing at it would corrupt the number, whereas passing it through is at
/// worst exactly as wrong as the behaviour this ticket replaces.
double convertWeight(double value, {required String from, required String to}) {
  if (from == to) return value;
  if (from == 'lb' && to == 'kg') return value * kgPerPound;
  if (from == 'kg' && to == 'lb') return value / kgPerPound;
  return value;
}
