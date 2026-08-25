import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../state/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un email válido')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final debugToken =
          await context.read<AuthController>().requestPasswordReset(email);
      if (!mounted) return;
      final qp = <String>[
        'email=${Uri.encodeComponent(email)}',
        if (debugToken != null && debugToken.isNotEmpty)
          'token=${Uri.encodeComponent(debugToken)}',
      ].join('&');
      context.push('/reset-password?$qp');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Recuperar contraseña', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text(
                    'Te enviaremos un enlace (o token) para restablecer tu contraseña.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  WantiField(
                    label: 'Correo electrónico',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  WantiButton(
                    label: 'Enviar',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.initialToken,
    this.email,
  });

  final String? initialToken;
  final String? email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _token;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_token.text.trim().isEmpty) {
      _toast('Ingresa el token de recuperación');
      return;
    }
    if (_password.text.length < 8) {
      _toast('La contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (_password.text != _confirm.text) {
      _toast('Las contraseñas no coinciden');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().confirmPasswordReset(
            token: _token.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada. Ya puedes iniciar sesión.')),
      );
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Nueva contraseña', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  if ((widget.email ?? '').isNotEmpty)
                    Text(
                      'Para ${widget.email}',
                      style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                    ),
                  const SizedBox(height: 12),
                  WantiField(
                    label: 'Token',
                    controller: _token,
                  ),
                  const SizedBox(height: 16),
                  WantiField(
                    label: 'Nueva contraseña',
                    controller: _password,
                    obscure: _obscure,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: WantiColors.inkFaint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  WantiField(
                    label: 'Confirmar contraseña',
                    controller: _confirm,
                    obscure: _obscure,
                  ),
                  const SizedBox(height: 24),
                  WantiButton(
                    label: 'Guardar contraseña',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
