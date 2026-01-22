import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/features/dependent/screens/dependent_type_selection_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_setup_choice_screen.dart';
import 'package:safety_app/services/auth_service.dart';
import 'package:safety_app/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/intent_card.dart';

/// Intent decides onboarding path (NOT backend role)
enum UserIntent { personal, guardian, dependent }

class RoleIntentScreen extends StatefulWidget {
  const RoleIntentScreen({super.key});

  @override
  State<RoleIntentScreen> createState() => _RoleIntentScreenState();
}

class _RoleIntentScreenState extends State<RoleIntentScreen> {
  final AuthService _authService = AuthService();
  UserIntent? _selectedIntent;
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateBasedOnIntent(UserIntent intent) {
    Widget nextScreen;

    switch (intent) {
      case UserIntent.personal:
        nextScreen = const PersonalOnboardingScreen();
        break;

      case UserIntent.guardian:
        nextScreen = const GuardianSetupChoiceScreen();
        break;

      case UserIntent.dependent:
        nextScreen = const DependentTypeSelectionScreen();
        break;
    }

    // TODO: When backend supports saving intent, call API here:
    // await _authService.saveUserIntent(intent);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome message with user name
                          if (_currentUser != null) ...[
                            Text(
                              "Welcome, ${_currentUser!.fullName}!",
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          Text(
                            "How will you use the app?",
                            style: AppTextStyles.heading,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "This helps us personalize your experience",
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: 32),

                          // PERSONAL
                          IntentCard(
                            title: "Just for me",
                            description:
                                "Personal safety features for your own protection",
                            icon: Icons.person_outline,
                            isSelected: _selectedIntent == UserIntent.personal,
                            onTap: () {
                              setState(() {
                                _selectedIntent = UserIntent.personal;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // GUARDIAN
                          IntentCard(
                            title: "I want to protect someone",
                            description:
                                "Help keep your loved ones safe and connected",
                            icon: Icons.shield_outlined,
                            isSelected: _selectedIntent == UserIntent.guardian,
                            onTap: () {
                              setState(() {
                                _selectedIntent = UserIntent.guardian;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // DEPENDENT
                          IntentCard(
                            title: "I need protection",
                            description:
                                "Get support from trusted guardians when needed",
                            icon: Icons.favorite_outline,
                            isSelected: _selectedIntent == UserIntent.dependent,
                            onTap: () {
                              setState(() {
                                _selectedIntent = UserIntent.dependent;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: AnimatedBottomButton(
                      label: "Continue",
                      usePositioned: false,
                      isEnabled: _selectedIntent != null,
                      onPressed: () {
                        if (_selectedIntent != null) {
                          _navigateBasedOnIntent(_selectedIntent!);
                        }
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class PersonalOnboardingScreen extends StatelessWidget {
  const PersonalOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Personal Onboarding")),
      body: const Center(
        child: Text("Personal Onboarding Flow", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
