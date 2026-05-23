import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../constants/media_size_limits.dart';
import '../models/meta_template.dart';
import '../models/template_preset.dart';
import '../services/chat_media_service.dart';
import '../services/template_service.dart';
import '../utils/media_size_helper.dart';

class PresetFormDialog extends StatefulWidget {
  final MetaTemplate metaTemplate;
  final TemplatePreset? initialPreset;

  const PresetFormDialog({
    super.key,
    required this.metaTemplate,
    this.initialPreset,
  });

  static Future<TemplatePreset?> show(
    BuildContext context, {
    required MetaTemplate metaTemplate,
    TemplatePreset? initialPreset,
  }) {
    return showDialog<TemplatePreset>(
      context: context,
      builder: (_) => PresetFormDialog(
        metaTemplate: metaTemplate,
        initialPreset: initialPreset,
      ),
    );
  }

  @override
  State<PresetFormDialog> createState() => _PresetFormDialogState();
}

class _PresetFormDialogState extends State<PresetFormDialog> {
  final TemplateService _templateService = TemplateService();
  final ChatMediaService _chatMediaService = ChatMediaService();

  late final TextEditingController _displayNameController;

  String? _selectedMediaUrl;
  String? _selectedMediaType;
  String? _selectedFilename;
  int? _selectedSize;
  String? _selectedMimeType;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialPreset?.displayName ?? '',
    );
    _selectedMediaUrl = widget.initialPreset?.mediaUrl;
    _selectedMediaType = widget.initialPreset?.mediaType;
    _selectedFilename = widget.initialPreset?.mediaFilename;
    _selectedSize = widget.initialPreset?.mediaSizeBytes;
    _selectedMimeType = widget.initialPreset?.mimeType;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  bool get _mediaRequired => widget.metaTemplate.hasMediaHeader;

  bool get _canSave {
    if (_isSaving || _isUploading) return false;
    if (_displayNameController.text.trim().isEmpty) return false;
    if (_mediaRequired && (_selectedMediaUrl == null || _selectedMediaUrl!.isEmpty)) {
      return false;
    }
    return true;
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: _fileTypeForHeader(widget.metaTemplate.headerType),
      allowedExtensions: widget.metaTemplate.headerType.toUpperCase() == 'DOCUMENT'
          ? ChatMediaService.documentExtensions
          : null,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showError('Seçilen dosya okunamadı.');
      return;
    }

    final maxAllowed = _maxAllowedBytes(widget.metaTemplate.headerType);
    final sizeBytes = resolvePickerFileSize(pickerSize: file.size, bytes: file.bytes);
    if (sizeBytes > maxAllowed) {
      _showError(
        'Dosya boyutu sınırı aşıldı. En fazla ${formatFileSizeDisplay(maxAllowed)} yükleyebilirsiniz.',
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final upload = await _chatMediaService.uploadMedia(file);
      if (!mounted) return;
      setState(() {
        _selectedMediaUrl = upload.url;
        _selectedMediaType = _resolveMediaType(
          headerType: widget.metaTemplate.headerType,
          filename: file.name,
        );
        _selectedFilename = upload.filename;
        _selectedSize = upload.sizeBytes;
        _selectedMimeType = _guessMimeType(file.name);
        if (_displayNameController.text.trim().isEmpty) {
          _displayNameController.text = _filenameBase(upload.filename);
        }
        _isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showError('Medya yükleme hatası: $e');
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final preset = widget.initialPreset == null
          ? await _templateService.createPreset(
              displayName: _displayNameController.text.trim(),
              metaTemplateName: widget.metaTemplate.name,
              language: widget.metaTemplate.language,
              mediaType: _selectedMediaType,
              mediaUrl: _selectedMediaUrl,
              mediaFilename: _selectedFilename,
              mediaSizeBytes: _selectedSize,
              mimeType: _selectedMimeType,
            )
          : await _templateService.updatePreset(
              widget.initialPreset!.id,
              displayName: _displayNameController.text.trim(),
              metaTemplateName: widget.metaTemplate.name,
              language: widget.metaTemplate.language,
              mediaType: _selectedMediaType,
              mediaUrl: _selectedMediaUrl,
              mediaFilename: _selectedFilename,
              mediaSizeBytes: _selectedSize,
              mimeType: _selectedMimeType,
            );

      if (!mounted) return;
      Navigator.of(context).pop(preset);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Kaydetme hatası: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialPreset != null;
    return AlertDialog(
      title: Text(isEdit ? 'Hazır Kaydı Düzenle' : 'Yeni Hazır Kayıt'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Şablon: ${widget.metaTemplate.name}'),
              const SizedBox(height: 4),
              Text('Header tipi: ${widget.metaTemplate.headerType}'),
              const SizedBox(height: 14),
              TextField(
                controller: _displayNameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Kayıt İsmi',
                  hintText: 'Örn: Afrika Kurban Bayramı',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickMedia,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded),
                    label: Text(_isUploading ? 'Yükleniyor...' : 'Medya Seç'),
                  ),
                  const SizedBox(width: 8),
                  if (_mediaRequired)
                    const Text(
                      'Bu şablon için medya zorunlu',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                ],
              ),
              if (_selectedFilename != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFilename!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_selectedSize != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          formatFileSizeDisplay(_selectedSize!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _isUploading ? null : _pickMedia,
                            child: const Text('Değiştir'),
                          ),
                          TextButton(
                            onPressed: _isUploading
                                ? null
                                : () {
                                    setState(() {
                                      _selectedMediaUrl = null;
                                      _selectedMediaType = null;
                                      _selectedFilename = null;
                                      _selectedSize = null;
                                      _selectedMimeType = null;
                                    });
                                  },
                            child: const Text('Kaldır'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
        ),
      ],
    );
  }

  FileType _fileTypeForHeader(String headerType) {
    switch (headerType.toUpperCase()) {
      case 'IMAGE':
        return FileType.image;
      case 'VIDEO':
        return FileType.video;
      case 'DOCUMENT':
        return FileType.custom;
      default:
        return FileType.any;
    }
  }

  int _maxAllowedBytes(String headerType) {
    switch (headerType.toUpperCase()) {
      case 'IMAGE':
        return MediaSizeLimits.bulkImageMaxBytes;
      case 'VIDEO':
        return MediaSizeLimits.whatsappMaxBytes;
      case 'DOCUMENT':
        return MediaSizeLimits.whatsappMaxBytes;
      default:
        return MediaSizeLimits.whatsappMaxBytes;
    }
  }

  String _resolveMediaType({
    required String headerType,
    required String filename,
  }) {
    switch (headerType.toUpperCase()) {
      case 'IMAGE':
      case 'VIDEO':
      case 'DOCUMENT':
        return headerType.toUpperCase();
      default:
        final ext = filename.toLowerCase();
        if (ext.endsWith('.jpg') ||
            ext.endsWith('.jpeg') ||
            ext.endsWith('.png') ||
            ext.endsWith('.gif') ||
            ext.endsWith('.webp')) {
          return 'IMAGE';
        }
        if (ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.webm')) {
          return 'VIDEO';
        }
        return 'DOCUMENT';
    }
  }

  String _guessMimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _filenameBase(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return filename.substring(0, dotIndex);
  }
}
