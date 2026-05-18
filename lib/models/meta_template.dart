class MetaTemplate {
  final String name;
  final String language;
  final String status;
  final String category;
  final String headerType;
  final String? bodyText;

  MetaTemplate({
    required this.name,
    required this.language,
    required this.status,
    required this.category,
    required this.headerType,
    this.bodyText,
  });

  factory MetaTemplate.fromJson(Map<String, dynamic> json) {
    return MetaTemplate(
      name: (json['name'] ?? '').toString(),
      language: (json['language'] ?? 'tr').toString(),
      status: (json['status'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      headerType: (json['headerType'] ?? 'NONE').toString(),
      bodyText: json['bodyText']?.toString(),
    );
  }

  bool get isApproved => status.toUpperCase() == 'APPROVED';

  bool get hasMediaHeader =>
      const ['IMAGE', 'VIDEO', 'DOCUMENT'].contains(headerType.toUpperCase());
}
