import 'package:flutter/material.dart';

import '../models/delivery_record.dart';
import '../services/api_service.dart';
import '../theme/wa_colors.dart';
import '../utils/delivery_filters.dart';
import '../widgets/delivery_status_icon.dart';
import '../widgets/responsive_layout.dart';
import 'mobile/mobile_delivery_history_view.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<DeliveryRecord> _records = [];
  Map<String, int> _stats = {};
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  DeliveryStatus? _filterStatus;
  String _sortKey = 'sentAt_desc';
  String? _purgeMessage;

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _purgeOldRecords();
    await _loadStats();
    await _loadRecords(reset: true);
  }

  Future<void> _purgeOldRecords() async {
    try {
      final deleted = await _apiService.purgeOldDeliveries(days: 2);
      if (!mounted) return;
      if (deleted > 0) {
        setState(() {
          _purgeMessage = '$deleted eski kayit silindi';
        });
      }
    } catch (_) {
      // Sunucu purge desteklemiyorsa yalnizca istemci tarafinda filtre uygulanir.
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadRecords();
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _apiService.getDeliveryStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _loadRecords({bool reset = false}) async {
    if (_loadingMore || (_loading && !reset)) return;

    if (reset) {
      setState(() {
        _loading = true;
        _records = [];
        _page = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final sort = _resolveSort();
    try {
      if (_filterStatus != null) {
        await _loadFilteredPage(reset: reset, sort: sort);
      } else {
        await _loadUnfilteredPage(reset: reset, sort: sort);
      }
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadUnfilteredPage({
    required bool reset,
    required _SortOption sort,
  }) async {
    final items = await _apiService.listDeliveries(
      page: _page,
      size: _pageSize,
      sortBy: sort.sortBy,
      direction: sort.direction,
    );

    if (!mounted) return;
    final visible = filterDeliveryRecords(items);
    setState(() {
      if (reset) {
        _records = visible;
      } else {
        _records = _mergeUnique(_records, visible);
      }
      _page += 1;
      _hasMore = items.length == _pageSize;
    });
  }

  Future<void> _loadFilteredPage({
    required bool reset,
    required _SortOption sort,
  }) async {
    final status = _filterStatus!;
    final targetCount = reset ? _pageSize : _records.length + _pageSize;
    final accumulated = reset ? <DeliveryRecord>[] : [..._records];
    var fetchPage = reset ? 0 : _page;
    var rawHasMore = true;

    while (accumulated.length < targetCount && rawHasMore) {
      final items = await _apiService.listDeliveries(
        page: fetchPage,
        size: 100,
        status: status,
        sortBy: sort.sortBy,
        direction: sort.direction,
      );

      final visible = filterDeliveryRecords(items, status: status);
      accumulated.addAll(visible);
      rawHasMore = items.length == 100;
      fetchPage += 1;
      if (fetchPage > 100) break;
    }

    if (!mounted) return;
    setState(() {
      _records = _mergeUnique(const [], accumulated);
      _page = fetchPage;
      _hasMore = rawHasMore;
    });
  }

  List<DeliveryRecord> _mergeUnique(
    List<DeliveryRecord> current,
    List<DeliveryRecord> incoming,
  ) {
    final ids = current.map((e) => e.id).toSet();
    final merged = [...current];
    for (final item in incoming) {
      if (ids.add(item.id)) merged.add(item);
    }
    return merged;
  }

  void _setFilter(DeliveryStatus? status) {
    setState(() => _filterStatus = status);
    _loadRecords(reset: true);
  }

  void _setSort(String value) {
    setState(() => _sortKey = value);
    _loadRecords(reset: true);
  }

  _SortOption _resolveSort() {
    switch (_sortKey) {
      case 'sentAt_asc':
        return const _SortOption(sortBy: 'sentAt', direction: 'asc');
      case 'name_asc':
        return const _SortOption(sortBy: 'contactName', direction: 'asc');
      case 'sentAt_desc':
      default:
        return const _SortOption(sortBy: 'sentAt', direction: 'desc');
    }
  }

  Future<void> _showHistoryForPhone(DeliveryRecord record) async {
    final phone = record.phoneNumber;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<List<DeliveryRecord>>(
          future: _apiService.getDeliveryByPhone(phone),
          builder: (context, snapshot) {
            final items = filterDeliveryRecords(snapshot.data ?? []);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record.contactName ?? phone,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )
                  else if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Gonderim gecmisi bulunamadi.'),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            dense: true,
                            leading: DeliveryStatusIcon(status: item.status),
                            title: Text(item.templateName),
                            subtitle: Text(
                              _formatDateTime(item.sentAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: MobileDeliveryHistoryView(
        records: _records,
        stats: _stats,
        loading: _loading,
        loadingMore: _loadingMore,
        filterStatus: _filterStatus,
        sortKey: _sortKey,
        scrollController: _scrollController,
        purgeMessage: _purgeMessage,
        onRefresh: _bootstrap,
        onFilterChanged: _setFilter,
        onSortChanged: _setSort,
        onRecordTap: _showHistoryForPhone,
        formatDateTime: _formatDateTime,
      ),
      desktop: _buildDesktopView(context),
    );
  }

  Widget _buildDesktopView(BuildContext context) {
    final total = _stats['total'] ?? 0;
    final delivered = _stats['delivered'] ?? 0;
    final failed = _stats['failed'] ?? 0;
    final read = _stats['read'] ?? 0;

    return Scaffold(
      backgroundColor: WAColors.appBackground,
      appBar: AppBar(
        backgroundColor: WAColors.leftPanelHeader,
        title: const Text('Gonderim Raporlari'),
        actions: [
          if (_purgeMessage != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  _purgeMessage!,
                  style: const TextStyle(fontSize: 12, color: WAColors.accent),
                ),
              ),
            ),
          IconButton(
            onPressed: _bootstrap,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _StatTile(
                  icon: Icons.pie_chart_rounded,
                  label: 'Toplam',
                  value: '$total',
                  color: WAColors.textPrimary,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  icon: Icons.done_all_rounded,
                  label: 'Iletildi',
                  value: '$delivered',
                  color: WAColors.accent,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  icon: Icons.visibility_rounded,
                  label: 'Okundu',
                  value: '$read',
                  color: WAColors.statusRead,
                ),
                const SizedBox(width: 12),
                _StatTile(
                  icon: Icons.error_outline_rounded,
                  label: 'Basarisiz',
                  value: '$failed',
                  color: WAColors.errorRed,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _ReportFilterChip(
                  label: 'Tumu',
                  selected: _filterStatus == null,
                  onTap: () => _setFilter(null),
                ),
                const SizedBox(width: 8),
                _ReportFilterChip(
                  label: 'Iletildi',
                  selected: _filterStatus == DeliveryStatus.delivered,
                  onTap: () => _setFilter(DeliveryStatus.delivered),
                ),
                const SizedBox(width: 8),
                _ReportFilterChip(
                  label: 'Okundu',
                  selected: _filterStatus == DeliveryStatus.read,
                  onTap: () => _setFilter(DeliveryStatus.read),
                ),
                const SizedBox(width: 8),
                _ReportFilterChip(
                  label: 'Basarisiz',
                  selected: _filterStatus == DeliveryStatus.failed,
                  onTap: () => _setFilter(DeliveryStatus.failed),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WAColors.divider),
                  ),
                  child: DropdownButton<String>(
                    value: _sortKey,
                    underline: const SizedBox.shrink(),
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
                      _setSort(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Son 2 gunluk kayitlar gosterilir',
                style: TextStyle(
                  fontSize: 12,
                  color: WAColors.textTertiary.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(child: Text('Gonderim bulunamadi.'))
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _records.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          if (index >= _records.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final record = _records[index];
                          return _ReportListTile(
                            record: record,
                            formatDateTime: _formatDateTime,
                            onTap: () => _showHistoryForPhone(record),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WAColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: WAColors.textSecondary)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReportFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? WAColors.accent : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? WAColors.accent : WAColors.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : WAColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportListTile extends StatelessWidget {
  final DeliveryRecord record;
  final String Function(DateTime) formatDateTime;
  final VoidCallback onTap;

  const _ReportListTile({
    required this.record,
    required this.formatDateTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = record.contactName ?? record.phoneNumber;
    final subtitle = record.status == DeliveryStatus.failed
        ? '${record.templateName} • ${record.failureReason ?? 'Basarisiz'}'
        : record.templateName;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WAColors.divider),
          ),
          child: Row(
            children: [
              DeliveryStatusIcon(status: record.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: WAColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: WAColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatDateTime(record.sentAt),
                style: const TextStyle(fontSize: 12, color: WAColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortOption {
  final String sortBy;
  final String direction;

  const _SortOption({required this.sortBy, required this.direction});
}
