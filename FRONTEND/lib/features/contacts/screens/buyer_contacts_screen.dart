import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/whatsapp.dart';
import '../data/contacts_repository.dart';
import '../models/contact_unlock_model.dart';

class BuyerContactsScreen extends StatefulWidget {
  const BuyerContactsScreen({super.key});

  @override
  State<BuyerContactsScreen> createState() => _BuyerContactsScreenState();
}

class _BuyerContactsScreenState extends State<BuyerContactsScreen> {
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
      final items = await context.read<ContactsRepository>().listUnlocks(role: 'buyer');
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

  String _outcomeLabel(String outcome) {
    switch (outcome) {
      case 'PURCHASED':
        return 'Compré';
      case 'IN_PROGRESS':
        return 'En proceso';
      case 'NOT_PURCHASED':
        return 'No compré';
      default:
        return 'Pendiente';
    }
  }

  Future<void> _open(ContactUnlockModel u) async {
    if (u.matchId == null || u.matchId!.isEmpty) return;
    await context.push(
      '/matches/${u.matchId}/unlocked'
      '?unlockId=${Uri.encodeComponent(u.id)}'
      '&phone=${Uri.encodeComponent(u.sellerPhone ?? '')}',
    );
    _load();
  }

  Future<void> _whatsapp(ContactUnlockModel u) async {
    final phone = u.sellerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin teléfono disponible')),
      );
      return;
    }
    final name = (u.sellerName ?? 'hola').split(' ').first;
    final item = u.itemTitle ?? 'tu publicación';
    await openWhatsAppChat(
      phone: phone,
      message: 'Hola $name, vi tu publicación “$item” en Wanti. ¿Sigues disponible?',
    );
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
                        'Mis contactos',
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
                child: Text(
                  'Contactos que un vendedor desbloqueó',
                  style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
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
                    'Todavía no hay contactos desbloqueados. Cuando un vendedor gaste Wanti en tu sueño, los verás aquí.',
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
                      child: InkWell(
                        onTap: () => _open(u),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: WantiColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.sellerName ?? 'Vendedor',
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
                              if (u.itemPrice != null)
                                Text(
                                  '${formatCop(u.itemPrice!)} COP',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: WantiColors.inkFaint,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                _outcomeLabel(u.outcome),
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: WantiColors.tealDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _open(u),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: WantiColors.tealDark,
                                        side: const BorderSide(color: WantiColors.teal),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(
                                        'Ver detalle',
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _whatsapp(u),
                                      icon: const Icon(Icons.chat_rounded, size: 16),
                                      label: Text(
                                        'WhatsApp',
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
