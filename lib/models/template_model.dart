class TemplateModel {
  final int id;
  final String title;
  final String content;
  final String createdBy;

  TemplateModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdBy,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawCreatedBy = json['createdBy'];

    String createdBy;
    if (rawCreatedBy is String) {
      createdBy = rawCreatedBy;
    } else if (rawCreatedBy is Map<String, dynamic>) {
      createdBy =
          (rawCreatedBy['username'] ?? rawCreatedBy['name'] ?? '-').toString();
    } else {
      createdBy = '-';
    }

    return TemplateModel(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdBy: createdBy,
    );
  }
}
