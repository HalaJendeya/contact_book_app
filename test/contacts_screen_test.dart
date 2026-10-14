import 'dart:convert';

import 'package:contact_book_app/main.dart';
import 'package:contact_book_app/services/contact_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Two fake users, shaped like the JSONPlaceholder response.
final _users = [
  {'id': 1, 'name': 'Leanne Graham', 'email': 'sincere@april.biz', 'phone': '111'},
  {'id': 2, 'name': 'Ervin Howell', 'email': 'shanna@melissa.tv', 'phone': '222'},
];

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

// Builds the app with a fake server. [requests] records "METHOD path" strings.
Widget _app(
  List<String> requests, {
  int getStatus = 200,
  int putStatus = 200,
  int deleteStatus = 200,
}) {
  final client = MockClient((request) async {
    // A real network takes longer than one frame, so the screen can rebuild first.
    await Future.delayed(const Duration(milliseconds: 500));
    requests.add('${request.method} ${request.url.path}');
    switch (request.method) {
      case 'GET':
        return getStatus == 200 ? _json(_users, 200) : _json({}, getStatus);
      case 'POST':
        return _json({...jsonDecode(request.body), 'id': 11}, 201);
      case 'PUT':
        return _json(jsonDecode(request.body), putStatus);
      default:
        return _json({}, deleteStatus);
    }
  });
  return MyApp(service: ContactService(client: client));
}

Future<void> _swipeFirstCard(WidgetTester tester) async {
  // The app is right-to-left, so "end to start" is a drag to the right.
  await tester.drag(find.text('Leanne Graham'), const Offset(500, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows name, email and phone of each contact', (tester) async {
    await tester.pumpWidget(_app([]));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Leanne Graham'), findsOneWidget);
    expect(find.text('sincere@april.biz'), findsOneWidget);
    expect(find.text('111'), findsOneWidget);
    expect(find.text('Ervin Howell'), findsOneWidget);
    expect(find.text('L'), findsOneWidget); // avatar letter
  });

  testWidgets('shows an error and the retry button works', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(_app(requests, getStatus: 500));
    await tester.pumpAndSettle();

    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('Leanne Graham'), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(requests.where((r) => r == 'GET /users').length, 2);
  });

  testWidgets('add: validates, sends POST and shows the new contact', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(_app(requests));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Saving with empty fields shows errors and sends nothing.
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('هذا الحقل مطلوب'), findsNWidgets(3));
    expect(requests.where((r) => r.startsWith('POST')), isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'Sara Ali');
    await tester.enterText(find.byType(TextFormField).at(1), 'sara@test.com');
    await tester.enterText(find.byType(TextFormField).at(2), '555');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(requests, contains('POST /users'));
    expect(find.text('Sara Ali'), findsOneWidget); // dialog closed, in the list
    expect(find.text('تمت إضافة جهة الاتصال'), findsOneWidget);
  });

  testWidgets('edit: long press pre-fills the form and PUT updates the list', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(_app(requests));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Leanne Graham'));
    await tester.pumpAndSettle();

    // The form starts with the current values.
    expect(find.widgetWithText(TextFormField, 'Leanne Graham'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Leanne Updated');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(requests, contains('PUT /users/1'));
    expect(find.text('Leanne Updated'), findsOneWidget);
    expect(find.text('Leanne Graham'), findsNothing);
  });

  testWidgets('edit: a failed PUT keeps the dialog open and the old data', (tester) async {
    await tester.pumpWidget(_app([], putStatus: 500));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Leanne Graham'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Changed');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('تعذر الحفظ، حاول مرة أخرى.'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('Leanne Graham'), findsOneWidget);
    expect(find.text('Changed'), findsNothing);
  });

  testWidgets('delete: cancelling the dialog keeps the contact', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(_app(requests));
    await tester.pumpAndSettle();

    await _swipeFirstCard(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('Leanne Graham'), findsOneWidget);
    expect(requests.where((r) => r.startsWith('DELETE')), isEmpty);
  });

  testWidgets('delete: confirming sends DELETE and removes the contact', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(_app(requests));
    await tester.pumpAndSettle();

    await _swipeFirstCard(tester);
    await tester.tap(find.text('حذف'));
    await tester.pump(const Duration(seconds: 1)); // wait for the fake server
    await tester.pumpAndSettle();

    expect(requests, contains('DELETE /users/1'));
    expect(find.text('Leanne Graham'), findsNothing);
    expect(find.text('Ervin Howell'), findsOneWidget);
  });

  testWidgets('delete: a failed DELETE keeps the contact in the list', (tester) async {
    await tester.pumpWidget(_app([], deleteStatus: 500));
    await tester.pumpAndSettle();

    await _swipeFirstCard(tester);
    await tester.tap(find.text('حذف'));
    await tester.pump(const Duration(seconds: 1)); // wait for the fake server
    await tester.pumpAndSettle();

    expect(find.text('Leanne Graham'), findsOneWidget);
    expect(find.text('تعذر حذف جهة الاتصال'), findsOneWidget);
  });
}
