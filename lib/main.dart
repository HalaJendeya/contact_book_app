import 'package:flutter/material.dart';

import 'screens/contacts_screen.dart';
import 'services/contact_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // [service] is optional: only tests pass a fake one.
  const MyApp({super.key, this.service});

  final ContactService? service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دفتر جهات الاتصال',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA), // light background
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      // Make the whole app right-to-left (Arabic).
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: ContactsScreen(service: service),
    );
  }
}
