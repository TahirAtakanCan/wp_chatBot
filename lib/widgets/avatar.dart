import 'package:flutter/material.dart';

import '../theme/wa_colors.dart';
import '../utils/avatar_color.dart';

class Avatar extends StatelessWidget {
  final String? name;
  final String? phoneNumber;
  final double radius;

  const Avatar({
    super.key,
    this.name,
    this.phoneNumber,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final display = (name ?? '').trim();
    final hasName = display.isNotEmpty;
    final label = hasName ? _extractInitials(display) : '';
    final seed = hasName ? display : (phoneNumber ?? '');
    final bgColor = avatarColorFor(seed);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: hasName
          ? Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            )
          : Icon(
              Icons.person,
              color: Colors.white,
              size: radius,
            ),
    );
  }

  String _extractInitials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    final first = words.first.characters.first;
    final second = words[1].characters.first;
    return (first + second).toUpperCase();
  }
}
