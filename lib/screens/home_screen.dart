import 'package:flutter/material.dart';
import 'package:ihh_project_chatbot/screens/contacts_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/session_management_screen.dart';
import '../screens/templates_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/login_screen.dart';
import '../services/session_service.dart';
import '../widgets/contact_list_panel.dart';
import '../widgets/message_content_panel.dart';
import '../widgets/action_panel.dart';
import '../widgets/progress_log_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> _selectedContactNumbers = [];
  bool? _metaApiConnected;

  @override
  void initState() {
    super.initState();
    _checkMetaApiConnection();
  }

  Future<void> _checkMetaApiConnection() async {
    final token = context.read<AuthProvider>().token ?? '';
    final reachable =
        await SessionService(token: token).isIntegrationReachable();
    if (!mounted) return;
    setState(() {
      _metaApiConnected = reachable;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = _metaApiConnected == null
      ? const Color(0xFFFFF8E1)
      : (_metaApiConnected == true
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE));
    final badgeBorder = _metaApiConnected == null
      ? const Color(0xFFFFB300)
      : (_metaApiConnected == true
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935));
    final badgeIcon = _metaApiConnected == null
      ? Icons.sync
      : (_metaApiConnected == true ? Icons.check_circle : Icons.error);
    final badgeText = _metaApiConnected == null
      ? 'Meta API kontrol ediliyor'
      : (_metaApiConnected == true
        ? 'Meta API Bağlı'
        : 'Meta API Ulaşılamıyor');
    final badgeTextColor = _metaApiConnected == null
      ? const Color(0xFF7A5A00)
      : (_metaApiConnected == true
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828));

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
                // Seçimi Temizle ile dönüldü veya boş liste döndü
                setState(() {
                  _selectedContactNumbers = (result is List<String>) ? result : [];
                });
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
              message: 'Entegrasyon Durumu',
              child: IconButton.filledTonal(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SessionManagementScreen(),
                    ),
                  );
                  _checkMetaApiConnection();
                },
                icon: const Icon(Icons.monitor_heart_outlined, size: 22),
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
          
          // Meta API Bağlantı Durumu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: badgeTextColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
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
                        setState(() {
                          _selectedContactNumbers = (result is List<String>) ? result : [];
                        });
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
