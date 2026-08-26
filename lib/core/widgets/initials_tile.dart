import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// CMP-011: a generated colour plus the item's initials, standing in for the
/// reference app's photography. Cheap, needs no image pipeline, and has no
/// empty state to design — every item has a name.
class InitialsTile extends StatelessWidget {
  const InitialsTile({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colourFor(name),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _initials(name),
        style: AppTheme.setNumeral.copyWith(fontSize: 20, color: Colors.black),
      ),
    );
  }

  static String _initials(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  /// Deterministic from the name, so a routine keeps its colour across
  /// launches without storing one.
  static Color _colourFor(String name) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.45, 0.68).toColor();
  }
}
