class TemplatePreset {
  final int id;
  final String displayName;
  final String metaTemplateName;
  final String language;
  final String? mediaType;
  final String? mediaUrl;
  final String? mediaFilename;
  final int? mediaSizeBytes;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TemplatePreset({
    required this.id,
    required this.displayName,
    required this.metaTemplateName,
    required this.language,
    this.mediaType,
    this.mediaUrl,
    this.mediaFilename,
    this.mediaSizeBytes,
    this.mimeType,
    required this.createdAt,
    this.updatedAt,
  });

  factory TemplatePreset.fromJson(Map<String, dynamic> json) {
    return TemplatePreset(
      id: (json['id'] as num).toInt(),
      displayName: (json['displayName'] ?? '').toString(),
      metaTemplateName: (json['metaTemplateName'] ?? '').toString(),
      language: (json['language'] ?? 'tr').toString(),
      mediaType: json['mediaType']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      mediaFilename: json['mediaFilename']?.toString(),
      mediaSizeBytes: (json['mediaSizeBytes'] as num?)?.toInt(),
      mimeType: json['mimeType']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
    );
  }

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  String get sizeFormatted {
    if (mediaSizeBytes == null) return '';
    final mb = mediaSizeBytes! / (1024 * 1024);
    if (mb < 1) {
      return '${(mediaSizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}
