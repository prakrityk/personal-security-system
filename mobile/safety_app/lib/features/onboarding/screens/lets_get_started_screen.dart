import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/features/auth/screens/phone_number_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LetsGetStartedScreen extends StatefulWidget {
  const LetsGetStartedScreen({super.key});

  @override
  State<LetsGetStartedScreen> createState() => _LetsGetStartedScreenState();
}

class _LetsGetStartedScreenState extends State<LetsGetStartedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideOutAnimation;
  late Animation<Offset> _slideInAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  final List<String> texts = [
    'Safety, when it matters most',
    'Your personal guardian',
    'Protect yourself and your loved ones',
    'Keep your family closer',
  ];

  int _currentIndex = 0;
  int _nextIndex = 1;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _slideInAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _startTextRotation();
  }

  void _startTextRotation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;

      setState(() {
        _nextIndex = (_currentIndex + 1) % texts.length;
      });

      await _controller.forward();

      if (!mounted) return false;

      setState(() {
        _currentIndex = _nextIndex;
      });

      _controller.reset();
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateNext() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const PhoneNumberScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Main content area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/lottie/lets.json',
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 40),
                  
                  // Animated text
                  SizedBox(
                    height: 100,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Stack(
                        children: [
                          SlideTransition(
                            position: _slideOutAnimation,
                            child: FadeTransition(
                              opacity: _fadeOutAnimation,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  texts[_currentIndex],
                                  textAlign: TextAlign.left,
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 26,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.black.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SlideTransition(
                            position: _slideInAnimation,
                            child: FadeTransition(
                              opacity: _fadeInAnimation,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  texts[_nextIndex],
                                  textAlign: TextAlign.left,
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 26,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.black.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(
                currentStep: 0,
                totalSteps: 3,
                previewOnly: true,
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: "Let's Get Started",
                usePositioned: false, // Changed to false
                onPressed: _navigateNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}