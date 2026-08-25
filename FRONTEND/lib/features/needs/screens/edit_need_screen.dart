import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../data/needs_repository.dart';

/// Edición limitada: solo el nombre/título.
/// El presupuesto no se edita para no invalidar matches ya generados.
class EditNeedScreen extends StatefulWidget {
  const EditNeedScreen({super.key, required this.needId});

  final String needId;

  @override
  State<EditNeedScreen> createState() => _EditNeedScreenState();
}

class _EditNeedScreenState extends State<EditNeedScreen> {
  final _title = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final need = await context.read<NeedsRepository>().detail(widget.needId);
      if (!mounted) return;
      _title.text = need.title;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _toast('El nombre es obligatorio');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<NeedsRepository>().update(widget.needId, {
        'title': _title.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sueño actualizado')),
      );
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: WantiColors.teal))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: WantiColors.error)))
                : Column(
                    children: [
                      ScreenHeader(
                        title: 'Editar sueño',
                        onBack: () => context.pop(),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          children: [
                            Text(
                              'Solo puedes cambiar el nombre. El presupuesto no se edita para no invalidar los matches ya generados.',
                              style: GoogleFonts.nunito(
                                color: WantiColors.inkMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            WantiField(label: 'Nombre', controller: _title),
                            const SizedBox(height: 24),
                            WantiButton(
                              label: 'Guardar cambios',
                              loading: _saving,
                              onPressed: _save,
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
