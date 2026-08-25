import 'package:flutter/material.dart';

import '../../../../core/theme/semantic_colors.dart';

/// The background rule shared by every set row, strength and duration alike.
///
/// It lives here rather than in each row because the two widgets had drifted
/// into carrying identical copies of it, and a state added to one would
/// silently not exist on the other.
///
/// Three states, in precedence order:
///
/// 1. **Current** — `surfaceHigh` plus a 3px chalk bar on the leading edge.
///    A row can be both current and complete (completed sets stay editable,
///    PRD §17); "where you are" is the more specific signal and wins, while
///    the row's filled disc still marks it done.
/// 2. **Complete** — a full-width [SemanticColors.completedRow] wash, so set
///    state is legible at arm's length rather than only in the 24dp disc.
/// 3. **Pending** — nothing.
BoxDecoration setRowDecoration(
  SemanticColors semantic, {
  required bool isCurrent,
  required bool isComplete,
  required Color currentEdgeColor,
}) {
  if (isCurrent) {
    return BoxDecoration(
      color: semantic.surfaceHigh,
      border: Border(left: BorderSide(color: currentEdgeColor, width: 3)),
    );
  }
  return BoxDecoration(
    color: isComplete ? semantic.completedRow : Colors.transparent,
  );
}
