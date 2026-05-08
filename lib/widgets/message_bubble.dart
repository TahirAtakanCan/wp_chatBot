import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';

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
    final background =
        isInbound ? WAColors.bubbleInbound : WAColors.bubbleOutbound;
    final status = message.status.toUpperCase();

    return Align(
      alignment: alignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final widthFactor = maxWidth >= 1024 ? 0.65 : 0.75;

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth * widthFactor,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 6, 9, 8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: _bubbleRadius(isInbound, isFirstInGroup),
                boxShadow: const [
                  BoxShadow(
                    color: WAColors.bubbleShadow,
                    blurRadius: 0.5,
                    offset: Offset(0, 1),
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
                        style: WATextStyles.messageTime,
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
    if (messageType == 'IMAGE') {
      return InkWell(
        onTap: onImageTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.image_outlined, size: 32, color: WAColors.textSecondary),
            SizedBox(width: 8),
            Text('Resim', style: WATextStyles.messageBody),
          ],
        ),
      );
    }

    return Text(
      (message.content ?? '').trim(),
      style: WATextStyles.messageBody,
    );
  }

  BorderRadius _bubbleRadius(bool isInbound, bool isFirst) {
    if (!isFirst) {
      return BorderRadius.circular(8);
    }

    if (isInbound) {
      return const BorderRadius.only(
        topLeft: Radius.circular(8),
        topRight: Radius.circular(8),
        bottomRight: Radius.circular(8),
        bottomLeft: Radius.circular(2),
      );
    }

    return const BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
      bottomRight: Radius.circular(2),
      bottomLeft: Radius.circular(8),
    );
  }

  Widget _buildStatusIcon(String statusRaw) {
    final status = statusRaw.trim().toUpperCase();
    switch (status) {
      case 'PENDING':
        return const Icon(
          Icons.access_time,
          size: 10,
          color: WAColors.statusDefault,
        );
      case 'SENT':
        return const Icon(Icons.done, size: 12, color: WAColors.statusDefault);
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
          size: 12,
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
