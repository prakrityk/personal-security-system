import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/intent_card.dart';
import 'scan_or_upload_qr_screen.dart';

enum DependentType { child, elderly }

class DependentTypeSelectionScreen extends StatefulWidget {
  const DependentTypeSelectionScreen({super.key});

  @override
  State<DependentTypeSelectionScreen> createState() =>
      _DependentTypeSelectionScreenState();
}

class _DependentTypeSelectionScreenState
    extends State<DependentTypeSelectionScreen> {
  DependentType? _selectedType;

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
            /// 1️⃣ Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Who needs protection?", style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text(
                      "Choose the option that best describes you",
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 32),

                    IntentCard(
                      title: "I am a child",
                      description: "Protected by parents or guardians",
                      icon: Icons.child_care_outlined,
                      isSelected: _selectedType == DependentType.child,
                      onTap: () {
                        setState(() {
                          _selectedType = DependentType.child;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    IntentCard(
                      title: "I am elderly",
                      description: "Assisted and protected by caregivers",
                      icon: Icons.elderly_outlined,
                      isSelected: _selectedType == DependentType.elderly,
                      onTap: () {
                        setState(() {
                          _selectedType = DependentType.elderly;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            /// 2️⃣ Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: "Continue",
                usePositioned: false,
                onPressed: _selectedType == null
                    ? () {}
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScanOrUploadQrScreen(
                              dependentType: _selectedType!,
                            ),
                          ),
                        );

                        // TODO:
                        // Save dependent type to backend
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
