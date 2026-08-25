import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _phone = TextEditingController(text: '+57');
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _awaitingOtp = false;
  String? _debugOtp;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final phone = _phone.text.trim();
    if (phone.length < 10) {
      _toast('Ingresa un teléfono válido');
      return;
    }
    if (_password.text.isEmpty) {
      _toast('Confirma con tu contraseña');
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthController>();
      final result = await auth.changePhone(newPhone: phone, password: _password.text);
      if (!mounted) return;
      setState(() {
        _awaitingOtp = true;
        _debugOtp = result.debugCode;
      });
      _toast(result.detail);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length < 4) {
      _toast('Ingresa el código OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().verifyOtp(_otp.text.trim());
      await context.read<AuthController>().refreshMe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teléfono actualizado')),
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
    final current = context.watch<AuthController>().user?.phone ?? '';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Cambiar teléfono'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text(
                    'Actual: $current',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  if (!_awaitingOtp) ...[
                    WantiField(
                      label: 'Nuevo teléfono',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      hint: '+57 300 123 4567',
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
                    WantiButton(label: 'Enviar OTP', loading: _loading, onPressed: _request),
                  ] else ...[
                    Text(
                      'Ingresa el código que enviamos a ${_phone.text.trim()}',
                      style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                    ),
                    if (_debugOtp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Código de prueba: $_debugOtp',
                        style: GoogleFonts.nunito(
                          color: WantiColors.tealDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    WantiField(
                      label: 'Código OTP',
                      controller: _otp,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 28),
                    WantiButton(label: 'Confirmar teléfono', loading: _loading, onPressed: _verify),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              try {
                                final result = await context.read<AuthController>().changePhone(
                                      newPhone: _phone.text.trim(),
                                      password: _password.text,
                                    );
                                if (!mounted) return;
                                setState(() => _debugOtp = result.debugCode);
                                _toast('Código reenviado');
                              } on ApiException catch (e) {
                                if (!mounted) return;
                                _toast(e.message);
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                      child: Text(
                        'Reenviar código',
                        style: GoogleFonts.nunito(color: WantiColors.teal, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
