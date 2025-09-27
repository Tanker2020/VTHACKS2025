// removed unused import 'dart:typed_data'
import 'package:flutter/material.dart';
import 'package:nash/pages/market_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nash/main.dart';
import 'package:nash/pages/login.dart';

// Local toast helper (overlay) — keeps behavior consistent with login page.
void showToast(BuildContext context, String message, {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
  final overlay = Overlay.of(context);

  final theme = Theme.of(context);
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 48,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: true,
          child: Container(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? Colors.redAccent : Colors.black87,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, () {
    try {
      entry.remove();
    } catch (_) {}
  });
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _usernameController = TextEditingController();
  final _websiteController = TextEditingController();

  var _loading = true;

  /// Called once a user id is received within `onAuthenticated()`
  Future<void> _getProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = supabase.auth.currentSession!.user.id;
      final data =
          await supabase.from('profiles').select().eq('id', userId).single();
      _usernameController.text = (data['username'] ?? '') as String;
      _websiteController.text = (data['website'] ?? '') as String;

    } on PostgrestException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } catch (error) {
      if (mounted) {
        showToast(context, 'Unexpected error occurred', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Show a dialog that allows editing username and avatar URL (photo)
  Future<bool?> _showEditProfileDialog() async {
    final username = _usernameController.text.trim();
  final usernameController = TextEditingController(text: username);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
              final newName = usernameController.text.trim();
              Navigator.of(context).pop(true);

              setState(() => _loading = true);
              try {
                final user = supabase.auth.currentUser;
                final updates = {
                  'id': user!.id,
                  'username': newName,
                  'updated_at': DateTime.now().toIso8601String(),
                };
                await supabase.from('profiles').upsert(updates);
                if (mounted) {
                  _usernameController.text = newName;
                }
              } on PostgrestException catch (error) {
                if (mounted) showToast(context, error.message, isError: true);
              } catch (error) {
                if (mounted) showToast(context, 'Unexpected error occurred', isError: true);
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    usernameController.dispose();
    return result == true;
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } catch (error) {
      if (mounted) {
        showToast(context, 'Unexpected error occurred', isError: true);
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple, Colors.white12],
          ),
        ),
        child: Stack(
          children: [
            // Top banner with centered plus icon
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 12,
                        left: 12,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AccountPage()),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            child: const Icon(
                              Icons.account_circle_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MarketPage()),
                          ),
                          icon: const Icon(Icons.storefront_outlined, size: 28, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              top: 160,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile picture (centered below banner)
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.white],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (_usernameController.text.isNotEmpty ? _usernameController.text[0].toUpperCase() : 'U'),
                          style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 48),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _usernameController.text.isNotEmpty ? _usernameController.text : 'Unknown User',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      // Stylized Nash Score text
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '1,234', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          TextSpan(text: ' NASH', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.7), letterSpacing: 1.2)),
                        ]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Edit Profile button
                      ElevatedButton.icon(
                        onPressed: _loading ? null : () => _showEditProfileDialog(),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Username'),
                        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),

                      TextButton(onPressed: _signOut, child: const Text('Sign Out')),
                      const SizedBox(height: 12),

                      // Tab container with 3 tabs (Posts / Info / Settings)
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: DefaultTabController(
                            length: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  child: TabBar(
                                    labelColor: theme.colorScheme.primary,
                                    unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                    indicator: UnderlineTabIndicator(
                                      borderSide: BorderSide(width: 3.0, color: theme.colorScheme.primary),
                                      insets: const EdgeInsets.symmetric(horizontal: 24),
                                    ),
                                    tabs: const [
                                      Tab(text: 'PROFIT'),
                                      Tab(text: 'LENDING'),
                                      Tab(text: 'BORROWING'),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 260,
                                  child: TabBarView(
                                    children: [
                                      // Profit tab - placeholder
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                          ],
                                        ),
                                      ),

                                      // Lending tab - placeholder
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                          ],
                                        ),
                                      ),

                                      // Borrowing tab - placeholder
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}