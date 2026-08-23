import 'package:flutter/material.dart';

import '../../../../core/utils/constants.dart';
import '../../../../core/utils/formatting.dart';

/// A non-null wrapper around an RIR selection, so a dismissal (`null`) can be
/// told apart from a deliberate pick of the `—` entry, whose value is itself
/// `null`. Dismissing must leave the logged RIR alone; picking `—` must clear
/// it.
class RirChoice {
  const RirChoice(this.value);

  final double? value;
}

/// Unanchored RIR picker, for callers with nowhere sensible to anchor a menu —
/// the in-session keypad's `RIR` key is pressed at the bottom of the screen,
/// far from the row being edited.
///
/// The set row keeps its own anchored `showMenu` version: there, the menu
/// opening next to the value it edits is the clearer affordance.
Future<RirChoice?> showRirPicker(BuildContext context) {
  return showModalBottomSheet<RirChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Reps in reserve', style: theme.textTheme.titleSmall),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final rir in kRirValues)
                      ListTile(
                        // 48dp floor: tapped mid-set.
                        minTileHeight: 48,
                        title: Text(formatRir(rir)),
                        onTap: () => Navigator.of(ctx).pop(RirChoice(rir)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
