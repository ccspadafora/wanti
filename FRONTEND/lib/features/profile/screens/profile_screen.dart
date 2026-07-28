import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_mode_controller.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/state/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.embedded = true});

  /// When true (seller tab), no back button — opens via bottom nav.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final mode = context.watch<AppModeController>();

    return SafeArea(
      top: !embedded,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, embedded ? 24 : 8, 24, 40),
        children: [
          if (!embedded)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
            ),
          Text(
            'Mi perfil',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: WantiColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: WantiColors.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: WantiColors.navy,
                  backgroundImage: (user?.profilePhotoUrl != null &&
                          user!.profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(user.profilePhotoUrl!)
                      : null,
                  child: (user?.profilePhotoUrl == null || user!.profilePhotoUrl!.isEmpty)
                      ? Text(
                          initialsOf(user?.fullName ?? '?'),
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: WantiColors.ink,
                        ),
                      ),
                      Text(user?.email ?? '', style: GoogleFonts.nunito(color: WantiColors.inkMuted)),
                      Text(user?.phone ?? '', style: GoogleFonts.nunito(color: WantiColors.inkMuted)),
                      Text(
                        '${user?.city ?? ''} · ${mode.isSeller ? 'Vendedor' : 'Comprador'}',
                        style: GoogleFonts.nunito(color: WantiColors.inkFaint, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ProfileLink(
            icon: Icons.edit_outlined,
            title: 'Editar datos',
            subtitle: 'Nombre, ciudad y foto',
            onTap: () => context.push('/profile/edit'),
          ),
          _ProfileLink(
            icon: Icons.email_outlined,
            title: 'Cambiar email',
            subtitle: user?.email ?? '',
            onTap: () => context.push('/profile/change-email'),
          ),
          _ProfileLink(
            icon: Icons.phone_outlined,
            title: 'Cambiar teléfono',
            subtitle: user?.phone ?? '',
            onTap: () => context.push('/profile/change-phone'),
          ),
          _ProfileLink(
            icon: Icons.lock_outline_rounded,
            title: 'Cambiar contraseña',
            subtitle: 'Actualizá tu acceso',
            onTap: () => context.push('/profile/change-password'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            child: Text(
              'Abrir menú · cambiar a ${mode.isSeller ? 'comprador' : 'vendedor'}',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: WantiColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: WantiColors.canvas,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: WantiColors.surfaceTeal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: WantiColors.tealDark),
        ),
        title: Text(
          title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: WantiColors.ink),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(color: WantiColors.inkMuted, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: WantiColors.inkFaint),
      ),
    );
  }
}
