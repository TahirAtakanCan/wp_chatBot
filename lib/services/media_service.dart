import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class MediaService {
  /// Resmi Base64 formatında JSON body ile sunucuya gönderir.
  ///
  /// [fileBytes] : Seçilen resmin byte verisi
  /// [fileName]  : Dosya adı (uzantı tespiti için)
  /// [phone]     : Alıcı telefon numarası
  /// [caption]   : (Opsiyonel) Resim altı yazısı
  /// [sessionId] : WhatsApp session ID
  static Future<({bool success, String message})> sendImage({
    required List<int> fileBytes,
    required String fileName,
    required String phone,
    String? caption,
    required String sessionId,
  }) async {
    try {
      final base64Image = base64Encode(fileBytes);

      // Uzantıdan mimeType belirle
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png'           => 'image/png',
        'gif'           => 'image/gif',
        'webp'          => 'image/webp',
        'bmp'           => 'image/bmp',
        _               => 'image/jpeg',
      };

      final token = await AuthService.getToken();
      final headers = token != null
          ? AppConfig.authHeaders(token)
          : <String, String>{'Content-Type': 'application/json'};

      final response = await http.post(
        Uri.parse('${AppConfig.apiMediaUrl}/send'),
        headers: headers,
        body: jsonEncode({
          'phone': phone,
          'imageBase64': base64Image,
          'mimeType': mimeType,
          'caption': caption,
          'sessionId': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        return (success: true, message: 'Resim başarıyla gönderildi.');
      } else {
        return (
          success: false,
          message: 'Sunucu hatası (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      return (success: false, message: 'Gönderim hatası: $e');
    }
  }

  /// FilePicker ile resim seçer ve byte verisini döner (Web + Desktop uyumlu)
  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files.first;
    }
    return null;
  }
}
