import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;
  DateTime _lastPlayed = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minInterval = Duration(seconds: 2);
  bool _isInitialized = false;

  bool get isSoundEnabled => _soundEnabled;

  void enableSound(bool enable) {
    _soundEnabled = enable;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb && Platform.isWindows) {
      await localNotifier.setup(
        appName: 'IHH WhatsApp Bot',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      await windowManager.ensureInitialized();
    }
    _isInitialized = true;
  }

  Future<void> playNewMessageSound({String? contactName, String? preview}) async {
    if (!_soundEnabled) return;

    final now = DateTime.now();
    if (now.difference(_lastPlayed) < _minInterval) return;
    _lastPlayed = now;

    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      if (kDebugMode) {
        print('Ses calinamadi: $e');
      }
    }

    if (!kIsWeb && Platform.isWindows) {
      try {
        final notification = LocalNotification(
          title: contactName ?? 'Yeni Mesaj',
          body: preview ?? 'WhatsApp\'ta yeni bir mesaj var',
        );
        await notification.show();

        final isFocused = await windowManager.isFocused();
        if (!isFocused) {
          await windowManager.setSkipTaskbar(false);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Windows bildirim hatasi: $e');
        }
      }
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
