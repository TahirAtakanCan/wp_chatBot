import '../config/app_config.dart';
import '../models/message.dart';

/// Public medya endpoint'i — JWT gerektirmez.
bool isPublicMediaUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return path.contains('/api/media/public/');
}

String _absoluteUrl(String raw) {
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }
  if (raw.startsWith('/')) {
    return '${AppConfig.baseHost}$raw';
  }
  return '${AppConfig.baseHost}/$raw';
}

/// Backend sozlesmesi: mediaUrl/url → mediaId → messageId/media
String? resolveMessageMediaUrl(Message message) {
  for (final candidate in [message.mediaUrl, message.url]) {
    final raw = candidate?.trim();
    if (raw != null && raw.isNotEmpty) {
      return _absoluteUrl(raw);
    }
  }

  final mediaId = message.mediaId?.trim();
  if (mediaId != null && mediaId.isNotEmpty) {
    return '${AppConfig.baseHost}/api/media/$mediaId';
  }

  if (message.id > 0) {
    return '${AppConfig.baseHost}/api/conversations/messages/${message.id}/media';
  }

  return null;
}
