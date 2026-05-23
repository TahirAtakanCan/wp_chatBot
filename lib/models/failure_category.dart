class FailureCategory {
  final String code;
  final String category;

  FailureCategory({
    required this.code,
    required this.category,
  });

  factory FailureCategory.fromJson(Map<String, dynamic> json) {
    return FailureCategory(
      code: (json['code'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
    );
  }
}
