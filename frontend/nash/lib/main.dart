import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nash/pages/account_page.dart';
import 'package:nash/pages/login.dart' as login_page;
import 'package:nash/theme/app_theme.dart';

Future<void> main() async {
  await dotenv.load(fileName: "assets/env");
  await Supabase.initialize(
    url: dotenv.env['YOUR_SUPABASE_URL'] ?? "",
    anonKey: dotenv.env['YOUR_SUPABASE_PUBLISHABLE_KEY'] ?? "", 
  );
  usePathUrlStrategy();
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final initialHome = supabase.auth.currentSession == null
        ? const login_page.LoginPage()
        : const AccountPage();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nash',
      theme: AppTheme.themeData,
      home: initialHome,
    );
  }
}
extension ContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    // Fallback to overlay-based toast in case the ScaffoldMessenger isn't available.
    login_page.showToast(this, message, isError: isError);
  }
}
