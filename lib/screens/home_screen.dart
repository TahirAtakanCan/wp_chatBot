import 'package:flutter/material.dart';
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
                  child: const Icon(Icons.public,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İHH İnsani Yardım Vakfı',
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
          // WhatsApp bağlantı durumu
          const WhatsappQrConnector(),
          const SizedBox(width: 12),
          // Anti-Spam Ayarları butonu
          Tooltip(
            message: 'Anti-Spam Ayarları',
            child: IconButton.filledTonal(
              onPressed: () =>
                  _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.shield_outlined, size: 22),
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
                  const Expanded(
                    flex: 4,
                    child: ContactListPanel(),
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
