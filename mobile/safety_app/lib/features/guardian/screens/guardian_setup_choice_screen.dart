import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/animated_bottom_button.dart';
import '../../../core/widgets/intent_card.dart';

enum GuardianSetupType { primary, collaborator }

class GuardianSetupChoiceScreen extends StatefulWidget {
  const GuardianSetupChoiceScreen({super.key});

  @override
  State<GuardianSetupChoiceScreen> createState() =>
      _GuardianSetupChoiceScreenState();
}

class _GuardianSetupChoiceScreenState extends State<GuardianSetupChoiceScreen> {
  GuardianSetupType? _selectedType;

  void _continue() {
    if (_selectedType == null) return;

    // ✅ Updated navigation with GoRouter
    switch (_selectedType!) {
      case GuardianSetupType.primary:
        context.push('/guardian-add-dependent');
        break;

      case GuardianSetupType.collaborator:
        context.push('/collaborator-join');
        break;
    }
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
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Header with icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryGreen.withOpacity(0.1),
                            AppColors.accentGreen1.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.family_restroom,
                              color: AppColors.primaryGreen,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "How would you like to add your loved one?",
                            style: AppTextStyles.h2,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "This helps us set things up correctly",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkHint
                                  : AppColors.lightHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    /// PRIMARY GUARDIAN
                    IntentCard(
                      title: "Add as primary guardian",
                      description:
                          "Choose this if you're setting up their account for the first time. "
                          "You'll create their profile and generate a secure QR code.",
                      icon: Icons.admin_panel_settings,
                      isSelected: _selectedType == GuardianSetupType.primary,
                      onTap: () {
                        setState(() {
                          _selectedType = GuardianSetupType.primary;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    /// COLLABORATOR
                    IntentCard(
                      title: "Join as a collaborator",
                      description:
                          "Choose this if your loved one already has an account. "
                          "Connect by scanning or entering an existing invitation code.",
                      icon: Icons.groups,
                      isSelected:
                          _selectedType == GuardianSetupType.collaborator,
                      onTap: () {
                        setState(() {
                          _selectedType = GuardianSetupType.collaborator;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Fixed bottom button with shadow
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: AnimatedBottomButton(
                label: "Continue",
                usePositioned: false,
                isEnabled: _selectedType != null,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
