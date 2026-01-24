import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';  // ✅ Add this import
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/animated_bottom_button.dart';
import '../../../core/widgets/intent_card.dart';
import 'package:safety_app/routes/app_router.dart';
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
        context.push(AppRouter.guardianCollaborator);
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
                    Text(
                      "How would you like to add your loved one?",
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This helps us set things up correctly",
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 32),

                    /// PRIMARY GUARDIAN
                    IntentCard(
                      title: "Add as primary guardian",
                      description:
                          "Choose this if you're setting up their account for the first time. "
                          "You'll create their profile and generate a secure QR code.",
                      icon: Icons.qr_code_2,
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
                      icon: Icons.group_outlined,
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

            // Fixed bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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

/// 🔹 Placeholder – collaborator flow (scan / paste code)
class GuardianCollaboratorLinkScreen extends StatelessWidget {
  const GuardianCollaboratorLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connect as Collaborator")),
      body: const Center(
        child: Text(
          "Scan QR or enter invitation code",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}