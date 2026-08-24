import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/semantic_colors.dart';
import 'app_keypad.dart';

class NumericField extends StatefulWidget {
  const NumericField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowDecimal = false,
    this.min,
    this.max,
    this.suffix,
    this.autofocus = false,
    this.dense = false,
    this.style,
    this.hintText,
    this.keypadSortKey,
    this.keypadTag,
  });

  final String label;
  final num? value;
  final ValueChanged<num?> onChanged;
  final bool allowDecimal;
  final num? min;
  final num? max;
  final String? suffix;
  final bool autofocus;

  /// Set-row mode (design system: "no box chrome"): no floating label, no
  /// border, zero content padding. The column header supplies the label
  /// once per exercise instead of once per row.
  final bool dense;

  /// Overrides the default 18/tabular style — set rows pass the condensed
  /// numeral style.
  final TextStyle? style;

  /// Shown, muted, while the field is empty. Session set rows pass the
  /// routine's snapshotted plan here (CMP-015), so a pending row reads as
  /// what you *meant* to do without claiming it as logged — a hint is not a
  /// value, and nothing is persisted until the set is completed or edited.
  final String? hintText;

  /// Opts this field into the in-app keypad, when one is in scope. The value
  /// is its position in the entry order, which `Next` walks. Null (the
  /// default) keeps the system keyboard, so every field outside the session
  /// screen is untouched.
  final int? keypadSortKey;

  /// Passed through to [KeypadEditor.tag] for the host's own use.
  final Object? keypadTag;

  @override
  State<NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<NumericField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));
  final FocusNode _focusNode = FocusNode();

  AppKeypadController? _keypad;
  KeypadEditor? _editor;

  bool get _usesAppKeypad => _editor != null;

  /// Guards the controller listener while [didUpdateWidget] writes an external
  /// value in, so syncing down never echoes back up as a user edit.
  bool _syncingExternalValue = false;

  /// Last text this field reported upward. Without it, a selection change or
  /// a rebuild would re-emit an unchanged value, and each emit round-trips
  /// through the database — a write storm at best, a rebuild loop at worst.
  late String _lastEmittedText = _format(widget.value);

  static String _format(num? v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keypad =
        widget.keypadSortKey == null ? null : AppKeypadScope.readOf(context);
    if (keypad == _keypad) return;
    _releaseKeypad();
    _keypad = keypad;
    if (keypad != null) {
      _editor = KeypadEditor(
        controller: _controller,
        focusNode: _focusNode,
        allowDecimal: widget.allowDecimal,
        sortKey: widget.keypadSortKey!,
        tag: widget.keypadTag,
      );
      keypad.register(_editor!);
      // The pad edits the controller directly, and programmatic controller
      // changes do not fire `TextField.onChanged` — so in keypad mode the
      // controller itself is the source of edits.
      _controller.addListener(_onControllerChanged);
    }
  }

  void _releaseKeypad() {
    if (_editor != null) {
      _controller.removeListener(_onControllerChanged);
      _keypad?.unregister(_editor!);
      _editor = null;
    }
  }

  void _onFocusChanged() {
    final keypad = _keypad;
    final editor = _editor;
    if (keypad == null || editor == null) return;
    if (_focusNode.hasFocus) {
      keypad.attach(editor);
    } else {
      keypad.detach(editor);
    }
  }

  void _onControllerChanged() {
    if (_syncingExternalValue) return;
    // The controller fires for selection changes too — focusing a field
    // selects its value — so only react when the text itself moved.
    if (_controller.text == _lastEmittedText) return;
    _lastEmittedText = _controller.text;
    _emit(_controller.text);
  }

  @override
  void didUpdateWidget(covariant NumericField old) {
    super.didUpdateWidget(old);
    // Only push external changes down when the field is not being edited,
    // so typing is never fought by a rebuild.
    final incoming = _format(widget.value);
    if (widget.value != old.value && _controller.text != incoming) {
      _syncingExternalValue = true;
      _controller.text = incoming;
      _lastEmittedText = incoming;
      _syncingExternalValue = false;
    }
  }

  @override
  void dispose() {
    _releaseKeypad();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _emit(String raw) {
    if (raw.trim().isEmpty) {
      widget.onChanged(null);
      return;
    }
    final rawParsed =
        widget.allowDecimal ? double.tryParse(raw) : int.tryParse(raw);
    if (rawParsed == null) return;
    num parsed = rawParsed;
    if (widget.min != null && parsed < widget.min!) parsed = widget.min!;
    if (widget.max != null && parsed > widget.max!) parsed = widget.max!;
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedStyle = widget.style ??
        const TextStyle(
          fontSize: 18,
          fontFeatures: [FontFeature.tabularFigures()],
        );
    // The hint wears the field's own numerals so it lines up with a logged
    // value character-for-character, recoloured to `muted`. Falls back to the
    // ambient hint colour where the app's `SemanticColors` extension isn't
    // installed (a bare `ThemeData` in a test harness).
    final hintStyle = resolvedStyle.copyWith(
      color: theme.extension<SemanticColors>()?.muted ?? theme.hintColor,
    );
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      // `readOnly` suppresses the system keyboard while leaving the field
      // focusable, selectable and caret-visible — the app pad supplies the
      // input instead.
      readOnly: _usesAppKeypad,
      showCursor: _usesAppKeypad ? true : null,
      textAlign: TextAlign.center,
      style: resolvedStyle,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          widget.allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: widget.dense
          ? InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              hintStyle: hintStyle,
              // Vertical padding only — it adds no box chrome (still no
              // border, no label, no horizontal inset), but it lifts the
              // field's *tappable* height from ~33dp of bare glyph box to
              // ≥48dp, which PRD §16.3/§24.4 require of every input. The
              // set row is 56dp tall regardless (the done control sets
              // that), so this costs no layout.
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            )
          : InputDecoration(
              labelText: widget.label,
              suffixText: widget.suffix,
              hintText: widget.hintText,
              hintStyle: hintStyle,
            ),
      // In keypad mode the controller listener already emits; keeping this
      // as well would double-fire on the rare hardware-keyboard edit.
      onChanged: _usesAppKeypad ? null : _emit,
    );
  }
}
