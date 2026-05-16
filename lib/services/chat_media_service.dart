import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../config/app_config.dart';
import '../models/media_upload_result.dart';
import '../models/message.dart';
import '../utils/media_size_helper.dart';
import 'auth_service.dart';
import 'conversation_service.dart';

typedef UploadProgressCallback = void Function(int sent, int total);

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
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(minutes: 15),
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  ChatMediaService({ConversationService? conversationService})
      : _conversationService =
            conversationService ?? ConversationService();

  Future<MediaUploadResult> uploadMedia(
    PlatformFile file, {
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final sizeBytes = resolvePickerFileSize(
      pickerSize: file.size,
      bytes: file.bytes,
    );

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Yetkilendirme tokeni bulunamadı.');
    }

    final multipartFile = await _dioMultipartFile(file);
    final formData = FormData.fromMap({'file': multipartFile});

    final response = await _dio.post<Map<String, dynamic>>(
      '${AppConfig.apiMediaUrl}/upload',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
      ),
      cancelToken: cancelToken,
      onSendProgress: onProgress == null
          ? null
          : (sent, total) {
              final effectiveTotal = total > 0 ? total : sizeBytes;
              onProgress(sent, effectiveTotal);
            },
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode != 200 && statusCode != 201) {
      throw Exception('Medya yüklenemedi ($statusCode).');
    }

    final data = response.data;
    if (data == null) {
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

  Future<MultipartFile> _dioMultipartFile(PlatformFile file) async {
    final contentType = _guessContentType(file.name);

    if (file.bytes != null) {
      return MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
        contentType: contentType,
      );
    }

    if (!kIsWeb) {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        return MultipartFile.fromFile(
          path,
          filename: file.name,
          contentType: contentType,
        );
      }
    }

    throw Exception('Dosya verisine erişilemiyor. Lütfen tekrar deneyin.');
  }

  static MediaType _guessContentType(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';

    if (['mp4', 'm4v'].contains(ext)) return MediaType('video', 'mp4');
    if (ext == 'mov') return MediaType('video', 'quicktime');
    if (ext == '3gp') return MediaType('video', '3gpp');
    if (ext == 'webm') return MediaType('video', 'webm');

    if (['jpg', 'jpeg'].contains(ext)) return MediaType('image', 'jpeg');
    if (ext == 'png') return MediaType('image', 'png');
    if (ext == 'gif') return MediaType('image', 'gif');
    if (ext == 'webp') return MediaType('image', 'webp');

    if (ext == 'pdf') return MediaType('application', 'pdf');
    if (ext == 'doc') return MediaType('application', 'msword');
    if (ext == 'docx') {
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    }
    if (ext == 'xls') return MediaType('application', 'vnd.ms-excel');
    if (ext == 'xlsx') {
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    }
    if (ext == 'ppt') return MediaType('application', 'vnd.ms-powerpoint');
    if (ext == 'pptx') {
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.presentationml.presentation',
      );
    }
    if (ext == 'txt') return MediaType('text', 'plain');
    if (ext == 'csv') return MediaType('text', 'csv');
    if (ext == 'zip') return MediaType('application', 'zip');

    if (ext == 'mp3') return MediaType('audio', 'mpeg');
    if (ext == 'ogg') return MediaType('audio', 'ogg');
    if (ext == 'aac') return MediaType('audio', 'aac');

    return MediaType('application', 'octet-stream');
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

  /// Seçilmiş video dosyasını yükler ve gönderir (progress destekli).
  Future<Message> sendVideoFile(
    int conversationId,
    PlatformFile file, {
    String? caption,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final sizeBytes = resolvePickerFileSize(
      pickerSize: file.size,
      bytes: file.bytes,
    );
    ensureWithinWhatsAppLimit(sizeBytes, isVideo: true);

    final upload = await uploadMedia(
      file,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
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

  /// Seçilmiş belge dosyasını yükler ve gönderir (progress destekli).
  Future<Message> sendDocumentFile(
    int conversationId,
    PlatformFile file, {
    String? caption,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final sizeBytes = resolvePickerFileSize(
      pickerSize: file.size,
      bytes: file.bytes,
    );
    ensureWithinWhatsAppLimit(sizeBytes, isVideo: false);

    final upload = await uploadMedia(
      file,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    return _conversationService.sendReplyDocument(
      conversationId,
      mediaUrl: upload.url,
      filename: upload.filename,
      caption: caption,
    );
  }

  /// Video seçer, boyuta göre inline video veya belge olarak gönderir.
  Future<Message?> pickAndSendVideo(
    int conversationId, {
    String? caption,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    return sendVideoFile(
      conversationId,
      result.files.first,
      caption: caption,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// Belge seçer ve gönderir.
  Future<Message?> pickAndSendDocument(
    int conversationId, {
    String? caption,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: documentExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    return sendDocumentFile(
      conversationId,
      result.files.first,
      caption: caption,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
