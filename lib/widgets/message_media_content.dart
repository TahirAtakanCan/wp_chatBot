import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../utils/message_media_url.dart';
import 'authenticated_network_image.dart';

class MessageMediaContent extends StatelessWidget {
  final Message message;
  final VoidCallback? onTap;

  const MessageMediaContent({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = message.messageType.toUpperCase();
    final caption = message.effectiveCaption;

    if (type == 'IMAGE') {
      return _buildImage(context, caption);
    }

    if (type == 'STICKER') {
      return _buildImage(context, caption, maxHeight: 140);
    }

    if (type == 'AUDIO' || type == 'VOICE') {
      return _placeholder(Icons.mic_rounded, 'Ses mesaji', subtitle: caption);
    }

    return _placeholder(Icons.attach_file, 'Medya', subtitle: caption);
  }

  Widget _buildImage(BuildContext context, String? caption, {double maxHeight = 200}) {
    final mediaUrl = resolveMessageMediaUrl(message);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap ?? (mediaUrl != null ? () => _openFullScreen(context, mediaUrl) : null),
          child: mediaUrl != null
              ? AuthenticatedNetworkImage(
                  url: mediaUrl,
                  width: 260,
                  height: maxHeight,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
                )
              : _placeholder(Icons.image_outlined, 'Fotograf yukleniyor...'),
        ),
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption, style: WATextStyles.messageBody),
        ],
      ],
    );
  }

  Widget _placeholder(IconData icon, String label, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: WAColors.composerBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: WAColors.accent),
              const SizedBox(width: 10),
              Flexible(child: Text(label, style: WATextStyles.messageBody)),
            ],
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: WATextStyles.messageBody),
        ],
      ],
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            InteractiveViewer(
              child: AuthenticatedNetworkImage(
                url: url,
                width: MediaQuery.sizeOf(context).width * 0.85,
                height: MediaQuery.sizeOf(context).height * 0.75,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
