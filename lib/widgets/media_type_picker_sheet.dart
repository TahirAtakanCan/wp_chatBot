import 'package:flutter/material.dart';

import '../models/bulk_media_attachment.dart';
import '../theme/wa_colors.dart';

/// Toplu gönderim — medya tipi seçimi.
class MediaTypePickerSheet extends StatelessWidget {
  const MediaTypePickerSheet({super.key});

  static Future<BulkMediaKind?> show(BuildContext context) {
    return showModalBottomSheet<BulkMediaKind>(
      context: context,
      showDragHandle: true,
      builder: (_) => const MediaTypePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.attach_file_rounded, color: WAColors.accent),
                  SizedBox(width: 10),
                  Text(
                    'Medya Seç',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Resim'),
              subtitle: const Text('JPG, PNG, GIF, WebP'),
              onTap: () => Navigator.pop(context, BulkMediaKind.image),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              subtitle: const Text('MP4, MOV (Meta template gerekir)'),
              onTap: () => Navigator.pop(context, BulkMediaKind.video),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Belge'),
              subtitle: const Text('PDF, Word, Excel'),
              onTap: () => Navigator.pop(context, BulkMediaKind.document),
            ),
          ],
        ),
      ),
    );
  }
}
