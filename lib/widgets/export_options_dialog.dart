import 'package:flutter/material.dart';

import '../models/delivery_record.dart';
import '../models/export_options.dart';
import '../models/failure_category.dart';
import '../services/api_service.dart';

class ExportOptionsDialog extends StatefulWidget {
  final DeliveryStatus? initialStatus;
  final int? initialDays;

  const ExportOptionsDialog({
    super.key,
    this.initialStatus,
    this.initialDays,
  });

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _phoneSearchController = TextEditingController();
  final TextEditingController _contactNameSearchController =
      TextEditingController();
  late Set<ExportColumn> _selectedColumns;
  final Set<String> _selectedFailureCodes = {};
  String? _selectedTemplate;
  int? _selectedDays;
  DeliveryStatus? _selectedStatus;

  List<FailureCategory> _categories = [];
  List<String> _availableTemplates = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedColumns = Set.of(ExportColumn.values);
    _selectedStatus = widget.initialStatus;
    _selectedDays = widget.initialDays;
    _loadInitialData();
  }

  @override
  void dispose() {
    _phoneSearchController.dispose();
    _contactNameSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _api.fetchFailureCategories(),
        _api.listDeliveries(page: 0, size: 300),
      ]);
      if (!mounted) return;
      final categories = results[0] as List<FailureCategory>;
      final records = results[1] as List<DeliveryRecord>;
      final templates = records
          .map((r) => r.templateName.trim())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _categories = categories;
        _availableTemplates = templates;
      });
    } catch (_) {
      // Sessiz: dialog kullanılmaya devam eder.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doExport() async {
    setState(() => _isExporting = true);
    try {
      final options = ExportOptions(
        status: _selectedStatus?.name.toUpperCase(),
        days: _selectedDays,
        failureCodes: _selectedFailureCodes.toList(),
        templateName: _selectedTemplate,
        phoneSearch: _phoneSearchController.text.trim(),
        contactNameSearch: _contactNameSearchController.text.trim(),
        columns: _selectedColumns,
        sortBy: 'SENT_AT_DESC',
      );
      await _api.downloadExcelWithOptions(options);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel dosyası indirildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_download, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  const Text(
                    'Excel İndirme Seçenekleri',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('📅 Tarih Aralığı'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _dayChip('Bugün', 1),
                        _dayChip('Son 7 gün', 7),
                        _dayChip('Son 30 gün', 30),
                        _dayChip('Son 90 gün', 90),
                        _dayChip('Tümü', null),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('📊 Durum'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _statusChip('Tümü', null),
                        _statusChip('Gönderildi', DeliveryStatus.sent),
                        _statusChip('İletildi', DeliveryStatus.delivered),
                        _statusChip('Okundu', DeliveryStatus.read),
                        _statusChip('Başarısız', DeliveryStatus.failed),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('🧩 Şablon'),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedTemplate,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Tüm şablonlar',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tüm şablonlar'),
                        ),
                        ..._availableTemplates.map(
                          (t) => DropdownMenuItem<String?>(value: t, child: Text(t)),
                        ),
                      ],
                      onChanged: (value) => setState(() => _selectedTemplate = value),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('🔎 Kişi Filtreleri'),
                    TextField(
                      controller: _phoneSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Telefon Ara',
                        hintText: 'Örn: 9053...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contactNameSearchController,
                      decoration: const InputDecoration(
                        labelText: 'İsim Ara',
                        hintText: 'Örn: Ahmet',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('❌ Hata Sebepleri (sadece başarısızlar için)'),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_categories.isEmpty)
                      const Text(
                        'Kategori listesi yüklenemedi',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _categories.map((cat) {
                          final selected = _selectedFailureCodes.contains(cat.code);
                          return FilterChip(
                            label: Text(
                              '${cat.category} (${cat.code})',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedFailureCodes.add(cat.code);
                                } else {
                                  _selectedFailureCodes.remove(cat.code);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    _sectionTitle('📋 İndirilecek Sütunlar'),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(
                            () => _selectedColumns = Set.of(ExportColumn.values),
                          ),
                          child: const Text('Tümünü Seç'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedColumns.clear()),
                          child: const Text('Hepsini Kaldır'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ExportColumn.values.map((col) {
                        final selected = _selectedColumns.contains(col);
                        return FilterChip(
                          label: Text(col.label, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedColumns.add(col);
                              } else {
                                _selectedColumns.remove(col);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey, width: 0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedColumns.length} sütun seçili',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedColumns.isEmpty || _isExporting ? null : _doExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isExporting ? 'Hazırlanıyor...' : 'Excel İndir'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _dayChip(String label, int? days) {
    final selected = _selectedDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedDays = days),
    );
  }

  Widget _statusChip(String label, DeliveryStatus? status) {
    final selected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatus = status),
    );
  }
}
