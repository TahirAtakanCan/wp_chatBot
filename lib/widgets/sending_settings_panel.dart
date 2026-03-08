import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../providers/message_provider.dart';
import '../services/session_service.dart';

class SendingSettingsPanel extends StatefulWidget {
  const SendingSettingsPanel({super.key});

  @override
  State<SendingSettingsPanel> createState() => _SendingSettingsPanelState();
}

class _SendingSettingsPanelState extends State<SendingSettingsPanel> {
  List<SessionModel> _connectedSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await SessionService.getAllSessions();
    if (mounted) {
      setState(() {
        _connectedSessions =
            sessions.where((s) => s.connected).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Anti-Spam Ayarları',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Min bekleme
            SizedBox(
              width: 160,
              child: TextField(
                controller: provider.minDelayController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Min Bekleme (sn)',
                  isDense: true,
                  prefixIcon: Icon(Icons.hourglass_top, size: 18),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            // Max bekleme
            SizedBox(
              width: 160,
              child: TextField(
                controller: provider.maxDelayController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Max Bekleme (sn)',
                  isDense: true,
                  prefixIcon: Icon(Icons.hourglass_bottom, size: 18),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            // Gönderen Hesap Seçimi
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                value: _connectedSessions.any(
                        (s) => s.sessionId == provider.activeSessionId)
                    ? provider.activeSessionId
                    : null,
                decoration: InputDecoration(
                  labelText: 'Gönderen Hesap',
                  isDense: true,
                  prefixIcon: Icon(Icons.phone_android,
                      size: 18, color: theme.colorScheme.primary),
                ),
                items: _connectedSessions.map((session) {
                  return DropdownMenuItem<String>(
                    value: session.sessionId,
                    child: Text(
                      session.user != null && session.user!.isNotEmpty
                          ? '${session.sessionId} (${session.user})'
                          : session.sessionId,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    provider.setActiveSession(value);
                  }
                },
                onTap: _loadSessions,
              ),
            ),
            // Bilgi etiketi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 4),
                  Text(
                    'Her mesaj arasında rastgele beklenir',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onTertiaryContainer,
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