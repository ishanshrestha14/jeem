/// "1:05", "0:09", "12:30" — always at least M:SS.
String mmss(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Trims trailing zeros: 80.0 -> "80", 77.5 -> "77.5".
String formatWeight(double? w) {
  if (w == null) return '';
  return w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();
}

/// null -> "—", 2.0 -> "2", 1.5 -> "1.5".
String formatRir(double? rir) => rir == null ? '—' : formatWeight(rir);

/// 45 -> "45s", 90 -> "1:30".
String formatDurationSeconds(int? seconds) {
  if (seconds == null) return '';
  if (seconds < 60) return '${seconds}s';
  return mmss(Duration(seconds: seconds));
}
