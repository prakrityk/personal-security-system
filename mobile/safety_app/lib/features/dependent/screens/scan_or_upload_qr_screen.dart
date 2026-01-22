import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/features/dependent/screens/dependent_type_selection_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ScanOrUploadQrScreen extends StatelessWidget {
  final DependentType dependentType;

  const ScanOrUploadQrScreen({super.key, required this.dependentType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = dependentType == DependentType.child
        ? "Connect with your guardian"
        : "Connect with your caregiver";

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            /// 1️⃣ Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text(
                      "Scan the QR code provided by your guardian",
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 40),

                    /// QR Placeholder
                    Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryGreen),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          size: 120,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// Upload QR
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Upload QR from gallery"),
                        onPressed: () {
                          // TODO:
                          // Pick image from gallery
                          // Decode QR
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// 2️⃣ Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: "Scan QR",
                usePositioned: false,
                onPressed: () {
                  // TODO:
                  // Open camera
                  // Scan QR
                  // Verify guardian
                  // Navigate to dependent home
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
