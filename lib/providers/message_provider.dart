import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/sending_state.dart';

class MessageProvider extends ChangeNotifier {
  // --- API Ayarları ---
  final String _baseUrl = AppConfig.apiSendUrl;
  final String _mediaApiUrl = AppConfig.apiMediaUrl;
  String? _sessionId;
  Timer? _pollingTimer;

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- WhatsApp Session ---
  String? _activeSessionId;
  String? get activeSessionId => _activeSessionId;

  void setActiveSession(String sessionId) {
    _activeSessionId = sessionId;
    phoneController.clear();
    _phoneNumbers = [];
    _lastLoadedFileName = null;
    _originalFileNumbers = [];
    notifyListeners();
  }

  // --- Kişi Listesi ---
  final TextEditingController phoneController = TextEditingController();
  List<String> _phoneNumbers = [];
  List<String> get phoneNumbers => _phoneNumbers;
  int get phoneCount => _phoneNumbers.length;

  // --- Dosya Devam (Resume) Sistemi ---
  String? _lastLoadedFileName;
  List<String> _originalFileNumbers = [];

  // --- Mesaj İçeriği ---
  final TextEditingController messageController = TextEditingController();

  static const String messageSplitMarker = '✂ ── Mesaj Ayrımı ──';

  List<String> get splitMessages {
    final text = messageController.text.trim();
    if (text.isEmpty) return [];
    return text
        .split(messageSplitMarker)
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty && m != messageSplitMarker)
        .toList();
  }

  int get messagePartCount {
    final parts = splitMessages;
    return parts.isEmpty ? 0 : parts.length;
  }

  // --- Kişiselleştirme ---
  bool _personalizedMessage = false;
  bool get personalizedMessage => _personalizedMessage;

  void togglePersonalizedMessage() {
    _personalizedMessage = !_personalizedMessage;
    notifyListeners();
  }

  /// "İsim Soyisim - 905551234567" → "İsim Soyisim"
  String _extractName(String entry) {
    if (entry.contains(' - ')) {
      return entry.substring(0, entry.lastIndexOf(' - ')).trim();
    }
    return '';
  }

  /// Mesaj içindeki {isim} → gerçek isim (yoksa "kardeşim")
  String _personalize(String message, String entry) {
    final name = _extractName(entry);
    return message.replaceAll('{isim}', name.isNotEmpty ? name : 'kardeşim');
  }

  // ==========================================
  // MEDYA SİSTEMİ (URL BAZLI)
  // ==========================================
  final List<String> _selectedMediaUrls = [];
  List<String> get attachedMedia => List.unmodifiable(_selectedMediaUrls);
  int get mediaCount => _selectedMediaUrls.length;
  bool get hasMedia => _selectedMediaUrls.isNotEmpty;

  // ==========================================
  // BASE64 MEDYA SİSTEMİ
  // ==========================================
  final List<Map<String, String>> _base64MediaList = [];
  List<Map<String, String>> get base64MediaList =>
      List.unmodifiable(_base64MediaList);
  int get base64MediaCount => _base64MediaList.length;
  bool get hasBase64Media => _base64MediaList.isNotEmpty;

  Future<bool> pickAndAddBase64Media() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        _addLog('[BİLGİ] Resim seçimi iptal edildi.');
        return false;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        _addLog('[HATA] Dosya okunamadı (Bytes null).');
        return false;
      }
      final base64Image = base64Encode(file.bytes!);
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'bmp' => 'image/bmp',
        _ => 'image/jpeg',
      };
      _base64MediaList.add({
        'fileName': file.name,
        'imageBase64': base64Image,
        'mimeType': mimeType,
      });
      _addLog('[BAŞARILI] Base64 medya eklendi: ${file.name}');
      notifyListeners();
      return true;
    } catch (e) {
      _addLog('[HATA] Base64 resim seçme hatası: $e');
      notifyListeners();
      return false;
    }
  }

  void removeBase64Media(int index) {
    if (index >= 0 && index < _base64MediaList.length) {
      final removed = _base64MediaList.removeAt(index);
      _addLog('[BİLGİ] "${removed['fileName']}" kaldırıldı.');
      notifyListeners();
    }
  }

  void clearAllBase64Media() {
    _base64MediaList.clear();
    _addLog('[BİLGİ] Tüm Base64 medya dosyaları kaldırıldı.');
    notifyListeners();
  }

  Future<List<String>> fetchAvailableMedia() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
          Uri.parse('$_mediaApiUrl/list'), headers: headers);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e.toString()).toList();
      }
    } catch (e) {
      _addLog('[HATA] Sunucudan medya listesi alınamadı: $e');
    }
    return [];
  }

  Future<bool> uploadMediaFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        _addLog('[BİLGİ] Resim seçimi iptal edildi.');
        return false;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        _addLog('[HATA] Dosya okunamadı (Bytes null).');
        return false;
      }
      _addLog('[YÜKLEME] "${file.name}" sunucuya yükleniyor...');
      notifyListeners();

      final request = http.MultipartRequest(
          'POST', Uri.parse('$_mediaApiUrl/upload'));
      final authHeaders = await _getAuthHeaders();
      request.headers.addAll(authHeaders);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String? url;
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            url = data['url'] as String?;
          }
        } catch (_) {}
        if (url != null) {
          addMediaUrl(url);
          _addLog('[BAŞARILI] Yüklendi → $url');
          return true;
        } else {
          _addLog('[HATA] Resim yüklendi ama geri dönen URL okunamadı.');
          return false;
        }
      } else {
        _addLog('[HATA] Yükleme başarısız (${response.statusCode})');
        return false;
      }
    } catch (e) {
      _addLog('[HATA] Yükleme sırasında kritik hata: $e');
      notifyListeners();
      return false;
    }
  }

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

  Future<void> loadFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        _addLog('[BİLGİ] Dosya seçimi iptal edildi.');
        return;
      }
      final file = result.files.first;
      final extension = file.extension?.toLowerCase() ?? '';
      List<String> numbers = [];

      if (extension == 'csv' && file.path != null) {
        try {
          final csvFile = File(file.path!);
          if (await csvFile.exists()) {
            await csvFile.delete();
            _addLog('[BİLGİ] CSV dosyası silindi: ${file.name}');
          }
        } catch (e) {
          _addLog('[UYARI] CSV dosyası silinemedi: $e');
        }
      }

      if (extension == 'txt' || extension == 'csv') {
        final bytes = file.bytes;
        if (bytes == null) {
          _addLog('[HATA] Dosya okunamadı.');
          return;
        }
        final content = utf8.decode(bytes);
        numbers = content
            .split(RegExp(r'[\n,;\r]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (extension == 'xlsx' || extension == 'xls') {
        final bytes = file.bytes;
        if (bytes == null) {
          _addLog('[HATA] Dosya okunamadı.');
          return;
        }
        final excel = Excel.decodeBytes(bytes);
        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table]!;
          for (var row in sheet.rows) {
            for (var cell in row) {
              if (cell != null && cell.value != null) {
                final val = cell.value.toString().trim();
                if (val.isNotEmpty && RegExp(r'\d').hasMatch(val)) {
                  numbers.add(val);
                }
              }
            }
          }
        }
      } else {
        _addLog('[HATA] Desteklenmeyen dosya formatı: .$extension');
        return;
      }

      if (numbers.isEmpty) {
        _addLog('[UYARI] Dosyada numara bulunamadı.');
        return;
      }

      final resumeState = await _getResumeState(file.name);
      final totalCount = numbers.length;

      if (resumeState != null) {
        final alreadySent = resumeState['sentCount'] as int;
        if (alreadySent > 0 && alreadySent < numbers.length) {
          numbers = numbers.sublist(alreadySent);
          _addLog(
              '[DEVAM] "${file.name}" dosyasında $alreadySent/$totalCount numara daha önce gönderilmiş.');
          _addLog('[DEVAM] Kalan ${numbers.length} numaradan devam ediliyor.');
        } else if (alreadySent >= numbers.length) {
          _addLog(
              '[BİLGİ] "${file.name}" dosyasındaki tüm numaralar zaten gönderilmiş. Liste sıfırdan yükleniyor.');
          await _clearResumeState();
        }
      }

      _lastLoadedFileName = file.name;
      _originalFileNumbers = List.from(numbers);

      final existing = phoneController.text.trim();
      final newContent = numbers.join('\n');
      phoneController.text =
          existing.isEmpty ? newContent : '$existing\n$newContent';
      parsePhoneNumbers();
      _addLog(
          '[BAŞARILI] ${numbers.length} numara dosyadan yüklendi (${file.name}).');
      notifyListeners();
    } catch (e) {
      _addLog('[HATA] Dosya okunurken hata: $e');
      notifyListeners();
    }
  }

  bool isImageUrl(String url) {
    final ext = url.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  // ==========================================
  // GÖNDERİM AYARLARI VE DURUMU
  // ==========================================
  final TextEditingController minDelayController =
      TextEditingController(text: '5');
  final TextEditingController maxDelayController =
      TextEditingController(text: '15');

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
      final rawList = raw
          .split(RegExp(r'[\n,;]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      _phoneNumbers = [];
      for (var entry in rawList) {
        // "İsim - Numara" formatından numarayı ayıkla
        String numberPart = entry;
        if (entry.contains(' - ')) {
          numberPart = entry.substring(entry.lastIndexOf(' - ') + 3).trim();
        }
        var cleaned = numberPart.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned.startsWith('0') && cleaned.length == 11) {
          cleaned = '90${cleaned.substring(1)}';
        } else if (cleaned.length == 10 && cleaned.startsWith('5')) {
          cleaned = '90$cleaned';
        }
        if (cleaned.isNotEmpty) _phoneNumbers.add(cleaned);
      }
    }
    notifyListeners();
  }

  // ==========================================
  // API İLETİŞİM METODLARI
  // ==========================================

  Future<void> startSending() async {
    if (_status == SendingStatus.sending) return;


    // Önce rawEntries'i al (parsePhoneNumbers'dan ÖNCE)
    final rawEntries = phoneController.text
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    parsePhoneNumbers();

     // DEBUG — Flutter konsolunda göreceksin
  debugPrint('=== GÖNDERIM DEBUG ===');
  debugPrint('rawEntries: $rawEntries');
  debugPrint('phoneNumbers: $_phoneNumbers');
  debugPrint('isPersonalized: $_personalizedMessage');
  debugPrint('messages: ${splitMessages}');

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
      final messages = splitMessages;

      if (messages.isNotEmpty) {
        for (int i = 0; i < messages.length; i++) {
          final msgTemplate = messages[i];
          if (msgTemplate.isEmpty) continue;

          // Kişiselleştirme açıksa her giriş için ayrı mesaj üret
          final List<String> personalizedMessages = _personalizedMessage
              ? rawEntries
                  .map((entry) => _personalize(msgTemplate, entry))
                  .toList()
              : [];

          debugPrint('personalizedMessages: $personalizedMessages');
          debugPrint('requestBody isPersonalized: $_personalizedMessage');

          Map<String, dynamic> requestBody = {
            'phoneNumbers': _phoneNumbers,
            'message': msgTemplate,
            'personalizedMessages': personalizedMessages,
            'isPersonalized': _personalizedMessage,
            'minDelay': minDelay,
            'maxDelay': maxDelay,
            'media': [],
            if (_activeSessionId != null) 'sessionId': _activeSessionId,
          };

          if (i == 0 && _selectedMediaUrls.isNotEmpty) {
            for (var url in _selectedMediaUrls) {
              (requestBody['media'] as List).add({
                'url': url,
                'type': 'image',
                'fileName': url.split('/').last,
              });
            }
          }

          final authHeaders = await _getAuthHeaders();
          final response = await http.post(
            Uri.parse('$_baseUrl/start'),
            headers: authHeaders,
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            _sessionId = data['sessionId'];
            _addLog('[BAŞARILI] API Session ID: $_sessionId');
            _startPolling();
          } else {
            _status = SendingStatus.idle;
            _addLog('[HATA] API reddetti: ${response.body}');
            notifyListeners();
            break;
          }
        }
      } else if (hasMedia) {
        Map<String, dynamic> requestBody = {
          'phoneNumbers': _phoneNumbers,
          'message': '',
          'personalizedMessages': [],
          'isPersonalized': false,
          'minDelay': minDelay,
          'maxDelay': maxDelay,
          'media': [],
          if (_activeSessionId != null) 'sessionId': _activeSessionId,
        };
        for (var url in _selectedMediaUrls) {
          (requestBody['media'] as List).add({
            'url': url,
            'type': 'image',
            'fileName': url.split('/').last,
          });
        }
        final authHeaders = await _getAuthHeaders();
        final response = await http.post(
          Uri.parse('$_baseUrl/start'),
          headers: authHeaders,
          body: jsonEncode(requestBody),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _sessionId = data['sessionId'];
          _addLog('[BAŞARILI] API Session ID: $_sessionId');
          _startPolling();
        } else {
          _status = SendingStatus.idle;
          _addLog('[HATA] API reddetti: ${response.body}');
          notifyListeners();
        }
      }
    } catch (e) {
      _status = SendingStatus.idle;
      _addLog('[HATA] Backend bağlantısı kurulamadı: $e');
      notifyListeners();
    }
  }

  void _startPolling() {
    _startPollingWithOffset(0);
  }

  void _startPollingWithOffset(int sentOffset) {
    _pollingTimer?.cancel();
    int lastBackendLogCount = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_sessionId == null) return;
      try {
        final headers = await _getAuthHeaders();
        final response = await http.get(
            Uri.parse('$_baseUrl/status/$_sessionId'),
            headers: headers);
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final newSentCount = (data['sentCount'] ?? 0) + sentOffset;
          if (newSentCount != _sentCount) {
            _sentCount = newSentCount;
            _saveResumeState();
          }
          _progress = _phoneNumbers.isNotEmpty
              ? _sentCount / _phoneNumbers.length
              : (data['progress'] ?? 0.0);

          final List<dynamic> backendLogs = data['logs'] ?? [];
          if (backendLogs.length > lastBackendLogCount) {
            for (int i = lastBackendLogCount; i < backendLogs.length; i++) {
              _logs.add(backendLogs[i].toString());
            }
            lastBackendLogCount = backendLogs.length;
            _scrollToBottom();
          }

          final String currentStatus = data['status'];
          if (currentStatus == 'COMPLETED') {
            _status = SendingStatus.completed;
            _pollingTimer?.cancel();
            _clearResumeState();
            _addLog('─── Tüm işlemler tamamlandı ───');
          } else if (currentStatus == 'FAILED') {
            _status = SendingStatus.idle;
            _pollingTimer?.cancel();
            _addLog('─── GÖNDERİM İPTAL OLDU ───');
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Polling hatası: $e');
      }
    });
  }

  Future<void> stopSending() async {
    if (_status != SendingStatus.sending || _sessionId == null) return;
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .post(Uri.parse('$_baseUrl/stop/$_sessionId'), headers: headers);
      if (response.statusCode == 200) {
        _pollingTimer?.cancel();
        _status = SendingStatus.paused;
        _saveResumeState();
        _addLog(
            '[DURDURULDU] İşlem kullanıcı tarafından durduruldu. Kaldığınız yerden devam edebilirsiniz.');
        notifyListeners();
      }
    } catch (e) {
      _addLog('[HATA] Durdurma isteği başarısız: $e');
    }
  }

  Future<void> resumeSending() async {
    if (_status != SendingStatus.paused) return;

    parsePhoneNumbers();

    if (_phoneNumbers.isEmpty) {
      _addLog('[HATA] Devam edilecek telefon numarası bulunamadı.');
      return;
    }

    final remaining = _phoneNumbers.sublist(_sentCount);
    if (remaining.isEmpty) {
      _addLog('[BİLGİ] Gönderilecek numara kalmadı.');
      _status = SendingStatus.completed;
      _clearResumeState();
      notifyListeners();
      return;
    }

    _status = SendingStatus.sending;
    _addLog(
        '─── Gönderim kaldığı yerden devam ediyor ($_sentCount/${_phoneNumbers.length}) ───');
    notifyListeners();

    try {
      final messages = splitMessages
          .where((m) => m != messageSplitMarker && m.trim().isNotEmpty)
          .toList();

      Map<String, dynamic> requestBody = {
        'phoneNumbers': remaining,
        'message': messageController.text.trim(),
        'messages': messages,
        'personalizedMessages': [],
        'isPersonalized': false,
        'minDelay': minDelay,
        'maxDelay': maxDelay,
        'media': [],
        if (_activeSessionId != null) 'sessionId': _activeSessionId,
      };

      if (_selectedMediaUrls.isNotEmpty) {
        for (var url in _selectedMediaUrls) {
          (requestBody['media'] as List).add({
            'url': url,
            'type': 'image',
            'fileName': url.split('/').last,
          });
        }
      }

      final previousSent = _sentCount;
      final authHeaders = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/start'),
        headers: authHeaders,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionId = data['sessionId'];
        _addLog('[BAŞARILI] Devam ediliyor - API Session ID: $_sessionId');
        _startPollingWithOffset(previousSent);
      } else {
        _status = SendingStatus.paused;
        _addLog('[HATA] API reddetti: ${response.body}');
        notifyListeners();
      }
    } catch (e) {
      _status = SendingStatus.paused;
      _addLog('[HATA] Backend bağlantısı kurulamadı: $e');
      notifyListeners();
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
    _base64MediaList.clear();
    _lastLoadedFileName = null;
    notifyListeners();
  }

  // ==========================================
  // DEVAM (RESUME) SİSTEMİ
  // ==========================================

  Future<void> _saveResumeState() async {
    if (_lastLoadedFileName == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = {
        'fileName': _lastLoadedFileName,
        'sentCount': _sentCount,
        'messageHash': messageController.text.trim().hashCode,
      };
      await prefs.setString('resume_state', jsonEncode(state));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getResumeState(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString('resume_state');
      if (stateJson == null) return null;
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      final currentMsgHash = messageController.text.trim().hashCode;
      if (state['fileName'] == fileName &&
          state['messageHash'] == currentMsgHash) {
        return state;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _clearResumeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('resume_state');
    } catch (_) {}
    _lastLoadedFileName = null;
    _originalFileNumbers.clear();
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
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