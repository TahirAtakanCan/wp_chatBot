import 'package:flutter/material.dart';

import '../../models/delivery_record.dart';
import '../../widgets/delivery_status_icon.dart';

class MobileDeliveryHistoryView extends StatelessWidget {
  final List<DeliveryRecord> records;
  final Map<String, int> stats;
  final bool loading;
  final bool loadingMore;
  final DeliveryStatus? filterStatus;
  final String sortKey;
  final ScrollController scrollController;
  final String? purgeMessage;
  final VoidCallback onRefresh;
  final VoidCallback onExportExcel;
  final ValueChanged<DeliveryStatus?> onFilterChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<DeliveryRecord> onRecordTap;
  final String Function(DateTime) formatDateTime;

  const MobileDeliveryHistoryView({
    super.key,
    required this.records,
    required this.stats,
    required this.loading,
    required this.loadingMore,
    required this.filterStatus,
    required this.sortKey,
    required this.scrollController,
    this.purgeMessage,
    required this.onRefresh,
    required this.onExportExcel,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onRecordTap,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] ?? 0;
    final delivered = stats['delivered'] ?? 0;
    final failed = stats['failed'] ?? 0;
    final read = stats['read'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gonderim Raporlari'),
        actions: [
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: onExportExcel,
            tooltip: 'Excel indir',
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (purgeMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                purgeMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _StatsGrid(
              total: total,
              delivered: delivered,
              read: read,
              failed: failed,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Tumu',
                  selected: filterStatus == null,
                  onSelected: () => onFilterChanged(null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Iletildi',
                  selected: filterStatus == DeliveryStatus.delivered,
                  onSelected: () => onFilterChanged(DeliveryStatus.delivered),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Okundu',
                  selected: filterStatus == DeliveryStatus.read,
                  onSelected: () => onFilterChanged(DeliveryStatus.read),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Basarisiz',
                  selected: filterStatus == DeliveryStatus.failed,
                  onSelected: () => onFilterChanged(DeliveryStatus.failed),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Text('Siralama'),
                const Spacer(),
                DropdownButton<String>(
                  value: sortKey,
                  items: const [
                    DropdownMenuItem(
                      value: 'sentAt_desc',
                      child: Text('Yeniden Eskiye'),
                    ),
                    DropdownMenuItem(
                      value: 'sentAt_asc',
                      child: Text('Eskiden Yeniye'),
                    ),
                    DropdownMenuItem(
                      value: 'name_asc',
                      child: Text('Isim A-Z'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onSortChanged(value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                    ? const Center(child: Text('Gonderim bulunamadi.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: records.length + (loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= records.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final record = records[index];
                          final title = record.contactName ?? record.phoneNumber;
                          final subtitle = record.status == DeliveryStatus.failed
                              ? '${record.templateName} • ${record.failureReason ?? 'Basarisiz'}'
                              : '${record.templateName} • ${formatDateTime(record.sentAt)}';

                          return SizedBox(
                            height: 72,
                            child: ListTile(
                              leading: DeliveryStatusIcon(status: record.status),
                              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Text(
                                formatDateTime(record.sentAt),
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => onRecordTap(record),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int total;
  final int delivered;
  final int read;
  final int failed;

  const _StatsGrid({
    required this.total,
    required this.delivered,
    required this.read,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.pie_chart,
                label: 'Toplam',
                value: total.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.done_all,
                label: 'Iletildi',
                value: delivered.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.visibility,
                label: 'Okundu',
                value: read.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.error_outline,
                label: 'Basarisiz',
                value: failed.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onSelected,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
