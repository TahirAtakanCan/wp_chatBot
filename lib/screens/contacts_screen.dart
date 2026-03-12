import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';
import '../providers/auth_provider.dart';

class ContactsScreen extends StatefulWidget {
  final List<String> initiallySelectedNumbers;
  const ContactsScreen({Key? key, this.initiallySelectedNumbers = const []})
      : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactService _contactService = ContactService();
  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  Set<int> _selectedContactIds = {};
  bool _autoSelect = true;
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
    _fetchContacts();
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

  void _updateFilteredAndAutoSelect() {
    _filteredContacts = _applyFilters();
    if (_autoSelect) {
      _selectedContactIds = _filteredContacts.map((c) => c.id).toSet();
    }
  }

  // ─── VERİ ÇEKME ───────────────────────────────────────────────
  Future<void> _fetchContacts() async {
    setState(() => _loading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final contacts = await _contactService.getAllContacts(context, authProvider);
      setState(() {
        _contacts = contacts;
        _selectedContactIds = contacts
            .where((c) => widget.initiallySelectedNumbers.contains(c.phone))
            .map((c) => c.id)
            .toSet();
        _filteredContacts = _applyFilters();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ─── ARAMA ────────────────────────────────────────────────────
  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _updateFilteredAndAutoSelect();
    });
  }

  // ─── SEÇİM ────────────────────────────────────────────────────
  void _onSelectAll() {
    setState(() {
      _autoSelect = true;
      _selectedContactIds = _filteredContacts.map((c) => c.id).toSet();
    });
  }

  void _onDeselectAll() {
    setState(() {
      _autoSelect = false;
      _selectedContactIds.clear();
    });
  }

  void _onToggleContact(ContactModel contact, bool? val) {
    setState(() {
      _autoSelect = false;
      if (val == true) {
        _selectedContactIds.add(contact.id);
      } else {
        _selectedContactIds.remove(contact.id);
      }
    });
  }

  // ─── HARF FİLTRESİ ────────────────────────────────────────────
  void _onLetterTap(String letter) {
    setState(() {
      if (letter == 'Tümü') {
        _selectedLetters = {'Tümü'};
      } else {
        _selectedLetters.remove('Tümü');
        if (_selectedLetters.contains(letter)) {
          _selectedLetters.remove(letter);
          if (_selectedLetters.isEmpty) _selectedLetters = {'Tümü'};
        } else {
          _selectedLetters.add(letter);
        }
      }
      _autoSelect = true; // Harf seçince otomatik seçim aktif
      _updateFilteredAndAutoSelect();
    });
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
      final authProvider = context.read<AuthProvider>();
      final success = await _contactService.deleteContact(context, authProvider, contact.id);
      if (success) {
        await _fetchContacts();
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
      final authProvider = context.read<AuthProvider>();
      final success = await _contactService.deleteAllContacts(context, authProvider);
      if (success) {
        await _fetchContacts();
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
              child: const Text('Kaydet')),
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
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sheets URL sıfırlandı.')));
  }

  Future<void> _syncFromSheets() async {
    final sheetUrl = await _getOrAskSheetUrl();
    if (sheetUrl == null) return;

    setState(() => _syncing = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final result = await _contactService.syncFromGoogleSheets(context, authProvider, sheetUrl);
      final imported = result['imported'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      await _fetchContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellendi: $imported kişi eklendi, $skipped atlandı.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncelleme başarısız. URL\'yi kontrol edin.')),
      );
    } finally {
      setState(() => _syncing = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedContactIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kişi Rehberi${selectedCount > 0 ? ' ($selectedCount seçili)' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: 'Sheets URL\'yi Sıfırla',
            onPressed: _resetSheetUrl,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Column(
              children: [
                // Tümünü Seç / Seçimi Temizle
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('Tümünü Seç'),
                      onPressed: _onSelectAll,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Seçimi Temizle'),
                      onPressed: _onDeselectAll,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Harf filtresi
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _letters.length,
                    itemBuilder: (context, index) {
                      final letter = _letters[index];
                      final isSelected = _selectedLetters.contains(letter);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FilterChip(
                          label: Text(letter, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (_) => _onLetterTap(letter),
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Arama kutusu
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Ara',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),

          // Kişi listesi
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? const Center(child: Text('Kişi bulunamadı.'))
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final selected = _selectedContactIds.contains(contact.id);
                          return ListTile(
                            dense: true,
                            onLongPress: () => _onContactLongPress(contact),
                            leading: Checkbox(
                              value: selected,
                              onChanged: (val) => _onToggleContact(contact, val),
                            ),
                            title: Text(contact.name.isNotEmpty ? contact.name : '—'),
                            subtitle: Text(contact.phone),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'syncSheets',
            backgroundColor: Colors.green.shade700,
            icon: _syncing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_syncing ? 'Güncelleniyor...' : 'Sheets\'ten Güncelle'),
            onPressed: _syncing ? null : _syncFromSheets,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addSelected',
            icon: const Icon(Icons.person_add),
            label: Text('Seçilenleri Ekle ($selectedCount)'),
            onPressed: _onAddSelected,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'deleteAll',
            backgroundColor: Colors.red,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Rehberi Sil'),
            onPressed: _deleteAllContacts,
          ),
        ],
      ),
    );
  }
}