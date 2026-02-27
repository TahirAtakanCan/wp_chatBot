import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sending_state.dart';

class MessageProvider extends ChangeNotifier {
  // --- Kişi Listesi ---
  final TextEditingController phoneController = TextEditingController();
  List<String> _phoneNumbers = [];
  List<String> get phoneNumbers => _phoneNumbers;
  int get phoneCount => _phoneNumbers.length;

  // --- Mesaj İçeriği ---
  final TextEditingController messageController = TextEditingController();

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

    _addLog(
        '[GÖNDER] $currentNumber numarasına mesaj gönderildi. ✔');

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