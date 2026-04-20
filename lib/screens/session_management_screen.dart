import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';

class SessionManagementScreen extends StatefulWidget {
  const SessionManagementScreen({super.key});

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  List<SessionModel> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<SessionService> _getSessionService() async {
    String token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      token = await AuthService.getToken() ?? '';
      debugPrint('[SessionMgmt] AuthProvider token boş, SharedPreferences\'tan okundu: ${token.isNotEmpty ? "VAR (${token.length} karakter)" : "BOŞ"}');
    }
    return SessionService(token: token);
  }

  Future<void> _loadSessions() async {
    final service = await _getSessionService();
    final sessions = await service.getAllSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meta API Entegrasyon Durumu'),
        actions: [
          IconButton(
            onPressed: _loadSessions,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: const Text(
                    'Bu ekran yalnızca bilgilendirme amaçlıdır. Meta API tekil akış kullandığı için QR, yeni oturum oluşturma veya oturum silme işlemleri kapatılmıştır.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'Aktif oturum bilgisi bulunamadı.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Backend entegrasyonu tamamlandığında durum burada gösterilir.',
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
                            return _SessionCard(session: session);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;

  const _SessionCard({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = session.connected;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
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
                        ? 'Bağlı${session.user != null && session.user!.isNotEmpty ? ' — ${session.user}' : ''}'
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
          ],
        ),
      ),
    );
  }
}
