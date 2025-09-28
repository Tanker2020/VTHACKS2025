import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nash/pages/login.dart';

class TopNavbar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onLogout;
  final VoidCallback? onGoMarket;
  final Widget? trailing;
  const TopNavbar({Key? key, this.showBack = false, this.onBack, this.onLogout, this.onGoMarket, this.trailing}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            gradient: LinearGradient(colors: [theme.colorScheme.primary.withOpacity(0.08), Colors.transparent]),
          ),
          child: Row(
            children: [
              // leading: logout or back
              IconButton(
                icon: Icon(showBack ? Icons.arrow_back : Icons.logout, color: Colors.white),
                onPressed: showBack ? onBack ?? () => Navigator.of(context).maybePop() : onLogout ?? () {
                  // default logout action: push Login
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
                },
              ),

              const SizedBox(width: 8),
              // brand title
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('NASH', style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),

              // right side icons
              Builder(
                builder: (_) {
                  final widgets = <Widget>[];
                  if (trailing != null) {
                    widgets.add(trailing!);
                  }
                  if (onGoMarket != null) {
                    if (widgets.isNotEmpty) widgets.add(const SizedBox(width: 10));
                    widgets.add(
                      IconButton(
                        tooltip: 'Market',
                        icon: const Icon(Icons.storefront_outlined, color: Colors.white),
                        onPressed: onGoMarket,
                      ),
                    );
                  }

                  if (widgets.isEmpty) {
                    return const SizedBox(width: 48);
                  }
                  return Row(mainAxisSize: MainAxisSize.min, children: widgets);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
