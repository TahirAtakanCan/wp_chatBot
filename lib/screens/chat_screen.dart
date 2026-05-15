import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/api_exceptions.dart';
import '../services/api_service.dart';
import '../services/chat_media_service.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_header_bar.dart';
import '../widgets/date_separator.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final bool embedded;
  final ValueChanged<Conversation>? onConversationUpdated;

  const ChatScreen({
    super.key,
    required this.conversation,
    this.embedded = false,
    this.onConversationUpdated,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final ChatMediaService _chatMediaService = ChatMediaService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  Timer? _pollingTimer;
  Conversation? _conversation;
  List<Message> _messages = <Message>[];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _loadMessages();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _conversation = widget.conversation;

      setState(() {
        _messages.clear();
        _isLoading = true;
        _isSending = false;
      });

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }

      _loadMessages();
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scrollController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _startPolling() {
    if (_pollingTimer != null) return;
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(silent: true),
    );
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_conversation == null) return;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final incoming = await _apiService.fetchMessages(_conversation!.id);
      if (!mounted) return;

      final merged = _mergeMessages(_messages, incoming);
      final hadNewItems = merged.length > _messages.length;

      setState(() {
        _messages = merged;
        _isLoading = false;
      });

      if (hadNewItems) {
        _scrollToBottom();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Message> _mergeMessages(List<Message> current, List<Message> incoming) {
    final merged = <Message>[...current];

    for (final item in incoming) {
      final index = _findMessageIndexByUniqueKey(merged, item);
      if (index >= 0) {
        merged[index] = item;
      } else {
        merged.add(item);
      }
    }

    merged.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return merged;
  }

  int _findMessageIndexByUniqueKey(List<Message> list, Message message) {
    if ((message.waMessageId ?? '').isNotEmpty) {
      return list.indexWhere((e) => e.waMessageId == message.waMessageId);
    }
    return list.indexWhere((e) => e.id == message.id);
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSending || _conversation == null) return;
    _replyController.clear();
    await _sendText(text);
  }

  Future<void> _pickAndSendImage() async {
    if (_isSending || _conversation == null || !_conversation!.replyWindowOpen) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnackBar('Dosya okunamadi');
      return;
    }

    final caption = _replyController.text.trim();
    if (caption.isNotEmpty) {
      _replyController.clear();
    }

    setState(() => _isSending = true);
    try {
      final publicUrl = await _chatMediaService.uploadPublicImage(
        bytes: file.bytes!,
        filename: file.name,
      );
      if (!mounted) return;
      await _sendImage(publicUrl, caption: caption.isEmpty ? null : caption);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showSnackBar('Resim gonderilemedi: $e');
    }
  }

  Future<void> _sendImage(
    String imageUrl, {
    String? caption,
    int? replaceMessageId,
  }) async {
    if (_conversation == null) return;

    final tempMessage = Message(
      id: replaceMessageId ?? -DateTime.now().microsecondsSinceEpoch,
      direction: 'OUTBOUND',
      messageType: 'IMAGE',
      content: caption,
      caption: caption,
      mediaUrl: imageUrl,
      url: imageUrl,
      waMessageId: null,
      sentAt: DateTime.now(),
      status: 'PENDING',
    );

    setState(() {
      _isSending = true;
      if (replaceMessageId != null) {
        final idx = _messages.indexWhere((m) => m.id == replaceMessageId);
        if (idx >= 0) {
          _messages[idx] = tempMessage;
        }
      } else {
        _messages = <Message>[..._messages, tempMessage];
      }
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });

    _scrollToBottom();

    try {
      final sent = await _apiService.sendReplyImage(
        _conversation!.id,
        imageUrl: imageUrl,
        caption: caption,
      );
      if (!mounted) return;

      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempMessage.id);
        if (idx >= 0) {
          _messages[idx] = sent;
        } else {
          _messages = <Message>[..._messages, sent];
        }
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });
      _scrollToBottom();
    } on ReplyWindowClosedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Pencere kapali, sayfayi yenileyin');
    } on RateLimitedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Hiz limiti, biraz sonra deneyin');
    } catch (e) {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Gonderilemedi: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendText(String text, {int? replaceMessageId}) async {
    if (_conversation == null) return;

    final tempMessage = Message(
      id: replaceMessageId ?? -DateTime.now().microsecondsSinceEpoch,
      direction: 'OUTBOUND',
      messageType: 'TEXT',
      content: text,
      waMessageId: null,
      sentAt: DateTime.now(),
      status: 'PENDING',
    );

    setState(() {
      _isSending = true;
      if (replaceMessageId != null) {
        final idx = _messages.indexWhere((m) => m.id == replaceMessageId);
        if (idx >= 0) {
          _messages[idx] = tempMessage;
        }
      } else {
        _messages = <Message>[..._messages, tempMessage];
      }
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });

    _scrollToBottom();

    try {
      final sent = await _apiService.sendReply(_conversation!.id, text);
      if (!mounted) return;

      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempMessage.id);
        if (idx >= 0) {
          _messages[idx] = sent;
        } else {
          _messages = <Message>[..._messages, sent];
        }
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });

      _scrollToBottom();
    } on ReplyWindowClosedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Pencere kapanmış, sayfayı yenileyin');
    } on RateLimitedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Hız limiti, biraz sonra deneyin');
    } catch (e) {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Gönderilemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _confirmSendContactCard() async {
    if (_conversation == null || !mounted) return;

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kişi kartı gönderimi'),
        content: const Text(
          'İHH Seydişehir kişi kartını göndermek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (shouldSend == true) {
      await _sendContactCard();
    }
  }

  Future<void> _sendContactCard() async {
    if (_conversation == null || _isSending) return;

    final tempMessage = Message(
      id: -1,
      direction: 'OUTBOUND',
      messageType: 'TEXT',
      content: '📇 Kişi Kartı Gönderildi',
      waMessageId: null,
      sentAt: DateTime.now(),
      status: 'PENDING',
    );

    setState(() {
      _isSending = true;
      _messages = <Message>[..._messages, tempMessage];
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });

    _scrollToBottom();

    try {
      final sent = await _apiService.sendContactCard(_conversation!.id);
      if (!mounted) return;

      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempMessage.id);
        if (idx >= 0) {
          _messages[idx] = sent;
        } else {
          _messages = <Message>[..._messages, sent];
        }
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });

      _scrollToBottom();
    } on ReplyWindowClosedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('24 saat penceresi kapalı');
    } on RateLimitedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Hız limiti, biraz sonra deneyin');
    } catch (_) {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Kişi kartı gönderilemedi');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _markMessageFailed(int messageId) {
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        final failed = _messages[idx];
        _messages[idx] = Message(
          id: failed.id,
          direction: failed.direction,
          messageType: failed.messageType,
          content: failed.content,
          waMessageId: failed.waMessageId,
          sentAt: failed.sentAt,
          status: 'FAILED',
        );
      }
    });
  }

  Future<void> _closeConversation() async {
    if (_conversation == null) return;

    try {
      final updated = await _apiService.closeConversation(_conversation!.id);
      if (!mounted) return;

      setState(() {
        _conversation = updated;
      });

      widget.onConversationUpdated?.call(updated);

      _showSnackBar('Konuşma kapatıldı');
    } catch (e) {
      _showSnackBar('Konuşma kapatılamadı: $e');
    }
  }

  Future<void> _confirmClearMessages() async {
    if (!mounted) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesajları Temizle'),
        content: const Text(
          'Bu konuşmanın tüm mesajları temizlenecektir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      _clearMessages();
    }
  }

  Future<void> _clearMessages() async {
    if (!mounted || _conversation == null) return;

    try {
      final deletedCount =
          await _apiService.clearAllMessages(_conversation!.id);
      if (!mounted) return;

      setState(() {
        _messages.clear();
      });
      _showSnackBar('$deletedCount mesaj temizlendi');
    } catch (e) {
      _showSnackBar('Mesajlar temizlenemedi: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    if (conversation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.embedded) {
      return Container(
        color: WAColors.chatPanelBg,
        child: Column(
          children: [
            _buildEmbeddedHeader(conversation),
            Expanded(child: _buildMessageList()),
            ChatComposer(
              enabled: conversation.replyWindowOpen,
              controller: _replyController,
              focusNode: _replyFocusNode,
              isSending: _isSending,
              onSend: _sendReply,
              onAttachImage: _pickAndSendImage,
              onTemplatePressed: () {
                _showSnackBar('Yakında: template gönderimi');
              },
            ),
          ],
        ),
      );
    }

    return PopScope<Conversation>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_conversation);
      },
      child: Scaffold(
        backgroundColor: WAColors.chatPanelBg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ChatHeaderBar(
            conversation: conversation,
            showBack: true,
            onBack: () => Navigator.of(context).pop(conversation),
            actions: _buildHeaderActions(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _buildMessageList(),
            ),
            ChatComposer(
              enabled: conversation.replyWindowOpen,
              controller: _replyController,
              focusNode: _replyFocusNode,
              isSending: _isSending,
              onSend: _sendReply,
              onAttachImage: _pickAndSendImage,
              onTemplatePressed: () {
                _showSnackBar('Yakında: template gönderimi');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedHeader(Conversation conversation) {
    return ChatHeaderBar(
      conversation: conversation,
      showBack: true,
      onBack: () => Navigator.of(context).maybePop(),
      actions: _buildHeaderActions(),
    );
  }

  Widget _buildMessageList() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ChatWallpaper(),
        if (_isLoading && _messages.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_messages.isEmpty)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 44,
                    color: WAColors.accent,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Henüz mesaj yok',
                    style: WATextStyles.emptySubtitle,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'İlk mesajı aşağıdan gönderebilirsiniz',
                    style: TextStyle(
                      fontSize: 12,
                      color: WAColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          _buildMessageScrollView(),
      ],
    );
  }

  Widget _buildMessageScrollView() {
    final items = _buildMessageItems(_messages);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding =
            width >= 1024 ? 64.0 : (width >= 768 ? 24.0 : 16.0);

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            12,
          ),
          reverse: false,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item.isSeparator) {
              return DateSeparator(dateTime: item.dateTime!);
            }

            final message = item.message!;
            final previous = _previousMessage(items, index);
            final prevWasSeparator = _previousWasSeparator(items, index);
            final isFirstInGroup = previous == null ||
                previous.direction != message.direction ||
                prevWasSeparator;

            double topSpacing = 4;
            if (previous != null) {
              if (prevWasSeparator) {
                topSpacing = 4;
              } else if (previous.direction == message.direction) {
                topSpacing = 2;
              } else {
                topSpacing = 8;
              }
            }

            return Padding(
              padding: EdgeInsets.only(top: topSpacing),
              child: MessageBubble(
                message: message,
                isFirstInGroup: isFirstInGroup,
                onImageTap: null,
                onRetry: message.status.toUpperCase() == 'FAILED'
                    ? () {
                        final content = message.content?.trim() ?? '';
                        if (content.isEmpty) return;
                        _sendText(content, replaceMessageId: message.id);
                      }
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Widget> _buildHeaderActions() {
    return [
      IconButton(
        tooltip: 'Ara',
        onPressed: () => _showSnackBar('Yakında: mesaj arama'),
        icon: const Icon(Icons.search_rounded, size: 22),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        splashRadius: 20,
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'close') {
            _closeConversation();
          }
          if (value == 'contact_card') {
            _confirmSendContactCard();
          }
          if (value == 'clear_messages') {
            _confirmClearMessages();
          }
          if (value == 'info') {
            _showSnackBar('Yakında: bilgiler');
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'close',
            child: Text('Konuşmayı Kapat'),
          ),
          PopupMenuItem<String>(
            value: 'contact_card',
            child: Text('Kişi Kartı Gönder'),
          ),
          PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'clear_messages',
            child:
                Text('Mesajları Temizle', style: TextStyle(color: Colors.red)),
          ),
          PopupMenuItem<String>(
            value: 'info',
            child: Text('Bilgileri görüntüle'),
          ),
        ],
      ),
    ];
  }

  List<_ChatListItem> _buildMessageItems(List<Message> messages) {
    final items = <_ChatListItem>[];
    DateTime? lastDate;

    for (final msg in messages) {
      final msgDate =
          DateTime(msg.sentAt.year, msg.sentAt.month, msg.sentAt.day);
      if (lastDate == null || !_isSameDay(msgDate, lastDate)) {
        items.add(_ChatListItem.separator(msgDate));
        lastDate = msgDate;
      }
      items.add(_ChatListItem.message(msg));
    }

    return items;
  }

  Message? _previousMessage(List<_ChatListItem> items, int index) {
    for (var i = index - 1; i >= 0; i--) {
      final item = items[i];
      if (!item.isSeparator) return item.message;
    }
    return null;
  }

  bool _previousWasSeparator(List<_ChatListItem> items, int index) {
    if (index <= 0) return false;
    return items[index - 1].isSeparator;
  }
}

class _ChatListItem {
  final Message? message;
  final DateTime? dateTime;
  final bool isSeparator;

  const _ChatListItem._({
    this.message,
    this.dateTime,
    required this.isSeparator,
  });

  factory _ChatListItem.message(Message message) =>
      _ChatListItem._(message: message, isSeparator: false);

  factory _ChatListItem.separator(DateTime dateTime) =>
      _ChatListItem._(dateTime: dateTime, isSeparator: true);
}
