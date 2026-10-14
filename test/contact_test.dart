import 'package:contact_book_app/models/contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson reads id, name, email and phone', () {
    final contact = Contact.fromJson({
      'id': 3,
      'name': 'Clementine Bauch',
      'email': 'Nathan@yesenia.net',
      'phone': '1-463-123-4447',
      'username': 'ignored extra field',
    });

    expect(contact.id, 3);
    expect(contact.name, 'Clementine Bauch');
    expect(contact.email, 'Nathan@yesenia.net');
    expect(contact.phone, '1-463-123-4447');
  });

  test('toJson returns the four fields', () {
    final json = Contact(id: 1, name: 'A', email: 'a@b.c', phone: '123').toJson();

    expect(json, {'id': 1, 'name': 'A', 'email': 'a@b.c', 'phone': '123'});
  });
}
