import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/formatting.dart';

/// CMP-020: seven dots under weekday initials, one per day of the current
/// week, filled on days that have a completed workout (S-005).
///
/// The week runs **Sunday to Saturday** (owner's week), so the strip does not
/// shift under you mid-week the way a rolling seven days would.
class WeekDotStrip extends StatelessWidget {
  const WeekDotStrip({
    super.key,
    required this.trainedDays,
    required this.today,
  });

  /// Dates (any time of day) that have a completed workout.
  final Set<DateTime> trainedDays;
  final DateTime today;

  static const _initials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  /// The shared definition in `core/utils/formatting.dart`, re-exposed under
  /// the name this widget's tests already use. Aliased rather than
  /// reimplemented: this strip and S-001's weekly summary disagreeing about
  /// which week you are in would be a real bug, and an invisible one.
  static const startOfWeek = weekStart;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final start = weekStart(today);
    final trained = {for (final d in trainedDays) dateOnly(d)};
    final todayOnly = dateOnly(today);

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _Day(
              initial: _initials[i],
              trained: trained.contains(start.add(Duration(days: i))),
              isToday: start.add(Duration(days: i)) == todayOnly,
              accent: semantic.rest,
              muted: semantic.muted,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.initial,
    required this.trained,
    required this.isToday,
    required this.accent,
    required this.muted,
    required this.onSurface,
  });

  final String initial;
  final bool trained;
  final bool isToday;
  final Color accent;
  final Color muted;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    // A trained day is a filled accent dot; an untrained one stays a small
    // muted dot rather than disappearing, so the week keeps its shape whether
    // you trained once or six times.
    final size = trained ? 12.0 : 6.0;
    return Column(
      children: [
        SizedBox(
          height: 14,
          child: Center(
            // Scoped to the dot, not the whole day: wrapping the column would
            // merge the weekday letter into the label, announcing "Trained S".
            child: Semantics(
              container: true,
              label: trained ? 'Trained' : 'No workout',
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trained ? accent : muted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          initial,
          style: AppTheme.columnHeader.copyWith(
            // Today is named by weight, not by another dot — a second dot
            // shape would compete with the trained/untrained signal.
            color: isToday ? onSurface : muted,
            fontWeight: isToday ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}
