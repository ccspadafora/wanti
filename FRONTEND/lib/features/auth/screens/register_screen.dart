import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/colombia_cities.dart';
import '../../../core/utils/password_rules.dart';
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
  final _phone = TextEditingController(text: '+57 ');
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  String _idType = 'CC';
  String? _city;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _idNumber.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_city == null || _city!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ciudad')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().register(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _fullName.text.trim(),
            idType: _idType,
            idNumber: _idNumber.text.trim(),
            phone: _phone.text.trim(),
            city: _city!,
          );
      if (!mounted) return;
      final auth = context.read<AuthController>();
      if (auth.needsEmailVerification) {
        context.go('/verify-email');
      } else if (auth.needsPhoneVerification) {
        context.go('/verify-phone');
      } else {
        context.go('/home');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.displayMessage),
          duration: const Duration(seconds: 5),
        ),
      );
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
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                children: [
                  const Center(
                    child: WantiLogo(
                      variant: WantiLogoVariant.wordmark,
                      height: 44,
                      alignment: Alignment.center,
                      surface: true,
                      surfaceRadius: 16,
                      surfacePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'El marketplace al revés',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
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
                      WantiDropdown<String>(
                        label: 'Ciudad',
                        value: _city,
                        hint: 'Selecciona',
                        items: ColombiaCities.all
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _city = v),
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
                        validator: (v) => PasswordRules.validate(
                          v,
                          email: _email.text,
                          fullName: _fullName.text,
                        ),
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
                        controller: _passwordConfirm,
                        obscure: _obscureConfirm,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Obligatorio';
                          if (v != _password.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: WantiColors.inkFaint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: WantiColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: WantiColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'La contraseña debe cumplir:',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: WantiColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...PasswordRules.requirements.map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '• $r',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: WantiColors.inkFaint,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                          'Puedes publicar y vender desde el mismo perfil',
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
                          child: const Text('¿Ya tienes cuenta? Inicia sesión'),
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
