import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../data/reviews_repository.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  String _type = 'received';
  bool _loading = true;
  String? _error;
  List<ReviewModel> _items = [];

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
      final items = await context.read<ReviewsRepository>().mine(type: _type);
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

  Color _badgeColor(ReviewModel r) {
    if (r.dispute?.status == 'OPEN' || r.status == 'UNDER_REVIEW') {
      return WantiColors.warning;
    }
    if (r.dispute?.status == 'RESOLVED_REMOVED' || r.status == 'REMOVED') {
      return WantiColors.error;
    }
    if (r.dispute?.status == 'RESOLVED_KEPT') {
      return WantiColors.teal;
    }
    return WantiColors.inkFaint;
  }

  String _badgeText(ReviewModel r) {
    if (r.dispute != null) return r.dispute!.statusLabel;
    if (r.status != 'PUBLISHED') return r.statusLabel;
    return '';
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
                        'Mis reseñas',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
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
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Recibidas'),
                      selected: _type == 'received',
                      onSelected: (_) {
                        setState(() => _type = 'received');
                        _load();
                      },
                      selectedColor: WantiColors.navy,
                      labelStyle: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: _type == 'received' ? Colors.white : WantiColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Enviadas'),
                      selected: _type == 'given',
                      onSelected: (_) {
                        setState(() => _type = 'given');
                        _load();
                      },
                      selectedColor: WantiColors.navy,
                      labelStyle: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: _type == 'given' ? Colors.white : WantiColors.ink,
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
                    _type == 'received'
                        ? 'Todavía no recibiste reseñas.'
                        : 'Todavía no enviaste reseñas.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final r = _items[index];
                    final badge = _badgeText(r);
                    final color = _badgeColor(r);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: WantiColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.otherName ?? 'Usuario',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  '★ ${r.rating}',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    color: WantiColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            if (badge.isNotEmpty) ...[
                              const SizedBox(height: 8),
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
                                  badge,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                            if ((r.comment ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                r.comment!,
                                style: GoogleFonts.nunito(
                                  color: WantiColors.inkMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (r.tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: r.tags
                                    .map(
                                      (t) => Chip(
                                        label: Text(t, style: GoogleFonts.nunito(fontSize: 11)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (r.dispute != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: WantiColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tu motivo',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: WantiColors.inkFaint,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.dispute!.reason ?? '',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                    if ((r.dispute!.adminNote ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Respuesta admin',
                                        style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: WantiColors.inkFaint,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        r.dispute!.adminNote!,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            if (_type == 'received' && r.canDispute) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _disputeReview(r),
                                  icon: const Icon(Icons.flag_outlined, size: 16),
                                  label: Text(
                                    'Impugnar reseña',
                                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
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

  Future<void> _disputeReview(ReviewModel review) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Impugnar reseña', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explica por qué esta calificación o comentario es injusto o incorrecto.',
                style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Motivo de la impugnación'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un motivo')),
      );
      return;
    }
    try {
      await context.read<ReviewsRepository>().disputeReview(review.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impugnación enviada a revisión')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    }
  }
}
