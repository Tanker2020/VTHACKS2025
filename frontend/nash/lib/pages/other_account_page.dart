import 'package:flutter/material.dart';
import 'package:nash/data/mock_data.dart';

class OtherAccountPage extends StatelessWidget {
  final String userId;
  final String username;
  final String bio;

  const OtherAccountPage({
    super.key,
    required this.userId,
    this.username = 'guest',
    this.bio = 'This user has not added a bio yet.',
  });

  Widget _buildGradientAvatar(BuildContext context, {double size = 96}) {
    final colorA = Theme.of(context).colorScheme.primary;
    final colorB = Theme.of(context).colorScheme.secondary;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [colorA, colorB], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 12, offset: const Offset(0, 8))],
      ),
      child: Center(
        child: Text(initial, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.38)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // resolve the user from the centralized mock DB and format the Nash score safely
    final user = findUserById(userId);
    final String nashScoreStr = user != null && user['nashScore'] != null ? user['nashScore'].toString() : '—';
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple, theme.colorScheme.secondary.withOpacity(0.8)],
          ),
        ),
        child: Stack(
          children: [
            // Top banner area (similar to AccountPage)
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
                          onTap: () => Navigator.of(context).pop(),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            child: const Icon(
                              Icons.arrow_back,
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
                          onPressed: () {},
                          icon: const Icon(Icons.storefront_outlined, size: 28, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main content below banner
            Positioned.fill(
              top: 160,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar
                      _buildGradientAvatar(context, size: 128),
                      const SizedBox(height: 12),
                      Text(username.isNotEmpty ? username : 'Unknown User', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Stylized Nash Score text
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: nashScoreStr, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                            TextSpan(text: ' NASH', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.7), letterSpacing: 1.2)),
                          ]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stat tiles + Tab container like AccountPage
                      const SizedBox(height: 6),


                      // Tab container like AccountPage
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
                                      // profit
                                      // lending
                                      // borrowing
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
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

  // ...stat tiles are not used in this read-only profile page currently
}
