import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      _toast('Ingresá un email válido');
      return;
    }
    if (_password.text.isEmpty) {
      _toast('Confirmá con tu contraseña');
      return;
    }
    setState(() => _loading = true);
    try {
      final msg = await context.read<AuthController>().changeEmail(
            newEmail: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Revisá tu correo', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: Text(msg, style: GoogleFonts.nunito()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
      if (mounted) context.pop();
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
    final current = context.watch<AuthController>().user?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Cambiar email'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text(
                    'Actual: $current',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  WantiField(
                    label: 'Nuevo email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  WantiField(
                    label: 'Contraseña actual',
                    controller: _password,
                    obscure: _obscure,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  const SizedBox(height: 28),
                  WantiButton(label: 'Enviar confirmación', loading: _loading, onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
