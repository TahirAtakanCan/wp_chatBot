class ContactModel {
  final int id;
  final String name;
  final String phone;

  ContactModel({required this.id, required this.name, required this.phone});

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}
