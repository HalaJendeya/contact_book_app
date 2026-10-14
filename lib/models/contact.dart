// The Contact model: one person in our contact book.
// It knows how to turn itself into JSON (toJson) and how to be built
// from JSON (fromJson), so the rest of the app never touches raw maps.
class Contact {
  final int id;
  final String name;
  final String email;
  final String phone;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  // JSON -> Contact (used after GET / POST responses).
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
    );
  }

  // Contact -> JSON (used before sending POST / PUT requests).
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'phone': phone};
  }
}
