import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/core/widgets/avatar_picker.dart';
import 'package:safety_app/features/auth/screens/login_screen.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

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
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AvatarPicker(
                      onTap: () {
                        // UI-only for now
                      },
                    ),

                    const SizedBox(height: 16),

                    Text("Create your profile", style: AppTextStyles.h3),

                    const SizedBox(height: 32),

                    AppTextField(label: "Full Name"),

                    const SizedBox(height: 16),

                    AppTextField(
                      label: "Phone Number",
                      controller: TextEditingController(
                        text: "+977 98XXXXXXXX",
                      ),
                      enabled: false,
                    ),

                    const SizedBox(height: 16),

                    AppTextField(
                      label: "Email",
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),

                    AppTextField(label: "Password", obscureText: true),

                    const SizedBox(height: 16),

                    AppTextField(label: "Confirm Password", obscureText: true),
                  ],
                ),
              ),
            ),

            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(currentStep: 2, totalSteps: 3),
            ),

            const SizedBox(height: 16),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: "Register",
                usePositioned: false, // Changed to false
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
