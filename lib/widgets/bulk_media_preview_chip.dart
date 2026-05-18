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
    final metaText =
        '${attachment.filename} · ${formatFileSizeDisplay(attachment.sizeBytes)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLeading(),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              metaText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 3),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 12,
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
        borderRadius: BorderRadius.circular(4),
        child: AuthenticatedNetworkImage(
          url: attachment.url,
          width: 18,
          height: 18,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final icon = attachment.kind == BulkMediaKind.video
        ? Icons.videocam_outlined
        : Icons.insert_drive_file_outlined;

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WAColors.composerBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 12, color: theme.colorScheme.primary),
    );
  }
}
