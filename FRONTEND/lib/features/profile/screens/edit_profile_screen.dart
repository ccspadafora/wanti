import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _photo;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _name = TextEditingController(text: user?.fullName ?? '');
    _city = TextEditingController(text: user?.city ?? '');
    _photo = TextEditingController(text: user?.profilePhotoUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _photo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('Ingresá tu nombre completo');
      return;
    }
    if (_city.text.trim().isEmpty) {
      _toast('Ingresá tu ciudad');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().updateProfile(
            fullName: _name.text.trim(),
            city: _city.text.trim(),
            profilePhotoUrl: _photo.text.trim().isEmpty ? '' : _photo.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
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
            const ScreenHeader(title: 'Editar datos'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text(
                    'Estos datos se muestran a compradores y vendedores cuando hay un match.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  WantiField(label: 'Nombre completo', controller: _name),
                  const SizedBox(height: 14),
                  WantiField(label: 'Ciudad', controller: _city),
                  const SizedBox(height: 14),
                  WantiField(
                    label: 'URL de foto (opcional)',
                    controller: _photo,
                    hint: 'https://...',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 28),
                  WantiButton(label: 'Guardar cambios', loading: _loading, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
