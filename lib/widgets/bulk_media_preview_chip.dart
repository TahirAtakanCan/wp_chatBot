import 'package:flutter/material.dart';

import '../models/bulk_media_attachment.dart';
import '../theme/wa_colors.dart';
import '../utils/media_size_helper.dart';
import 'authenticated_network_image.dart';

class BulkMediaPreviewChip extends StatelessWidget {
  final BulkMediaAttachment attachment;
  final VoidCallback onRemove;
  final ThemeData theme;

  const BulkMediaPreviewChip({
    super.key,
    required this.attachment,
    required this.onRemove,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLeading(),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '${attachment.kind.apiValue} · ${formatFileSizeDisplay(attachment.sizeBytes)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 13,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeading() {
    if (attachment.kind == BulkMediaKind.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AuthenticatedNetworkImage(
          url: attachment.url,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    final icon = attachment.kind == BulkMediaKind.video
        ? Icons.videocam_outlined
        : Icons.insert_drive_file_outlined;

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WAColors.composerBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 18, color: theme.colorScheme.primary),
    );
  }
}
