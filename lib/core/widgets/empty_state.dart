import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A plain Center + Column overflows once the keyboard is open and the
    // available height shrinks below the content's height (e.g. the "no
    // search results" state, which by definition only ever appears while
    // the user is mid-typing in a search field). Wrapping in a
    // LayoutBuilder + SingleChildScrollView keeps the content visually
    // centered when it fits, but lets it scroll instead of overflow when it
    // doesn't.
    //
    // Some call sites (e.g. the exercise picker's no-results branch) also
    // need to nest this inside their own scrollable so a DraggableScrollableSheet
    // controller stays attached. In that case the incoming height constraint
    // is itself unbounded, so forcing a minHeight of it would ask for
    // infinite height. Only force the min height to fill the viewport when
    // the incoming constraint is actually bounded; otherwise just let the
    // content size itself.
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: onAction, child: Text(actionLabel!)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
