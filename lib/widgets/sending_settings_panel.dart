import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';

class SendingSettingsPanel extends StatelessWidget {
  const SendingSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MessageProvider>();
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