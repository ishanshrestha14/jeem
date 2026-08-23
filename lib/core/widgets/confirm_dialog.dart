import 'package:flutter/material.dart';
import '../theme/semantic_colors.dart';

Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  /// Defaults to "Cancel". Worth overriding wherever "Cancel" could be read as
  /// cancelling the *subject* rather than the dialog — "Cancel" next to
  /// "Discard workout" is exactly that trap.
  String cancelLabel = 'Cancel',
}) async {
  final danger = Theme.of(context).extension<SemanticColors>()!.danger;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
