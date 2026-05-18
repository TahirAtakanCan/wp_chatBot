import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/template_preset.dart';
import '../providers/message_provider.dart';
import '../screens/template_management_screen.dart';
import '../services/template_service.dart';
import '../theme/wa_colors.dart';
import '../utils/media_size_helper.dart';
import 'home_panel_card.dart';

class MessageContentPanel extends StatefulWidget {
  const MessageContentPanel({super.key});

  @override
  State<MessageContentPanel> createState() => _MessageContentPanelState();
}

class _MessageContentPanelState extends State<MessageContentPanel> {
  final TemplateService _templateService = TemplateService();
  List<TemplatePreset> _presets = <TemplatePreset>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() => _isLoading = true);
    try {
      final presets = await _templateService.fetchPresets();
      if (!mounted) return;
      final provider = context.read<MessageProvider>();
      final selected = provider.selectedPreset;
      if (selected != null && !presets.any((p) => p.id == selected.id)) {
        provider.setSelectedPreset(null);
      }
      setState(() {
        _presets = presets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hazır kayıt listesi alınamadı: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showPreviewDialog(TemplatePreset preset) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hazır Kayıt Önizleme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kayıt: ${preset.displayName}'),
            const SizedBox(height: 6),
            Text('Template: ${preset.metaTemplateName}'),
            const SizedBox(height: 6),
            Text('Dil: ${preset.language.toUpperCase()}'),
            const SizedBox(height: 6),
            Text(
              preset.hasMedia
                  ? 'Medya: ${preset.mediaFilename ?? 'Dosya'} (${preset.sizeFormatted})'
                  : 'Medya: Yok',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final theme = Theme.of(context);
    final selected = provider.selectedPreset;

    return HomePanelCard(
      title: 'Mesaj İçeriği',
      icon: Icons.chat_bubble_outline_rounded,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Hazır kayıtları yönet',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TemplateManagementScreen(),
                ),
              );
              if (!context.mounted) return;
              _loadPresets();
            },
            icon: const Icon(Icons.bookmark_outline_rounded),
          ),
          IconButton(
            tooltip: 'Listeyi yenile',
            onPressed: _isLoading ? null : _loadPresets,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hazır Kayıt Seç:',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  DropdownButtonFormField<int>(
                    initialValue: selected?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _presets
                        .map(
                          (preset) => DropdownMenuItem<int>(
                            value: preset.id,
                            child: Text(
                              preset.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      TemplatePreset? picked;
                      if (id != null) {
                        for (final preset in _presets) {
                          if (preset.id == id) {
                            picked = preset;
                            break;
                          }
                        }
                      }
                      provider.setSelectedPreset(picked);
                    },
                    hint: const Text('Bir hazır kayıt seçin'),
                  ),
                const SizedBox(height: 12),
                if (selected == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: WAColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: WAColors.warningYellow.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      'Gönderimden önce bir hazır kayıt seçmelisiniz.',
                      style: TextStyle(fontSize: 12, color: WAColors.textSecondary),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seçilen:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '📝 Template: ${selected.metaTemplateName}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selected.hasMedia
                              ? '📎 Medya: ${selected.mediaFilename ?? 'Dosya'} (${selected.mediaSizeBytes != null ? formatFileSizeDisplay(selected.mediaSizeBytes!) : selected.sizeFormatted})'
                              : '📎 Medya: Yok',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _showPreviewDialog(selected),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Önizle'),
                        ),
                      ],
                    ),
                  ),
                if (!_isLoading && _presets.isEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: WAColors.divider),
                    ),
                    child: const Text(
                      'Henüz hazır kayıt yok. Yukarıdaki Meta şablonlarından birine medya bağlayarak başlayabilirsin.',
                      style: TextStyle(fontSize: 12, color: WAColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
