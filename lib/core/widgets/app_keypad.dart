import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/semantic_colors.dart';

/// A field's registration with the keypad: everything the pad needs to edit
/// it, plus where it sits in the tab order.
class KeypadEditor {
  KeypadEditor({
    required this.controller,
    required this.focusNode,
    required this.allowDecimal,
    required this.sortKey,
    this.tag,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Drives whether the `.` key is offered at all. Withholding it for an
  /// integer field makes an invalid entry unreachable rather than rejected
  /// after the fact — validation as layout.
  final bool allowDecimal;

  /// Position in the logical entry order. `Next` moves to the lowest
  /// registered key above this one, so weight -> reps -> the following set's
  /// weight, across row boundaries.
  final int sortKey;

  /// Opaque payload for the host — the session screen passes the set id so
  /// the `RIR` key knows which set it is acting on.
  final Object? tag;
}

/// Owns which field the keypad is currently editing.
///
/// Fields register themselves on focus and clear themselves on blur, so the
/// pad never has to know what a set row looks like, and a row never has to
/// know a pad exists beyond opting in.
class AppKeypadController extends ChangeNotifier {
  final Map<int, KeypadEditor> _registered = {};
  KeypadEditor? _active;

  KeypadEditor? get active => _active;
  bool get isOpen => _active != null;

  void register(KeypadEditor editor) {
    _registered[editor.sortKey] = editor;
  }

  void unregister(KeypadEditor editor) {
    if (_registered[editor.sortKey] == editor) {
      _registered.remove(editor.sortKey);
    }
    if (!identical(_active, editor)) return;
    _active = null;
    // Fields unregister from `dispose()`, which runs while the tree is being
    // torn down. Notifying synchronously there marks listeners dirty during
    // build/teardown, which Flutter treats as an error. Defer to the next
    // frame, by which point the pad can safely rebuild itself away.
    _notifyAfterFrame();
  }

  void _notifyAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void attach(KeypadEditor editor) {
    if (identical(_active, editor)) return;
    _active = editor;
    // Select the whole value so the first keypress replaces rather than
    // appends: the field arrives pre-filled with the routine's plan, and the
    // common edit is "that is not what I did", not "add a digit to it".
    //
    // This is a selection-only change — the text is untouched — but it still
    // fires the controller's listeners, so the field must not read it as an
    // edit and write to the database (see `NumericField._onControllerChanged`).
    editor.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: editor.controller.text.length,
    );
    notifyListeners();
  }

  void detach(KeypadEditor editor) {
    if (!identical(_active, editor)) return;
    _active = null;
    notifyListeners();
  }

  void close() {
    _active?.focusNode.unfocus();
    _active = null;
    notifyListeners();
  }

  void input(String character) {
    final editor = _active;
    if (editor == null) return;
    final controller = editor.controller;
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);

    if (character == '.') {
      if (!editor.allowDecimal) return;
      final remaining = value.text.replaceRange(
        selection.start,
        selection.end,
        '',
      );
      // One decimal point only, and a leading '.' becomes '0.' so the value
      // is parseable the moment it is typed rather than after the next digit.
      if (remaining.contains('.')) return;
      if (selection.start == 0) {
        _replace(controller, selection, '0.');
        return;
      }
    }
    _replace(controller, selection, character);
  }

  void backspace() {
    final editor = _active;
    if (editor == null) return;
    final controller = editor.controller;
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);

    if (!selection.isCollapsed) {
      _replace(controller, selection, '');
      return;
    }
    if (selection.start == 0) return;
    _replace(
      controller,
      TextSelection(
        baseOffset: selection.start - 1,
        extentOffset: selection.start,
      ),
      '',
    );
  }

  /// Moves to the next registered field. Returns false when there is none,
  /// which the pad treats as "done" and closes.
  ///
  /// Only *registered* fields count, and a field registers when it is built —
  /// so chaining stops at the edge of what the list has rendered rather than
  /// scrolling to reach a set that is far offscreen.
  bool next() {
    final editor = _active;
    if (editor == null) return false;
    final keys = _registered.keys.where((k) => k > editor.sortKey).toList()
      ..sort();
    if (keys.isEmpty) return false;
    final target = _registered[keys.first]!;
    target.focusNode.requestFocus();
    return true;
  }

  void _replace(
    TextEditingController controller,
    TextSelection selection,
    String replacement,
  ) {
    final text = controller.text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.start + replacement.length,
      ),
    );
  }
}

/// Makes an [AppKeypadController] available to descendant fields.
class AppKeypadScope extends InheritedNotifier<AppKeypadController> {
  const AppKeypadScope({
    super.key,
    required AppKeypadController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppKeypadController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppKeypadScope>()
        ?.notifier;
  }

  /// Reads the controller without subscribing — for fields, which react to
  /// their own focus rather than to the pad's state.
  static AppKeypadController? readOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AppKeypadScope>()?.notifier;
  }
}

/// An in-app numeric pad, shown in place of the system keyboard while a set
/// value is being edited.
///
/// Worth its weight over the OS keyboard for three reasons: it does not
/// resize the app or animate in, so the row being edited stays put; every key
/// is a large target for a chalky thumb; and it has room for the actions this
/// screen actually needs — `RIR` and `Next` — which no system keyboard offers.
class AppKeypad extends StatelessWidget {
  const AppKeypad({
    super.key,
    required this.controller,
    this.onRir,
    this.rirEnabled = true,
  });

  final AppKeypadController controller;

  /// Supplied by the host; the pad passes back the active editor's [tag].
  /// When null the `RIR` key is not rendered at all.
  final Future<void> Function(Object? tag)? onRir;
  final bool rirEnabled;

  @override
  Widget build(BuildContext context) {
    final editor = controller.active;
    if (editor == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    // The pad is part of the field it edits, not somewhere else the user
    // tapped. `TextField` unfocuses on a pointer-down outside itself, and
    // that default fires **only on desktop** (macOS/Windows/Linux) — so on
    // macOS every key press detached the editor and closed the pad before it
    // could register. `TextFieldTapRegion` puts the pad in the field's own
    // tap group, which is exactly what it exists for.
    //
    // Invisible to the suite for the same reason it was invisible in review:
    // `flutter test` runs as `TargetPlatform.android`, where the default
    // handler does nothing. `session_keypad_focus_test.dart` overrides the
    // platform to macOS to keep this honest.
    return TextFieldTapRegion(
      child: Material(
        color: semantic.surfaceHigh,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: semantic.line)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  _KeyRow(
                    children: [
                      for (final digit in row)
                        _Key(
                          label: digit,
                          onPressed: () => controller.input(digit),
                        ),
                      _actionFor(row, editor, semantic),
                    ],
                  ),
                _KeyRow(
                  children: [
                    // The decimal point exists only where a fraction is valid,
                    // so an integer field cannot be given one.
                    editor.allowDecimal
                        ? _Key(
                            label: '.',
                            onPressed: () => controller.input('.'),
                          )
                        : const _Key.blank(),
                    _Key(label: '0', onPressed: () => controller.input('0')),
                    _Key(
                      icon: Icons.backspace_outlined,
                      semanticLabel: 'Backspace',
                      onPressed: controller.backspace,
                    ),
                    _Key(
                      label: 'Next',
                      filled: true,
                      onPressed: () {
                        if (!controller.next()) controller.close();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionFor(
    List<String> row,
    KeypadEditor editor,
    SemanticColors semantic,
  ) {
    if (row.first == '1') {
      return _Key(
        icon: Icons.keyboard_hide_outlined,
        semanticLabel: 'Close keypad',
        onPressed: controller.close,
      );
    }
    if (row.first == '4') {
      if (onRir == null) return const _Key.blank();
      return _Key(
        label: 'RIR',
        onPressed: rirEnabled ? () => onRir!(editor.tag) : null,
      );
    }
    return const _Key.blank();
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (final child in children)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semanticLabel,
    this.onPressed,
    this.filled = false,
  });

  const _Key.blank()
    : label = null,
      icon = null,
      semanticLabel = null,
      onPressed = null,
      filled = false;

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (label == null && icon == null) {
      return const SizedBox(height: 48);
    }
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final child = icon != null
        ? Icon(icon, size: 22)
        : Text(label!, style: AppTheme.setNumeral.copyWith(fontSize: 20));

    // 48dp floor everywhere: this is used mid-set, one-handed.
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      child: filled
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(
              onPressed: onPressed,
              style: style.copyWith(
                side: WidgetStateProperty.all(BorderSide(color: semantic.line)),
                foregroundColor: WidgetStateProperty.all(
                  theme.colorScheme.onSurface,
                ),
              ),
              child: child,
            ),
    );
  }
}
