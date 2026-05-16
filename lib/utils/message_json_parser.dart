import '../models/message.dart';

/// API yanitindan Message cikarir (duz veya ic ice JSON).
Message parseMessageResponse(
  dynamic decoded, {
  String defaultDirection = 'OUTBOUND',
  String? defaultMessageType,
}) {
  final map = extractMessageMap(
    decoded,
    defaultDirection: defaultDirection,
    defaultMessageType: defaultMessageType,
  );
  if (map == null) {
    throw FormatException('Gecersiz mesaj yaniti: $decoded');
  }
  return Message.fromJson(map);
}

Map<String, dynamic>? extractMessageMap(
  dynamic decoded, {
  String defaultDirection = 'OUTBOUND',
  String? defaultMessageType,
}) {
  if (decoded is! Map) return null;

  final root = Map<String, dynamic>.from(decoded);
  Map<String, dynamic>? candidate = _pickMessageCandidate(root);

  candidate ??= _buildFromSendAck(root, defaultMessageType: defaultMessageType);
  if (candidate == null) return null;

  return _normalizeMessageMap(
    candidate,
    defaultDirection: defaultDirection,
    defaultMessageType: defaultMessageType,
  );
}

Map<String, dynamic>? _pickMessageCandidate(Map<String, dynamic> root) {
  if (_looksLikeMessage(root)) return Map<String, dynamic>.from(root);

  for (final key in ['message', 'data', 'content', 'result', 'body']) {
    final nested = root[key];
    if (nested is Map) {
      final map = Map<String, dynamic>.from(nested);
      if (_looksLikeMessage(map)) return map;
    }
  }
  return null;
}

Map<String, dynamic>? _buildFromSendAck(
  Map<String, dynamic> root, {
  String? defaultMessageType,
}) {
  final waMessageId =
      root['waMessageId']?.toString() ?? root['wa_message_id']?.toString();
  if (waMessageId == null || waMessageId.isEmpty) return null;

  return {
    'id': root['id'] ?? root['messageId'] ?? root['message_id'] ?? 0,
    'waMessageId': waMessageId,
    'direction': root['direction'] ?? 'OUTBOUND',
    'messageType': root['messageType'] ??
        root['message_type'] ??
        defaultMessageType ??
        'TEXT',
    'status': root['status'] ?? 'SENT',
    'sentAt': root['sentAt'] ?? root['sent_at'] ?? DateTime.now().toIso8601String(),
    'content': root['content'],
    'caption': root['caption'],
    'mediaUrl': root['mediaUrl'] ?? root['media_url'],
    'url': root['url'],
    'mediaId': root['mediaId'] ?? root['media_id'],
    'mimeType': root['mimeType'] ?? root['mime_type'],
    'filename': root['filename'],
  };
}

Map<String, dynamic> _normalizeMessageMap(
  Map<String, dynamic> map, {
  required String defaultDirection,
  String? defaultMessageType,
}) {
  final normalized = Map<String, dynamic>.from(map);

  normalized.putIfAbsent('direction', () => defaultDirection);
  if (defaultMessageType != null) {
    normalized.putIfAbsent('messageType', () => defaultMessageType);
  }

  final waMessageId = normalized['waMessageId']?.toString() ??
      normalized['wa_message_id']?.toString();
  final status = normalized['status']?.toString().toUpperCase() ?? '';

  if (waMessageId != null && waMessageId.isNotEmpty) {
    if (status.isEmpty || status == 'FAILED' || status == 'PENDING') {
      normalized['status'] = 'SENT';
    }
  }

  return normalized;
}

bool _looksLikeMessage(Map<String, dynamic> map) {
  final hasId = map['id'] != null;
  final hasWaId =
      (map['waMessageId'] ?? map['wa_message_id'])?.toString().isNotEmpty == true;
  final hasType =
      map['messageType'] != null || map['message_type'] != null;
  final hasDirection = map['direction'] != null;

  if (hasWaId && hasId) return true;
  return hasId && hasType && hasDirection;
}
