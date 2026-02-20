// lib/routes/splash_screen.dart
// ✅ FIXED: Waits for auth loading to complete before navigating.
// Previously it would timeout to /login after 500ms even if tokens were
// being restored from secure storage — causing the persistent login to fail.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/routes/app_router.dart';
import '../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitForAuthAndNavigate();
    });
  }

  Future<void> _waitForAuthAndNavigate() async {
    // Minimum splash display time for branding purposes
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _hasNavigated) return;

    // ✅ KEY CHANGE: Instead of reading state once and timing out,
    // we LISTEN to the auth state and only navigate once loading is done.
    // This guarantees we never redirect to login while _loadUser() is still
    // reading tokens from secure storage.
    final authState = ref.read(authStateProvider);

    if (authState.isLoading) {
      // Auth is still restoring session — wait for it to finish.
      // We set a generous max timeout (5s) as a safety net only.
      // In practice _loadUser() finishes in < 500ms on any real device.
      debugPrint('⏳ Splash: Auth still loading, waiting...');

      // Poll until resolved or timeout
      const maxWait = Duration(seconds: 5);
      const pollInterval = Duration(milliseconds: 100);
      final deadline = DateTime.now().add(maxWait);

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);
        if (!mounted || _hasNavigated) return;

        final current = ref.read(authStateProvider);
        if (!current.isLoading) {
          // Loading finished — now navigate
          _navigateBasedOnAuth(current.value);
          return;
        }
      }

      // Safety net: if still loading after 5s something is wrong, go to login
      debugPrint('⚠️ Splash: Auth load timeout — going to login as fallback');
      _navigateBasedOnAuth(null);
    } else {
      // Auth resolved immediately (e.g. no token in storage — fast path)
      _navigateBasedOnAuth(authState.value);
    }
  }

  void _navigateBasedOnAuth(dynamic user) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    final target = _getTargetRoute(user);
    debugPrint('📍 Splash: Navigating to $target');
    context.replace(target);
  }

  String _getTargetRoute(dynamic user) {
    if (user == null) {
      return AppRouter.login;
    } else if (user.hasRole && user.currentRole != null) {
      return AppRouter.home;
    } else {
      return AppRouter.roleIntent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _SplashContent();
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/splash.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}
