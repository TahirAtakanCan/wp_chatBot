import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';

class MessageContentPanel extends StatefulWidget {
  const MessageContentPanel({super.key});

  @override
  State<MessageContentPanel> createState() => _MessageContentPanelState();
}

class _MessageContentPanelState extends State<MessageContentPanel> {
  late final FocusNode _messageFocusNode;

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
      selection: TextSelection.collapsed(offset: sel.start + sep.length),
    );
    setState(() {});
  }

  void _showServerMediaDialog(BuildContext context, MessageProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sunucudaki Medyalar'),
          content: SizedBox(
            width: 400,
            height: 400,
            child: FutureBuilder<List<String>>(
              future: provider.fetchAvailableMedia(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sunucuda hiç resim bulunamadı.\n(Önce uploads klasörüne resim atın)',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final url = snapshot.data![index];
                    return InkWell(
                      onTap: () {
                        provider.addMediaUrl(url);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
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
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık satırı
            Row(
              children: [
                Icon(Icons.message, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Mesaj İçeriği',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Mesaj ayrımı sayısı badge
                if (provider.messagePartCount > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_cut, size: 13,
                            color: theme.colorScheme.onTertiaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.messagePartCount} mesaj',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonalIcon(
                  onPressed: () => _showServerMediaDialog(context, provider),
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Medya Ekle'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                if (provider.hasMedia) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.perm_media, size: 14, color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          '${provider.mediaCount} dosya',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: provider.clearAllMedia,
                    icon: const Icon(Icons.clear_all, size: 20),
                    tooltip: 'Tüm medyayı kaldır',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mesaj yazma alanı
                    SizedBox(
                      height: 120,
                      child: TextField(
                        controller: provider.messageController,
                        focusNode: _messageFocusNode,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Gönderilecek mesajı buraya yazın...\n\nShift+Enter ile ayrı mesajlara bölebilirsiniz',
                          hintMaxLines: 3,
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    // Mesaj ayırma butonu
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _insertSeparator,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.content_cut,
                                      size: 14,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Mesaj Ayır',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Shift+Enter',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Eklenen medya önizlemeleri
                    if (provider.hasMedia) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ekli Medya Dosyaları',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: provider.attachedMedia.length,
                              itemBuilder: (context, index) {
                                final url = provider.attachedMedia[index];
                                final fileName = url.split('/').last;

                                return ListTile(
                                  leading: Image.network(url, width: 40, height: 40, fit: BoxFit.cover),
                                  title: Text(fileName),
                                  subtitle: const Text('Sunucudan eklendi'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => provider.removeMedia(index),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
            // ...existing code...
  }
}

