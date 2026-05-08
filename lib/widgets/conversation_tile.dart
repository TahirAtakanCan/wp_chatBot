import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../utils/avatar_color.dart';
import '../utils/date_format.dart';

class ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final bool isSelected;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final isClosed = conversation.status.toUpperCase() == 'CLOSED';
    final showUnread = conversation.unreadCount > 0;
    final baseOpacity = isClosed ? 0.55 : 1.0;
    final hoverOpacity = isClosed ? 0.75 : 1.0;
    final background = widget.isSelected
        ? WAColors.selectedBg
        : (_isHovered ? WAColors.hoverBg : WAColors.leftPanelBg);

    return Opacity(
      opacity: _isHovered ? hoverOpacity : baseOpacity,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: _isHovered
              ? const Duration(milliseconds: 100)
              : const Duration(milliseconds: 200),
          curve: _isHovered ? Curves.easeOut : Curves.easeInOut,
          color: background,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    if (widget.isSelected)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: 3,
                        color: WAColors.accent,
                      )
                    else
                      const SizedBox(width: 3),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            _buildAvatar(conversation),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          conversation.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: WATextStyles.conversationName,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatTime(conversation.lastMessageAt),
                                        style: WATextStyles.conversationTime,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          conversation.lastMessageText ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: WATextStyles.conversationPreview,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isClosed)
                                        const Icon(
                                          Icons.lock,
                                          size: 14,
                                          color: WAColors.textTertiary,
                                        ),
                                      if (isClosed && showUnread)
                                        const SizedBox(width: 6),
                                      if (showUnread)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WAColors.unreadBadge,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            conversation.unreadCount > 99
                                                ? '99+'
                                                : conversation.unreadCount.toString(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Conversation conversation) {
    final hasName = (conversation.contactName ?? '').trim().isNotEmpty;
    final initials = hasName ? _extractInitials(conversation.contactName!) : '';
    final color = avatarColorFor(conversation.phoneNumber);

    return CircleAvatar(
      radius: 24,
      backgroundColor: color,
      child: hasName
          ? Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            )
          : const Icon(Icons.person, color: Colors.white, size: 22),
    );
  }

  String _extractInitials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    final first = words.first.characters.first;
    final second = words[1].characters.first;
    return (first + second).toUpperCase();
  }
}
