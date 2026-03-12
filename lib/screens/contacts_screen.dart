import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';

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
  bool _loading = false;
  bool _syncing = false; // Sheets güncelleme loading

  static const String _sheetsUrlKey = 'google_sheets_url';

  @override
  void initState() {
    super.initState();
    _selectedContactIds.clear();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _loading = true);
    try {
      final contacts = await _contactService.getAllContacts();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _selectedContactIds = contacts
            .where((c) => widget.initiallySelectedNumbers.contains(c.phone))
            .map((c) => c.id)
            .toSet();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() => _filteredContacts = _contacts);
    } else {
      final results = await _contactService.searchContacts(value);
      setState(() => _filteredContacts = results);
    }
  }

  void _onSelectAll() {
    setState(() {
      _selectedContactIds = _filteredContacts.map((c) => c.id).toSet();
    });
  }

  void _onDeselectAll() {
    setState(() => _selectedContactIds.clear());
  }

  void _onContactLongPress(ContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kişiyi Sil'),
        content: Text('${contact.name} kişisini silmek istiyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await _contactService.deleteContact(contact.id);
      if (success) {
        await _fetchContacts();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Kişi silindi.')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Kişi silinemedi.')));
      }
    }
  }

  void _onAddSelected() {
    final selectedContacts = _contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .map((c) => c.name.isNotEmpty ? '${c.name} - ${c.phone}' : c.phone)
        .toList();
    Navigator.pop(context, selectedContacts);
  }

  Future<void> _deleteAllContacts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm rehber silinecek'),
        content: const Text('Bu işlem geri alınamaz. Emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await _contactService.deleteAllContacts();
      if (success) {
        await _fetchContacts();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tüm rehber başarıyla silindi.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rehber silinemedi.')));
      }
    }
  }

  /// Kayıtlı URL'yi getirir. Yoksa kullanıcıdan ister ve kaydeder.
  Future<String?> _getOrAskSheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedUrl = prefs.getString(_sheetsUrlKey);

    if (savedUrl != null && savedUrl.isNotEmpty) return savedUrl;

    // URL henüz kaydedilmemiş — dialog ile sor
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
              child: const Text('İptal')),
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

  /// URL'yi sıfırla — uzun basınca seçenek sun
  Future<void> _resetSheetUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sheetsUrlKey);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sheets URL sıfırlandı. Bir sonraki güncellemede yeniden girebilirsiniz.')));
  }

  Future<void> _syncFromSheets() async {
    final sheetUrl = await _getOrAskSheetUrl();
    if (sheetUrl == null) return;

    setState(() => _syncing = true);
    try {
      final result = await _contactService.syncFromGoogleSheets(sheetUrl);
      final imported = result['imported'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      await _fetchContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Güncellendi: $imported kişi eklendi, $skipped atlandı.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncelleme başarısız. URL\'yi kontrol edin.')),
      );
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişi Rehberi'),
        actions: [
          // URL sıfırlama — ayarlar ikonu
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
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.select_all),
                      label: const Text('Tümünü Seç'),
                      onPressed: _onSelectAll,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Seçimi Temizle'),
                      onPressed: _onDeselectAll,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Ara',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final selected = _selectedContactIds.contains(contact.id);
                      return ListTile(
                        onLongPress: () => _onContactLongPress(contact),
                        leading: Checkbox(
                          value: selected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedContactIds.add(contact.id);
                              } else {
                                _selectedContactIds.remove(contact.id);
                              }
                            });
                          },
                        ),
                        title: Text(contact.name),
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
          // 1. Google Sheets'ten Güncelle
          FloatingActionButton.extended(
            heroTag: 'syncSheets',
            backgroundColor: Colors.green.shade700,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_syncing ? 'Güncelleniyor...' : 'Sheets\'ten Güncelle'),
            onPressed: _syncing ? null : _syncFromSheets,
          ),
          const SizedBox(height: 12),
          // 2. Seçilenleri Ekle
          FloatingActionButton.extended(
            heroTag: 'addSelected',
            icon: const Icon(Icons.person_add),
            label: const Text('Seçilenleri Ekle'),
            onPressed: _onAddSelected,
          ),
          const SizedBox(height: 12),
          // 3. Rehberi Sil
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