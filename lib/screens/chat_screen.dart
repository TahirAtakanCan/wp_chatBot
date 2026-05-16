import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/media_upload_result.dart';
import '../services/api_exceptions.dart';
import '../services/api_service.dart';
import '../services/chat_media_service.dart';
import '../utils/media_size_helper.dart';
import '../utils/message_media_url.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_header_bar.dart';
import '../widgets/date_separator.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/message_bubble.dart';
import '../widgets/upload_progress_dialog.dart';

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
      if (item.isOutbound && item.hasWaMessageId && item.isDeliveredStatus) {
        _pruneOptimisticForDelivered(merged, item);
      }

      final index = _findMessageIndexByUniqueKey(merged, item);
      if (index >= 0) {
        merged[index] = item;
      } else {
        merged.add(item);
      }
    }

    _pruneStaleOptimisticMessages(merged);
    merged.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return merged;
  }

  void _pruneOptimisticForDelivered(List<Message> messages, Message delivered) {
    messages.removeWhere((candidate) {
      if (candidate.id >= 0) return false;
      if (!candidate.isOutbound) return false;
      if (candidate.messageType.toUpperCase() !=
          delivered.messageType.toUpperCase()) {
        return false;
      }

      final timeDiff = delivered.sentAt.difference(candidate.sentAt).abs();
      if (timeDiff > const Duration(minutes: 10)) return false;

      final candidateUrl = candidate.mediaUrl ?? candidate.url;
      final deliveredUrl = delivered.mediaUrl ?? delivered.url;
      if (candidateUrl != null &&
          deliveredUrl != null &&
          (candidateUrl == deliveredUrl ||
              _urlsLikelySame(candidateUrl, deliveredUrl))) {
        return true;
      }

      return candidate.status.toUpperCase() == 'FAILED' ||
          candidate.status.toUpperCase() == 'PENDING';
    });
  }

  void _pruneStaleOptimisticMessages(List<Message> messages) {
    messages.removeWhere((candidate) {
      if (candidate.id >= 0) return false;

      final candidateUrl = candidate.mediaUrl ?? candidate.url;
      if (candidateUrl == null || candidateUrl.isEmpty) return false;

      final candidateType = candidate.messageType.toUpperCase();
      return messages.any((other) {
        if (other.id <= 0 || other.id == candidate.id) return false;
        if (!other.isOutbound) return false;
        if (other.messageType.toUpperCase() != candidateType) return false;
        if (other.status.toUpperCase() == 'FAILED') return false;

        final otherUrl = other.mediaUrl ?? other.url;
        if (otherUrl == null || otherUrl.isEmpty) return false;

        return otherUrl == candidateUrl ||
            _urlsLikelySame(otherUrl, candidateUrl);
      });
    });
  }

  bool _urlsLikelySame(String a, String b) {
    if (a == b) return true;
    return a.endsWith(b) || b.endsWith(a);
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
      final upload = await _chatMediaService.uploadPublicImage(
        bytes: file.bytes!,
        filename: file.name,
      );
      if (!mounted) return;
      await _sendImage(upload.url, caption: caption.isEmpty ? null : caption);
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

      final resolved = _resolveSentMediaMessage(sent, fallback: tempMessage);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempMessage.id);
        if (idx >= 0) {
          _messages[idx] = resolved;
        } else {
          _messages = <Message>[..._messages, resolved];
        }
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });
      _scrollToBottom();
      _showSnackBar('Resim gönderildi', isSuccess: true);
    } on ReplyWindowClosedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Pencere kapali, sayfayi yenileyin');
    } on RateLimitedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Hiz limiti, biraz sonra deneyin');
    } catch (e) {
      final reconciled = await _tryReconcileMediaSend(
        tempMessageId: tempMessage.id,
        mediaUrl: imageUrl,
        messageType: 'IMAGE',
      );
      if (!reconciled) {
        _markMessageFailed(tempMessage.id);
        _showSnackBar(_formatSendError(e), isError: true);
      } else {
        _showSnackBar('Resim gönderildi', isSuccess: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    if (_isSending || _conversation == null || !_conversation!.replyWindowOpen) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnackBar('Dosya verisine erişilemedi', isError: true);
      return;
    }

    try {
      final sizeBytes = resolvePickerFileSize(
        pickerSize: file.size,
        bytes: file.bytes,
      );
      ensureWithinWhatsAppLimit(sizeBytes, isVideo: true);
    } on VideoTooLargeException catch (e) {
      _showSnackBar(e.message, isError: true, durationSeconds: 5);
      return;
    } catch (e) {
      _showSnackBar('Dosya boyutu okunamadı: $e', isError: true);
      return;
    }

    final caption = _takeCaption();
    setState(() => _isSending = true);
    try {
      final upload = await _uploadFileWithProgressDialog(
        file: file,
        dialogTitle: 'Video Yükleniyor',
      );
      if (!mounted) return;
      if (upload == null) {
        setState(() => _isSending = false);
        return;
      }

      final mode = decideVideoSendMode(upload.sizeBytes);
      if (mode == VideoSendMode.inlineVideo) {
        await _sendVideo(upload.url, caption: caption);
      } else {
        await _sendDocument(
          upload.url,
          upload.filename,
          caption: caption,
        );
      }
    } on VideoTooLargeException catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showSnackBar(e.message, isError: true, durationSeconds: 5);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showSnackBar('Video gönderilemedi: $e', isError: true);
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    if (_isSending || _conversation == null || !_conversation!.replyWindowOpen) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ChatMediaService.documentExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnackBar('Dosya verisine erişilemedi', isError: true);
      return;
    }

    try {
      final sizeBytes = resolvePickerFileSize(
        pickerSize: file.size,
        bytes: file.bytes,
      );
      ensureWithinWhatsAppLimit(sizeBytes, isVideo: false);
    } catch (e) {
      _showSnackBar(
        e is VideoTooLargeException ? e.message : 'Dosya boyutu okunamadı: $e',
        isError: true,
        durationSeconds: e is VideoTooLargeException ? 5 : 3,
      );
      return;
    }

    final caption = _takeCaption();
    setState(() => _isSending = true);
    try {
      final upload = await _uploadFileWithProgressDialog(
        file: file,
        dialogTitle: 'Belge Yükleniyor',
      );
      if (!mounted) return;
      if (upload == null) {
        setState(() => _isSending = false);
        return;
      }

      await _sendDocument(upload.url, upload.filename, caption: caption);
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showSnackBar('Belge gönderilemedi: $e', isError: true);
      }
    }
  }

  Future<MediaUploadResult?> _uploadFileWithProgressDialog({
    required PlatformFile file,
    required String dialogTitle,
  }) async {
    final sizeBytes = resolvePickerFileSize(
      pickerSize: file.size,
      bytes: file.bytes,
    );
    final dialogKey = GlobalKey<UploadProgressDialogState>();
    final cancelToken = CancelToken();
    var progressDialogOpen = false;

    if (!mounted) return null;

    progressDialogOpen = true;
    // ignore: unawaited_futures
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: UploadProgressDialog(
          key: dialogKey,
          title: dialogTitle,
          filename: file.name,
          sizeFormatted: formatFileSizeDisplay(sizeBytes),
          totalBytes: sizeBytes,
          onCancel: () {
            cancelToken.cancel('Kullanıcı iptal etti');
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    ).whenComplete(() => progressDialogOpen = false);

    try {
      return await _chatMediaService.uploadMedia(
        file,
        onProgress: (sent, total) {
          dialogKey.currentState?.updateProgress(sent, total);
        },
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (mounted) {
          _showSnackBar('Yükleme iptal edildi');
        }
        return null;
      }
      rethrow;
    } finally {
      if (progressDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  String? _takeCaption() {
    final caption = _replyController.text.trim();
    if (caption.isEmpty) return null;
    _replyController.clear();
    return caption;
  }

  Future<void> _sendVideo(
    String mediaUrl, {
    String? caption,
    int? replaceMessageId,
  }) async {
    if (_conversation == null) return;

    final tempMessage = Message(
      id: replaceMessageId ?? -DateTime.now().microsecondsSinceEpoch,
      direction: 'OUTBOUND',
      messageType: 'VIDEO',
      content: caption,
      caption: caption,
      mediaUrl: mediaUrl,
      url: mediaUrl,
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
      final sent = await _apiService.sendReplyVideo(
        _conversation!.id,
        mediaUrl: mediaUrl,
        caption: caption,
      );
      if (!mounted) return;

      final resolved = _resolveSentMediaMessage(sent, fallback: tempMessage);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempMessage.id);
        if (idx >= 0) {
          _messages[idx] = resolved;
        } else {
          _messages = <Message>[..._messages, resolved];
        }
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });
      _scrollToBottom();
      _showSnackBar('Video gönderildi', isSuccess: true);
    } on ReplyWindowClosedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Pencere kapali, sayfayi yenileyin');
    } on RateLimitedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Hiz limiti, biraz sonra deneyin');
    } catch (e) {
      final reconciled = await _tryReconcileMediaSend(
        tempMessageId: tempMessage.id,
        mediaUrl: mediaUrl,
        messageType: 'VIDEO',
      );
      if (!reconciled) {
        _markMessageFailed(tempMessage.id);
        _showSnackBar(_formatSendError(e), isError: true);
      } else {
        _showSnackBar('Video gönderildi', isSuccess: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendDocument(
    String mediaUrl,
    String filename, {
    String? caption,
    int? replaceMessageId,
  }) async {
    if (_conversation == null) return;

    final tempMessage = Message(
      id: replaceMessageId ?? -DateTime.now().microsecondsSinceEpoch,
      direction: 'OUTBOUND',
      messageType: 'DOCUMENT',
      content: filename,
      caption: caption,
      filename: filename,
      mediaUrl: mediaUrl,
      url: mediaUrl,
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
      final sent = await _apiService.sendReplyDocument(
        _conversation!.id,
        mediaUrl: mediaUrl,
        filename: filename,
        caption: caption,
      );
      if (!mounted) return;

      final resolved = _resolveSentMediaMessage(sent, fallback: tempMessage);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempMessage.id);
        if (idx >= 0) {
          _messages[idx] = resolved;
        } else {
          _messages = <Message>[..._messages, resolved];
        }
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });
      _scrollToBottom();
      _showSnackBar('Belge gönderildi', isSuccess: true);
    } on ReplyWindowClosedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Pencere kapali, sayfayi yenileyin');
    } on RateLimitedException {
      _markMessageFailed(tempMessage.id);
      _showSnackBar('Hiz limiti, biraz sonra deneyin');
    } catch (e) {
      final reconciled = await _tryReconcileMediaSend(
        tempMessageId: tempMessage.id,
        mediaUrl: mediaUrl,
        messageType: 'DOCUMENT',
      );
      if (!reconciled) {
        _markMessageFailed(tempMessage.id);
        _showSnackBar(_formatSendError(e), isError: true);
      } else {
        _showSnackBar('Belge gönderildi', isSuccess: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Message _resolveSentMediaMessage(Message sent, {required Message fallback}) {
    var status = sent.status.toUpperCase();
    if (sent.hasWaMessageId &&
        (status.isEmpty || status == 'FAILED' || status == 'PENDING')) {
      status = 'SENT';
    } else if (status.isEmpty) {
      status = 'SENT';
    }

    final displayUrls = _pickDisplayMediaUrls(sent, fallback);

    return Message(
      id: sent.id > 0 ? sent.id : fallback.id,
      direction:
          sent.direction.isNotEmpty ? sent.direction : fallback.direction,
      messageType: sent.messageType.isNotEmpty
          ? sent.messageType
          : fallback.messageType,
      content: sent.content ?? fallback.content,
      waMessageId: sent.waMessageId ?? fallback.waMessageId,
      mediaId: sent.mediaId ?? fallback.mediaId,
      mediaUrl: displayUrls.mediaUrl,
      url: displayUrls.url,
      mimeType: sent.mimeType ?? fallback.mimeType,
      caption: sent.caption ?? fallback.caption,
      filename: sent.filename ?? fallback.filename,
      fileSizeBytes: sent.fileSizeBytes ?? fallback.fileSizeBytes,
      sentAt: sent.sentAt,
      status: status,
    );
  }

  ({String? mediaUrl, String? url}) _pickDisplayMediaUrls(
    Message sent,
    Message fallback,
  ) {
    final sentMedia = sent.mediaUrl ?? sent.url;
    final sentUrl = sent.url ?? sent.mediaUrl;
    final fallbackMedia = fallback.mediaUrl ?? fallback.url;
    final fallbackUrl = fallback.url ?? fallback.mediaUrl;

    if (fallbackMedia != null && isPublicMediaUrl(fallbackMedia)) {
      return (mediaUrl: fallbackMedia, url: fallbackUrl ?? fallbackMedia);
    }

    return (
      mediaUrl: sentMedia ?? fallbackMedia,
      url: sentUrl ?? fallbackUrl,
    );
  }

  String _formatSendError(Object error) {
    if (error is ApiException && error.statusCode != null) {
      return 'Gönderilemedi (${error.statusCode}): ${error.message}';
    }
    return 'Gönderilemedi: $error';
  }

  Future<bool> _tryReconcileMediaSend({
    required int tempMessageId,
    required String mediaUrl,
    required String messageType,
  }) async {
    if (_conversation == null) return false;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
      try {
        final incoming = await _apiService.fetchMessages(_conversation!.id);
        final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
        final matches = incoming.where((m) {
          if (!m.isOutbound) return false;
          if (m.messageType.toUpperCase() != messageType) return false;
          if (m.sentAt.isBefore(cutoff)) return false;
          if (!m.hasWaMessageId && !m.isDeliveredStatus) return false;
          if (m.status.toUpperCase() == 'FAILED') return false;

          final url = m.mediaUrl ?? m.url;
          if (url != null &&
              url.isNotEmpty &&
              (url == mediaUrl || _urlsLikelySame(url, mediaUrl))) {
            return true;
          }

          return m.hasWaMessageId && m.isDeliveredStatus;
        }).toList();

        if (matches.isEmpty) continue;

        matches.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        if (!mounted) return false;

        setState(() {
          _messages.removeWhere((m) => m.id == tempMessageId);
          final serverMsg = matches.first;
          final idx = _findMessageIndexByUniqueKey(_messages, serverMsg);
          if (idx >= 0) {
            _messages[idx] = serverMsg;
          } else {
            _messages.add(serverMsg);
          }
          _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        });
        return true;
      } catch (_) {
        // Sonraki denemede tekrar dene.
      }
    }
    return false;
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
          mediaId: failed.mediaId,
          mediaUrl: failed.mediaUrl,
          url: failed.url,
          mimeType: failed.mimeType,
          caption: failed.caption,
          filename: failed.filename,
          fileSizeBytes: failed.fileSizeBytes,
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

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    int durationSeconds = 3,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade700
              : (isSuccess ? WAColors.accentDark : null),
          duration: Duration(seconds: durationSeconds),
        ),
      );
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
              onPickImage: _pickAndSendImage,
              onPickVideo: _pickAndSendVideo,
              onPickDocument: _pickAndSendDocument,
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
              onPickImage: _pickAndSendImage,
              onPickVideo: _pickAndSendVideo,
              onPickDocument: _pickAndSendDocument,
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
