import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../leads/data/leads_repository.dart';
import '../../leads/models/lead_model.dart';

class SellerLeadsScreen extends StatefulWidget {
  const SellerLeadsScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<SellerLeadsScreen> createState() => _SellerLeadsScreenState();
}

class _SellerLeadsScreenState extends State<SellerLeadsScreen> {
  static const _filters = <(String, String)>[
    ('ALL', 'Todos'),
    ('NEW', 'Nuevos'),
    ('IN_NEGOTIATION', 'Negociación'),
    ('TO_VISIT', 'Visita'),
    ('PURCHASED', 'Comprado'),
    ('DISCARDED', 'Descartado'),
  ];

  String _stage = 'ALL';
  bool _loading = true;
  String? _error;
  List<LeadModel> _leads = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final leads = await context.read<LeadsRepository>().list(
            stage: _stage == 'ALL' ? null : _stage,
            q: _search.text,
          );
      if (!mounted) return;
      setState(() {
        _leads = leads;
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

  Color _stageColor(String stage) {
    switch (stage) {
      case 'IN_NEGOTIATION':
        return WantiColors.warning;
      case 'TO_VISIT':
        return const Color(0xFF3B82F6);
      case 'PURCHASED':
        return WantiColors.teal;
      case 'DISCARDED':
        return WantiColors.inkFaint;
      default:
        return WantiColors.navy;
    }
  }

  Future<void> _openLead(LeadModel lead) async {
    await context.push('/leads/${lead.id}');
    _load();
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
                  16,
                  MediaQuery.paddingOf(context).top + 8,
                  24,
                  8,
                ),
                child: Row(
                  children: [
                    if (widget.showBack)
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CRM de leads que desbloqueaste con Wanti',
                      style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, sueño o ítem…',
                        prefixIcon: const Icon(Icons.search, color: WantiColors.inkFaint),
                        suffixIcon: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.arrow_forward_rounded, color: WantiColors.teal),
                        ),
                        filled: true,
                        fillColor: WantiColors.surfaceSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: _filters.map((f) {
                    final selected = _stage == f.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f.$2),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _stage = f.$1);
                          _load();
                        },
                        showCheckmark: false,
                        selectedColor: WantiColors.navy,
                        backgroundColor: WantiColors.surfaceSoft,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: selected ? Colors.white : WantiColors.inkMuted,
                        ),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
            else if (_leads.isEmpty)
              ContenedorVacio(
                message: _search.text.trim().isEmpty
                    ? 'Todavía no desbloqueaste contactos. Cuando gastes Wanti en un match, el lead aparece aquí.'
                    : 'No hay contactos con ese filtro.',
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final lead = _leads[index];
                    final color = _stageColor(lead.stage);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openLead(lead),
                          borderRadius: BorderRadius.circular(16),
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
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: WantiColors.navy,
                                      child: Text(
                                        initialsOf(lead.buyerName),
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lead.buyerName,
                                            style: GoogleFonts.nunito(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            lead.needTitle ?? lead.itemTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.nunito(
                                              fontSize: 13,
                                              color: WantiColors.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        lead.stageLabel,
                                        style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (lead.score != null) ...[
                                      Text(
                                        '${lead.score}% match',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: WantiColors.tealDark,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    if (lead.notesCount > 0)
                                      Text(
                                        '${lead.notesCount} nota${lead.notesCount == 1 ? '' : 's'}',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: WantiColors.inkMuted,
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      'Ver lead',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: WantiColors.tealDark,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: WantiColors.tealDark,
                                    ),
                                  ],
                                ),
                                if (lead.lastActivityAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Actividad ${relativeDaysAgo(lead.lastActivityAt)}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: WantiColors.inkFaint,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _leads.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class ContenedorVacio extends StatelessWidget {
  const ContenedorVacio({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
        ),
      ),
    );
  }
}
