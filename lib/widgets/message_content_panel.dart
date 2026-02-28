import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';

class MessageContentPanel extends StatelessWidget {
  const MessageContentPanel({super.key});

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
                Icon(Icons.message, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Mesaj İçeriği',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: provider.pickMedia,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Medya Ekle'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                if (provider.hasMedia) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.perm_media, size: 14, color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.mediaCount} dosya',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: provider.clearAllMedia,
                    icon: const Icon(Icons.clear_all, size: 20),
                    tooltip: 'Tüm medyayı kaldır',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mesaj yazma alanı
                    SizedBox(
                      height: 120,
                      child: TextField(
                        controller: provider.messageController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Gönderilecek mesajı buraya yazın...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    // Eklenen medya önizlemeleri
                    if (provider.hasMedia) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ekli Medya Dosyaları',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 80,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: provider.attachedMedia.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final file = provider.attachedMedia[index];
                                  return _MediaThumbnail(
                                    file: file,
                                    isImage: provider.isImageFile(file),
                                    fileSize: provider.formatFileSize(file.size),
                                    onRemove: () => provider.removeMedia(index),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
            // ...existing code...
  }
}

class _MediaThumbnail extends StatelessWidget {
  final dynamic file;
  final bool isImage;
  final String fileSize;
  final VoidCallback onRemove;

  const _MediaThumbnail({
    required this.file,
    required this.isImage,
    required this.fileSize,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          width: 100,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isImage ? Icons.image : Icons.videocam,
                size: 28,
                color: isImage
                    ? Colors.blue.shade400
                    : Colors.purple.shade400,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  file.name,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text(
                fileSize,
                style: TextStyle(
                  fontSize: 9,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Kaldır butonu
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}