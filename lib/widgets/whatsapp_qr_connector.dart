import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class WhatsappQrConnector extends StatefulWidget {
  const WhatsappQrConnector({super.key});

  @override
  State<WhatsappQrConnector> createState() => _WhatsappQrConnectorState();
}

class _WhatsappQrConnectorState extends State<WhatsappQrConnector> {
  static const String _baseUrl = 'http://localhost:8080';

  Timer? _timer;
  bool _connected = false;
  String? _connectedUser;
  String? _lastQr;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // İlk kontrolü hemen yap
    _checkStatus();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/system-status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final connected = data['connected'] as bool? ?? false;
        final qr = data['qr'] as String?;
        final user = data['connectedUser'] as String? ??
            data['user'] as String? ??
            '';

        if (connected) {
          _handleConnected(user);
        } else if (qr != null && qr.isNotEmpty) {
          _handleQrReceived(qr);
        }
      }
    } catch (_) {
      // Sunucuya ulaşılamıyorsa sessizce devam et
    }
  }

  void _handleConnected(String user) {
    _timer?.cancel();
    if (_dialogOpen && mounted) {
      Navigator.of(context).pop();
      _dialogOpen = false;
    }
    if (mounted) {
      setState(() {
        _connected = true;
        _connectedUser = user;
      });
    }
  }

  void _handleQrReceived(String qr) {
    if (_dialogOpen) {
      // Dialog zaten açıksa QR'ı güncelle
      if (_lastQr != qr && mounted) {
        setState(() => _lastQr = qr);
      }
      return;
    }

    _lastQr = qr;
    _dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QrDialog(connector: this),
    ).then((_) => _dialogOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_connected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Text(
              _connectedUser != null && _connectedUser!.isNotEmpty
                  ? 'WhatsApp Bağlı: $_connectedUser'
                  : 'WhatsApp Bağlı',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF9800), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFE65100),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'WhatsApp bağlantısı bekleniyor…',
            style: TextStyle(
              color: Color(0xFFE65100),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR Dialog ─────────────────────────────────────────────────────────

class _QrDialog extends StatelessWidget {
  final _WhatsappQrConnectorState connector;

  const _QrDialog({required this.connector});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChangeNotifier(),
      builder: (_, __) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final qr = connector._lastQr ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WhatsApp İkonu
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.chat, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),

            // Başlık
            const Text(
              'WhatsApp Bağlantısı',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),

            // Açıklama
            Text(
              'Telefonunuzda WhatsApp\'ı açın ve\naşağıdaki QR kodu taratın',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // QR Kod
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: qr,
                version: QrVersions.auto,
                size: 220,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 24),

            // Bağlantı bekleniyor
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Bağlantı bekleniyor...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
