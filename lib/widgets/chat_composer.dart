import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/wa_colors.dart';

class ChatComposer extends StatefulWidget {
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final Future<void> Function() onSend;
  final Future<void> Function()? onAttachImage;
  final VoidCallback onTemplatePressed;

  const ChatComposer({
    super.key,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    this.onAttachImage,
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

  void _handleSend() {
    final text = widget.controller.text;
    // === DEBUG START ===
    debugPrint('[COMPOSER DEBUG] text=[$text]');
    debugPrint('[COMPOSER DEBUG] length=${text.length}');
    debugPrint('[COMPOSER DEBUG] codeUnits=${text.codeUnits}');
    debugPrint('[COMPOSER DEBUG] runes=${text.runes.toList()}');
    debugPrint('[COMPOSER DEBUG] bytes=${utf8.encode(text)}');
    debugPrint('[COMPOSER DEBUG] isEmpty=${text.isEmpty}');
    debugPrint('[COMPOSER DEBUG] trim.isEmpty=${text.trim().isEmpty}');
    // === DEBUG END ===
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && !widget.isSending;
    final hintText = widget.enabled
        ? 'Bir mesaj yazın'
        : '24 saat penceresi kapalı';
    final canSend = isEnabled && _hasText;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.enabled) _buildWindowClosedBanner(),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: WAColors.divider.withValues(alpha: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildIconAction(
                    icon: Icons.emoji_emotions_outlined,
                    onPressed: isEnabled ? () => _showSnack('Yakında: emoji') : null,
                  ),
                  _buildIconAction(
                    icon: Icons.image_outlined,
                    onPressed: isEnabled && widget.onAttachImage != null
                        ? () => widget.onAttachImage!()
                        : null,
                  ),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            return KeyEventResult.ignored;
                          }
                          if (canSend) {
                            _handleSend();
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
                        style: const TextStyle(
                          fontSize: 15,
                          color: WAColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: const TextStyle(
                            color: WAColors.textTertiary,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  _buildSendButton(isEnabled, canSend),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowClosedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: WAColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WAColors.warningYellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 18,
            color: WAColors.warningYellow,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '24 saat penceresi kapalı. Yalnızca onaylı template ile yazabilirsiniz.',
              style: TextStyle(fontSize: 12, color: WAColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: widget.onTemplatePressed,
            style: TextButton.styleFrom(
              foregroundColor: WAColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Template'),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: WAColors.textSecondary,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      splashRadius: 20,
    );
  }

  Widget _buildSendButton(bool isEnabled, bool canSend) {
    final showSend = _hasText;
    final bgColor = !isEnabled
        ? WAColors.divider
        : (showSend ? WAColors.accent : WAColors.composerBg);
    final iconColor = !isEnabled
        ? WAColors.textTertiary
        : (showSend ? Colors.white : WAColors.textSecondary);

    return GestureDetector(
      onTapDown: (_) {
        if (isEnabled) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (isEnabled) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (isEnabled) setState(() => _pressed = false);
      },
      onTap: () {
        if (!isEnabled) return;
        if (_hasText) {
          _handleSend();
        } else {
          _showSnack('Yakında: ses kaydı');
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: showSend && isEnabled
                ? [
                    BoxShadow(
                      color: WAColors.accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: widget.isSending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  showSend ? Icons.send_rounded : Icons.mic_rounded,
                  size: 20,
                  color: iconColor,
                ),
        ),
      ),
    );
  }
}
