import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/wa_colors.dart';

class ChatComposer extends StatefulWidget {
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final Future<void> Function() onSend;
  final VoidCallback onTemplatePressed;

  const ChatComposer({
    super.key,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onTemplatePressed,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
      _hasText = widget.controller.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && !widget.isSending;
    final inputBackground = widget.enabled
        ? WAColors.inputBg
        : WAColors.inputBg.withValues(alpha: 0.7);
    final hintText = widget.enabled
        ? 'Bir mesaj yazın'
        : '24 saat penceresi kapalı, mesaj gönderilemez';
    final canSend = isEnabled && _hasText;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: const BoxDecoration(
          color: WAColors.composerBg,
          border: Border(
            top: BorderSide(color: WAColors.divider),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.enabled)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: WAColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: WAColors.warningYellow,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Bu kişiye 24 saatten fazladır mesaj gönderilmemiş. Yalnızca onaylı template ile iletişim kurabilirsiniz.',
                        style: TextStyle(fontSize: 12, color: WAColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onTemplatePressed,
                      style: TextButton.styleFrom(
                        foregroundColor: WAColors.accent,
                      ),
                      child: const Text('Template Gönder'),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: isEnabled
                      ? () => _showSnack('Yakında: emoji')
                      : null,
                  icon: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: WAColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isEnabled
                      ? () => _showSnack('Yakında: dosya')
                      : null,
                  icon: const Icon(
                    Icons.attach_file,
                    color: WAColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                    decoration: BoxDecoration(
                      color: inputBackground,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) return KeyEventResult.ignored;
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            return KeyEventResult.ignored;
                          }
                          if (canSend) {
                            widget.onSend();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: isEnabled,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: hintText,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTapDown: (_) {
                    if (isEnabled) {
                      setState(() {
                        _pressed = true;
                      });
                    }
                  },
                  onTapUp: (_) {
                    if (isEnabled) {
                      setState(() {
                        _pressed = false;
                      });
                    }
                  },
                  onTapCancel: () {
                    if (isEnabled) {
                      setState(() {
                        _pressed = false;
                      });
                    }
                  },
                  onTap: () {
                    if (!isEnabled) return;
                    if (_hasText) {
                      widget.onSend();
                    } else {
                      _showSnack('Yakında: ses kaydı');
                    }
                  },
                  child: AnimatedScale(
                    scale: _pressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: !isEnabled
                            ? WAColors.divider
                            : (_hasText ? WAColors.accent : WAColors.composerBg),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _hasText ? Icons.send : Icons.mic,
                        size: 20,
                        color: !isEnabled
                            ? WAColors.textTertiary
                            : (_hasText ? Colors.white : WAColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
