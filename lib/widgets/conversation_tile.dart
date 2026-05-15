import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../utils/avatar_color.dart';
import '../utils/date_format.dart';
import '../utils/message_text_utils.dart';

class ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final bool isSelected;
  final VoidCallback? onDelete;
  final VoidCallback? onClear;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
    this.onDelete,
    this.onClear,
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
        ? WAColors.accent.withValues(alpha: 0.08)
        : (_isHovered ? WAColors.hoverBg : Colors.transparent);

    return Opacity(
      opacity: _isHovered ? hoverOpacity : baseOpacity,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
              border: widget.isSelected
                  ? Border.all(
                      color: WAColors.accent.withValues(alpha: 0.25),
                    )
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onTap,
                onSecondaryTapDown: (details) {
                  _showContextMenu(context, details.globalPosition);
                },
                child: SizedBox(
                  height: 72,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
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
                                      style: WATextStyles.conversationName
                                          .copyWith(
                                        fontWeight: showUnread
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatTime(conversation.lastMessageAt),
                                    style: WATextStyles.conversationTime
                                        .copyWith(
                                      color: showUnread
                                          ? WAColors.accent
                                          : WAColors.textTertiary,
                                      fontWeight: showUnread
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                        child: Text(
                                          formatConversationPreview(
                                            conversation.lastMessageText,
                                            messageType:
                                                conversation.lastMessageType,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                      style: WATextStyles.conversationPreview
                                          .copyWith(
                                        color: showUnread
                                            ? WAColors.textPrimary
                                            : WAColors.textSecondary,
                                        fontWeight: showUnread
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (isClosed)
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 14,
                                      color: WAColors.textTertiary,
                                    ),
                                  if (isClosed && showUnread)
                                    const SizedBox(width: 6),
                                  if (showUnread)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 22,
                                      ),
                                      decoration: BoxDecoration(
                                        color: WAColors.unreadBadge,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: WAColors.unreadBadge
                                                .withValues(alpha: 0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        conversation.unreadCount > 99
                                            ? '99+'
                                            : conversation.unreadCount
                                                .toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'clear',
          child: const Row(
            children: [
              Icon(Icons.cleaning_services, color: Colors.orange, size: 18),
              SizedBox(width: 12),
              Text('Temizle'),
            ],
          ),
          onTap: () => widget.onClear?.call(),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 18),
              SizedBox(width: 12),
              Text('Sil', style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () => widget.onDelete?.call(),
        ),
      ],
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
