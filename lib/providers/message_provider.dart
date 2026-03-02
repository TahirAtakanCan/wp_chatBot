import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/sending_state.dart';

class MessageProvider extends ChangeNotifier {
  // --- API Ayarları ---
  final String _baseUrl = 'http://localhost:8080/api/send';
  final String _mediaApiUrl = 'http://localhost:8080/api/media'; // Resimleri çekeceğimiz yeni API
  String? _sessionId;
  Timer? _pollingTimer;

  // --- Kişi Listesi ---
  final TextEditingController phoneController = TextEditingController();
  List<String> _phoneNumbers = [];
  List<String> get phoneNumbers => _phoneNumbers;
  int get phoneCount => _phoneNumbers.length;

  // --- Mesaj İçeriği ---
  final TextEditingController messageController = TextEditingController();

  static const String messageSplitMarker = '✂ ── Mesaj Ayrımı ──';

  List<String> get splitMessages {
    final text = messageController.text.trim();
    if (text.isEmpty) return [];
    return text
        .split(messageSplitMarker)
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
  }

  int get messagePartCount {
    final parts = splitMessages;
    return parts.isEmpty ? 0 : parts.length;
  }

  // ==========================================
  // YENİ MEDYA SİSTEMİ (URL BAZLI)
  // ==========================================
  final List<String> _selectedMediaUrls = [];
  List<String> get attachedMedia => List.unmodifiable(_selectedMediaUrls);
  int get mediaCount => _selectedMediaUrls.length;
  bool get hasMedia => _selectedMediaUrls.isNotEmpty;

  /// Sunucudaki yüklü resimlerin listesini getirir
  Future<List<String>> fetchAvailableMedia() async {
    try {
      final response = await http.get(Uri.parse('$_mediaApiUrl/list'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e.toString()).toList();
      }
    } catch (e) {
      _addLog('[HATA] Sunucudan medya listesi alınamadı: $e');
    }
    return [];
  }

  /// Kullanıcı arayüzden bir resim seçtiğinde listeye ekler
  void addMediaUrl(String url) {
    if (!_selectedMediaUrls.contains(url)) {
      _selectedMediaUrls.add(url);
      _addLog('[BİLGİ] Medya mesaja eklendi: ${url.split('/').last}');
      notifyListeners();
    }
  }

  void removeMedia(int index) {
    if (index >= 0 && index < _selectedMediaUrls.length) {
      final removed = _selectedMediaUrls.removeAt(index);
      _addLog('[BİLGİ] "${removed.split('/').last}" kaldırıldı.');
      notifyListeners();
    }
  }

  void clearAllMedia() {
    _selectedMediaUrls.clear();
    _addLog('[BİLGİ] Tüm medya dosyaları kaldırıldı.');
    notifyListeners();
  }

  // Yardımcı metodlar
  void loadFromFile() {
    _addLog('[BİLGİ] Dosyadan yükleme özelliği henüz aktif değil.');
    notifyListeners();
  }

  bool isImageUrl(String url) {
    final ext = url.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  // ==========================================
  // GÖNDERİM AYARLARI VE DURUMU
  // ==========================================
  final TextEditingController minDelayController = TextEditingController(text: '5');
  final TextEditingController maxDelayController = TextEditingController(text: '15');

  int get minDelay => int.tryParse(minDelayController.text) ?? 5;
  int get maxDelay => int.tryParse(maxDelayController.text) ?? 15;

  SendingStatus _status = SendingStatus.idle;
  SendingStatus get status => _status;

  int _sentCount = 0;
  int get sentCount => _sentCount;

  double _progress = 0.0;
  double get progress => _progress;

  List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);
  final ScrollController logScrollController = ScrollController();

  void parsePhoneNumbers() {
    final raw = phoneController.text.trim();
    if (raw.isEmpty) {
      _phoneNumbers = [];
    } else {
      var rawList = raw.split(RegExp(r'[\n,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      _phoneNumbers = [];
      for (var number in rawList) {
        var cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned.startsWith('0') && cleaned.length == 11) {
          cleaned = '90${cleaned.substring(1)}';
        } else if (cleaned.length == 10 && cleaned.startsWith('5')) {
          cleaned = '90$cleaned';
        } 
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
    if (messageController.text.trim().isEmpty && !hasMedia) {
      _addLog('[HATA] Lütfen bir mesaj metni veya medya ekleyin.');
      return;
    }

    _status = SendingStatus.sending;
    _sentCount = 0;
    _progress = 0.0;
    _logs.clear(); 
    _addLog('─── Gönderim API\'ye İletiliyor ───');
    notifyListeners();

    try {
      final messages = splitMessages.where((m) => m != messageSplitMarker && m.trim().isNotEmpty).toList();
      
      Map<String, dynamic> requestBody = {
        'phoneNumbers': _phoneNumbers,
        'message': messageController.text.trim(),
        'messages': messages,
        'minDelay': minDelay,
        'maxDelay': maxDelay,
        'media': [],
      };

      // YENİ: Backend'in beklediği MediaRequest listesi formatında URL'leri gönder
      if (hasMedia) {
        for (var url in _selectedMediaUrls) {
          requestBody['media'].add({
            'url': url,
            'type': 'image',
            'fileName': url.split('/').last,
          });
        }
      }

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
            _addLog('─── Tüm işlemler tamamlandı ───');
          } else if (currentStatus == 'FAILED') {
            _status = SendingStatus.idle;
            _pollingTimer?.cancel();
            _addLog('─── GÖNDERİM İPTAL OLDU ───');
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
        _addLog('[DURDURULDU] İşlem kullanıcı tarafından durduruldu.');
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
    _selectedMediaUrls.clear();
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