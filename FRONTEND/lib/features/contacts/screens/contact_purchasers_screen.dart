import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/whatsapp.dart';
import '../../auth/state/auth_controller.dart';
import '../../contacts/data/contacts_repository.dart';
import '../../contacts/models/contact_unlock_model.dart';
import '../../disputes/dispute_reasons.dart';
import '../../disputes/widgets/open_dispute_sheet.dart';

class ContactPurchasersScreen extends StatefulWidget {
  const ContactPurchasersScreen({super.key});

  @override
  State<ContactPurchasersScreen> createState() => _ContactPurchasersScreenState();
}

class _ContactPurchasersScreenState extends State<ContactPurchasersScreen> {
  bool _loading = true;
  String? _error;
  List<ContactUnlockModel> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ContactsRepository>().listUnlocks(role: 'seller');
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _contact(ContactUnlockModel unlock) async {
    final me = context.read<AuthController>().user?.fullName ?? 'un vendedor Wanti';
    final phone = unlock.buyerPhone;
    final name = (unlock.buyerName ?? 'hola').split(' ').first;
    final item = unlock.itemTitle ?? 'tu búsqueda';
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin teléfono disponible')),
      );
      return;
    }
    final msg =
        'Hola $name, te desbloqueé tu contacto por Wanti. Mucho gusto, mi nombre es $me. Vi tu búsqueda “$item”.';
    await openWhatsAppChat(phone: phone, message: msg);
  }

  Future<void> _dispute(ContactUnlockModel unlock) async {
    if (!unlock.canOpenDispute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya hay una disputa activa para este contacto')),
      );
      return;
    }
    final ok = await showOpenDisputeSheet(
      context,
      unlockId: unlock.id,
      role: 'seller',
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disputa enviada')),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        color: WantiColors.teal,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.paddingOf(context).top + 8,
                  24,
                  8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        'Contactos desbloqueados',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: WantiColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        'Contactos que desbloqueaste con Wanti',
                        style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WantiColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DisputeReasons.sellerExplainer,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: WantiColors.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: WantiColors.teal)),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: WantiColors.error)),
                ),
              )
            else if (_items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Todavía nadie compró tu contacto. Cuando alguien lo desbloquee, lo verás aquí.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final u = _items[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: WantiColors.canvas,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: WantiColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.buyerName ?? 'Comprador',
                              style: GoogleFonts.nunito(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              u.itemTitle ?? 'Publicación',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: WantiColors.inkMuted,
                              ),
                            ),
                            if (u.buyerPhone != null)
                              Text(u.buyerPhone!, style: GoogleFonts.nunito(fontSize: 13)),
                            if (u.buyerEmail != null)
                              Text(
                                u.buyerEmail!,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: WantiColors.inkMuted,
                                ),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _contact(u),
                                icon: const Icon(Icons.chat_rounded, size: 18),
                                label: Text(
                                  'Contactar por WhatsApp',
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: u.canOpenDispute ? () => _dispute(u) : null,
                                icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
                                label: Text(
                                  u.canOpenDispute
                                      ? 'Abrir disputa / reembolso Wanti'
                                      : 'Disputa ya abierta',
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: WantiColors.error,
                                  side: BorderSide(
                                    color: u.canOpenDispute
                                        ? WantiColors.error
                                        : WantiColors.borderLight,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
