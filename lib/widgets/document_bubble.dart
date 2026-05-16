import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../utils/media_size_helper.dart';
import '../utils/message_media_url.dart';
import '../utils/open_media_url.dart';

class DocumentBubble extends StatelessWidget {
  final Message message;

  const DocumentBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final mediaUrl = resolveMessageMediaUrl(message);
    final caption = message.effectiveCaption;
    final displayName = _displayFilename();
    final extension = _fileExtension(displayName, message.mimeType);
    final sizeLabel = message.fileSizeBytes != null
        ? '${formatFileSizeMb(message.fileSizeBytes!)} MB'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: WAColors.composerBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.insert_drive_file_outlined,
                    size: 32,
                    color: WAColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: WATextStyles.messageBody.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (sizeLabel != null) sizeLabel,
                            if (extension != null) extension,
                          ].join(' · '),
                          style: WATextStyles.messageTime,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (mediaUrl != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _openUrl(context, mediaUrl),
                      style: TextButton.styleFrom(
                        foregroundColor: WAColors.accent,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('İndir'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _openUrl(context, mediaUrl),
                      style: TextButton.styleFrom(
                        foregroundColor: WAColors.accent,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Aç'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption, style: WATextStyles.messageBody),
        ],
      ],
    );
  }

  String _displayFilename() {
    final name = message.filename?.trim();
    if (name != null && name.isNotEmpty) return name;

    final content = message.content?.trim();
    if (content != null &&
        content.isNotEmpty &&
        !content.startsWith('[') &&
        content.contains('.')) {
      return content;
    }

    final url = resolveMessageMediaUrl(message);
    if (url != null) {
      final segment = Uri.tryParse(url)?.pathSegments.last;
      if (segment != null && segment.isNotEmpty) return segment;
    }

    return 'Dosya';
  }

  String? _fileExtension(String filename, String? mimeType) {
    final dot = filename.lastIndexOf('.');
    if (dot > 0 && dot < filename.length - 1) {
      return filename.substring(dot + 1).toUpperCase();
    }
    if (mimeType != null && mimeType.contains('/')) {
      return mimeType.split('/').last.toUpperCase();
    }
    return null;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      await openMediaUrl(url);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya açılamadı: $e')),
      );
    }
  }
}
