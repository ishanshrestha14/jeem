import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  State<NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<NumericField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  static String _format(num? v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  @override
  void didUpdateWidget(covariant NumericField old) {
    super.didUpdateWidget(old);
    // Only push external changes down when the field is not being edited,
    // so typing is never fought by a rebuild.
    final incoming = _format(widget.value);
    if (widget.value != old.value && _controller.text != incoming) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
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
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textAlign: TextAlign.center,
      style: widget.style ??
          const TextStyle(
            fontSize: 18,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          widget.allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: widget.dense
          ? const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            )
          : InputDecoration(
              labelText: widget.label,
              suffixText: widget.suffix,
            ),
      onChanged: _emit,
    );
  }
}
