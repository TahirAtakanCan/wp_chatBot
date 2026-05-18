import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../utils/message_media_url.dart';
import '../utils/message_text_utils.dart';
import 'document_bubble.dart';
import 'message_media_content.dart';
import 'video_bubble.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onImageTap;
  final bool isFirstInGroup;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onImageTap,
    this.isFirstInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    final isInbound = message.isInbound;
    final alignment = isInbound ? Alignment.centerLeft : Alignment.centerRight;
    final background = isInbound ? Colors.white : const Color(0xFFDCF8C6);
    final status = message.status.toUpperCase();

    return Align(
      alignment: alignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final compactWidth = availableWidth * 0.58;
          final maxBubbleWidth =
              compactWidth > 440 ? 440.0 : compactWidth;

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxBubbleWidth,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: _bubbleRadius(isInbound, isFirstInGroup),
                border: isInbound
                    ? Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isInbound ? 0.05 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContent(context),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        _formatHourMinute(message.sentAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (message.isOutbound) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message.status),
                      ],
                    ],
                  ),
                  if (status == 'FAILED')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Gönderilemedi',
                            style: TextStyle(
                              fontSize: 10,
                              color: WAColors.errorRed,
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: onRetry,
                            style: TextButton.styleFrom(
                              foregroundColor: WAColors.accent,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Tekrar gönder'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final messageType = message.messageType.toUpperCase();

    if (messageType == 'VIDEO') {
      return VideoBubble(message: message);
    }

    if (messageType == 'DOCUMENT') {
      return DocumentBubble(message: message);
    }

    if (messageType == 'IMAGE' ||
        messageType == 'STICKER' ||
        messageType == 'AUDIO' ||
        messageType == 'VOICE') {
      return MessageMediaContent(message: message, onTap: onImageTap);
    }

    if (isMediaPlaceholderContent(message.content) &&
        resolveMessageMediaUrl(message) != null) {
      return MessageMediaContent(message: message, onTap: onImageTap);
    }

    return Text(
      normalizeMessageContent(message.content),
      style: WATextStyles.messageBody.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  BorderRadius _bubbleRadius(bool isInbound, bool isFirst) {
    const grouped = 12.0;
    const tail = 4.0;
    const corner = 12.0;

    if (!isFirst) {
      return BorderRadius.circular(grouped);
    }

    if (isInbound) {
      return const BorderRadius.only(
        topLeft: Radius.circular(corner),
        topRight: Radius.circular(corner),
        bottomRight: Radius.circular(corner),
        bottomLeft: Radius.circular(tail),
      );
    }

    return const BorderRadius.only(
      topLeft: Radius.circular(corner),
      topRight: Radius.circular(corner),
      bottomRight: Radius.circular(tail),
      bottomLeft: Radius.circular(corner),
    );
  }

  Widget _buildStatusIcon(String statusRaw) {
    final status = statusRaw.trim().toUpperCase();
    switch (status) {
      case 'PENDING':
      case 'SENDING':
        return const Icon(
          Icons.access_time,
          size: 14,
          color: WAColors.statusDefault,
        );
      case 'SENT':
        return const Icon(Icons.done, size: 14, color: WAColors.statusDefault);
      case 'DELIVERED':
        return const Icon(
          Icons.done_all,
          size: 14,
          color: WAColors.statusDefault,
        );
      case 'READ':
        return const Icon(
          Icons.done_all,
          size: 14,
          color: WAColors.statusRead,
        );
      case 'FAILED':
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: WAColors.errorRed,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatHourMinute(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
