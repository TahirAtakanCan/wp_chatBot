import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../utils/message_media_url.dart';
import '../utils/open_media_url.dart';

class VideoBubble extends StatelessWidget {
  final Message message;

  const VideoBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final mediaUrl = resolveMessageMediaUrl(message);
    final caption = message.effectiveCaption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 180),
          child: GestureDetector(
            onTap: mediaUrl == null
                ? null
                : () async {
                    try {
                      await openMediaUrl(mediaUrl);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Video açılamadı: $e')),
                      );
                    }
                  },
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: WAColors.composerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.movie_creation_outlined,
                      size: 44,
                      color: WAColors.textTertiary.withValues(alpha: 0.7),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption, style: WATextStyles.messageBody),
        ],
      ],
    );
  }
}
