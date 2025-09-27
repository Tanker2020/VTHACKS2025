// removed unused import 'dart:typed_data'
import 'package:flutter/material.dart';
import 'package:nash/widgets/top_banner.dart';
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

class _AccountPageState extends State<AccountPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _websiteController = TextEditingController();

  var _loading = true;
  int? _nashScore;
  late final AnimationController _animController;
  late final Animation<double> _avatarScale;

  /// Called once a user id is received within `onAuthenticated()`
  Future<void> _getProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = supabase.auth.currentSession!.user.id;
        final data =
            await supabase.from('profiles').select('username, website, nashScore').eq('id', userId).single();
        _usernameController.text = (data['username'] ?? '') as String;
        _websiteController.text = (data['website'] ?? '') as String;
        _nashScore = (data['nashScore'] is num) ? (data['nashScore'] as num).toInt() : null;

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
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _avatarScale = Tween<double>(begin: 0.96, end: 1.03).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _animController.repeat(reverse: true);
    _getProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _websiteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: Stack(
          children: [
            // Top banner
            Positioned(top: 0, left: 0, right: 0, child: TopBanner()),

            Positioned.fill(
              top: 140,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Elevated profile card
                      Card(
                        elevation: 12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18.0),
                          child: Column(
                            children: [
                              // Profile picture with subtle scale animation
                              ScaleTransition(
                                scale: _avatarScale,
                                child: Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary], begin: Alignment.topRight, end: Alignment.bottomLeft),
                                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 6))],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    (_usernameController.text.isNotEmpty ? _usernameController.text[0].toUpperCase() : 'U'),
                                    style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 48),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                child: Text(
                                  _usernameController.text.isNotEmpty ? _usernameController.text : 'Unknown User',
                                  key: ValueKey<String>(_usernameController.text),
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: Text(
                                  '${_nashScore != null ? _nashScore.toString() : '—'} NASH',
                                  key: ValueKey<int?>(_nashScore),
                                  style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _loading ? null : () => _showEditProfileDialog(),
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit Profile'),
                                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    onPressed: _signOut,
                                    child: const Text('Sign Out'),
                                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

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