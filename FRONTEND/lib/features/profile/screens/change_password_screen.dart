import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _next.text.length < 8) {
      _toast('La nueva contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (_next.text != _confirm.text) {
      _toast('Las contraseñas no coinciden');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
      context.pop();
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
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Cambiar contraseña'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text(
                    'Después de cambiarla, otras sesiones pueden cerrarse por seguridad.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  WantiField(
                    label: 'Contraseña actual',
                    controller: _current,
                    obscure: _obscure,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  WantiField(label: 'Nueva contraseña', controller: _next, obscure: _obscure),
                  const SizedBox(height: 14),
                  WantiField(label: 'Confirmar nueva', controller: _confirm, obscure: _obscure),
                  const SizedBox(height: 28),
                  WantiButton(label: 'Actualizar contraseña', loading: _loading, onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
