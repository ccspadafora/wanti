import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../state/auth_controller.dart';

class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _sending = false;
  String _channel = 'WHATSAPP';
  int _secondsLeft = 300;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendOtp());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  Future<void> _sendOtp({String? channel}) async {
    setState(() {
      _sending = true;
      if (channel != null) _channel = channel;
    });
    try {
      await context.read<AuthController>().requestOtp(channel: _channel);
      if (!mounted) return;
      _startTimer();
      final debug = context.read<AuthController>().pendingOtpCode;
      if (debug != null && mounted) {
        for (var i = 0; i < 6 && i < debug.length; i++) {
          _controllers[i].text = debug[i];
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código local: $debug')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm() async {
    if (_code.length != 6) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().verifyOtp(_code);
      if (!mounted) return;
      context.go('/verified');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final mins = (_secondsLeft ~/ 60).toString();
    final secs = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Verifica tu celular'),
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
                            color: WantiColors.tealDark,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: WantiColors.teal.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: WantiColors.surfaceTeal,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _channel == 'WHATSAPP' ? Icons.chat : Icons.sms_outlined,
                                  size: 16,
                                  color: WantiColors.tealDark,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _channel == 'WHATSAPP'
                                      ? 'ENVIADO POR WHATSAPP'
                                      : 'ENVIADO POR SMS',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: WantiColors.tealDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Ingresá el código',
                            style: GoogleFonts.nunito(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: WantiColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Código de 6 dígitos enviado a ${user?.maskedPhone ?? ''}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: WantiColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (i) {
                              return SizedBox(
                                width: 48,
                                height: 60,
                                child: TextField(
                                  controller: _controllers[i],
                                  focusNode: _focus[i],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: WantiColors.ink,
                                  ),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: WantiColors.surfaceSoft,
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: WantiColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: WantiColors.teal,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v.isNotEmpty && i < 5) {
                                      _focus[i + 1].requestFocus();
                                    }
                                    if (v.isEmpty && i > 0) {
                                      _focus[i - 1].requestFocus();
                                    }
                                    setState(() {});
                                  },
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'El código vence en $mins:$secs',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: WantiColors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 28),
                          WantiButton(
                            label: 'Confirmar código',
                            loading: _loading,
                            onPressed: _code.length == 6 && !_sending ? _confirm : null,
                          ),
                          TextButton(
                            onPressed: _sending
                                ? null
                                : () => _sendOtp(
                                      channel: _channel == 'WHATSAPP' ? 'SMS' : 'WHATSAPP',
                                    ),
                            child: Text(
                              _channel == 'WHATSAPP'
                                  ? 'Enviar por SMS en su lugar'
                                  : 'Enviar por WhatsApp en su lugar',
                            ),
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
              child: DotsProgress(step: 2),
            ),
          ],
        ),
      ),
    );
  }
}
