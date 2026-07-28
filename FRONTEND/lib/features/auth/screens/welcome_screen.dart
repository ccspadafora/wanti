import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_logo.dart';
import '../../../shared/widgets/wanti_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantiColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const WantiLogo(
                variant: WantiLogoVariant.full,
                height: 240,
                surface: true,
                surfaceRadius: 32,
                surfacePadding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              ),
              const Spacer(flex: 3),
              const DotsProgress(step: 1),
              const SizedBox(height: 28),
              WantiButton(
                label: 'Crear cuenta',
                variant: WantiButtonVariant.teal,
                onPressed: () => context.go('/register'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  '¿Ya tenés cuenta? Inicia sesión',
                  style: GoogleFonts.nunito(
                    color: WantiColors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
