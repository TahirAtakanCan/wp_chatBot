import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact_model.dart';
import '../models/delivery_record.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/contact_service.dart';
import '../theme/wa_colors.dart';
import '../widgets/contact_row.dart';
import '../widgets/responsive_layout.dart';
import 'mobile/mobile_contacts_view.dart';

class ContactsScreen extends StatefulWidget {
  final List<String> initiallySelectedNumbers;
  const ContactsScreen({super.key, this.initiallySelectedNumbers = const []});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactService _contactService = ContactService();
  final ApiService _apiService = ApiService();
  final ScrollController _listController = ScrollController();
  Timer? _statusLookupTimer;
  bool _statusRequestInFlight = false;
  final Map<String, DeliveryStatus> _deliveryStatusByPhone = {};
  static const double _itemExtent = 56.0;
  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  Set<int> _selectedContactIds = {};
  bool _loading = false;
  bool _syncing = false;
  String _searchQuery = '';
  Set<String> _selectedLetters = {'Tümü'};

  static final List<String> _letters = [
    'Tümü',
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H',
    'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P',
    'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
    'İsimsiz',
  ];

  static const String _sheetsUrlKey = 'google_sheets_url';

  @override
  void initState() {
    super.initState();
    _selectedContactIds.clear();
    _listController.addListener(_scheduleStatusLookup);
    _fetchContacts();
  }

  @override
  void dispose() {
    _statusLookupTimer?.cancel();
    _listController.removeListener(_scheduleStatusLookup);
    _listController.dispose();
    super.dispose();
  }

  // ─── FİLTRELEME ───────────────────────────────────────────────

  /// Türkçe karakterleri normalize eder
  String _normalizeFirstChar(String name) {
    if (name.isEmpty) return '';
    final first = name.trimLeft()[0];
    // Türkçe küçük → büyük özel dönüşümler
    const map = {
      'ç': 'Ç', 'ğ': 'Ğ', 'ı': 'I', 'i': 'İ',
      'ö': 'Ö', 'ş': 'Ş', 'ü': 'Ü',
    };
    return map[first] ?? first.toUpperCase();
  }

  List<ContactModel> _applyFilters() {
    var result = _contacts;

    // 1. Harf filtresi
    if (!_selectedLetters.contains('Tümü')) {
      result = result.where((c) {
        final trimmed = c.name.trim();
        if (trimmed.isEmpty) {
          return _selectedLetters.contains('İsimsiz');
        }
        final firstChar = _normalizeFirstChar(trimmed);
        return _selectedLetters.any((l) => l != 'İsimsiz' && l == firstChar);
      }).toList();
    }

    // 2. Arama filtresi
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((c) {
        return c.name.toLowerCase().contains(q) || c.phone.contains(q);
      }).toList();
    }

    return result;
  }

  void _applyListFilter({bool scrollToTop = false}) {
    _filteredContacts = _applyFilters();
    _scheduleStatusLookup();
    if (scrollToTop && _listController.hasClients) {
      _listController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── VERİ ÇEKME ───────────────────────────────────────────────
  Future<void> _fetchContacts() async {
    setState(() => _loading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final contacts = await _contactService.getAllContacts(context, authProvider);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _selectedContactIds = contacts
            .where((c) => widget.initiallySelectedNumbers.contains(c.phone))
            .map((c) => c.id)
            .toSet();
        _filteredContacts = _applyFilters();
      });
      _scheduleStatusLookup();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _scheduleStatusLookup() {
    if (!mounted) return;
    _statusLookupTimer?.cancel();
    _statusLookupTimer = Timer(const Duration(milliseconds: 200), () {
      if (!_listController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleStatusLookup();
        });
        return;
      }
      _lookupVisibleStatuses();
    });
  }

  Future<void> _lookupVisibleStatuses() async {
    if (_statusRequestInFlight) return;
    if (!_listController.hasClients) return;

    final viewport = _listController.position.viewportDimension;
    final offset = _listController.offset;
    final startIndex = (offset / _itemExtent)
        .floor()
        .clamp(0, _filteredContacts.length);
    final endIndex = ((offset + viewport) / _itemExtent)
        .ceil()
        .clamp(0, _filteredContacts.length);
    final visible = _filteredContacts.sublist(
      startIndex,
      endIndex > startIndex ? endIndex : startIndex,
    );

    final phones = visible
        .map((c) => c.phone)
        .where((p) => !_deliveryStatusByPhone.containsKey(p))
        .toList();

    if (phones.isEmpty) return;

    _statusRequestInFlight = true;
    try {
      final result = await _apiService.lookupDeliveryStatuses(phones);
      if (!mounted) return;
      setState(() {
        _deliveryStatusByPhone.addAll(result);
      });
    } catch (_) {
      // Sessiz geç: status yoksa ikon gösterilmez.
    } finally {
      _statusRequestInFlight = false;
    }
  }

  // ─── ARAMA ────────────────────────────────────────────────────
  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyListFilter();
    });
  }

  // ─── SEÇİM ────────────────────────────────────────────────────
  void _onSelectAll() {
    setState(() {
      _selectedContactIds = _filteredContacts.map((c) => c.id).toSet();
    });
  }

  void _onDeselectAll() {
    setState(() {
      _selectedContactIds.clear();
    });
  }

  void _onToggleContact(ContactModel contact, bool? val) {
    setState(() {
      if (val == true) {
        _selectedContactIds.add(contact.id);
      } else {
        _selectedContactIds.remove(contact.id);
      }
    });
  }

  // ─── HARF FİLTRESİ (yalnizca listeyi daraltir, secimi degistirmez) ──
  void _onLetterTap(String letter) {
    setState(() {
      if (letter == 'Tümü') {
        _selectedLetters = {'Tümü'};
      } else if (_selectedLetters.contains(letter) &&
          !_selectedLetters.contains('Tümü')) {
        _selectedLetters = {'Tümü'};
      } else {
        _selectedLetters = {letter};
      }
      _applyListFilter();
    });
    if (_listController.hasClients) {
      _listController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  String? get _activeLetterFilter {
    if (_selectedLetters.contains('Tümü') || _selectedLetters.isEmpty) {
      return null;
    }
    if (_selectedLetters.length == 1) {
      return _selectedLetters.first;
    }
    return '${_selectedLetters.length} harf';
  }

  // ─── KİŞİ SİL ─────────────────────────────────────────────────
  void _onContactLongPress(ContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kişiyi Sil'),
        content: Text('${contact.name} kişisini silmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final success = await _contactService.deleteContact(context, authProvider, contact.id);
      if (!mounted) return;
      if (success) {
        await _fetchContacts();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kişi silindi.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kişi silinemedi.')));
      }
    }
  }

  // ─── SEÇİLENLERİ ANA EKRANA GÖNDER ───────────────────────────
  void _onAddSelected() {
    final selectedContacts = _contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .map((c) => c.name.isNotEmpty ? '${c.name} - ${c.phone}' : c.phone)
        .toList();
    Navigator.pop(context, selectedContacts);
  }

  // ─── TÜM REHBERİ SİL ──────────────────────────────────────────
  Future<void> _deleteAllContacts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm rehber silinecek'),
        content: const Text('Bu işlem geri alınamaz. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final success = await _contactService.deleteAllContacts(context, authProvider);
      if (!mounted) return;
      if (success) {
        await _fetchContacts();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tüm rehber başarıyla silindi.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rehber silinemedi.')));
      }
    }
  }

  // ─── GOOGLE SHEETS ────────────────────────────────────────────
  Future<String?> _getOrAskSheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedUrl = prefs.getString(_sheetsUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) return savedUrl;
    if (!mounted) return null;

    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Sheets URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://docs.google.com/spreadsheets/d/...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (entered != null && entered.isNotEmpty) {
      await prefs.setString(_sheetsUrlKey, entered);
      return entered;
    }
    return null;
  }

  Future<void> _resetSheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sheetsUrlKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sheets URL sıfırlandı.')));
  }

  Future<void> _syncFromSheets() async {
    final sheetUrl = await _getOrAskSheetUrl();
    if (sheetUrl == null) return;
    if (!mounted) return;

    setState(() => _syncing = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final result = await _contactService.syncFromGoogleSheets(context, authProvider, sheetUrl);
      final imported = result['imported'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      await _fetchContacts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellendi: $imported kişi eklendi, $skipped atlandı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncelleme başarısız. URL\'yi kontrol edin.')),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedContactIds.length;

    return ResponsiveLayout(
      mobile: MobileContactsView(
        contacts: _filteredContacts,
        statusByPhone: _deliveryStatusByPhone,
        selectedContactIds: _selectedContactIds,
        selectedLetters: _selectedLetters,
        letters: _letters,
        loading: _loading,
        syncing: _syncing,
        selectedCount: selectedCount,
        onSelectAll: _onSelectAll,
        onDeselectAll: _onDeselectAll,
        onSearchChanged: _onSearchChanged,
        onLetterTap: _onLetterTap,
        onToggleContact: _onToggleContact,
        onContactLongPress: _onContactLongPress,
        onAddSelected: _onAddSelected,
        onSyncFromSheets: _syncFromSheets,
        onDeleteAll: _deleteAllContacts,
        onResetSheetUrl: _resetSheetUrl,
      ),
      desktop: _buildDesktopView(context, selectedCount),
    );
  }

  Widget _buildDesktopView(BuildContext context, int selectedCount) {
    return Scaffold(
      backgroundColor: WAColors.appBackground,
      appBar: AppBar(
        backgroundColor: WAColors.leftPanelHeader,
        title: Text(
          'Kişi Rehberi${selectedCount > 0 ? ' ($selectedCount seçili)' : ''}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off_rounded),
            tooltip: 'Sheets URL\'yi Sıfırla',
            onPressed: _resetSheetUrl,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: WAColors.leftPanelHeader,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _onSelectAll,
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('Tümünü Seç'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _onDeselectAll,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Temizle'),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: WAColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredContacts.length} kişi',
                            style: const TextStyle(
                              color: WAColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_activeLetterFilter != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _activeLetterFilter == 'İsimsiz'
                                ? 'İsimsiz kayıtlar'
                                : '"$_activeLetterFilter" ile başlayanlar',
                            style: const TextStyle(
                              fontSize: 11,
                              color: WAColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: WAColors.divider),
                  ),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'İsim veya telefon ara...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _letters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final letter = _letters[index];
                      final isSelected = _selectedLetters.contains(letter);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _onLetterTap(letter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? WAColors.accent
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? WAColors.accent
                                    : WAColors.divider,
                              ),
                            ),
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : WAColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? const Center(child: Text('Kişi bulunamadı.'))
                    : ListView.builder(
                        controller: _listController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final selected =
                              _selectedContactIds.contains(contact.id);
                          return ContactRow(
                            contact: contact,
                            selected: selected,
                            deliveryStatus:
                                _deliveryStatusByPhone[contact.phone],
                            onSelected: (val) =>
                                _onToggleContact(contact, val),
                            onLongPress: () => _onContactLongPress(contact),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: WAColors.divider)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _syncing ? null : _syncFromSheets,
                    style: FilledButton.styleFrom(
                      backgroundColor: WAColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _syncing ? 'Güncelleniyor...' : "Sheets'ten Güncelle",
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _onAddSelected,
                    style: FilledButton.styleFrom(
                      backgroundColor: WAColors.accentDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text('Ekle ($selectedCount)'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _deleteAllContacts,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WAColors.errorRed,
                    side: const BorderSide(color: WAColors.errorRed),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}