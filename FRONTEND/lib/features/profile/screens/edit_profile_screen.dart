import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/colombia_cities.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  String? _city;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _city = ColombiaCities.normalize(user?.city) ??
        (ColombiaCities.all.contains(user?.city) ? user!.city : null);
  }

  Future<void> _save() async {
    if (_city == null || _city!.isEmpty) {
      _toast('Selecciona tu ciudad');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().updateProfile(city: _city!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ciudad actualizada')),
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
    final user = context.watch<AuthController>().user;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Editar ciudad'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text(
                    'Solo puedes cambiar tu ciudad desde la app. '
                    'Nombre, correo y teléfono son datos de autenticación: '
                    'para actualizarlos contacta al equipo de 1T.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Nombre',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: WantiColors.inkMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: WantiColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: WantiColors.borderLight),
                    ),
                    child: Text(
                      user?.fullName ?? '',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w600,
                        color: WantiColors.inkFaint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  WantiDropdown<String>(
                    label: 'Ciudad',
                    value: _city,
                    hint: 'Selecciona',
                    items: ColombiaCities.all
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _city = v),
                  ),
                  const SizedBox(height: 28),
                  WantiButton(label: 'Guardar ciudad', loading: _loading, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
