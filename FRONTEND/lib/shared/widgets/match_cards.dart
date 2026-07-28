import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/wanti_colors.dart';
import '../../core/utils/formatters.dart';
import '../../features/matches/models/match_model.dart';

class MatchPercentLabel extends StatelessWidget {
  const MatchPercentLabel({super.key, required this.score, this.highMatch});

  final int score;
  final bool? highMatch;

  bool get _high => highMatch ?? score >= 85;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$score%',
      style: GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: _high ? WantiColors.teal : WantiColors.warning,
        height: 1,
      ),
    );
  }
}

class PreferenceChip extends StatelessWidget {
  const PreferenceChip({
    super.key,
    required this.label,
    this.accent = WantiColors.teal,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent == WantiColors.warning
            ? WantiColors.warningLight
            : WantiColors.surfaceTeal,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent == WantiColors.warning ? WantiColors.warning : WantiColors.tealDark,
        ),
      ),
    );
  }
}

class SellerMatchCard extends StatelessWidget {
  const SellerMatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.compact = false,
  });

  final MatchModel match;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final high = match.isHighMatch;
    final accent = high ? WantiColors.teal : WantiColors.warning;
    final buyer = match.buyer;
    final title = match.needTitle ?? 'Búsqueda de comprador';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WantiColors.canvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent, width: 1.4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MatchPercentLabel(score: match.score),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.startsWith('Busca') ? title : 'Busca $title',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: WantiColors.ink,
                      ),
                    ),
                    if (!compact && buyer != null) ...[
                      const SizedBox(height: 4),
                      if (buyer.isNewUser)
                        PreferenceChip(label: 'Usuario nuevo', accent: WantiColors.warning)
                      else
                        Text(
                          '${buyer.fullName.split(' ').take(2).join(' ')}'
                          '${buyer.ratingAverage != null ? ' ★ ${buyer.ratingAverage!.toStringAsFixed(1)}' : ''}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: WantiColors.inkMuted,
                          ),
                        ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: match.sellerAlertTags
                          .map((t) => PreferenceChip(label: t))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyerMatchCard extends StatelessWidget {
  const BuyerMatchCard({
    super.key,
    required this.match,
    required this.onUnlock,
    this.onOpenUnlocked,
    this.unlocking = false,
  });

  final MatchModel match;
  final VoidCallback? onUnlock;
  final VoidCallback? onOpenUnlocked;
  final bool unlocking;

  @override
  Widget build(BuildContext context) {
    final high = match.isHighMatch;
    final accent = high ? WantiColors.teal : WantiColors.warning;
    final seller = match.seller;
    final details = <String>[
      if (match.itemCity != null && match.itemCity!.isNotEmpty) match.itemCity!,
      if (match.itemPrice != null) '${formatCop(match.itemPrice!, compact: true)} COP',
      if (match.itemMileage != null) formatKm(match.itemMileage),
    ].where((e) => e.isNotEmpty).join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: match.alreadyUnlocked ? onOpenUnlocked : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WantiColors.canvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MatchPercentLabel(score: match.score),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.itemTitle ?? 'Publicación',
                          style: GoogleFonts.nunito(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: WantiColors.ink,
                          ),
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: WantiColors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (match.alreadyUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: WantiColors.surfaceTeal,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Desbloqueado',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WantiColors.tealDark,
                        ),
                      ),
                    ),
                ],
              ),
              if (seller != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: WantiColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: seller.isNewUser
                      ? Text(
                          'Usuario nuevo',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: WantiColors.warning,
                          ),
                        )
                      : Text(
                          '${seller.fullName}'
                          '${seller.ratingAverage != null ? '  ★ ${seller.ratingAverage!.toStringAsFixed(1)}' : ''}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: WantiColors.ink,
                          ),
                        ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: match.buyerMatchTags
                    .map((t) => PreferenceChip(label: t, accent: accent))
                    .toList(),
              ),
              if (match.unmetPreferences.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Deseable, pero no excluyente: ${match.unmetPreferences.take(2).join(', ')}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: WantiColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: unlocking
                      ? null
                      : match.alreadyUnlocked
                          ? onOpenUnlocked
                          : onUnlock,
                  icon: Icon(
                    match.alreadyUnlocked
                        ? Icons.chat_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                  ),
                  label: Text(
                    unlocking
                        ? 'Desbloqueando...'
                        : match.alreadyUnlocked
                            ? 'Ver ítem y contactar'
                            : 'Desbloquear — ${match.unlockCostWantis} Wanti',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: match.alreadyUnlocked
                        ? const Color(0xFF25D366)
                        : (high ? WantiColors.navy : WantiColors.warning),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: WantiColors.border,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
