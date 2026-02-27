import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/sending_state.dart';

class MessageProvider extends ChangeNotifier {
  // --- Kişi Listesi ---
  final TextEditingController phoneController = TextEditingController();
  List<String> _phoneNumbers = [];
  List<String> get phoneNumbers => _phoneNumbers;
  int get phoneCount => _phoneNumbers.length;

  // --- Mesaj İçeriği ---
  final TextEditingController messageController = TextEditingController();

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
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          // Tekrar eklemeyi engelle
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

  /// Tek bir medya dosyasını kaldır
  void removeMedia(int index) {
    if (index >= 0 && index < _attachedMedia.length) {
      final removed = _attachedMedia.removeAt(index);
      _addLog('[BİLGİ] "${removed.name}" kaldırıldı. Kalan: $mediaCount');
      notifyListeners();
    }
  }

  /// Tüm medya dosyalarını temizle
  void clearAllMedia() {
    _attachedMedia.clear();
    _addLog('[BİLGİ] Tüm medya dosyaları kaldırıldı.');
    notifyListeners();
  }

  /// Dosya uzantısına göre resim mi kontrol et
  bool isImageFile(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  /// Dosya boyutunu okunabilir formata çevir
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // --- Gönderim Ayarları ---
  final TextEditingController minDelayController =
      TextEditingController(text: '5');
  final TextEditingController maxDelayController =
      TextEditingController(text: '15');

  int get minDelay => int.tryParse(minDelayController.text) ?? 5;
  int get maxDelay => int.tryParse(maxDelayController.text) ?? 15;

  // --- Gönderim Durumu ---
  SendingStatus _status = SendingStatus.idle;
  SendingStatus get status => _status;

  int _sentCount = 0;
  int get sentCount => _sentCount;

  double get progress =>
      _phoneNumbers.isEmpty ? 0.0 : _sentCount / _phoneNumbers.length;

  // --- Log ---
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  final ScrollController logScrollController = ScrollController();

  Timer? _sendTimer;

  /// Telefon numaralarını parse et
  void parsePhoneNumbers() {
    final raw = phoneController.text.trim();
    if (raw.isEmpty) {
      _phoneNumbers = [];
    } else {
      _phoneNumbers = raw
          .split(RegExp(r'[\n,;]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    notifyListeners();
  }

  /// TXT/Excel'den yükleme (şimdilik placeholder)
  void loadFromFile() {
    _addLog('[BİLGİ] Dosyadan yükleme özelliği henüz aktif değil.');
    notifyListeners();
  }

  /// Gönderimi başlat
  void startSending() {
    if (_status == SendingStatus.sending) return;

    parsePhoneNumbers();

    if (_phoneNumbers.isEmpty) {
      _addLog('[HATA] Gönderilecek telefon numarası bulunamadı.');
      notifyListeners();
      return;
    }

    final message = messageController.text.trim();
    if (message.isEmpty) {
      _addLog('[HATA] Mesaj içeriği boş olamaz.');
      notifyListeners();
      return;
    }

    if (minDelay > maxDelay) {
      _addLog(
          '[HATA] Minimum bekleme süresi, maksimum bekleme süresinden büyük olamaz.');
      notifyListeners();
      return;
    }

    _status = SendingStatus.sending;
    _sentCount = 0;
    _addLog('─── Gönderim başlatıldı ───');
    _addLog(
        '[BİLGİ] Toplam ${_phoneNumbers.length} numaraya mesaj gönderilecek.');
    if (_attachedMedia.isNotEmpty) {
      _addLog('[BİLGİ] ${_attachedMedia.length} medya dosyası mesajla birlikte gönderilecek.');
    }
    _addLog(
        '[BİLGİ] Bekleme aralığı: $minDelay - $maxDelay saniye.');
    notifyListeners();

    _simulateSending();
  }

  /// Simüle gönderim (gerçek API yerine demo amaçlı)
  void _simulateSending() {
    if (_sentCount >= _phoneNumbers.length) {
      _status = SendingStatus.completed;
      _addLog('─── Tüm mesajlar gönderildi ───');
      notifyListeners();
      return;
    }

    if (_status != SendingStatus.sending) return;

    final currentNumber = _phoneNumbers[_sentCount];
    final delay = minDelay +
        (DateTime.now().millisecondsSinceEpoch % (maxDelay - minDelay + 1));

    final mediaInfo = _attachedMedia.isNotEmpty
        ? ' (+${_attachedMedia.length} medya)'
        : '';
    _addLog(
        '[GÖNDER] $currentNumber numarasına mesaj$mediaInfo gönderildi. ✔');

    _sentCount++;
    notifyListeners();

    if (_sentCount < _phoneNumbers.length) {
      _addLog(
          '[BEKLE] Sıradaki mesaj için $delay saniye bekleniyor...');
      notifyListeners();

      // TODO: Gerçek uygulamada burada HTTP isteği atılacak.
      // Şimdilik kısa bir süre ile simüle ediyoruz.
      _sendTimer = Timer(Duration(seconds: delay), () {
        _simulateSending();
      });
    } else {
      _status = SendingStatus.completed;
      _addLog('─── Tüm mesajlar başarıyla gönderildi! ───');
      notifyListeners();
    }
  }

  /// Gönderimi durdur
  void stopSending() {
    if (_status != SendingStatus.sending) return;

    _sendTimer?.cancel();
    _sendTimer = null;
    _status = SendingStatus.paused;
    _addLog('[DURDURULDU] Gönderim kullanıcı tarafından durduruldu. '
        '($_sentCount / ${_phoneNumbers.length})');
    notifyListeners();
  }

  /// Sıfırla
  void resetState() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _status = SendingStatus.idle;
    _sentCount = 0;
    _logs.clear();
    _attachedMedia.clear();
    notifyListeners();
  }

  /// Log satırı ekle
  void _addLog(String message) {
    final timestamp = _formatTime(DateTime.now());
    _logs.add('[$timestamp] $message');

    // Log ekranını aşağı kaydır
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

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    phoneController.dispose();
    messageController.dispose();
    minDelayController.dispose();
    maxDelayController.dispose();
    logScrollController.dispose();
    _sendTimer?.cancel();
    super.dispose();
  }
}