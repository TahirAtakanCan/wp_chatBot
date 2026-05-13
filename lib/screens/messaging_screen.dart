import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import 'chat_screen.dart';
import 'inbox_screen.dart';
import '../widgets/responsive_layout.dart';
import 'mobile/mobile_inbox_screen.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  Conversation? _selectedConversation;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: const Material(
        color: WAColors.leftPanelBg,
        child: MobileInboxScreen(),
      ),
      desktop: Scaffold(
        backgroundColor: WAColors.appBackground,
        body: Row(
          children: [
            SizedBox(
              width: 400,
              child: Material(
                color: WAColors.leftPanelBg,
                child: InboxScreen(
                  showAppBar: false,
                  showBackButton: true,
                  selectedConversation: _selectedConversation,
                  onConversationSelected: (conversation) {
                    setState(() {
                      _selectedConversation = conversation;
                    });
                  },
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: WAColors.divider),
            Expanded(
              child: Material(
                color: WAColors.chatPanelBg,
                child: _selectedConversation == null
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.message,
                                size: 120,
                                color: WAColors.textTertiary,
                              ),
                              SizedBox(height: 24),
                              Text(
                                'İHH İletişim Paneli',
                                textAlign: TextAlign.center,
                                style: WATextStyles.emptyTitle,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Konuşmalarınız burada görüntülenir.\n\nSoldan bir konuşma seçerek mesajlaşmaya başlayabilirsiniz.',
                                textAlign: TextAlign.center,
                                style: WATextStyles.emptySubtitle,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ChatScreen(
                        conversation: _selectedConversation!,
                        embedded: true,
                        onConversationUpdated: (updated) {
                          setState(() {
                            _selectedConversation = updated;
                          });
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
