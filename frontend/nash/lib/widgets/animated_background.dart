import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable animated background (drifting gradient blobs) used on Login and Account pages.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({Key? key}) : super(key: key);

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final p1 = Offset(0.55 + 0.10 * sin(t * pi * 2), 0.30 + 0.05 * cos(t * pi * 2));
        final p2 = Offset(0.20 + 0.08 * cos(t * pi * 2), 0.75 + 0.06 * sin(t * pi * 2));
        final p3 = Offset(0.85 + 0.06 * sin(t * pi * 2), 0.85 + 0.04 * cos(t * pi * 2));

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.8, -1.0),
              end: Alignment(0.9, 1.0),
              colors: [Color(0xFF0B1020), Color(0xFF0E1230), Color(0xFF0B1020)],
            ),
          ),
          child: Stack(children: [
            _blob(theme.colorScheme.primary.withOpacity(.32), 260, p1),
            _blob(theme.colorScheme.secondary.withOpacity(.28), 300, p2),
            _blob(Colors.lightBlueAccent.withOpacity(.18), 220, p3),
          ]),
        );
      },
    );
  }

  Widget _blob(Color color, double size, Offset rel) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment(rel.dx * 2 - 1, rel.dy * 2 - 1),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(.35), blurRadius: 64, spreadRadius: 12)],
          ),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: const SizedBox()),
        ),
      ),
    );
  }
}
