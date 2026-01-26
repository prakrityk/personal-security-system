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
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash animation for at least 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      // Get authentication state
      final authState = ref.read(authStateProvider);

      authState.when(
        data: (user) {
          if (!mounted) return;

          if (user != null) {
            // User is logged in
            print('✅ Splash: User logged in - ${user.fullName}');

            if (user.hasRole) {
              // Has role assigned - go to home
              print('📍 Splash: Navigating to Home (has role)');
              context.go(AppRouter.home);
            } else {
              // No role assigned - go to role selection
              print('📍 Splash: Navigating to Role Intent (no role)');
              context.go(AppRouter.roleIntent);
            }
          } else {
            // No user - go to login
            print('📍 Splash: No user found - Navigating to Login');
            context.go(AppRouter.login);
          }
        },
        loading: () {
          // Still loading - default to login after a short wait
          print('⏳ Splash: Auth state loading...');
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              print('📍 Splash: Loading timeout - Navigating to Login');
              context.go(AppRouter.login);
            }
          });
        },
        error: (error, stack) {
          // Error loading auth state - go to login
          print('❌ Splash: Auth error - $error');
          print('📍 Splash: Navigating to Login due to error');
          if (mounted) {
            context.go(AppRouter.login);
          }
        },
      );
    } catch (e) {
      // Catch any unexpected errors
      print('❌ Splash: Unexpected error - $e');
      if (mounted) {
        context.go(AppRouter.login);
      }
    }
  }

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
            // Optional: Add loading indicator
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
