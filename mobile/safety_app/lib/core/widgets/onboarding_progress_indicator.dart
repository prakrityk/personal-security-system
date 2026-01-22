import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  /// If true → shows all steps as inactive (grey)
  final bool previewOnly;

  const OnboardingProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.previewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inactiveColor = isDark
        ? AppColors.darkDivider
        : AppColors.lightDivider;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          final isActive = !previewOnly && stepIndex <= currentStep;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.primaryGreen : inactiveColor,
            ),
          );
        } else {
          final isActive = !previewOnly && currentStep >= (index ~/ 2);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 24,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryGreen : inactiveColor,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }
      }),
    );
  }
}
