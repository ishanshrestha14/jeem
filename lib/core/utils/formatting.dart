import '../../db/tables.dart';

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

/// "Today", "Yesterday", "2 days ago", or the date itself past a month.
///
/// Compares **calendar days**, not elapsed hours: a session logged at 11pm
/// last night should read "Yesterday" at 1am, which is how anyone describing
/// it would say it. A date in the future (clock skew, an edited session)
/// clamps to "Today" rather than rendering negative days.
String relativeDay(DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final a = DateTime(today.year, today.month, today.day);
  final b = DateTime(when.year, when.month, when.day);
  final days = a.difference(b).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days <= 30) return '$days days ago';
  return '${when.day} ${_months[when.month - 1]} ${when.year}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The reps half of a set prescription, as a set row hints it: `8`, `8-10`,
/// or null when nothing was planned. Null rather than `''` so a caller can
/// hand it straight to `hintText`, where an empty string would still reserve
/// a (blank) hint.
String? formatPlannedReps(int? reps, int? repsMax) {
  if (reps == null) return null;
  return repsMax == null ? '$reps' : '$reps-$repsMax';
}

/// null -> "—", 2.0 -> "2", 1.5 -> "1.5".
String formatRir(double? rir) => rir == null ? '—' : formatWeight(rir);

/// 45 -> "45s", 90 -> "1:30".
String formatDurationSeconds(int? seconds) {
  if (seconds == null) return '';
  if (seconds < 60) return '${seconds}s';
  return mmss(Duration(seconds: seconds));
}

/// Human labels for [Muscle]. Written out rather than derived from the enum
/// name so multi-word values read properly ("Front delts", not "deltsFront")
/// and so renaming an enum value can never silently change UI copy.
String muscleLabel(Muscle m) => switch (m) {
      Muscle.chest => 'Chest',
      Muscle.lats => 'Lats',
      Muscle.upperBack => 'Upper back',
      Muscle.lowerBack => 'Lower back',
      Muscle.deltsFront => 'Front delts',
      Muscle.deltsSide => 'Side delts',
      Muscle.deltsRear => 'Rear delts',
      Muscle.biceps => 'Biceps',
      Muscle.triceps => 'Triceps',
      Muscle.forearms => 'Forearms',
      Muscle.abs => 'Abs',
      Muscle.obliques => 'Obliques',
      Muscle.quadriceps => 'Quadriceps',
      Muscle.hamstrings => 'Hamstrings',
      Muscle.glutes => 'Glutes',
      Muscle.hipFlexors => 'Hip flexors',
      Muscle.adductors => 'Adductors',
      Muscle.calves => 'Calves',
      Muscle.neck => 'Neck',
      Muscle.cardio => 'Cardio',
    };

String equipmentLabel(Equipment e) => switch (e) {
      Equipment.barbell => 'Barbell',
      Equipment.dumbbell => 'Dumbbell',
      Equipment.cable => 'Cable',
      Equipment.machine => 'Machine',
      Equipment.bodyweight => 'Bodyweight',
      Equipment.band => 'Band',
      Equipment.other => 'Other',
    };

String bodyPartLabel(BodyPart b) => switch (b) {
      BodyPart.chest => 'Chest',
      BodyPart.back => 'Back',
      BodyPart.shoulders => 'Shoulders',
      BodyPart.arms => 'Arms',
      BodyPart.core => 'Core',
      BodyPart.legs => 'Legs',
      BodyPart.glutes => 'Glutes',
      BodyPart.calves => 'Calves',
      BodyPart.neck => 'Neck',
      BodyPart.cardio => 'Cardio',
    };

/// Subtitle for a list/picker row: body parts joined, capped at two with a
/// `+n` overflow so long taxonomies cannot push the row's height around.
String bodyPartsSubtitle(List<BodyPart> parts) {
  if (parts.isEmpty) return '';
  final labels = parts.map(bodyPartLabel).toList()..sort();
  if (labels.length <= 2) return labels.join(' · ');
  return '${labels.take(2).join(' · ')} +${labels.length - 2}';
}

/// `null` -> null, so callers can decide whether to render a chip at all.
String? muscleLabelOrNull(Muscle? m) => m == null ? null : muscleLabel(m);
String? equipmentLabelOrNull(Equipment? e) => e == null ? null : equipmentLabel(e);
