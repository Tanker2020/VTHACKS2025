import 'package:flutter/material.dart';

/// Minimal TopBanner used as a simple header to replace the original widget.
class TopBanner extends StatelessWidget {
  final Widget? child;
  const TopBanner({Key? key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
      ),
      child: child ?? Center(child: Text('Nash', style: Theme.of(context).textTheme.headlineSmall)),
    );
  }
}
