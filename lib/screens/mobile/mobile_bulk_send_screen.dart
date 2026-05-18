import 'package:flutter/material.dart';

import '../contacts_screen.dart';
import '../../widgets/action_panel.dart';
import '../../widgets/contact_list_panel.dart';
import '../../widgets/preset_message_content_panel.dart';
import '../../widgets/progress_log_panel.dart';

class MobileBulkSendScreen extends StatefulWidget {
  const MobileBulkSendScreen({super.key});

  @override
  State<MobileBulkSendScreen> createState() => _MobileBulkSendScreenState();
}

class _MobileBulkSendScreenState extends State<MobileBulkSendScreen> {
  List<String> _selectedContactNumbers = [];

  Future<void> _openContacts() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactsScreen(
          initiallySelectedNumbers: _selectedContactNumbers,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _selectedContactNumbers = (result is List<String>) ? result : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toplu Mesaj Gonder'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Numaralar',
              child: SizedBox(
                height: 280,
                child: ContactListPanel(
                  rehberdenSecilenler: _selectedContactNumbers,
                  onRehberdenSec: _openContacts,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Hazır Kayıt',
              child: SizedBox(
                height: 360,
                child: MessageContentPanel(),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Gonderim Kontrolu',
              child: const ActionPanel(),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Ilerleme & Log',
              child: SizedBox(
                height: 320,
                child: ProgressLogPanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
