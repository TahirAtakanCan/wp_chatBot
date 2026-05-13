import 'package:flutter/material.dart';

class MobileHomeScreen extends StatelessWidget {
  final VoidCallback onInbox;
  final VoidCallback onBulkSend;
  final VoidCallback onDeliveryHistory;
  final VoidCallback onContacts;
  final VoidCallback onTemplates;
  final VoidCallback onLogout;

  const MobileHomeScreen({
    super.key,
    required this.onInbox,
    required this.onBulkSend,
    required this.onDeliveryHistory,
    required this.onContacts,
    required this.onTemplates,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_HomeMenuItem>[
      _HomeMenuItem(
        icon: Icons.inbox_outlined,
        title: 'Gelen Kutusu',
        subtitle: 'Mesajlasmalar',
        onTap: onInbox,
      ),
      _HomeMenuItem(
        icon: Icons.send_rounded,
        title: 'Toplu Mesaj Gonder',
        subtitle: 'Numara listesi ve template',
        onTap: onBulkSend,
      ),
      _HomeMenuItem(
        icon: Icons.bar_chart,
        title: 'Gonderim Raporlari',
        subtitle: 'Durum ve istatistikler',
        onTap: onDeliveryHistory,
      ),
      _HomeMenuItem(
        icon: Icons.contacts,
        title: 'Kisi Rehberi',
        subtitle: 'Rehberi yonet',
        onTap: onContacts,
      ),
      _HomeMenuItem(
        icon: Icons.bookmark_border,
        title: 'Sablonlarim',
        subtitle: 'Mesaj sablonlari',
        onTap: onTemplates,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('IHH WhatsApp'),
        actions: [
          IconButton(
            tooltip: 'Cikis',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _HomeMenuCard(item: item);
        },
      ),
    );
  }
}

class _HomeMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _HomeMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _HomeMenuCard extends StatelessWidget {
  final _HomeMenuItem item;

  const _HomeMenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    size: 26,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
