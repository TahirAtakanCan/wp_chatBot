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

    final metadata = [
      if (sizeLabel != null) sizeLabel,
      if (extension != null) extension,
    ].join(' · ');
    final lineText =
        metadata.isEmpty ? displayName : '$displayName · $metadata';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: WAColors.composerBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: mediaUrl == null ? null : () => _openUrl(context, mediaUrl),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 20,
                      color: WAColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lineText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WATextStyles.messageBody.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 4),
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
