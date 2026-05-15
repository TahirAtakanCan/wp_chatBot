import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sending_state.dart';
import '../providers/message_provider.dart';
import '../theme/wa_colors.dart';

class ActionPanel extends StatelessWidget {
  final bool compact;

  const ActionPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final isSending = provider.status == SendingStatus.sending;
    final isPaused = provider.status == SendingStatus.paused;

    if (compact) {
      return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: isSending || isPaused ? null : provider.startSending,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Gonderimi Baslat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    disabledBackgroundColor: Colors.green.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: isPaused
                    ? FilledButton.icon(
                        onPressed: provider.resumeSending,
                        icon: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 22,
                        ),
                        label: const Text(
                          'Kaldigi Yerden Devam',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: isSending ? provider.stopSending : null,
                        icon: const Icon(Icons.stop_rounded, size: 22),
                        label: const Text(
                          'Gonderimi Durdur',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          disabledBackgroundColor: Colors.red.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: isSending ? null : provider.resetState,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Sifirla'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WAColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Başlat butonu
            Expanded(
              child: FilledButton.icon(
                onPressed: isSending || isPaused ? null : provider.startSending,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Gönderimi Başlat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: WAColors.accent,
                  disabledBackgroundColor: WAColors.accent.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Durdur / Devam Et butonu
            Expanded(
              child: isPaused
                  ? FilledButton.icon(
                      onPressed: provider.resumeSending,
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
                      label: const Text(
                        'Kaldığı Yerden Devam',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: isSending ? provider.stopSending : null,
                      icon: const Icon(Icons.stop_rounded, size: 22),
                      label: const Text(
                        'Gönderimi Durdur',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        disabledBackgroundColor: Colors.red.shade200,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Sıfırla butonu
            Flexible(
              child: OutlinedButton.icon(
                onPressed: isSending ? null : provider.resetState,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Sıfırla'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}