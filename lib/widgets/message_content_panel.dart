import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/template_model.dart';
import '../providers/message_provider.dart';
import '../services/template_service.dart';

class MessageContentPanel extends StatefulWidget {
  const MessageContentPanel({super.key});

  @override
  State<MessageContentPanel> createState() => _MessageContentPanelState();
}

class _MessageContentPanelState extends State<MessageContentPanel> {
  late final FocusNode _messageFocusNode;
  final TemplateService _templateService = TemplateService();

  @override
  void initState() {
    super.initState();
    _messageFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            HardwareKeyboard.instance.isShiftPressed) {
          _insertSeparator();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  void _insertSeparator() {
    final provider = context.read<MessageProvider>();
    final controller = provider.messageController;
    final sel = controller.selection;
    if (!sel.isValid) return;
    const sep = '\n✂ ── Mesaj Ayrımı ──\n';
    final text = controller.text;
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    controller.value = TextEditingValue(
      text: '$before$sep$after',
      selection:
          TextSelection.collapsed(offset: sel.start + sep.length),
    );
    setState(() {});
  }

  void _insertTemplateContent(String templateContent) {
    final provider = context.read<MessageProvider>();
    final controller = provider.messageController;
    final selection = controller.selection;
    if (!selection.isValid) {
      final nextText = controller.text.isEmpty
          ? templateContent
          : '${controller.text}\n$templateContent';
      controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    } else {
      final text = controller.text;
      final before = text.substring(0, selection.start);
      final after = text.substring(selection.end);
      controller.value = TextEditingValue(
        text: '$before$templateContent$after',
        selection: TextSelection.collapsed(
            offset: selection.start + templateContent.length),
      );
    }
    _messageFocusNode.requestFocus();
    setState(() {});
  }

  void _showTemplateBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.55,
            child: FutureBuilder<List<TemplateModel>>(
              future: _templateService.getTemplates(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final templates = snapshot.data ?? [];
                if (templates.isEmpty) {
                  return Center(
                    child: Text(
                      'Henüz kayıtlı şablon bulunmuyor.',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return ListTile(
                      leading: Icon(Icons.bookmark_outline_rounded,
                          color: theme.colorScheme.primary),
                      title: Text(template.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(template.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _insertTemplateContent(template.content);
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  'Mesaj İçeriği',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (provider.messagePartCount > 1) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${provider.messagePartCount} parça',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showTemplateBottomSheet(context),
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Şablon Seç'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Kişiselleştirme Toggle ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: provider.personalizedMessage
                    ? theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4)
                    : theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: provider.personalizedMessage
                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                      : theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: provider.personalizedMessage
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kişiselleştirilmiş Mesaj',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: provider.personalizedMessage
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          provider.personalizedMessage
                              ? 'Mesajda {isim} kullanın → kişi adıyla değiştirilir'
                              : 'Açınca {isim} ile kişi adı ekleyebilirsiniz',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: provider.personalizedMessage,
                    onChanged: (_) =>
                        provider.togglePersonalizedMessage(),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Mesaj Yazma Alanı ──
            Expanded(
              child: TextField(
                controller: provider.messageController,
                focusNode: _messageFocusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: provider.personalizedMessage
                      ? 'Mesajınızı yazın...\n\nÖrn: Merhaba {isim}, ...'
                      : 'Mesajınızı yazın...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor:
                      theme.colorScheme.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style:
                    const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 8),

            // ── Araç Çubuğu ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _ToolbarButton(
                    icon: Icons.content_cut_rounded,
                    label: 'Mesaj Ayır',
                    shortcut: '⇧ Enter',
                    onTap: _insertSeparator,
                    theme: theme,
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2),
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4),
                  ),
                  _ToolbarButton(
                    icon: Icons.upload_file_rounded,
                    label: 'Bilgisayardan Yükle',
                    onTap: () => provider.uploadMediaFromDevice(),
                    theme: theme,
                    badge: provider.hasMedia
                        ? provider.mediaCount
                        : null,
                  ),
                  if (provider.hasMedia) ...[
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 2),
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              provider.attachedMedia.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 4),
                          itemBuilder: (context, index) {
                            final url =
                                provider.attachedMedia[index];
                            final fileName =
                                Uri.decodeComponent(
                                    url.split('/').last);
                            final shortName =
                                fileName.length > 18
                                    ? '${fileName.substring(0, 15)}...'
                                    : fileName;
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4),
                              decoration: BoxDecoration(
                                color: theme
                                    .colorScheme.primaryContainer
                                    .withValues(alpha: 0.4),
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme
                                      .colorScheme.primary
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_outlined,
                                      size: 13,
                                      color: theme
                                          .colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    shortName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    onTap: () =>
                                        provider.removeMedia(index),
                                    child: Icon(
                                        Icons.close_rounded,
                                        size: 13,
                                        color: theme
                                            .colorScheme.error),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (!provider.hasMedia) const Spacer(),
                  if (provider.hasMedia)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: provider.clearAllMedia,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Icon(Icons.delete_sweep_outlined,
                            size: 18,
                            color: theme.colorScheme.error),
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

// ── Araç Çubuğu Butonu ──
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback onTap;
  final ThemeData theme;
  final int? badge;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.shortcut,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              if (shortcut != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme
                        .colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    shortcut!,
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}