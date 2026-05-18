import 'package:flutter/material.dart';

import '../models/meta_template.dart';
import '../models/template_preset.dart';
import '../services/template_service.dart';
import '../theme/wa_colors.dart';
import '../widgets/preset_form_dialog.dart';

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  final TemplateService _templateService = TemplateService();

  List<MetaTemplate> _metaTemplates = <MetaTemplate>[];
  List<TemplatePreset> _presets = <TemplatePreset>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _templateService.fetchMetaTemplates(),
        _templateService.fetchPresets(),
      ]);
      if (!mounted) return;
      setState(() {
        _metaTemplates = results[0] as List<MetaTemplate>;
        _presets = results[1] as List<TemplatePreset>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Yükleme hatası: $e');
    }
  }

  Future<void> _refreshMeta() async {
    setState(() => _isLoading = true);
    try {
      final refreshed = await _templateService.refreshMetaTemplates();
      final presets = await _templateService.fetchPresets();
      if (!mounted) return;
      setState(() {
        _metaTemplates = refreshed;
        _presets = presets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Yenileme başarısız: $e');
    }
  }

  Future<void> _openCreatePreset(MetaTemplate template) async {
    final created = await PresetFormDialog.show(
      context,
      metaTemplate: template,
    );
    if (created == null || !mounted) return;
    _showInfo('Hazır kayıt oluşturuldu.');
    _loadData();
  }

  Future<void> _openEditPreset(TemplatePreset preset) async {
    final template = _metaTemplates.firstWhere(
      (m) => m.name == preset.metaTemplateName,
      orElse: () => MetaTemplate(
        name: preset.metaTemplateName,
        language: preset.language,
        status: 'APPROVED',
        category: '',
        headerType: preset.mediaType ?? 'NONE',
      ),
    );

    final updated = await PresetFormDialog.show(
      context,
      metaTemplate: template,
      initialPreset: preset,
    );
    if (updated == null || !mounted) return;
    _showInfo('Hazır kayıt güncellendi.');
    _loadData();
  }

  Future<void> _deletePreset(TemplatePreset preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hazır kaydı sil'),
        content: Text('"${preset.displayName}" kaydını silmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _templateService.deletePreset(preset.id);
      if (!mounted) return;
      _showInfo('Hazır kayıt silindi.');
      _loadData();
    } catch (e) {
      _showError('Silme hatası: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şablonlarım'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _isLoading ? null : _refreshMeta,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '📋 Meta Şablonlarım',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ..._metaTemplates.map(_buildMetaTemplateCard),
                  const SizedBox(height: 18),
                  Text(
                    '📂 Hazır Kayıtlarım (${_presets.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_presets.isEmpty) _buildEmptyState(),
                  ..._presets.map(_buildPresetCard),
                ],
              ),
            ),
    );
  }

  Widget _buildMetaTemplateCard(MetaTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Header: ${template.headerType} · Status: ${template.status} · ${template.language.toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: WAColors.textSecondary),
            ),
            if ((template.bodyText ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                template.bodyText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Tooltip(
              message: template.isApproved
                  ? ''
                  : 'Bu şablon henüz Meta tarafından onaylanmadı',
              child: FilledButton.icon(
                onPressed: template.isApproved ? () => _openCreatePreset(template) : null,
                icon: const Icon(Icons.add),
                label: const Text('Hazır Kayıt Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard(TemplatePreset preset) {
    final icon = switch (preset.mediaType?.toUpperCase()) {
      'IMAGE' => Icons.image_outlined,
      'VIDEO' => Icons.videocam_outlined,
      'DOCUMENT' => Icons.insert_drive_file_outlined,
      _ => Icons.bookmark_outline_rounded,
    };
    final mediaInfo = preset.hasMedia
        ? '${preset.metaTemplateName} · ${preset.sizeFormatted}'
        : preset.metaTemplateName;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: WAColors.accent),
        title: Text(
          preset.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          mediaInfo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _openEditPreset(preset),
              child: const Text('Düzenle'),
            ),
            TextButton(
              onPressed: () => _deletePreset(preset),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Sil'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WAColors.divider),
      ),
      child: const Text(
        'Henüz hazır kayıt yok. Yukarıdaki Meta şablonlarından birine medya bağlayarak başlayabilirsin.',
        style: TextStyle(fontSize: 13, color: WAColors.textSecondary),
      ),
    );
  }
}
