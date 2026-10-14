import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/contact.dart';

// The Service talks to the API. The screen never builds URLs or reads
// status codes itself: it just calls these four methods.
//
// Every method checks the status code. If it is not the expected one,
// the method throws an Exception, and the screen catches it with try/catch.
//
// Note: JSONPlaceholder only SIMULATES POST / PUT / DELETE. It answers with
// the right status code but never really changes its data.
class ContactService {
  // [client] is optional. The app uses the default one; tests pass a fake.
  ContactService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://jsonplaceholder.typicode.com/users';
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
  };
  // Without a timeout a bad connection could keep the loading spinner forever.
  static const Duration _timeout = Duration(seconds: 15);

  // GET: read all contacts. Expected status: 200.
  Future<List<Contact>> getContacts() async {
    final response = await _client.get(Uri.parse(_baseUrl)).timeout(_timeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Contact.fromJson(item)).toList();
    }
    throw Exception('Failed to load contacts (status ${response.statusCode})');
  }

  // POST: create a contact. Expected status: 201 (Created).
  // Returns the contact that the server sends back.
  Future<Contact> addContact(Contact contact) async {
    // The server decides the id of a new item, so we do not send ours.
    final body = contact.toJson()..remove('id');

    final response = await _client
        .post(Uri.parse(_baseUrl), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(_timeout);

    if (response.statusCode == 201) {
      return Contact.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to add contact (status ${response.statusCode})');
  }

  // PUT: replace a contact. Expected status: 200.
  Future<void> updateContact(Contact contact) async {
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/${contact.id}'),
          headers: _jsonHeaders,
          body: jsonEncode(contact.toJson()),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update contact (status ${response.statusCode})',
      );
    }
  }

  // DELETE: remove a contact. Expected status: 200.
  Future<void> deleteContact(int id) async {
    final response =
        await _client.delete(Uri.parse('$_baseUrl/$id')).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete contact (status ${response.statusCode})',
      );
    }
  }
}
