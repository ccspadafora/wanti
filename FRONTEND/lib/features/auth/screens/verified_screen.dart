import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';

class VerifiedScreen extends StatelessWidget {
  const VerifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: WantiColors.teal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: WantiColors.teal.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 28),
              Text(
                '¡Cuenta verificada!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: WantiColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ya puedes publicar sueños y explorar matches en Wanti.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: WantiColors.ink,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _chip(Icons.mail_outline, 'Email')),
                  const SizedBox(width: 12),
                  Expanded(child: _chip(Icons.chat_bubble_outline, 'Celular')),
                ],
              ),
              const Spacer(flex: 3),
              WantiButton(
                label: 'Explorar Wanti',
                onPressed: () => context.go('/home'),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WantiColors.teal, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: WantiColors.teal),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: WantiColors.tealDark,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.check_circle, size: 16, color: WantiColors.teal),
        ],
      ),
    );
  }
}
