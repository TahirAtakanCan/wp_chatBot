import '../constants/media_size_limits.dart';
import '../models/bulk_media_attachment.dart';
import 'media_size_helper.dart';

String? validateBulkMediaSize(int sizeBytes, BulkMediaKind kind) {
  if (sizeBytes <= 0) return 'Dosya boyutu okunamadı.';

  switch (kind) {
    case BulkMediaKind.image:
      if (sizeBytes > MediaSizeLimits.bulkImageMaxBytes) {
        return 'Resim çok büyük (${formatFileSizeMb(sizeBytes)} MB). '
            'Toplu gönderim için en fazla '
            '${formatFileSizeMb(MediaSizeLimits.bulkImageMaxBytes)} MB.';
      }
      return null;
    case BulkMediaKind.video:
    case BulkMediaKind.document:
      if (sizeBytes > MediaSizeLimits.whatsappMaxBytes) {
        return 'Dosya çok büyük (${formatFileSizeMb(sizeBytes)} MB). '
            'WhatsApp en fazla '
            '${formatFileSizeMb(MediaSizeLimits.whatsappMaxBytes)} MB kabul eder.';
      }
      return null;
  }
}
