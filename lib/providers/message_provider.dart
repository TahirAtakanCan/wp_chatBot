import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/sending_state.dart';

class MessageProvider extends ChangeNotifier {
  // --- API Ayarları ---
  final String _baseUrl = 'http://localhost:8080/api/send';
  String? _sessionId;
  Timer? _pollingTimer;

  // --- Kişi Listesi ---
  final TextEditingController phoneController = TextEditingController();
  List<String> _phoneNumbers = [];
  List<String> get phoneNumbers => _phoneNumbers;
  int get phoneCount => _phoneNumbers.length;

  // --- Mesaj İçeriği ---
  final TextEditingController messageController = TextEditingController();

  /// Mesaj ayırma işareti
  static const String messageSplitMarker = '✂ ── Mesaj Ayrımı ──';

  /// Mesajı Shift+Enter ile ayrılmış parçalara böler
  List<String> get splitMessages {
    final text = messageController.text.trim();
    if (text.isEmpty) return [];
    return text
        .split(messageSplitMarker)
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Kaç ayrı mesaj parçası olduğu
  int get messagePartCount {
    final parts = splitMessages;
    return parts.isEmpty ? 0 : parts.length;
  }

  // --- Medya Ekleri ---
  final List<PlatformFile> _attachedMedia = [];
  List<PlatformFile> get attachedMedia => List.unmodifiable(_attachedMedia);
  int get mediaCount => _attachedMedia.length;
  bool get hasMedia => _attachedMedia.isNotEmpty;

  /// Dosya seçici ile resim/video ekle
  Future<void> pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'mp4', 'avi', 'mov', 'mkv', 'webm'],
        allowMultiple: true,
        withData: true, // Her platformda byte verisini zorunlu al
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          final alreadyExists = _attachedMedia.any((f) => f.name == file.name && f.size == file.size);
          if (!alreadyExists) {
            _attachedMedia.add(file);
          }
        }
        _addLog('[BİLGİ] ${result.files.length} medya dosyası eklendi. Toplam: $mediaCount');
        notifyListeners();
      }
    } catch (e) {
      _addLog('[HATA] Dosya seçilirken hata oluştu: $e');
      notifyListeners();
    }
  }

  void removeMedia(int index) {
    if (index >= 0 && index < _attachedMedia.length) {
      final removed = _attachedMedia.removeAt(index);
      _addLog('[BİLGİ] "${removed.name}" kaldırıldı. Kalan: $mediaCount');
      notifyListeners();
    }
  }

  void clearAllMedia() {
    _attachedMedia.clear();
    _addLog('[BİLGİ] Tüm medya dosyaları kaldırıldı.');
    notifyListeners();
  }

  // ==========================================
  // EKSİK OLDUĞU SÖYLENEN METODLAR BURADA
  // ==========================================

  void loadFromFile() {
    _addLog('[BİLGİ] Dosyadan yükleme özelliği henüz aktif değil.');
    notifyListeners();
  }

  bool isImageFile(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ==========================================

  // --- Gönderim Ayarları ---
  final TextEditingController minDelayController = TextEditingController(text: '5');
  final TextEditingController maxDelayController = TextEditingController(text: '15');

  int get minDelay => int.tryParse(minDelayController.text) ?? 5;
  int get maxDelay => int.tryParse(maxDelayController.text) ?? 15;

  // --- Gönderim Durumu ---
  SendingStatus _status = SendingStatus.idle;
  SendingStatus get status => _status;

  int _sentCount = 0;
  int get sentCount => _sentCount;

  double _progress = 0.0;
  double get progress => _progress;

  // --- Log ---
  List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);
  final ScrollController logScrollController = ScrollController();

  void parsePhoneNumbers() {
    final raw = phoneController.text.trim();
    if (raw.isEmpty) {
      _phoneNumbers = [];
    } else {
      // 1. Metni satır satır veya virgülle ayır
      var rawList = raw.split(RegExp(r'[\n,;]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      _phoneNumbers = [];
      
      for (var number in rawList) {
        // 2. Sadece rakamları bırak (Boşluk, tire, parantez, + gibi işaretleri temizle)
        var cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');

        // 3. Türkiye formatına (90...) dönüştür
        if (cleaned.startsWith('0') && cleaned.length == 11) {
          // Örnek: 05551234567 -> 905551234567 (Baştaki 0'ı at, 90 ekle)
          cleaned = '90${cleaned.substring(1)}';
        } 
        else if (cleaned.length == 10 && cleaned.startsWith('5')) {
          // Örnek: 5551234567 -> 905551234567 (Başına direkt 90 ekle)
          cleaned = '90$cleaned';
        } 
        else if (cleaned.startsWith('90') && cleaned.length == 12) {
          // Örnek: 905551234567 -> Zaten doğru format, dokunma
        } 
        // Not: Eğer yurt dışı numaraları da olacaksa (örneğin 49 ile başlayan Almanya),
        // Else bloğuna düşeceği için onlara da dokunmamış oluyoruz, ham haliyle bırakıyoruz.

        _phoneNumbers.add(cleaned);
      }
    }
    notifyListeners();
  }

  // ==========================================
  // API İLETİŞİM METODLARI
  // ==========================================

  Future<void> startSending() async {
    if (_status == SendingStatus.sending) return;

    parsePhoneNumbers();

    if (_phoneNumbers.isEmpty) {
      _addLog('[HATA] Gönderilecek telefon numarası bulunamadı.');
      return;
    }
    // Metin boşsa, medya yoksa hata ver. Medya varsa gönderime izin ver.
    if (messageController.text.trim().isEmpty && !hasMedia) {
      _addLog('[HATA] Lütfen bir mesaj metni veya medya (resim/video) ekleyin.');
      return;
    }

    _status = SendingStatus.sending;
    _sentCount = 0;
    _progress = 0.0;
    _logs.clear(); 
    _addLog('─── Gönderim API\'ye İletiliyor ───');
    notifyListeners();

    try {
      // 1. JSON İsteğinin Gövdesini Hazırla
        // Separator içeren mesajları filtrele
        final messages = splitMessages.where((m) => m != messageSplitMarker && m.trim().isNotEmpty).toList();
      Map<String, dynamic> requestBody = {
        'phoneNumbers': _phoneNumbers,
        'message': messageController.text.trim(),
          'messages': messages,
        'minDelay': minDelay,
        'maxDelay': maxDelay,
        'media': [],
      };

      // 2. Varsa Medya Dosyalarını Base64 String'e Çevir
      if (hasMedia) {
        for (var file in _attachedMedia) {
          if (file.bytes != null) {
            requestBody['media'].add({
              'fileName': file.name,
              'base64Data': base64Encode(file.bytes!), // Dart'ın yerleşik base64Encode fonksiyonu
            });
          }
        }
      }

      // 3. Normal HTTP POST İsteği At (Multipart YERİNE JSON)
      var response = await http.post(
        Uri.parse('$_baseUrl/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        _sessionId = data['sessionId'];
        _addLog('[BAŞARILI] API Session ID: $_sessionId');
        
        _startPolling();
      } else {
        _status = SendingStatus.idle;
        _addLog('[HATA] API reddetti: ${response.body}');
        notifyListeners();
      }
    } catch (e) {
      _status = SendingStatus.idle;
      _addLog('[HATA] Backend bağlantısı kurulamadı: $e');
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_sessionId == null) return;

      try {
        var response = await http.get(Uri.parse('$_baseUrl/status/$_sessionId'));
        
        if (response.statusCode == 200) {
          var data = jsonDecode(utf8.decode(response.bodyBytes)); 
          
          _sentCount = data['sentCount'] ?? 0;
          _progress = data['progress'] ?? 0.0;
          
          List<dynamic> backendLogs = data['logs'] ?? [];
          if (backendLogs.length > _logs.length) {
            _logs = backendLogs.map((e) => e.toString()).toList();
            _scrollToBottom();
          }

          String currentStatus = data['status'];
          
          if (currentStatus == 'COMPLETED') {
            _status = SendingStatus.completed;
            _pollingTimer?.cancel();
            _addLog('─── Tüm mesajlar başarıyla gönderildi! ───');
          } else if (currentStatus == 'FAILED') {
            _status = SendingStatus.idle;
            _pollingTimer?.cancel();
            _addLog('─── GÖNDERİM ÇÖKTÜ VEYA İPTAL OLDU ───');
          }
          
          notifyListeners();
        }
      } catch (e) {
        print("Polling hatası: $e");
      }
    });
  }

  Future<void> stopSending() async {
    if (_status != SendingStatus.sending || _sessionId == null) return;

    try {
      var response = await http.post(Uri.parse('$_baseUrl/stop/$_sessionId'));
      if (response.statusCode == 200) {
        _pollingTimer?.cancel();
        _status = SendingStatus.paused;
        _addLog('[DURDURULDU] Gönderim kullanıcı tarafından durduruldu.');
        notifyListeners();
      }
    } catch (e) {
      _addLog('[HATA] Durdurma isteği başarısız: $e');
    }
  }

  void resetState() {
    _pollingTimer?.cancel();
    _status = SendingStatus.idle;
    _sentCount = 0;
    _progress = 0.0;
    _sessionId = null;
    _logs.clear();
    _attachedMedia.clear();
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = '${DateTime.now().hour.toString().padLeft(2, '0')}:'
        '${DateTime.now().minute.toString().padLeft(2, '0')}:'
        '${DateTime.now().second.toString().padLeft(2, '0')}';
    _logs.add('[$timestamp] $message');
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (logScrollController.hasClients) {
        logScrollController.animateTo(
          logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    messageController.dispose();
    minDelayController.dispose();
    maxDelayController.dispose();
    logScrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }
}