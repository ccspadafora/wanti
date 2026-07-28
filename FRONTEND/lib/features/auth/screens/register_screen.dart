import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_logo.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../state/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumber = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController(text: '+57 ');
  final _password = TextEditingController();
  String _idType = 'CC';
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _idNumber.dispose();
    _fullName.dispose();
    _email.dispose();
    _city.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().register(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _fullName.text.trim(),
            idType: _idType,
            idNumber: _idNumber.text.trim(),
            phone: _phone.text.trim(),
            city: _city.text.trim(),
          );
      if (!mounted) return;
      context.go('/verify-email');
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
      backgroundColor: WantiColors.navy,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WantiLogo(
                    variant: WantiLogoVariant.wordmark,
                    height: 48,
                    surface: true,
                    surfaceRadius: 16,
                    surfacePadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El marketplace al revés',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: WantiColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crear cuenta',
                        style: GoogleFonts.nunito(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: WantiColors.ink,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TIPO ID Y NÚMERO',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WantiColors.inkMuted,
                          letterSpacing: 0.24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: DropdownButtonFormField<String>(
                              initialValue: _idType,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                              items: const [
                                DropdownMenuItem(value: 'CC', child: Text('CC')),
                                DropdownMenuItem(value: 'CE', child: Text('CE')),
                                DropdownMenuItem(value: 'PASSPORT', child: Text('PASS')),
                                DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                              ],
                              onChanged: (v) => setState(() => _idType = v ?? 'CC'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _idNumber,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '1.020.445.778'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      WantiField(
                        label: 'Nombre completo',
                        controller: _fullName,
                        hint: 'María García',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                      ),
                      const SizedBox(height: 16),
                      WantiField(
                        label: 'Correo electrónico',
                        controller: _email,
                        hint: 'maria.garcia@ejemplo.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obligatorio';
                          if (!v.contains('@')) return 'Email inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      WantiField(
                        label: 'Ciudad',
                        controller: _city,
                        hint: 'Bogotá',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                      ),
                      const SizedBox(height: 16),
                      WantiField(
                        label: 'Celular',
                        controller: _phone,
                        hint: '+57 310 555 0192',
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().length < 10) ? 'Celular inválido' : null,
                      ),
                      const SizedBox(height: 16),
                      WantiField(
                        label: 'Contraseña',
                        controller: _password,
                        obscure: _obscure,
                        validator: (v) {
                          if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
                          return null;
                        },
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: WantiColors.inkFaint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: WantiColors.surfaceTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Podés publicar y vender desde el mismo perfil',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: WantiColors.tealDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      WantiButton(
                        label: 'Crear cuenta',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('¿Ya tenés cuenta? Inicia sesión'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
