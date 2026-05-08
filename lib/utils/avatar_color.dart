import 'package:flutter/material.dart';

const List<Color> _avatarPalette = <Color>[
  Color(0xFF6BCB77),
  Color(0xFF4D96FF),
  Color(0xFFFF6B6B),
  Color(0xFFFFD93D),
  Color(0xFFB983FF),
  Color(0xFFFF8E72),
  Color(0xFF2EC4B6),
  Color(0xFFE71D36),
];

Color avatarColorFor(String seed) {
  if (seed.isEmpty) return _avatarPalette.first;
  final hash = seed.hashCode.abs();
  return _avatarPalette[hash % _avatarPalette.length];
}
