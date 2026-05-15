import 'package:flutter/material.dart';

import '../theme/wa_colors.dart';

/// Ana sayfa panelleri için ortak kart stili.
class HomePanelCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? headerTrailing;
  final bool expandBody;

  const HomePanelCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.headerTrailing,
    this.expandBody = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WAColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: WAColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: WAColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: WAColors.textPrimary,
                    ),
                  ),
                ),
                if (headerTrailing != null) headerTrailing!,
              ],
            ),
            const SizedBox(height: 14),
            if (expandBody) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
