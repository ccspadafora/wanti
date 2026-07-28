import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/wanti_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/verified_screen.dart';
import 'features/auth/screens/verify_email_screen.dart';
import 'features/auth/screens/verify_phone_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/contacts/screens/contact_unlocked_screen.dart';
import 'features/home/screens/home_shell.dart';
import 'features/inventory/screens/add_inventory_screen.dart';
import 'features/needs/screens/new_need_flow_screen.dart';
import 'features/profile/screens/change_email_screen.dart';
import 'features/profile/screens/change_password_screen.dart';
import 'features/profile/screens/change_phone_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/seller/screens/seller_leads_screen.dart';

GoRouter createRouter(AuthController auth) {
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth.loading) return null;
      final loc = state.matchedLocation;
      final public = {'/welcome', '/login', '/register'};

      if (!auth.isAuthenticated) {
        return public.contains(loc) ? null : '/welcome';
      }

      if (auth.needsEmailVerification) {
        return loc == '/verify-email' ? null : '/verify-email';
      }

      if (auth.needsPhoneVerification) {
        return (loc == '/verify-phone' || loc == '/verified') ? null : '/verify-phone';
      }

      if (public.contains(loc) ||
          loc == '/verify-email' ||
          loc == '/verify-phone') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/verify-email', builder: (_, _) => const VerifyEmailScreen()),
      GoRoute(path: '/verify-phone', builder: (_, _) => const VerifyPhoneScreen()),
      GoRoute(path: '/verified', builder: (_, _) => const VerifiedScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeShell(
          initialTab: state.uri.queryParameters['tab'],
          initialNeedId: state.uri.queryParameters['needId'],
        ),
      ),
      GoRoute(
        path: '/needs/new',
        builder: (context, state) {
          final asset = state.uri.queryParameters['asset'] ?? 'VEHICLE';
          return NewNeedFlowScreen(
            initialAssetType: asset == 'PROPERTY' ? 'PROPERTY' : 'VEHICLE',
          );
        },
      ),
      GoRoute(
        path: '/inventory/new',
        builder: (_, _) => const AddInventoryScreen(),
      ),
      GoRoute(
        path: '/leads',
        builder: (_, _) => const SellerLeadsScreen(showBack: true),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const ProfileScreen(embedded: false),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/change-email',
        builder: (_, _) => const ChangeEmailScreen(),
      ),
      GoRoute(
        path: '/profile/change-phone',
        builder: (_, _) => const ChangePhoneScreen(),
      ),
      GoRoute(
        path: '/profile/change-password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/matches/:id/unlocked',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ContactUnlockedScreen(
            matchId: id,
            unlockId: state.uri.queryParameters['unlockId'],
            phone: state.uri.queryParameters['phone'],
            score: int.tryParse(state.uri.queryParameters['score'] ?? ''),
          );
        },
      ),
    ],
  );
}

class WantiApp extends StatefulWidget {
  const WantiApp({super.key, required this.auth});

  final AuthController auth;

  @override
  State<WantiApp> createState() => _WantiAppState();
}

class _WantiAppState extends State<WantiApp> {
  late final GoRouter _router = createRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wanti',
      debugShowCheckedModeBanner: false,
      theme: WantiTheme.light(),
      routerConfig: _router,
    );
  }
}
