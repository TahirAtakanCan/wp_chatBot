import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import 'avatar.dart';

class ChatHeaderBar extends StatelessWidget {
  final Conversation conversation;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;

  const ChatHeaderBar({
    super.key,
    required this.conversation,
    this.actions = const [],
    this.onBack,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WAColors.leftPanelHeader,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'Geri',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                splashRadius: 20,
              ),
            Avatar(
              name: conversation.contactName,
              phoneNumber: conversation.phoneNumber,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildTitle(conversation)),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(Conversation conversation) {
    final isActive = conversation.replyWindowOpen;
    final statusColor = isActive ? WAColors.accent : WAColors.warningYellow;
    final statusText = isActive ? 'Aktif' : 'Pencere kapalı';
    final statusBg = isActive
        ? WAColors.accent.withValues(alpha: 0.12)
        : WAColors.warningBg;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          conversation.displayName,
          style: WATextStyles.chatTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                statusText,
                style: WATextStyles.chatSubtitle.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
