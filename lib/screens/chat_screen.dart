import 'dart:async';

import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/api_exceptions.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
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

      _showSnackBar('Konuşma kapatıldı');
    } catch (e) {
      _showSnackBar('Konuşma kapatılamadı: $e');
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

    return PopScope<Conversation>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_conversation);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(conversation),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conversation.displayName),
              Text(
                conversation.replyWindowOpen
                    ? 'Aktif'
                    : '24 saat penceresi kapalı',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'close') {
                  _closeConversation();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'close',
                  child: Text('Konuşmayı Kapat'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _buildMessageList(),
            ),
            ReplyComposer(
              enabled: conversation.replyWindowOpen,
              controller: _replyController,
              focusNode: _replyFocusNode,
              isSending: _isSending,
              onSend: _sendReply,
              onTemplatePressed: () {
                _showSnackBar('Yakında');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading && _messages.isEmpty) {
      return const Center(
        child: Text('Mesajlar yükleniyor...'),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text('Henüz mesaj yok'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      reverse: false,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return MessageBubble(
          message: message,
          onRetry: message.status.toUpperCase() == 'FAILED'
              ? () {
                  final content = message.content?.trim() ?? '';
                  if (content.isEmpty) return;
                  _sendText(content, replaceMessageId: message.id);
                }
              : null,
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isInbound = message.isInbound;
    final alignment =
        isInbound ? Alignment.centerLeft : Alignment.centerRight;
    final background = isInbound ? Colors.grey.shade100 : const Color(0xFFDCF8C6);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0,
          color: background,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContent(),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      _formatHourMinute(message.sentAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (message.isOutbound) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(message.status),
                    ],
                  ],
                ),
                if (message.status.toUpperCase() == 'FAILED' && onRetry != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onRetry,
                      child: const Text('Tekrar gönder'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final messageType = message.messageType.toUpperCase();
    if (messageType == 'IMAGE') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 16),
          const SizedBox(width: 6),
          Text(
            '[Resim] ${message.content ?? ''}'.trim(),
            style: const TextStyle(fontSize: 15),
          ),
        ],
      );
    }

    return Text(
      (message.content ?? '').trim(),
      style: const TextStyle(fontSize: 15),
    );
  }

  Widget _buildStatusIcon(String statusRaw) {
    final status = statusRaw.trim().toUpperCase();
    switch (status) {
      case 'PENDING':
        return const Icon(Icons.schedule, size: 14, color: Colors.grey);
      case 'SENT':
        return const Icon(Icons.check, size: 15, color: Colors.grey);
      case 'DELIVERED':
        return const Icon(Icons.done_all, size: 15, color: Colors.grey);
      case 'READ':
        return const Icon(Icons.done_all, size: 15, color: Colors.blue);
      case 'FAILED':
        return const Icon(Icons.error_outline, size: 15, color: Colors.red);
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatHourMinute(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class ReplyComposer extends StatelessWidget {
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final Future<void> Function() onSend;
  final VoidCallback onTemplatePressed;

  const ReplyComposer({
    super.key,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onTemplatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Bu kişiye 24 saatten fazladır mesaj gönderilmemiş. Sadece onaylı template ile iletişim kurabilirsiniz.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onTemplatePressed,
                    child: const Text('Template Gönder'),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled && !isSending,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) {
                    if (enabled && !isSending) {
                      onSend();
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Mesaj yaz...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: (enabled && !isSending) ? onSend : null,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}