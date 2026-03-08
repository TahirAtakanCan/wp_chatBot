import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../providers/message_provider.dart';
import '../services/session_service.dart';
import '../widgets/whatsapp_qr_connector.dart';

class SessionManagementScreen extends StatefulWidget {
  const SessionManagementScreen({super.key});

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  List<SessionModel> _sessions = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadSessions(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await SessionService.getAllSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  Future<void> _createSession(String sessionId) async {
    final ok = await SessionService.createSession(sessionId);
    if (ok) {
      _loadSessions();
      // Session oluşturulduktan sonra otomatik QR dialog aç
      if (mounted) {
        WhatsappQrConnector.showQrDialog(context, sessionId);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session oluşturulamadı.')),
      );
    }
  }

  void _selectSession(String sessionId) {
    context.read<MessageProvider>().setActiveSession(sessionId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aktif hesap: $sessionId')),
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    final ok = await SessionService.deleteSession(sessionId);
    if (ok) {
      _loadSessions();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session silinemedi.')),
      );
    }
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni WhatsApp Hesabı'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Session ID',
            hintText: 'Örn: ihh-hesap-1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final id = controller.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(ctx);
                _createSession(id);
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Hesap Yönetimi'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Hesap Ekle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_android,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz WhatsApp hesabı eklenmemiş.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sağ alttaki butona basarak yeni hesap ekleyin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _SessionCard(
                      session: session,
                      onDelete: () => _deleteSession(session.sessionId),
                      onShowQr: () => WhatsappQrConnector.showQrDialog(
                        context,
                        session.sessionId,
                      ),
                      onSelect: () => _selectSession(session.sessionId),
                      isActive: session.sessionId ==
                          context.read<MessageProvider>().activeSessionId,
                    );
                  },
                ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onDelete;
  final VoidCallback onShowQr;
  final VoidCallback onSelect;
  final bool isActive;

  const _SessionCard({
    required this.session,
    required this.onDelete,
    required this.onShowQr,
    required this.onSelect,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = session.connected;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? const Color(0xFF4CAF50) : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: connected ? onSelect : null,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Durum ikonu
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                connected ? Icons.check_circle : Icons.error_outline,
                color: connected
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFE65100),
              ),
            ),
            const SizedBox(width: 16),

            // Session bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.sessionId,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connected
                        ? 'Bağlı${session.user != null && session.user!.isNotEmpty ? ' — ${session.user}' : ''}${isActive ? '  ✓ Aktif' : ''}'
                        : 'Bağlı Değil',
                    style: TextStyle(
                      fontSize: 13,
                      color: connected
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Aksiyon butonları
            if (!connected)
              FilledButton.icon(
                onPressed: onShowQr,
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('QR Göster'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Session Sil',
              style: IconButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
