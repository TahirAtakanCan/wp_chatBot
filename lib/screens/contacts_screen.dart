import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact_model.dart';
import '../models/delivery_record.dart';
import '../models/export_options.dart';
import '../models/failure_category.dart';
import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../services/api_service.dart';
import '../services/contact_service.dart';
import '../theme/wa_colors.dart';
import '../widgets/contact_row.dart';
import '../widgets/delivery_status_icon.dart';

class ContactsScreen extends StatefulWidget {
  final List<String> initiallySelectedNumbers;
  const ContactsScreen({super.key, this.initiallySelectedNumbers = const []});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  final ContactService _contactService = ContactService();
  final ApiService _apiService = ApiService();
  final ScrollController _listController = ScrollController();
  late final TabController _tabController;

  Timer? _statusLookupTimer;
  bool _statusRequestInFlight = false;
  bool _loading = false;
  bool _syncing = false;
  bool _isExporting = false;

  final Map<String, DeliveryRecord?> _deliveryCache = {};
  List<ContactModel> _contacts = [];
  Set<int> _selectedContactIds = {};
  String _searchQuery = '';
  Set<String> _selectedLetters = {'Tümü'};
  List<FailureCategory> _failureCategories = [];
  final Set<String> _selectedFailureFilters = {};
  String? _selectedPasifTemplate;
  int? _passiveDays = 30;

  static const String _sheetsUrlKey = 'google_sheets_url';
  static const double _itemExtent = 84.0;
  static final List<String> _letters = [
    'Tümü',
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H',
    'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P',
    'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
    'İsimsiz',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_scheduleStatusLookup);
    _listController.addListener(_scheduleStatusLookup);
    _fetchContacts();
    _loadFailureCategories();
  }

  @override
  void dispose() {
    _statusLookupTimer?.cancel();
    _listController.removeListener(_scheduleStatusLookup);
    _tabController.removeListener(_scheduleStatusLookup);
    _listController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<ContactModel> get _activeContactsRaw {
    return _contacts.where((c) {
      final delivery = _deliveryCache[c.phone];
      if (delivery == null) return true;
      if (delivery.status == DeliveryStatus.sent ||
          delivery.status == DeliveryStatus.delivered ||
          delivery.status == DeliveryStatus.read) {
        return true;
      }
      if (delivery.status == DeliveryStatus.failed) {
        final reference = delivery.failedAt ?? delivery.sentAt;
        final daysSince = DateTime.now().difference(reference).inDays;
        return daysSince > 30;
      }
      return true;
    }).toList();
  }

  List<ContactModel> get _inactiveContactsRaw {
    return _contacts.where((c) {
      final delivery = _deliveryCache[c.phone];
      if (delivery == null) return false;
      if (delivery.status != DeliveryStatus.failed) return false;
      final reference = delivery.failedAt ?? delivery.sentAt;
      final daysSince = DateTime.now().difference(reference).inDays;
      return daysSince <= 30;
    }).toList();
  }

  List<ContactModel> get _newContactsRaw {
    // Contact model'inde createdAt olmadığı için bu sekme şimdilik boş.
    return const <ContactModel>[];
  }

  List<String> get _availableTemplates {
    final names = _deliveryCache.values
        .whereType<DeliveryRecord>()
        .map((d) => d.templateName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  List<ContactModel> get _filteredInactiveContacts {
    return _applyTextAndLetterFilters(_inactiveContactsRaw).where((c) {
      final delivery = _deliveryCache[c.phone];
      if (delivery == null || delivery.status != DeliveryStatus.failed) {
        return false;
      }

      if (_selectedFailureFilters.isNotEmpty) {
        final code = delivery.failureCode ?? '';
        if (!_selectedFailureFilters.contains(code)) return false;
      }

      if ((_selectedPasifTemplate ?? '').isNotEmpty &&
          delivery.templateName != _selectedPasifTemplate) {
        return false;
      }

      if (_passiveDays != null) {
        final reference = delivery.failedAt ?? delivery.sentAt;
        final daysSince = DateTime.now().difference(reference).inDays;
        if (daysSince > _passiveDays!) return false;
      }

      return true;
    }).toList();
  }

  List<ContactModel> _contactsForCurrentTabRaw() {
    switch (_tabController.index) {
      case 1:
        return _inactiveContactsRaw;
      case 2:
        return _newContactsRaw;
      case 0:
      default:
        return _activeContactsRaw;
    }
  }

  List<ContactModel> _applyTextAndLetterFilters(List<ContactModel> source) {
    var result = source;
    if (!_selectedLetters.contains('Tümü')) {
      result = result.where((c) {
        final trimmed = c.name.trim();
        if (trimmed.isEmpty) return _selectedLetters.contains('İsimsiz');
        final first = _normalizeFirstChar(trimmed);
        return _selectedLetters.any((l) => l != 'İsimsiz' && l == first);
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
          .toList();
    }
    return result;
  }

  List<ContactModel> get _visibleContacts =>
      _applyTextAndLetterFilters(_contactsForCurrentTabRaw());

  String _normalizeFirstChar(String name) {
    if (name.isEmpty) return '';
    final first = name.trimLeft()[0];
    const map = {
      'ç': 'Ç',
      'ğ': 'Ğ',
      'ı': 'I',
      'i': 'İ',
      'ö': 'Ö',
      'ş': 'Ş',
      'ü': 'Ü',
    };
    return map[first] ?? first.toUpperCase();
  }

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
      });
      await _loadLatestDeliveries();
      _scheduleStatusLookup();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFailureCategories() async {
    try {
      final categories = await _apiService.fetchFailureCategories();
      if (!mounted) return;
      setState(() => _failureCategories = categories);
    } catch (_) {
      // Kategori alınamazsa pasif filtre chipleri boş kalır.
    }
  }

  Future<void> _loadLatestDeliveries() async {
    final latestByPhone = <String, DeliveryRecord>{};
    var page = 0;
    while (true) {
      final items = await _apiService.listDeliveries(page: page, size: 200);
      for (final item in items) {
        latestByPhone.putIfAbsent(item.phoneNumber, () => item);
      }
      if (items.length < 200 || page > 30) break;
      page += 1;
    }
    if (!mounted) return;
    setState(() {
      _deliveryCache
        ..clear()
        ..addAll(latestByPhone.map((k, v) => MapEntry(k, v)));
    });
  }

  void _scheduleStatusLookup() {
    if (!mounted) return;
    _statusLookupTimer?.cancel();
    _statusLookupTimer = Timer(const Duration(milliseconds: 200), () {
      _lookupVisibleStatuses();
    });
  }

  Future<void> _lookupVisibleStatuses() async {
    if (_statusRequestInFlight || !_listController.hasClients) return;
    final visibleList = _visibleContacts;
    if (visibleList.isEmpty) return;

    final viewport = _listController.position.viewportDimension;
    final offset = _listController.offset;
    final start = (offset / _itemExtent).floor().clamp(0, visibleList.length);
    final end = ((offset + viewport) / _itemExtent).ceil().clamp(0, visibleList.length);
    final visibleSlice = visibleList.sublist(start, end > start ? end : start);
    final phones = visibleSlice
        .map((c) => c.phone)
        .where((p) => !_deliveryCache.containsKey(p))
        .toList();
    if (phones.isEmpty) return;

    _statusRequestInFlight = true;
    try {
      final statuses = await _apiService.lookupDeliveryStatuses(phones);
      if (!mounted) return;
      setState(() {
        for (final phone in phones) {
          final status = statuses[phone];
          if (status != null) {
            _deliveryCache[phone] = DeliveryRecord(
              id: -1,
              phoneNumber: phone,
              templateName: '',
              status: status,
              sentAt: DateTime.now(),
              createdAt: DateTime.now(),
            );
          } else {
            _deliveryCache[phone] = null;
          }
        }
      });
    } catch (_) {
      // Sessiz geç.
    } finally {
      _statusRequestInFlight = false;
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _scheduleStatusLookup();
  }

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
    });
    if (_listController.hasClients) {
      _listController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    _scheduleStatusLookup();
  }

  void _onSelectAll() {
    setState(() {
      _selectedContactIds.addAll(_visibleContacts.map((c) => c.id));
    });
  }

  void _onDeselectAll() {
    setState(() {
      for (final c in _visibleContacts) {
        _selectedContactIds.remove(c.id);
      }
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

  Future<void> _onContactLongPress(ContactModel contact) async {
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
    if (confirmed != true) return;

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final success = await _contactService.deleteContact(context, authProvider, contact.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Kişi silindi.' : 'Kişi silinemedi.')),
    );
    if (success) {
      await _fetchContacts();
    }
  }

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
    if (confirmed != true) return;
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final success = await _contactService.deleteAllContacts(context, authProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Tüm rehber silindi.' : 'Rehber silinemedi.')),
    );
    if (success) {
      await _fetchContacts();
    }
  }

  Future<void> _onPassiveContactTap(ContactModel contact) async {
    final delivery = _deliveryCache[contact.phone];
    final failedAt = delivery?.failedAt ?? delivery?.sentAt;
    final daysAgo = failedAt == null ? '-' : DateTime.now().difference(failedAt).inDays;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(contact.name.isEmpty ? 'İsimsiz' : contact.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.phone),
            const SizedBox(height: 10),
            Text(
              'Son durum: Başarısız (${delivery?.failureCode ?? '-'})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Son deneme: ${daysAgo == '-' ? '-' : '$daysAgo gün önce'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('retry'),
            child: const Text('Tekrar Dene'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            style: TextButton.styleFrom(foregroundColor: WAColors.errorRed),
            child: const Text('Sil'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );

    if (action == 'retry') {
      await _retrySendToContact(contact);
    } else if (action == 'delete') {
      await _onContactLongPress(contact);
    }
  }

  Future<void> _retrySendToContact(ContactModel contact) async {
    final messageProvider = context.read<MessageProvider>();
    if (messageProvider.selectedPreset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir hazır kayıt seçin.')),
      );
      return;
    }
    messageProvider.phoneController.text = contact.phone;
    messageProvider.parsePhoneNumbers();
    await messageProvider.startSending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${contact.phone} için yeniden gönderim başlatıldı.')),
    );
  }

  Future<void> _exportCurrentTab() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      ExportOptions options;
      String tabName;
      switch (_tabController.index) {
        case 1:
          tabName = 'pasif';
          options = ExportOptions(
            status: DeliveryStatus.failed.name.toUpperCase(),
            days: _passiveDays ?? 30,
            failureCodes: _selectedFailureFilters.toList(),
            templateName: _selectedPasifTemplate,
            columns: {
              ExportColumn.isim,
              ExportColumn.telefon,
              ExportColumn.sablon,
              ExportColumn.hataKodu,
              ExportColumn.hataKategori,
              ExportColumn.hataDetay,
              ExportColumn.basarisizTarihi,
            },
            sortBy: 'SENT_AT_DESC',
          );
          break;
        case 2:
          tabName = 'yeni';
          options = ExportOptions(
            days: 7,
            columns: {ExportColumn.isim, ExportColumn.telefon},
            sortBy: 'SENT_AT_DESC',
          );
          break;
        case 0:
        default:
          tabName = 'aktif';
          options = ExportOptions(
            days: 30,
            columns: {
              ExportColumn.isim,
              ExportColumn.telefon,
              ExportColumn.durum,
              ExportColumn.gonderimTarihi,
              ExportColumn.okunduTarihi,
            },
            sortBy: 'SENT_AT_DESC',
          );
      }

      await _apiService.downloadExcelWithOptions(options);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tabName.xlsx indiriliyor')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel indirme hatası: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPasif() async {
    await _exportCurrentTab();
  }

  String _translateFailureReason(String? code) {
    switch (code) {
      case '131026':
        return 'Mesaj iletilemedi';
      case '131048':
        return 'Spam koruma';
      case '131049':
        return 'Ekosistem koruma';
      case '131050':
        return 'Engellenmiş';
      case '130472':
        return 'Pazarlama iptal';
      case null:
      case '':
        return 'Hata detayı yok';
      default:
        return 'Hata: $code';
    }
  }

  void _onAddSelected() {
    final selectedContacts = _contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .map((c) => c.name.isNotEmpty ? '${c.name} - ${c.phone}' : c.phone)
        .toList();
    Navigator.pop(context, selectedContacts);
  }

  Future<String?> _getOrAskSheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sheetsUrlKey);
    if (saved != null && saved.isNotEmpty) return saved;
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
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('İptal')),
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
      const SnackBar(content: Text('Sheets URL sıfırlandı.')),
    );
  }

  Future<void> _syncFromSheets() async {
    final sheetUrl = await _getOrAskSheetUrl();
    if (sheetUrl == null || !mounted) return;
    setState(() => _syncing = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final result =
          await _contactService.syncFromGoogleSheets(context, authProvider, sheetUrl);
      final imported = result['imported'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      await _fetchContacts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellendi: $imported eklendi, $skipped atlandı.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncelleme başarısız. URL’yi kontrol edin.')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedContactIds.length;
    final activeCount = _activeContactsRaw.length;
    final inactiveCount = _inactiveContactsRaw.length;
    final newCount = _newContactsRaw.length;

    return Scaffold(
      backgroundColor: WAColors.appBackground,
      appBar: AppBar(
        backgroundColor: WAColors.leftPanelHeader,
        title: Text('Kişi Rehberi${selectedCount > 0 ? ' ($selectedCount seçili)' : ''}'),
        actions: [
          IconButton(
            tooltip: 'Görünen kişileri Excel indir',
            onPressed: _isExporting ? null : _exportCurrentTab,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_rounded),
          ),
          IconButton(
            tooltip: 'Sheets\'ten güncelle',
            onPressed: _syncing ? null : _syncFromSheets,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _resetSheetUrl();
              if (value == 'delete_all') _deleteAllContacts();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Sheets URL sıfırla')),
              PopupMenuItem(value: 'delete_all', child: Text('Rehberi sil')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Aktif ($activeCount)'),
            Tab(text: 'Pasif ($inactiveCount)'),
            Tab(text: 'Yeni ($newCount)'),
          ],
        ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: WAColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_visibleContacts.length} kişi',
                        style: const TextStyle(
                          color: WAColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                      hintText: 'Ara...',
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? WAColors.accent : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? WAColors.accent : WAColors.divider,
                              ),
                            ),
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : WAColors.textSecondary,
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
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContactList(_applyTextAndLetterFilters(_activeContactsRaw)),
                      _buildPassiveTab(),
                      _buildContactList(_applyTextAndLetterFilters(_newContactsRaw)),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: WAColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: selectedCount == 0 ? null : _onAddSelected,
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text('Seçilenleri Ekle ($selectedCount)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList(List<ContactModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text('Kişi bulunamadı.'));
    }
    return ListView.builder(
      controller: _listController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final contact = list[index];
        final selected = _selectedContactIds.contains(contact.id);
        return ContactRow(
          contact: contact,
          selected: selected,
          deliveryStatus: _deliveryCache[contact.phone]?.status,
          onSelected: (val) => _onToggleContact(contact, val),
          onLongPress: () => _onContactLongPress(contact),
        );
      },
    );
  }

  Widget _buildPassiveTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Tarih: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        _buildPassiveDayChip('Bugün', 1),
                        _buildPassiveDayChip('7 gün', 7),
                        _buildPassiveDayChip('30 gün', 30),
                        _buildPassiveDayChip('Tümü', null),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Sebep: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _failureCategories.map((cat) {
                        final selected = _selectedFailureFilters.contains(cat.code);
                        return FilterChip(
                          label: Text(
                            '${cat.category} (${cat.code})',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedFailureFilters.add(cat.code);
                              } else {
                                _selectedFailureFilters.remove(cat.code);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Şablon: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Expanded(
                    child: DropdownButton<String?>(
                      value: _selectedPasifTemplate,
                      isExpanded: true,
                      hint: const Text('Tüm şablonlar'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tüm şablonlar'),
                        ),
                        ..._availableTemplates.map(
                          (t) => DropdownMenuItem<String?>(value: t, child: Text(t)),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedPasifTemplate = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sonuç: ${_filteredInactiveContacts.length} kişi',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  ElevatedButton.icon(
                    onPressed: _filteredInactiveContacts.isEmpty ? null : _exportPasif,
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Excel İndir'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _buildPassiveList(_filteredInactiveContacts)),
      ],
    );
  }

  Widget _buildPassiveDayChip(String label, int? days) {
    final selected = _passiveDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _passiveDays = days),
    );
  }

  Widget _buildPassiveList(List<ContactModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text('Pasif kişi bulunamadı.'));
    }
    return ListView.builder(
      controller: _listController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final contact = list[index];
        final selected = _selectedContactIds.contains(contact.id);
        final delivery = _deliveryCache[contact.phone];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Material(
            color: selected
                ? WAColors.accent.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _onPassiveContactTap(contact),
              onLongPress: () => _onContactLongPress(contact),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WAColors.divider),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (val) => _onToggleContact(contact, val),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name.isEmpty ? 'İsimsiz' : contact.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            contact.phone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: WAColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if ((delivery?.failureCode ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    delivery!.failureCode!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              Text(
                                _translateFailureReason(delivery?.failureCode),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DeliveryStatusIcon(status: delivery?.status),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
