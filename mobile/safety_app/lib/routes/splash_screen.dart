// lib/routes/splash_screen.dart (FIXED)

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
  bool _isNavigating = false; // Track if navigation is in progress

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (_isNavigating) return; // Prevent multiple navigations
    _isNavigating = true;

    try {
      // Get authentication state
      final authState = ref.read(authStateProvider);

      // Wait for initial animation
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      authState.when(
        data: (user) {
          if (!mounted) return;

          final targetRoute = _getTargetRoute(user);
          print('📍 Splash: Navigating to $targetRoute');

          // Use replace instead of go to remove splash from stack
          context.replace(targetRoute);
        },
        loading: () {
          // If still loading after delay, go to login
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              print('📍 Splash: Loading timeout - Navigating to Login');
              context.replace(AppRouter.login);
            }
          });
        },
        error: (error, stack) {
          if (mounted) {
            print('❌ Splash: Auth error - $error');
            context.replace(AppRouter.login);
          }
        },
      );
    } catch (e) {
      print('❌ Splash: Unexpected error - $e');
      if (mounted) {
        context.replace(AppRouter.login);
      }
    }
  }

  String _getTargetRoute(dynamic user) {
    if (user == null) {
      return AppRouter.login;
    } else if (user.hasRole) {
      return AppRouter.home;
    } else {
      return AppRouter.roleIntent;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Prevent any rebuilds by using a const widget
    return _SplashContent();
  }
}

// ✅ FIX: Separate widget to prevent rebuilds
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
