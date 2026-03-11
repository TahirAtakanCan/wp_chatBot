import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';

class ContactsScreen extends StatefulWidget {
  final List<String> initiallySelectedNumbers;
  const ContactsScreen({Key? key, this.initiallySelectedNumbers = const []}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactService _contactService = ContactService();
  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  Set<int> _selectedContactIds = {};
  String _searchQuery = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedContactIds.clear(); // Seçim senkronizasyonu: her açılışta temizle
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
    setState(() => _searchQuery = value);
    if (value.isEmpty) {
      setState(() => _filteredContacts = _contacts);
    } else {
      final results = await _contactService.searchContacts(value);
      setState(() => _filteredContacts = results);
    }
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final csvContent = await file.readAsString();
      final success = await _contactService.importContacts(csvContent);
      if (success) {
        await _fetchContacts();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV başarıyla içe aktarıldı.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV içe aktarılamadı.')));
      }
    }
  }

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

  void _onContactLongPress(ContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kişiyi Sil'),
        content: Text('${contact.name} kişisini silmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await _contactService.deleteContact(contact.id);
      if (success) {
        await _fetchContacts();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kişi silindi.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kişi silinemedi.')));
      }
    }
  }

  void _onAddSelected() {
    final selectedContacts = _contacts
      .where((c) => _selectedContactIds.contains(c.id))
      .map((c) => (c.name.isNotEmpty ? '${c.name} - ${c.phone}' : c.phone))
      .toList();
    Navigator.pop(context, selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kişi Rehberi'),
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
                      icon: Icon(Icons.select_all),
                      label: Text('Tümünü Seç'),
                      onPressed: _onSelectAll,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.clear_all),
                      label: Text('Seçimi Temizle'),
                      onPressed: _onDeselectAll,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
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
                ? Center(child: CircularProgressIndicator())
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
          FloatingActionButton.extended(
            heroTag: 'importCsv',
            icon: Icon(Icons.upload_file),
            label: Text('CSV İçe Aktar'),
            onPressed: _importCsv,
          ),
          SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addSelected',
            icon: Icon(Icons.person_add),
            label: Text('Seçilenleri Ekle'),
            onPressed: _onAddSelected,
          ),
        ],
      ),
    );
  }
}
