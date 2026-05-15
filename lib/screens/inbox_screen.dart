import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/wa_colors.dart';
import '../theme/wa_text_styles.dart';
import '../widgets/conversation_tile.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  final ValueChanged<Conversation>? onConversationSelected;
  final Conversation? selectedConversation;
  final bool showAppBar;
  final bool showBackButton;

  const InboxScreen({
    super.key,
    this.onConversationSelected,
    this.selectedConversation,
    this.showAppBar = true,
    this.showBackButton = false,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final FocusNode _listFocusNode = FocusNode();
  Timer? _pollingTimer;
  int _lastTotalUnreadCount = 0;
  bool _isFirstLoad = true;

  List<Conversation> _conversations = <Conversation>[];
  String _searchQuery = '';
  _InboxFilter _activeFilter = _InboxFilter.all;
  int? _focusedIndex;
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
  void didUpdateWidget(covariant InboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updated = widget.selectedConversation;
    if (updated == null) return;
    final idx = _conversations.indexWhere((c) => c.id == updated.id);
    if (idx < 0) return;
    setState(() {
      _conversations[idx] = updated;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _listFocusNode.dispose();
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
      final conversations =
          await _apiService.fetchConversations(page: 0, size: 50);
      if (!mounted) return;

      final newTotalUnread = conversations.fold<int>(
        0,
        (sum, conv) => sum + conv.unreadCount,
      );

      if (!_isFirstLoad && newTotalUnread > _lastTotalUnreadCount) {
        Conversation? newestUnread;
        for (final conv in conversations) {
          if (conv.unreadCount > 0) {
            newestUnread = conv;
            break;
          }
        }
        NotificationService().playNewMessageSound(
          contactName: newestUnread?.contactName ?? newestUnread?.phoneNumber,
          preview: newestUnread?.lastMessageText,
        );
      }

      _lastTotalUnreadCount = newTotalUnread;
      _isFirstLoad = false;

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
    final content = Column(
      children: [
        _buildSearchBar(),
        _buildFilters(),
        const Divider(height: 1, color: WAColors.divider),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadConversations(silent: true),
            child: _buildBody(),
          ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return Container(
        color: WAColors.leftPanelBg,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: WAColors.leftPanelBg,
      appBar: _buildAppBarHeader(),
      body: content,
    );
  }

  PreferredSizeWidget _buildAppBarHeader() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: _buildHeader(),
    );
  }

  Widget _buildHeader() {
    final soundEnabled = NotificationService().isSoundEnabled;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: WAColors.leftPanelHeader,
        border: Border(
          bottom: BorderSide(color: WAColors.divider),
        ),
      ),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              tooltip: 'Geri',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 24),
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              splashRadius: 20,
            ),
          CircleAvatar(
            radius: 20,
            backgroundColor: WAColors.accent,
            child: const Text(
              'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: soundEnabled ? 'Bildirimi Kapat' : 'Bildirimi Ac',
            onPressed: () async {
              final newValue = !NotificationService().isSoundEnabled;
              NotificationService().enableSound(newValue);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('sound_enabled', newValue);
              if (mounted) setState(() {});
            },
            icon: Icon(
              soundEnabled ? Icons.volume_up : Icons.volume_off,
              size: 24,
            ),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            splashRadius: 20,
          ),
          IconButton(
            tooltip: 'Filtrele',
            onPressed: () {},
            icon: const Icon(Icons.tune, size: 24),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            splashRadius: 20,
          ),
          IconButton(
            tooltip: 'Yeni konuşma',
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Yakında: yeni konuşma başlatma'),
                  ),
                );
            },
            icon: const Icon(Icons.chat, size: 24),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            splashRadius: 20,
          ),
          IconButton(
            tooltip: 'Menü',
            onPressed: () {},
            icon: const Icon(Icons.more_vert, size: 24),
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: WAColors.inputBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: WAColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim();
            });
          },
          style: const TextStyle(fontSize: 15, color: WAColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Konuşma ara...',
            hintStyle: TextStyle(color: WAColors.textTertiary, fontSize: 15),
            prefixIcon: Icon(Icons.search_rounded, color: WAColors.textTertiary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        children: [
          _buildFilterChip('Tümü', _InboxFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Okunmamış', _InboxFilter.unread),
          const SizedBox(width: 8),
          _buildFilterChip('Aktif', _InboxFilter.active),
          const SizedBox(width: 8),
          _buildFilterChip('Kapalı', _InboxFilter.closed),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _InboxFilter filter) {
    final isSelected = _activeFilter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _activeFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? WAColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? WAColors.accent : WAColors.divider,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: WAColors.accent.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : WAColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _LoadingSkeleton();
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_conversations.isEmpty) {
      return _buildEmptyState();
    }

    final filtered = _applyFilters();
    if (filtered.isEmpty) {
      return _buildNoResults();
    }

    return Focus(
      focusNode: _listFocusNode,
      onKeyEvent: (_, event) => _handleListKeyEvent(event, filtered),
      child: GestureDetector(
        onTap: () => _listFocusNode.requestFocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final conversation = filtered[index];
            return ConversationTile(
              conversation: conversation,
              isSelected: widget.selectedConversation?.id == conversation.id,
              onTap: () => _openConversation(conversation),
              onDelete: () => _confirmDeleteConversation(conversation),
              onClear: () => _confirmClearConversation(conversation),
            );
          },
        ),
      ),
    );
  }

  List<Conversation> _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _conversations.where((conversation) {
      final name = (conversation.contactName ?? '').toLowerCase();
      final phone = conversation.phoneNumber.toLowerCase();
      final preview = (conversation.lastMessageText ?? '').toLowerCase();
      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          phone.contains(query) ||
          preview.contains(query);

      if (!matchesQuery) return false;

      switch (_activeFilter) {
        case _InboxFilter.unread:
          return conversation.unreadCount > 0;
        case _InboxFilter.active:
          return conversation.replyWindowOpen;
        case _InboxFilter.closed:
          return conversation.status.toUpperCase() == 'CLOSED';
        case _InboxFilter.all:
          return true;
      }
    }).toList();

    return filtered;
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 420,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: WAColors.textTertiary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Henüz konuşma yok',
                    textAlign: TextAlign.center,
                    style: WATextStyles.emptyTitle,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Bir kullanıcı size mesaj gönderdiğinde burada görünecek.',
                    textAlign: TextAlign.center,
                    style: WATextStyles.emptySubtitle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    final query = _searchQuery.trim();
    final message =
        query.isEmpty ? 'Sonuç bulunamadı' : '$query için sonuç bulunamadı';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 320,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off,
                    size: 48, color: WAColors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: WATextStyles.emptySubtitle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: WAColors.errorRed),
                const SizedBox(height: 12),
                const Text(
                  'Bağlantı kurulamadı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: WAColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WAColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _loadConversations(),
                  style: TextButton.styleFrom(
                    foregroundColor: WAColors.accent,
                  ),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openConversation(Conversation conversation) async {
    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!(conversation);
      return;
    }

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
  }

  Future<void> _confirmDeleteConversation(Conversation conversation) async {
    if (!mounted) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konuşmayı Sil'),
        content: Text(
          '${conversation.displayName} ile olan konuşma silinecektir. Bu işlem geri alınamaz.',
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
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      _deleteConversation(conversation);
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    if (!mounted) return;

    try {
      await _apiService.deleteConversation(conversation.id);
      if (!mounted) return;

      setState(() {
        _conversations.removeWhere((c) => c.id == conversation.id);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${conversation.displayName} silindi'),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Silme başarısız: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _clearConversation(Conversation conversation) async {
    if (!mounted) return;

    try {
      final deletedCount = await _apiService.clearAllMessages(conversation.id);
      if (!mounted) return;

      final idx = _conversations.indexWhere((c) => c.id == conversation.id);
      if (idx < 0) return;

      // Konuşmayı sıfırla
      final cleared = Conversation(
        id: conversation.id,
        phoneNumber: conversation.phoneNumber,
        contactName: conversation.contactName,
        lastMessageAt: DateTime.now(),
        lastMessageText: null,
        unreadCount: 0,
        status: conversation.status,
        replyWindowOpen: conversation.replyWindowOpen,
      );

      setState(() {
        _conversations[idx] = cleared;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$deletedCount mesaj temizlendi'),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Temizleme başarısız: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _confirmClearConversation(Conversation conversation) async {
    if (!mounted) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konuşmayı Temizle'),
        content: Text(
          '${conversation.displayName} ile olan konuşmanın içeriği silinecektir. Konuşma listede kalacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      _clearConversation(conversation);
    }
  }

  KeyEventResult _handleListKeyEvent(
    KeyEvent event,
    List<Conversation> filtered,
  ) {
    if (event is! KeyDownEvent || filtered.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedIndex = (_focusedIndex ?? -1) + 1;
        if (_focusedIndex! >= filtered.length) {
          _focusedIndex = filtered.length - 1;
        }
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedIndex = (_focusedIndex ?? filtered.length) - 1;
        if (_focusedIndex! < 0) {
          _focusedIndex = 0;
        }
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final index = _focusedIndex ?? 0;
      if (index >= 0 && index < filtered.length) {
        _openConversation(filtered[index]);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}

enum _InboxFilter { all, unread, active, closed }

class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton();

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.9).animate(_controller),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: WAColors.composerBg,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
