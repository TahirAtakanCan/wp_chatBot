import 'dart:async';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sending_state.dart';

class MessageProvider extends ChangeNotifier {
  // --- API Ayarları ---
  final String _baseUrl = 'http://94.130.231.165:8080/api/send';
  final String _mediaApiUrl = 'http://94.130.231.165:8080/api/media'; // Resimleri çekeceğimiz yeni API
  String? _sessionId;
  Timer? _pollingTimer;

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

  /// Bilgisayardan resim seçip sunucuya yükler, dönen URL'i listeye ekler
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
        _addLog('[HATA] Dosya okunamadı.');
        return false;
      }

      _addLog('[YÜKLEME] "${file.name}" sunucuya yükleniyor...');
      notifyListeners();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_mediaApiUrl/upload'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String? url;

        // Önce JSON olarak parse etmeyi dene
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            url = data['url'] as String?;
          }
        } catch (_) {
          // JSON değilse düz metin dönmüş demektir, URL'i dosya adından oluştur
        }

        // JSON'dan URL gelemediyse, dosya adından URL oluştur
        url ??= '$_mediaApiUrl/uploads/${Uri.encodeComponent(file.name)}';

        addMediaUrl(url);
        _addLog('[BAŞARILI] "${file.name}" yüklendi → $url');
        return true;
      } else {
        _addLog('[HATA] Yükleme başarısız (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      _addLog('[HATA] Dosya yüklenirken hata: $e');
      notifyListeners();
      return false;
    }
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

      // Devam durumunu kontrol et
      final resumeState = await _getResumeState(file.name);
      final totalCount = numbers.length;

      if (resumeState != null) {
        final alreadySent = resumeState['sentCount'] as int;
        if (alreadySent > 0 && alreadySent < numbers.length) {
          numbers = numbers.sublist(alreadySent);
          _addLog('[DEVAM] "${file.name}" dosyasında $alreadySent/$totalCount numara daha önce gönderilmiş.');
          _addLog('[DEVAM] Kalan ${numbers.length} numaradan devam ediliyor.');
        } else if (alreadySent >= numbers.length) {
          _addLog('[BİLGİ] "${file.name}" dosyasındaki tüm numaralar zaten gönderilmiş. Liste sıfırdan yükleniyor.');
          await _clearResumeState();
        }
      }

      _lastLoadedFileName = file.name;
      _originalFileNumbers = List.from(numbers);

      // Mevcut numaralara ekle
      final existing = phoneController.text.trim();
      final newContent = numbers.join('\n');
      phoneController.text = existing.isEmpty ? newContent : '$existing\n$newContent';
      parsePhoneNumbers();
      _addLog('[BAŞARILI] ${numbers.length} numara dosyadan yüklendi (${file.name}).');
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
    _startPollingWithOffset(0);
  }

  void _startPollingWithOffset(int sentOffset) {
    _pollingTimer?.cancel();
    int _lastBackendLogCount = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_sessionId == null) return;

      try {
        var response = await http.get(Uri.parse('$_baseUrl/status/$_sessionId'));
        if (response.statusCode == 200) {
          var data = jsonDecode(utf8.decode(response.bodyBytes)); 
          final newSentCount = (data['sentCount'] ?? 0) + sentOffset;
          if (newSentCount != _sentCount) {
            _sentCount = newSentCount;
            _saveResumeState();
          }
          _progress = _phoneNumbers.isNotEmpty
              ? _sentCount / _phoneNumbers.length
              : (data['progress'] ?? 0.0);
          
          List<dynamic> backendLogs = data['logs'] ?? [];
          if (backendLogs.length > _lastBackendLogCount) {
            for (int i = _lastBackendLogCount; i < backendLogs.length; i++) {
              _logs.add(backendLogs[i].toString());
            }
            _lastBackendLogCount = backendLogs.length;
            _scrollToBottom();
          }

          String currentStatus = data['status'];
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
        _saveResumeState();
        _addLog('[DURDURULDU] İşlem kullanıcı tarafından durduruldu. Kaldığınız yerden devam edebilirsiniz.');
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

    // Daha önce gönderilenleri atla
    final remaining = _phoneNumbers.sublist(_sentCount);
    if (remaining.isEmpty) {
      _addLog('[BİLGİ] Gönderilecek numara kalmadı.');
      _status = SendingStatus.completed;
      _clearResumeState();
      notifyListeners();
      return;
    }

    _status = SendingStatus.sending;
    _addLog('─── Gönderim kaldığı yerden devam ediyor ($_sentCount/${_phoneNumbers.length}) ───');
    notifyListeners();

    try {
      final messages = splitMessages.where((m) => m != messageSplitMarker && m.trim().isNotEmpty).toList();

      Map<String, dynamic> requestBody = {
        'phoneNumbers': remaining,
        'message': messageController.text.trim(),
        'messages': messages,
        'minDelay': minDelay,
        'maxDelay': maxDelay,
        'media': [],
      };

      if (hasMedia) {
        for (var url in _selectedMediaUrls) {
          requestBody['media'].add({
            'url': url,
            'type': 'image',
            'fileName': url.split('/').last,
          });
        }
      }

      final previousSent = _sentCount;

      var response = await http.post(
        Uri.parse('$_baseUrl/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
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
    _lastLoadedFileName = null;
    _originalFileNumbers.clear();
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
      if (state['fileName'] == fileName && state['messageHash'] == currentMsgHash) {
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