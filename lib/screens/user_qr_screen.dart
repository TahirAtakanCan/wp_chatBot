import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class UserQrScreen extends StatefulWidget {
  final String sessionId;

  const UserQrScreen({super.key, required this.sessionId});

  @override
  State<UserQrScreen> createState() => _UserQrScreenState();
}

class _UserQrScreenState extends State<UserQrScreen> {
  Timer? _timer;
  String? _qrData;
  bool _connected = false;
  String? _connectedUser;

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
    _checkStatus();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final token = context.read<AuthProvider>().token;
      final sid = Uri.encodeComponent(widget.sessionId);
      final headers = token != null
          ? AppConfig.authHeaders(token)
          : <String, String>{'Content-Type': 'application/json'};

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseHost}/api/session/$sid/status'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final connected = data['connected'] as bool? ?? false;
        final qr = data['qr'] as String?;
        final user = data['connectedUser'] as String? ??
            data['user'] as String? ??
            '';

        setState(() {
          _connected = connected;
          _connectedUser = user;
          if (!connected && qr != null && qr.isNotEmpty) {
            _qrData = qr;
          }
        });

        if (connected) {
          _timer?.cancel();
        }
      }
    } catch (_) {}
  }

  void _goToMessaging() {
    context.read<MessageProvider>().setActiveSession(widget.sessionId);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('WhatsApp Bağlantısı'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Çıkış'),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _connected ? _buildConnectedView() : _buildQrView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF25D366), size: 72),
        const SizedBox(height: 16),
        const Text(
          'WhatsApp Bağlandı!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        if (_connectedUser != null && _connectedUser!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _connectedUser!,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _goToMessaging,
            icon: const Icon(Icons.send),
            label: const Text('Mesaj Gönderime Geç'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.qr_code_2, color: Color(0xFF25D366), size: 48),
        const SizedBox(height: 12),
        Text(
          'Session: ${widget.sessionId}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'WhatsApp uygulamanızdan QR kodu okutun',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        if (_qrData != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: QrImageView(
              data: _qrData!,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
          )
        else
          SizedBox(
            height: 240,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF25D366),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QR kod bekleniyor...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
