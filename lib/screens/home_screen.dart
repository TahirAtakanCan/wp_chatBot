import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ihh_project_chatbot/screens/contacts_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../screens/session_management_screen.dart';
import '../screens/templates_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/login_screen.dart';
import '../services/session_service.dart';
import '../widgets/contact_list_panel.dart';
import '../widgets/message_content_panel.dart';
import '../widgets/action_panel.dart';
import '../widgets/progress_log_panel.dart';
import '../widgets/anti_spam_drawer.dart';
import '../widgets/whatsapp_qr_connector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _autoSelectTimer;
  List<String> _selectedContactNumbers = [];

  @override
  void initState() {
    super.initState();
    _tryAutoSelectSession();
  }

  @override
  void dispose() {
    _autoSelectTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryAutoSelectSession() async {
    final provider = context.read<MessageProvider>();
    if (provider.activeSessionId != null) return;

    final token = context.read<AuthProvider>().token ?? '';
    final sessions = await SessionService(token: token).getAllSessions();
    final connected = sessions.where((s) => s.connected).toList();

    if (connected.isNotEmpty) {
      provider.setActiveSession(connected.first.sessionId);
    } else {
      // Bağlı session yoksa 3 saniye sonra tekrar dene
      _autoSelectTimer?.cancel();
      _autoSelectTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _tryAutoSelectSession();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            // IHH Logo alanı
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/ihh_logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.public, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İHH İnsani Yardım Vakfı - Seydişehir Temsilciliği',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Toplu Mesaj Gönderim Sistemi',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          Tooltip(
            message: 'Rehber',
            child: IconButton.filledTonal(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactsScreen(
                      initiallySelectedNumbers: _selectedContactNumbers,
                    ),
                  ),
                );
                if (result == null) {
                  // Seçimi Temizle ile dönüldü
                  setState(() {
                    _selectedContactNumbers = [];
                  });
                } else if (result is List<String>) {
                  setState(() {
                    _selectedContactNumbers.addAll(
                      result.where((num) => !_selectedContactNumbers.contains(num)),
                    );
                  });
                }
              },
              icon: const Icon(Icons.contacts, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Şablonlar',
            child: IconButton.filledTonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TemplatesScreen(),
                ),
              ),
              icon: const Icon(Icons.bookmark, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          // WhatsApp Hesap Yönetimi (sadece ADMIN)
          if (context.read<AuthProvider>().isAdmin)
            Tooltip(
              message: 'WhatsApp Hesapları',
              child: IconButton.filledTonal(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SessionManagementScreen(),
                  ),
                ),
                icon: const Icon(Icons.phone_android, size: 22),
              ),
            ),
          const SizedBox(width: 8),
          // Kullanıcı Yönetimi (sadece ADMIN)
          if (context.read<AuthProvider>().isAdmin)
            Tooltip(
              message: 'Kullanıcılar',
              child: IconButton.filledTonal(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserManagementScreen(),
                  ),
                ),
                icon: const Icon(Icons.people, size: 22),
              ),
            ),
          const SizedBox(width: 8),
          // WhatsApp bağlantı durumu
          Consumer<MessageProvider>(
            builder: (context, provider, _) {
              final sessionId = provider.activeSessionId;
              if (sessionId == null || sessionId.isEmpty) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: const Color(0xFFFF9800), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFE65100), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Hesap seçilmedi',
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
              return WhatsappQrConnector(
                key: ValueKey(sessionId),
                sessionId: sessionId,
              );
            },
          ),
          const SizedBox(width: 12),
          // Anti-Spam Ayarları butonu
          Tooltip(
            message: 'Anti-Spam Ayarları',
            child: IconButton.filledTonal(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.shield_outlined, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          // Çıkış butonu
          Tooltip(
            message: 'Çıkış Yap',
            child: IconButton.filledTonal(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, size: 22),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      endDrawer: const AntiSpamDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Üst kısım: Kişi listesi + Mesaj içeriği yan yana
            Expanded(
              flex: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sol panel - Kişi Listesi
                  Expanded(
                    flex: 4,
                    child: ContactListPanel(
                      rehberdenSecilenler: _selectedContactNumbers,
                      onRehberdenSec: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContactsScreen(
                              initiallySelectedNumbers: _selectedContactNumbers,
                            ),
                          ),
                        );
                        if (result == null) {
                          setState(() {
                            _selectedContactNumbers.clear();
                          });
                        } else if (result is List<String>) {
                          setState(() {
                            _selectedContactNumbers.addAll(
                              result.where((num) => !_selectedContactNumbers.contains(num)),
                            );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Sağ panel - Mesaj + Aksiyon
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: const [
                        Expanded(
                          child: MessageContentPanel(),
                        ),
                        SizedBox(height: 12),
                        ActionPanel(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Alt kısım - İlerleme ve Log
            const Expanded(
              flex: 4,
              child: ProgressLogPanel(),
            ),
          ],
        ),
      ),
    );
  }
}
