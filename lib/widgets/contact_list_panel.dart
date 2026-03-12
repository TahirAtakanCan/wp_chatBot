import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';
import '../utils/phone_formatter.dart';

class ContactListPanel extends StatefulWidget {
  final List<String>? rehberdenSecilenler;
  final VoidCallback? onRehberdenSec;
  const ContactListPanel(
      {Key? key, this.rehberdenSecilenler, this.onRehberdenSec})
      : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık satırı
            Row(
              children: [
                Icon(Icons.contacts, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Kişi Listesi',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: provider.phoneCount > 0
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone,
                        size: 14,
                        color: provider.phoneCount > 0
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.phoneCount} numara',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: provider.phoneCount > 0
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Seçimi Temizle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    final provider = context.read<MessageProvider>();
                    final lines =
                        provider.phoneController.text.split('\n');
                    final manualLines = lines.where((line) {
                      final trimmed = line.trim();
                      if (trimmed.isEmpty) return false;
                      if (trimmed.contains('-')) return false;
                      if (RegExp(r'^\d{11,}$').hasMatch(trimmed))
                        return false;
                      return true;
                    }).toList();
                    setState(() {
                      provider.phoneController.text =
                          manualLines.join('\n');
                      provider.parsePhoneNumbers();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Telefon numaraları girişi
            Expanded(
              child: TextField(
                controller: provider.phoneController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => provider.parsePhoneNumbers(),
                inputFormatters: [PhoneNumberFormatter()],
                decoration: const InputDecoration(
                  hintText:
                      'Telefon numaralarını alt alta yazın...\n\n(555) 123 4567\n(555) 987 6543\n(555) 321 4567',
                  hintMaxLines: 6,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Sadece Rehberden Seç butonu — tam genişlik
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onRehberdenSec,
                icon: const Icon(Icons.contacts, size: 18),
                label: const Text('Rehberden Seç'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}