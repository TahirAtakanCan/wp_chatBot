import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/sending_state.dart';
import '../providers/message_provider.dart';
import '../theme/wa_colors.dart';
import 'home_panel_card.dart';

class ProgressLogPanel extends StatelessWidget {
  const ProgressLogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final theme = Theme.of(context);

    final progressPercent = (provider.progress * 100).toStringAsFixed(1);

    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    switch (provider.status) {
      case SendingStatus.idle:
        statusLabel = 'Hazır';
        statusColor = Colors.grey;
        statusIcon = Icons.circle_outlined;
        break;
      case SendingStatus.sending:
        statusLabel = 'Gönderiliyor...';
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        break;
      case SendingStatus.paused:
        statusLabel = 'Durduruldu';
        statusColor = Colors.red;
        statusIcon = Icons.pause_circle;
        break;
      case SendingStatus.rateLimited:
        statusLabel = 'Rate Limit: Gönderim Durduruldu';
        statusColor = Colors.deepOrange;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case SendingStatus.completed:
        statusLabel = 'Tamamlandı';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
    }

    return HomePanelCard(
      title: 'İlerleme & Log',
      icon: Icons.terminal_rounded,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider.logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Tüm logları kopyala',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                final allLogs = provider.logs.join('\n');
                Clipboard.setData(ClipboardData(text: allLogs));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loglar panoya kopyalandı'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${provider.sentCount} / ${provider.phoneCount}  •  %$progressPercent',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: provider.progress,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  provider.status == SendingStatus.completed
                      ? WAColors.accent
                      : WAColors.accentDark,
                ),
              ),
            ),
            const SizedBox(height: 10),

            if (provider.status == SendingStatus.rateLimited)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFE65100), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Meta API rate limit aşıldı. Gönderim durduruldu.',
                            style: TextStyle(
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sunucu yeniden başlatılmışsa gönderimi sıfırdan başlatmanız gerekebilir.',
                      style: TextStyle(
                        color: Color(0xFF8D6E63),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: provider.isResumingRateLimited
                          ? null
                          : () => provider.resumeSending(
                                sessionId: provider.rateLimitedSessionId ?? '',
                              ),
                      icon: provider.isResumingRateLimited
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_circle_outline_rounded,
                              size: 18),
                      label: Text(
                        provider.isResumingRateLimited
                            ? 'Devam Ettiriliyor...'
                            : 'Kaldığı Yerden Devam Et',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),

            // Log terminal kutusu
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111B21),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A3942)),
                ),
                child: provider.logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Loglar burada görünecek...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: provider.logScrollController,
                        itemCount: provider.logs.length,
                        itemBuilder: (context, index) {
                          final log = provider.logs[index];
                          Color logColor = Colors.grey.shade300;

                          if (log.contains('[HATA]')) {
                            logColor = Colors.redAccent;
                          } else if (log.contains('[GÖNDER]')) {
                            logColor = Colors.greenAccent;
                          } else if (log.contains('[BEKLE]')) {
                            logColor = Colors.amberAccent;
                          } else if (log.contains('[BİLGİ]')) {
                            logColor = Colors.lightBlueAccent;
                          } else if (log.contains('[DURDURULDU]')) {
                            logColor = Colors.orangeAccent;
                          } else if (log.contains('[RATE_LIMIT]') ||
                              log.contains('[UYARI]')) {
                            logColor = Colors.deepOrangeAccent;
                          } else if (log.contains('───')) {
                            logColor = Colors.white;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: SelectableText(
                              log,
                              style: TextStyle(
                                color: logColor,
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
    );
  }
}