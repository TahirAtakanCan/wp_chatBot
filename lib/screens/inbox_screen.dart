import 'dart:async';

import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../services/api_service.dart';
import '../utils/date_format.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  Timer? _pollingTimer;

  List<Conversation> _conversations = <Conversation>[];
  bool _isLoading = true;
  bool _isRequestInFlight = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _stopPolling();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _loadConversations(silent: true);
    }
  }

  void _startPolling() {
    if (_pollingTimer != null) return;
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadConversations(silent: true),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (_isRequestInFlight) return;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    _isRequestInFlight = true;
    try {
      final conversations = await _apiService.fetchConversations(page: 0, size: 50);
      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Konuşmalar yüklenemedi: $e';
      });
    } finally {
      _isRequestInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelen Kutusu'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => _loadConversations(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadConversations(silent: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 420,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _loadConversations(),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 420,
            child: Center(
              child: Text('Henüz konuşma yok'),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return ConversationTile(
          conversation: conversation,
          onTap: () async {
            final updated = await Navigator.push<Conversation>(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversation: conversation,
                ),
              ),
            );

            if (!context.mounted || updated == null) return;

            final idx = _conversations.indexWhere((c) => c.id == updated.id);
            if (idx < 0) return;
            setState(() {
              _conversations[idx] = updated;
            });
          },
        );
      },
    );
  }
}

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClosed = conversation.status.toUpperCase() == 'CLOSED';
    final theme = Theme.of(context);

    return Opacity(
      opacity: isClosed ? 0.55 : 1,
      child: ListTile(
        onTap: onTap,
        leading: _buildLeadingAvatar(),
        title: Text(
          conversation.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          conversation.lastMessageText ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isClosed)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock, size: 14),
                  ),
                Text(
                  formatTime(conversation.lastMessageAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (conversation.unreadCount > 0)
              CircleAvatar(
                radius: 11,
                backgroundColor: Colors.green,
                child: Text(
                  conversation.unreadCount > 99
                      ? '99+'
                      : conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingAvatar() {
    final hasName = conversation.contactName != null &&
        conversation.contactName!.trim().isNotEmpty;

    if (!hasName) {
      return const CircleAvatar(
        child: Icon(Icons.phone),
      );
    }

    final initials = _extractInitials(conversation.contactName!);
    return CircleAvatar(
      child: Text(initials),
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