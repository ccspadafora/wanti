import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_logo.dart';
import '../../../shared/widgets/wanti_widgets.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final Animation<double> _fade;
  late final Animation<Offset> _rise;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic));
    _motion.forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: WantiColors.surfaceSoft,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _WelcomeAtmosphere(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _rise,
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        const WantiLogo(
                          variant: WantiLogoVariant.wordmark,
                          height: 72,
                          alignment: Alignment.center,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Porque tus sueños no se buscan,\nse publican.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                            color: WantiColors.ink,
                          ),
                        ),
                        const Spacer(flex: 3),
                        WantiButton(
                          label: 'Crear cuenta',
                          variant: WantiButtonVariant.teal,
                          onPressed: () => context.go('/register'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            '¿Ya tienes cuenta? Inicia sesión',
                            style: GoogleFonts.nunito(
                              color: WantiColors.tealDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
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

/// Soft brand atmosphere: canvas base, teal wash, navy depth — no flat slab.
class _WelcomeAtmosphere extends StatelessWidget {
  const _WelcomeAtmosphere();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FBFD),
            WantiColors.surfaceSoft,
            Color(0xFFE8F6F5),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(
              size: 260,
              color: WantiColors.teal.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -90,
            child: _Blob(
              size: 280,
              color: WantiColors.navy.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -20,
            child: _Blob(
              size: 180,
              color: WantiColors.teal.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
