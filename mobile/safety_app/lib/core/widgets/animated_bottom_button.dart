import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AnimatedBottomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry margin;
  final bool usePositioned;
  final Duration animationDuration;
  final bool isEnabled;

  const AnimatedBottomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    this.usePositioned = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = AnimatedSlide(
      duration: animationDuration,
      offset: const Offset(0, 0),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: animationDuration,
        opacity: 1,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isEnabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(label, style: AppTextStyles.button),
          ),
        ),
      ),
    );

    /// If you want absolute positioning (like splash / get started)
    if (usePositioned) {
      return Positioned(
        left: margin.horizontal / 2,
        right: margin.horizontal / 2,
        bottom: margin.vertical,
        child: button,
      );
    }

    /// Normal layout usage (OTP, Register, etc.)
    return Padding(padding: margin, child: button);
  }
}
