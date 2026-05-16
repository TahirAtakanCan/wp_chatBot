import '../constants/media_size_limits.dart';
import '../models/media_upload_result.dart';
import '../services/api_exceptions.dart';

String formatFileSizeMb(int sizeBytes) {
  return (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
}

String formatFileSizeDisplay(int sizeBytes) {
  if (sizeBytes < 1024) return '$sizeBytes B';
  if (sizeBytes < 1024 * 1024) {
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${formatFileSizeMb(sizeBytes)} MB';
}

void ensureWithinWhatsAppLimit(int sizeBytes, {required bool isVideo}) {
  if (sizeBytes <= MediaSizeLimits.whatsappMaxBytes) return;

  final sizeMb = formatFileSizeMb(sizeBytes);
  if (isVideo) {
    throw VideoTooLargeException(
      'Bu video çok büyük ($sizeMb MB). '
      'WhatsApp 100 MB üstü medya kabul etmiyor. '
      'Lütfen videoyu sıkıştırın veya parçalara bölün.',
    );
  }
  throw Exception(
    'Bu dosya çok büyük ($sizeMb MB). WhatsApp 100 MB üstü medya kabul etmiyor.',
  );
}

VideoSendMode decideVideoSendMode(int sizeBytes) {
  ensureWithinWhatsAppLimit(sizeBytes, isVideo: true);
  if (sizeBytes <= MediaSizeLimits.inlineVideoMaxBytes) {
    return VideoSendMode.inlineVideo;
  }
  return VideoSendMode.asDocument;
}

int resolvePickerFileSize({
  required int? pickerSize,
  required List<int>? bytes,
}) {
  if (pickerSize != null && pickerSize > 0) return pickerSize;
  if (bytes != null) return bytes.length;
  throw Exception('Dosya boyutu okunamadı.');
}
