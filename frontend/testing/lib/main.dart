import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_quickstart/pages/account_page.dart';
import 'package:supabase_quickstart/pages/login.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://kgqcrpgiiwdvrwzudvaa.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtncWNycGdpaXdkdnJ3enVkdmFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzODM1MzEsImV4cCI6MjA3Mzk1OTUzMX0.BrL59OnX6YQ4yg2UlHMOfScmvskfw-qVloPkG5LK4xc',
  );
  usePathUrlStrategy();
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Testing Login App',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color.fromARGB(255, 100, 11, 54),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 100, 11, 54),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color.fromARGB(255, 100, 11, 54),
          ),
        ),
      ),
      home: supabase.auth.currentSession == null
          ? const LoginPage()
          : const AccountPage(),
    );
  }
}
extension ContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : Theme.of(this).snackBarTheme.backgroundColor,
      ),
    );
  }
}