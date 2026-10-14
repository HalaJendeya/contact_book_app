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
  List<Map<String, dynamic>>? users,
}) {
  final client = MockClient((request) async {
    // A real network takes longer than one frame, so the screen can rebuild first.
    await Future.delayed(const Duration(milliseconds: 500));
    requests.add('${request.method} ${request.url.path}');
    switch (request.method) {
      case 'GET':
        return getStatus == 200 ? _json(users ?? _users, 200) : _json({}, getStatus);
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

  testWidgets('add: an invalid email is rejected and nothing is sent', (tester) async {
    final requests = <String>[];
    await tester.pumpWidget(_app(requests));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Sara Ali');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(2), '555');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا'), findsOneWidget);
    expect(requests.where((r) => r.startsWith('POST')), isEmpty);
  });

  // ------------------------------------------------------------ details screen
  group('details screen', () {
    // Taps the first contact and waits for the new screen.
    Future<void> openDetails(WidgetTester tester) async {
      await tester.tap(find.text('Leanne Graham'));
      await tester.pumpAndSettle();
    }

    // Waits for the fake server to answer (it takes 500 ms).
    Future<void> waitForServer(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a contact shows all its details', (tester) async {
      await tester.pumpWidget(_app([]));
      await tester.pumpAndSettle();
      await openDetails(tester);

      expect(find.text('تفاصيل جهة الاتصال'), findsOneWidget);
      expect(find.text('Leanne Graham'), findsOneWidget);
      expect(find.text('sincere@april.biz'), findsOneWidget);
      expect(find.text('111'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // the contact id
      expect(find.text('L'), findsOneWidget); // big avatar letter
      expect(find.byIcon(Icons.call), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('edit: PUT is sent, details and list both show the new name', (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(_app(requests));
      await tester.pumpAndSettle();
      await openDetails(tester);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Leanne Graham'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Leanne Updated');
      await tester.tap(find.text('حفظ'));
      await waitForServer(tester);

      expect(requests, contains('PUT /users/1'));
      expect(find.text('Leanne Updated'), findsOneWidget); // details updated now

      await tester.pageBack(); // back to the list
      await tester.pumpAndSettle();
      expect(find.text('Leanne Updated'), findsOneWidget);
      expect(find.text('Leanne Graham'), findsNothing);
    });

    testWidgets('edit: a failed PUT changes neither the details nor the list', (tester) async {
      await tester.pumpWidget(_app([], putStatus: 500));
      await tester.pumpAndSettle();
      await openDetails(tester);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Changed');
      await tester.tap(find.text('حفظ'));
      await waitForServer(tester);

      await tester.tap(find.text('إلغاء')); // close the dialog
      await tester.pumpAndSettle();
      expect(find.text('Leanne Graham'), findsOneWidget);
      expect(find.text('Changed'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leanne Graham'), findsOneWidget);
    });

    testWidgets('delete: confirming sends DELETE, returns to the list and removes it', (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(_app(requests));
      await tester.pumpAndSettle();
      await openDetails(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'حذف'));
      await waitForServer(tester);

      expect(requests, contains('DELETE /users/1'));
      expect(find.text('تفاصيل جهة الاتصال'), findsNothing); // left the details
      expect(find.text('دفتر جهات الاتصال'), findsOneWidget); // on the list
      expect(find.text('Leanne Graham'), findsNothing);
      expect(find.text('Ervin Howell'), findsOneWidget);
    });

    testWidgets('delete: cancelling keeps the details screen and sends nothing', (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(_app(requests));
      await tester.pumpAndSettle();
      await openDetails(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('تفاصيل جهة الاتصال'), findsOneWidget);
      expect(find.text('Leanne Graham'), findsOneWidget);
      expect(requests.where((r) => r.startsWith('DELETE')), isEmpty);
    });

    testWidgets('delete: a failed DELETE keeps the contact and re-enables the buttons', (tester) async {
      await tester.pumpWidget(_app([], deleteStatus: 500));
      await tester.pumpAndSettle();
      await openDetails(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'حذف'));
      await waitForServer(tester);

      expect(find.text('تفاصيل جهة الاتصال'), findsOneWidget); // still here
      expect(find.text('تعذر حذف جهة الاتصال'), findsOneWidget);
      final deleteButton = find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.bySubtype<OutlinedButton>(),
      );
      expect(tester.widget<OutlinedButton>(deleteButton).onPressed, isNotNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leanne Graham'), findsOneWidget); // still in the list
    });

    testWidgets('a contact added locally can be opened and edited without a PUT', (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(_app(requests));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Sara Ali');
      await tester.enterText(find.byType(TextFormField).at(1), 'sara@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), '555');
      await tester.tap(find.text('حفظ'));
      await waitForServer(tester);

      await tester.tap(find.text('Sara Ali'));
      await tester.pumpAndSettle();
      expect(find.text('1000'), findsOneWidget); // temporary local id

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Sara Hassan');
      await tester.tap(find.text('حفظ'));
      await waitForServer(tester);

      expect(find.text('Sara Hassan'), findsOneWidget);
      // The server does not know id 1000, so no PUT is sent for it.
      expect(requests.where((r) => r.startsWith('PUT')), isEmpty);
    });

    testWidgets('Call shows a friendly error when no app can handle it', (tester) async {
      // In a test there is no phone app, so launching fails.
      await tester.pumpWidget(_app([]));
      await tester.pumpAndSettle();
      await openDetails(tester);

      await tester.tap(find.byIcon(Icons.call));
      // The failed launch comes back through a platform channel, which needs
      // real time (runAsync) before the screen can show the message.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      expect(find.text('تعذر فتح التطبيق المناسب على هذا الجهاز'), findsOneWidget);
    });

    testWidgets('long names and emails do not overflow on a small screen', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      final users = [
        {
          'id': 1,
          'name': List.filled(12, 'اسم طويل جدا').join(' '),
          'email': '${'a' * 70}@${'b' * 50}.com', // one very long word
          'phone': '1-770-736-8031 x56442',
        },
      ];
      await tester.pumpWidget(_app([], users: users));
      await tester.pumpAndSettle(); // an overflow would fail the test here

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle(); // ...or here
      expect(find.text('تفاصيل جهة الاتصال'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
