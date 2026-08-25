import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../state/auth_controller.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _loading = false;
  bool _resending = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    final auth = context.read<AuthController>();
    try {
      if (auth.pendingEmailToken != null) {
        await auth.verifyEmail();
      } else {
        await auth.refreshMe();
        if (auth.needsEmailVerification) {
          throw ApiException(
            message:
                'Todavía no verificamos tu correo. Si no te llega el email, toca "Reenviar enlace" '
                'o contacta soporte.',
          );
        }
      }
      if (!mounted) return;
      context.go('/verify-phone');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await context.read<AuthController>().resendEmail();
      if (!mounted) return;
      final token = context.read<AuthController>().pendingEmailToken;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            token != null
                ? 'Enlace listo (modo local). Toca "Ya verifiqué mi correo".'
                : 'Enlace reenviado. Revisa tu bandeja.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Confirma tu correo'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: WantiColors.surfaceTeal,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: WantiColors.teal,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: WantiColors.teal.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.mail_outline, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        children: [
                          Text(
                            'Revisa tu bandeja',
                            style: GoogleFonts.nunito(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: WantiColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Enviamos un enlace de activación a tu correo electrónico. '
                            'Revisa tu bandeja de entrada y la carpeta de spam.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              color: WantiColors.inkMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: WantiColors.surfaceTeal,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              user?.email ?? '',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: WantiColors.tealDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          WantiButton(
                            label: 'Ya verifiqué mi correo',
                            loading: _loading,
                            onPressed: _confirm,
                          ),
                          TextButton(
                            onPressed: _resending ? null : _resend,
                            child: _resending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Reenviar enlace'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: DotsProgress(step: 1),
            ),
          ],
        ),
      ),
    );
  }
}
