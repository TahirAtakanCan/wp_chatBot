import 'package:flutter/material.dart';
import '../widgets/contact_list_panel.dart';
import '../widgets/message_content_panel.dart';
import '../widgets/sending_settings_panel.dart';
import '../widgets/action_panel.dart';
import '../widgets/progress_log_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.send_rounded, size: 28),
            SizedBox(width: 10),
            Text(
              'Toplu Mesaj Gönderim Arayüzü',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 2,
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
                  const Expanded(
                    flex: 4,
                    child: ContactListPanel(),
                  ),
                  const SizedBox(width: 16),
                  // Sağ panel - Mesaj + Ayarlar + Aksiyon
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: const [
                        Expanded(
                          child: MessageContentPanel(),
                        ),
                        SizedBox(height: 12),
                        SendingSettingsPanel(),
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
