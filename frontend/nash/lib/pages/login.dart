// lib/pages/login.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui'; // for ImageFilter blur
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nash/main.dart'; // exposes `supabase`
import 'package:nash/pages/account_page.dart';
import 'package:nash/widgets/animated_background.dart';

/// ────────────────────────────────────────────────────────────────────────────
/// Lightweight toast (overlay)
void showToast(BuildContext context, String message,
    {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;
  final theme = Theme.of(context);

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 48,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: true,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? Colors.redAccent : Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: Colors.white, size: 20),
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
    try { entry.remove(); } catch (_) {}
  });
}

/// ────────────────────────────────────────────────────────────────────────────
/// Animated background with drifting gradient blobs (NO mouse parallax)
class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
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
        // slow drift positions (0..1 space)
        final p1 = Offset(0.55 + 0.10 * sin(t * pi * 2), 0.30 + 0.05 * cos(t * pi * 2));
        final p2 = Offset(0.20 + 0.08 * cos(t * pi * 2), 0.75 + 0.06 * sin(t * pi * 2));
        final p3 = Offset(0.85 + 0.06 * sin(t * pi * 2), 0.85 + 0.04 * cos(t * pi * 2));

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.8, -1.0),
              end: Alignment(0.9, 1.0),
              colors: [
                Color(0xFF0B1020),
                Color(0xFF0E1230),
                Color(0xFF0B1020),
              ],
            ),
          ),
          child: Stack(
            children: [
              _blob(theme.colorScheme.primary.withOpacity(.35), 260, p1),
              _blob(theme.colorScheme.secondary.withOpacity(.32), 300, p2),
              _blob(Colors.lightBlueAccent.withOpacity(.25), 220, p3),
            ],
          ),
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
            boxShadow: [
              BoxShadow(color: color.withOpacity(.35), blurRadius: 64, spreadRadius: 12),
            ],
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const SizedBox(),
          ),
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────────
/// Rotating brand avatar (ring + glow). Plug in assetPath for your logo.
class _BrandAvatar extends StatelessWidget {
  final AnimationController controller;
  final String? assetPath;

  const _BrandAvatar({required this.controller, this.assetPath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            gradient: SweepGradient(
              startAngle: 0,
              endAngle: 6.28318, // 2π
              transform: GradientRotation(controller.value * 6.28318),
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                theme.colorScheme.primary,
              ],
            ),
          ),
          child: Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withOpacity(.07), Colors.white.withOpacity(.02)],
                center: Alignment.topLeft,
                radius: 1.2,
              ),
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF0E1424),
                alignment: Alignment.center,
                child: assetPath != null
                    ? Image.asset(assetPath!, fit: BoxFit.cover)
                    : Text(
                        'N',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.lightBlueAccent,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 44,
                            ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────────
/// Hover scale (web) + press scale (mobile) for delightful micro-interaction.
class _PressHoverScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool disabled;

  const _PressHoverScale({required this.child, this.onTap, this.disabled = false});

  @override
  State<_PressHoverScale> createState() => _PressHoverScaleState();
}

class _PressHoverScaleState extends State<_PressHoverScale> {
  double _scale = 1.0;
  void _set(double v) => setState(() => _scale = v);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _set(widget.disabled ? 1.0 : 1.02),
      onExit: (_) => _set(1.0),
      child: GestureDetector(
        onTapDown: (_) => _set(widget.disabled ? 1.0 : 0.98),
        onTapUp: (_) => _set(1.02),
        onTapCancel: () => _set(1.0),
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────────
/// Login Page (magic link only) — Glass card, gradient button, premium feel.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _redirecting = false;

  late final TextEditingController _emailController = TextEditingController();
  late final StreamSubscription<AuthState> _authStateSubscription;
  late final AnimationController _logoAnimationController;

  @override
  void initState() {
    super.initState();
    _logoAnimationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..repeat(reverse: true);

    _authStateSubscription = supabase.auth.onAuthStateChange.listen(
      (data) {
        if (_redirecting) return;
        final session = data.session;
        if (session != null) {
          _redirecting = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AccountPage()),
          );
        }
      },
      onError: (error) {
        if (error is AuthException) {
          showToast(context, error.message, isError: true);
        } else {
          showToast(context, 'Unexpected error occurred', isError: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _authStateSubscription.cancel();
    _logoAnimationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showToast(context, 'Please enter a valid email address', isError: true);
      return;
    }

    try {
      setState(() => _isLoading = true);
      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? Uri.base.origin : 'nash://login-callback/', // adjust scheme if needed
      );
      if (mounted) {
        showToast(context, 'Check your email for a login link!');
        _emailController.clear();
      }
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showToast(context, 'Unexpected error occurred', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // If you have a bundled asset logo, pass assetPath:
        // _BrandAvatar(controller: _logoAnimationController, assetPath: 'assets/images/nash_logo.png'),
        _BrandAvatar(controller: _logoAnimationController),
        const SizedBox(height: 12),
        Text(
          'NASH',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          ).createShader(bounds),
          child: Text(
            '“Why not a second try?”',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              color: Colors.white, // masked by gradient
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(.18)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(.9)),
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(.6)),
                    prefixIcon: const Icon(Icons.alternate_email, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.03),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withOpacity(.14)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(.7), width: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Magic Link Button — gradient, glow, shine, hover/press micro-interaction.
              _PressHoverScale(
                disabled: _isLoading,
                onTap: _isLoading ? null : _signIn,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Gradient & glow layer
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(.35),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                    // Subtle moving shine
                    Positioned.fill(
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 3),
                          tween: Tween(begin: -1, end: 2),
                          curve: Curves.easeInOut,
                          builder: (context, v, child) {
                            return ShaderMask(
                              shaderCallback: (rect) {
                                return LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0),
                                    Colors.white.withOpacity(.26),
                                    Colors.white.withOpacity(0),
                                  ],
                                  begin: Alignment(-1 + v, 0),
                                  end: Alignment(v, 0),
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.srcATop,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white.withOpacity(.08),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Button label / spinner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Send Magic Link',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: _isLoading ? null : () => _emailController.clear(),
                child: const Text('Clear', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
    const AnimatedBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 22),
                    _buildForm(context),
                    const SizedBox(height: 18),
                    Text(
                      'By continuing you agree to our Terms & Privacy',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
