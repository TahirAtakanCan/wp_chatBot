import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/media_upload_result.dart';
import '../models/message.dart';
import '../utils/media_size_helper.dart';
import 'auth_service.dart';
import 'conversation_service.dart';

/// Chat icin medya yukleme ve boyut kontrolleri.
class ChatMediaService {
  static const List<String> documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'zip',
    'rar',
    '7z',
  ];

  final ConversationService _conversationService;

  ChatMediaService({ConversationService? conversationService})
      : _conversationService =
            conversationService ?? ConversationService();
  Future<MediaUploadResult> uploadMedia(PlatformFile file) async {
    final sizeBytes = resolvePickerFileSize(
      pickerSize: file.size,
      bytes: file.bytes,
    );

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Yetkilendirme tokeni bulunamadı.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiMediaUrl}/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path!, filename: file.name),
      );
    } else if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
    } else {
      throw Exception('Dosya okunamadı.');
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Medya yüklenemedi (${response.statusCode}).');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Geçersiz medya yanıtı.');
    }

    final url = _resolveUploadUrl(data);
    final responseSize = data['size'] ?? data['sizeBytes'] ?? data['fileSize'];
    final resolvedSize = responseSize is num
        ? responseSize.toInt()
        : int.tryParse(responseSize?.toString() ?? '') ?? sizeBytes;

    return MediaUploadResult(
      url: url,
      sizeBytes: resolvedSize,
      filename: file.name,
    );
  }

  Future<MediaUploadResult> uploadPublicImage({
    required List<int> bytes,
    required String filename,
  }) async {
    return uploadMedia(
      PlatformFile(
        name: filename,
        size: bytes.length,
        bytes: Uint8List.fromList(bytes),
      ),
    );
  }

  String _resolveUploadUrl(Map<String, dynamic> data) {
    final url = data['url'] ??
        data['mediaUrl'] ??
        data['imageUrl'] ??
        data['publicUrl'];
    if (url == null || url.toString().trim().isEmpty) {
      throw Exception('Medya URL alınamadı.');
    }

    final raw = url.toString().trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return '${AppConfig.baseHost}$raw';
    }
    return '${AppConfig.baseHost}/$raw';
  }

  /// Video seçer, boyuta göre inline video veya belge olarak gönderir.
  Future<Message?> pickAndSendVideo(
    int conversationId, {
    String? caption,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final sizeBytes = resolvePickerFileSize(
      pickerSize: file.size,
      bytes: file.bytes,
    );
    ensureWithinWhatsAppLimit(sizeBytes, isVideo: true);

    final upload = await uploadMedia(file);
    final mode = decideVideoSendMode(upload.sizeBytes);

    if (mode == VideoSendMode.inlineVideo) {
      return _conversationService.sendReplyVideo(
        conversationId,
        mediaUrl: upload.url,
        caption: caption,
      );
    }

    return _conversationService.sendReplyDocument(
      conversationId,
      mediaUrl: upload.url,
      filename: upload.filename,
      caption: caption,
    );
  }

  /// Belge seçer ve gönderir.
  Future<Message?> pickAndSendDocument(
    int conversationId, {
    String? caption,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: documentExtensions,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final sizeBytes = resolvePickerFileSize(
      pickerSize: file.size,
      bytes: file.bytes,
    );
    ensureWithinWhatsAppLimit(sizeBytes, isVideo: false);

    final upload = await uploadMedia(file);
    return _conversationService.sendReplyDocument(
      conversationId,
      mediaUrl: upload.url,
      filename: upload.filename,
      caption: caption,
    );
  }
}
