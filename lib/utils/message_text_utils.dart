/// Mesaj metni ve onizleme yardimcilari.
String normalizeMessageContent(String? raw) {
  if (raw == null) return '';
  var text = raw.trim();
  if (text.isEmpty) return '';

  if (text.contains(r'\u')) {
    text = _decodeUnicodeEscapes(text);
  }

  return text;
}

String _decodeUnicodeEscapes(String input) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < input.length) {
    if (i + 5 < input.length &&
        input[i] == r'\' &&
        input[i + 1] == 'u' &&
        _isHex(input[i + 2]) &&
        _isHex(input[i + 3]) &&
        _isHex(input[i + 4]) &&
        _isHex(input[i + 5])) {
      final code = int.parse(input.substring(i + 2, i + 6), radix: 16);
      buffer.writeCharCode(code);
      i += 6;
      continue;
    }
    buffer.write(input[i]);
    i++;
  }
  return buffer.toString();
}

bool _isHex(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 70) ||
      (code >= 97 && code <= 102);
}

String formatConversationPreview(String? text, {String? messageType}) {
  final type = (messageType ?? '').toUpperCase();
  switch (type) {
    case 'IMAGE':
    case 'STICKER':
      return '📷 Fotoğraf';
    case 'VIDEO':
      return '🎬 Video';
    case 'AUDIO':
    case 'VOICE':
      return '🎤 Ses';
    case 'DOCUMENT':
      return '📎 Dosya';
    case 'LOCATION':
      return '📍 Konum';
    default:
      break;
  }

  if (text == null || text.isEmpty) return '';
  final normalized = text.trim();
  final lower = normalized.toLowerCase();

  if (lower == '[medya]' ||
      lower == 'medya' ||
      lower == '[image]' ||
      lower == 'resim') {
    return '📷 Fotoğraf';
  }

  return normalizeMessageContent(normalized);
}

bool isMediaPlaceholderContent(String? text) {
  if (text == null) return false;
  final lower = text.trim().toLowerCase();
  return lower == '[medya]' ||
      lower == 'medya' ||
      lower == 'resim' ||
      lower == '[image]';
}
