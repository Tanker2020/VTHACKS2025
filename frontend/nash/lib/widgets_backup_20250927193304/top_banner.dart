import 'package:flutter/material.dart';
import 'package:nash/pages/account_page.dart';
import 'package:nash/pages/market_page.dart';

/// Reusable top banner with animated gradient and consistent left/right buttons.
class TopBanner extends StatefulWidget implements PreferredSizeWidget {
  final double height;
  const TopBanner({Key? key, this.height = 84}) : super(key: key);

  @override
  State<TopBanner> createState() => _TopBannerState();

  @override
  Size get preferredSize => Size.fromHeight(height);
}

class _TopBannerState extends State<TopBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final c1 = Color.lerp(Colors.deepPurple, theme.colorScheme.primary, t) ?? Colors.deepPurple;
        final c2 = Color.lerp(Colors.purpleAccent, theme.colorScheme.secondary, t) ?? theme.colorScheme.secondary;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage())),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white24,
                      child: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketPage())),
                    icon: const Icon(Icons.storefront_outlined, size: 28, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
