import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';

class ContactListPanel extends StatelessWidget {
  const ContactListPanel({super.key});

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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Numara sayacı rozeti
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
                decoration: const InputDecoration(
                  hintText:
                      'Telefon numaralarını alt alta yazın...\n\n5551234567\n5559876543\n5553214567',
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

            // Dosyadan Yükle butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: provider.loadFromFile,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('TXT / Excel\'den Yükle'),
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