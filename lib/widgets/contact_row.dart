import 'package:flutter/material.dart';

import '../models/contact_model.dart';
import '../models/delivery_record.dart';
import '../theme/wa_colors.dart';
import '../utils/avatar_color.dart';
import 'delivery_status_icon.dart';

class ContactRow extends StatelessWidget {
  final ContactModel contact;
  final bool selected;
  final DeliveryStatus? deliveryStatus;
  final ValueChanged<bool?> onSelected;
  final VoidCallback? onLongPress;

  const ContactRow({
    super.key,
    required this.contact,
    required this.selected,
    this.deliveryStatus,
    required this.onSelected,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact.name.trim().isNotEmpty ? contact.name.trim() : 'İsimsiz';
    final initials = _initials(name);
    final color = avatarColorFor(contact.phone);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: selected
            ? WAColors.accent.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onLongPress: onLongPress,
          onTap: () => onSelected(!selected),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? WAColors.accent.withValues(alpha: 0.3)
                    : WAColors.divider,
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  activeColor: WAColors.accent,
                  onChanged: onSelected,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: WAColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: WAColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                DeliveryStatusIcon(status: deliveryStatus),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first).toUpperCase();
  }
}
