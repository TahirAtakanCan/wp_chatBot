import 'package:flutter/material.dart';

import '../../models/contact_model.dart';
import '../../models/delivery_record.dart';
import '../../theme/wa_colors.dart';
import '../../widgets/contact_row.dart';

class MobileContactsView extends StatelessWidget {
  final List<ContactModel> contacts;
  final Map<String, DeliveryStatus> statusByPhone;
  final Set<int> selectedContactIds;
  final Set<String> selectedLetters;
  final List<String> letters;
  final bool loading;
  final bool syncing;
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onLetterTap;
  final void Function(ContactModel, bool?) onToggleContact;
  final void Function(ContactModel) onContactLongPress;
  final VoidCallback onAddSelected;
  final VoidCallback onSyncFromSheets;
  final VoidCallback onDeleteAll;
  final VoidCallback onResetSheetUrl;

  const MobileContactsView({
    super.key,
    required this.contacts,
    required this.statusByPhone,
    required this.selectedContactIds,
    required this.selectedLetters,
    required this.letters,
    required this.loading,
    required this.syncing,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onSearchChanged,
    required this.onLetterTap,
    required this.onToggleContact,
    required this.onContactLongPress,
    required this.onAddSelected,
    required this.onSyncFromSheets,
    required this.onDeleteAll,
    required this.onResetSheetUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WAColors.appBackground,
      appBar: AppBar(
        backgroundColor: WAColors.leftPanelHeader,
        title: Text('Kişi Rehberi${selectedCount > 0 ? ' ($selectedCount seçili)' : ''}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                onResetSheetUrl();
              }
              if (value == 'delete_all') {
                onDeleteAll();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'reset',
                child: Text('Sheets URL Sifirla'),
              ),
              PopupMenuItem<String>(
                value: 'delete_all',
                child: Text('Rehberi Sil'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: syncing ? null : onSyncFromSheets,
        backgroundColor: Colors.green.shade700,
        icon: syncing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        label: Text(syncing ? 'Guncelleniyor...' : "Sheets'ten Guncelle"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.select_all, size: 18),
                        label: const Text('Tumunu Sec'),
                        onPressed: onSelectAll,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Secimi Temizle'),
                        onPressed: onDeselectAll,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Ara',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: letters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final letter = letters[index];
                      final isSelected = selectedLetters.contains(letter);
                      return FilterChip(
                        label: Text(letter, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (_) => onLetterTap(letter),
                        selectedColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : contacts.isEmpty
                    ? const Center(child: Text('Kisi bulunamadi.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final selected =
                              selectedContactIds.contains(contact.id);
                          return ContactRow(
                            contact: contact,
                            selected: selected,
                            deliveryStatus: statusByPhone[contact.phone],
                            onSelected: (val) => onToggleContact(contact, val),
                            onLongPress: () => onContactLongPress(contact),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: selectedCount == 0 ? null : onAddSelected,
              icon: const Icon(Icons.person_add),
              label: Text('Secilenleri Ekle ($selectedCount)'),
            ),
          ),
        ),
      ),
    );
  }
}
