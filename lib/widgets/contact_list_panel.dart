import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/message_provider.dart';
import '../theme/wa_colors.dart';
import 'home_panel_card.dart';

class ContactListPanel extends StatefulWidget {
  final List<String>? rehberdenSecilenler;
  final VoidCallback? onRehberdenSec;
  final bool compact;
  const ContactListPanel({
    super.key,
    this.rehberdenSecilenler,
    this.onRehberdenSec,
    this.compact = false,
  });

  @override
  State<ContactListPanel> createState() => _ContactListPanelState();
}

class _ContactListPanelState extends State<ContactListPanel> {
  @override
  void didUpdateWidget(covariant ContactListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rehberdenSecilenler != null &&
        widget.rehberdenSecilenler!.isEmpty) {
      final provider = context.read<MessageProvider>();
      final lines = provider.phoneController.text.split('\n');
      final manualLines = lines.where((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return false;
        if (trimmed.contains('-')) return false;
        if (RegExp(r'^\d{11,}$').hasMatch(trimmed)) return false;
        return true;
      }).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          provider.phoneController.text = manualLines.join('\n');
          provider.parsePhoneNumbers();
        });
      });
    } else if (widget.rehberdenSecilenler != null &&
        widget.rehberdenSecilenler!.isNotEmpty) {
      final provider = context.read<MessageProvider>();
      final currentLines = provider.phoneController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final newLines = widget.rehberdenSecilenler!
          .where((line) => !currentLines.contains(line))
          .toList();
      if (newLines.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            final updated = [...currentLines, ...newLines].join('\n');
            provider.phoneController.text = updated;
            provider.parsePhoneNumbers();
          });
        });
      }
    }
  }

  Widget _buildHeaderTrailing(MessageProvider provider, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: provider.phoneCount > 0
                ? WAColors.accent.withValues(alpha: 0.12)
                : WAColors.composerBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_rounded,
                size: 14,
                color: provider.phoneCount > 0
                    ? WAColors.accent
                    : WAColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${provider.phoneCount} numara',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: provider.phoneCount > 0
                      ? WAColors.accent
                      : WAColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (!widget.compact) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Temizle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: WAColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: _clearNumbers,
          ),
        ],
      ],
    );
  }

  void _clearNumbers() {
    final provider = context.read<MessageProvider>();
    setState(() {
      provider.phoneController.text = '';
      provider.parsePhoneNumbers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final theme = Theme.of(context);

    return HomePanelCard(
      title: 'Kişi Listesi',
      icon: Icons.contacts_rounded,
      headerTrailing: _buildHeaderTrailing(provider, theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Seçimi Temizle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WAColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _clearNumbers,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: TextField(
              controller: provider.phoneController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => provider.parsePhoneNumbers(),
              decoration: InputDecoration(
                filled: true,
                fillColor: WAColors.composerBg,
                hintText:
                    'Telefon numaralarını alt alta yazın...\n\n(555) 123 4567\n(555) 987 6543',
                hintMaxLines: 6,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onRehberdenSec,
              icon: const Icon(Icons.contacts_rounded, size: 18),
              label: const Text('Rehberden Seç'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WAColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}