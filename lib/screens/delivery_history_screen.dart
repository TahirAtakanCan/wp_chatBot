import 'package:flutter/material.dart';

import '../models/delivery_record.dart';
import '../services/api_service.dart';
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

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadStats();
    _loadRecords(reset: true);
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
      setState(() {
        _stats = stats;
      });
    } catch (_) {
      // Sessiz gec
    }
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
      setState(() {
        _loadingMore = true;
      });
    }

    final sort = _resolveSort();
    try {
      final items = await _apiService.listDeliveries(
        page: _page,
        size: _pageSize,
        status: _filterStatus,
        sortBy: sort.sortBy,
        direction: sort.direction,
      );

      if (!mounted) return;
      setState(() {
        _records = [..._records, ...items];
        _page += 1;
        _hasMore = items.length == _pageSize;
      });
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
            final items = snapshot.data ?? [];
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
        onRefresh: () {
          _loadStats();
          _loadRecords(reset: true);
        },
        onFilterChanged: (value) {
          setState(() => _filterStatus = value);
          _loadRecords(reset: true);
        },
        onSortChanged: (value) {
          setState(() => _sortKey = value);
          _loadRecords(reset: true);
        },
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gonderim Raporlari'),
        actions: [
          IconButton(
            onPressed: () {
              _loadStats();
              _loadRecords(reset: true);
            },
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pie_chart, size: 18),
                        const SizedBox(width: 8),
                        Text('Toplam: $total'),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.done_all, size: 18),
                        const SizedBox(width: 6),
                        Text('Iletildi: $delivered'),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18),
                        const SizedBox(width: 6),
                        Text('Basarisiz: $failed'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Tumu'),
                      selected: _filterStatus == null,
                      onSelected: (_) {
                        setState(() => _filterStatus = null);
                        _loadRecords(reset: true);
                      },
                    ),
                    FilterChip(
                      label: const Text('Iletildi'),
                      selected: _filterStatus == DeliveryStatus.delivered,
                      onSelected: (_) {
                        setState(() => _filterStatus = DeliveryStatus.delivered);
                        _loadRecords(reset: true);
                      },
                    ),
                    FilterChip(
                      label: const Text('Okundu'),
                      selected: _filterStatus == DeliveryStatus.read,
                      onSelected: (_) {
                        setState(() => _filterStatus = DeliveryStatus.read);
                        _loadRecords(reset: true);
                      },
                    ),
                    FilterChip(
                      label: const Text('Basarisiz'),
                      selected: _filterStatus == DeliveryStatus.failed,
                      onSelected: (_) {
                        setState(() => _filterStatus = DeliveryStatus.failed);
                        _loadRecords(reset: true);
                      },
                    ),
                  ],
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _sortKey,
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
                    setState(() => _sortKey = value);
                    _loadRecords(reset: true);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(child: Text('Gonderim bulunamadi.'))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _records.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _records.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final record = _records[index];
                          final title = record.contactName ?? record.phoneNumber;
                          final subtitle = record.status == DeliveryStatus.failed
                              ? '${record.templateName} • ${record.failureReason ?? 'Basarisiz'}'
                              : '${record.templateName} • ${_formatDateTime(record.sentAt)}';

                          return ListTile(
                            leading: DeliveryStatusIcon(status: record.status),
                            title: Text(title),
                            subtitle: Text(subtitle),
                            trailing: Text(
                              _formatDateTime(record.sentAt),
                              style: const TextStyle(fontSize: 12),
                            ),
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

class _SortOption {
  final String sortBy;
  final String direction;

  const _SortOption({required this.sortBy, required this.direction});
}
