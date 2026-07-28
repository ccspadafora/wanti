import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_mode_controller.dart';
import '../../core/theme/wanti_colors.dart';
import '../../core/utils/formatters.dart';
import '../../features/auth/state/auth_controller.dart';
import 'wanti_logo.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cerrar sesión', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: Text(
          '¿Querés salir de tu cuenta en este dispositivo?',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cerrar sesión', style: GoogleFonts.nunito(color: WantiColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // close drawer
      await context.read<AuthController>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final mode = context.watch<AppModeController>();

    return Drawer(
      backgroundColor: WantiColors.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const WantiLogo(variant: WantiLogoVariant.wordmark, height: 36),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: WantiColors.inkMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WantiColors.surfaceTeal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
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
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: WantiColors.ink,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: WantiColors.inkMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user?.city != null && user!.city.isNotEmpty)
                            Text(
                              user.city,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: WantiColors.inkFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Modo de uso',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: WantiColors.inkMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTile(
                      label: 'Comprador',
                      icon: Icons.shopping_bag_outlined,
                      selected: mode.isBuyer,
                      onTap: () {
                        mode.setMode(AppMode.buyer);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeTile(
                      label: 'Vendedor',
                      icon: Icons.storefront_outlined,
                      selected: mode.isSeller,
                      onTap: () {
                        mode.setMode(AppMode.seller);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: WantiColors.borderLight),
            _DrawerTile(
              icon: Icons.person_outline_rounded,
              label: 'Mi perfil',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile');
              },
            ),
            _DrawerTile(
              icon: Icons.edit_outlined,
              label: 'Editar datos',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile/edit');
              },
            ),
            _DrawerTile(
              icon: Icons.lock_outline_rounded,
              label: 'Cambiar contraseña',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile/change-password');
              },
            ),
            if (mode.isSeller)
              _DrawerTile(
                icon: Icons.handshake_outlined,
                label: 'Mis leads',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/leads');
                },
              ),
            const Spacer(),
            const Divider(height: 1, color: WantiColors.borderLight),
            _DrawerTile(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              danger: true,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? WantiColors.navy : WantiColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? WantiColors.navy : WantiColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : WantiColors.ink, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? Colors.white : WantiColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? WantiColors.error : WantiColors.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: color),
      ),
      onTap: onTap,
    );
  }
}

/// Shared home header bar: brand + menu that opens the shell drawer.
class HomeAppHeader extends StatelessWidget {
  const HomeAppHeader({
    super.key,
    required this.greeting,
    this.subtitle,
  });

  final String greeting;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WantiColors.surfaceTeal,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 12,
        12,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: WantiLogo(variant: WantiLogoVariant.wordmark, height: 52),
                ),
              ),
              IconButton(
                tooltip: 'Menú',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: WantiColors.navy, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            greeting,
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: WantiColors.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
