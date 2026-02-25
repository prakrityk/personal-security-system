import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/models/role_info.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/intent_card.dart';
import 'package:safety_app/routes/app_router.dart';

enum UserIntent { personal, guardian, dependent }

class RoleIntentScreen extends StatefulWidget {
  const RoleIntentScreen({super.key});

  @override
  State<RoleIntentScreen> createState() => _RoleIntentScreenState();
}

class _RoleIntentScreenState extends State<RoleIntentScreen> {
  final AuthApiService _authApiService = AuthApiService();

  List<RoleInfo> _roles = [];
  UserIntent? _selectedIntent;
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// Load user + roles together
  Future<void> _initData() async {
    try {
      final user = await _authApiService.getCurrentUser();
      final roles = await _authApiService.fetchRoles();

      if (!mounted) return;

      setState(() {
        _currentUser = user;
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Get role for a specific intent
  RoleInfo? _getRoleForIntent(UserIntent intent) {
    try {
      switch (intent) {
        case UserIntent.personal:
          return _roles.firstWhere((r) => r.roleName == "global_user");
        case UserIntent.guardian:
          return _roles.firstWhere((r) => r.roleName == "guardian");
        case UserIntent.dependent:
          // ❌ DON'T assign role here for dependent
          // User needs to choose child/elderly on next screen
          return null;
      }
    } catch (e) {
      print('Error finding role: $e');
      return null;
    }
  }

  Future<void> _navigateBasedOnIntent(UserIntent intent) async {
    // ✅ For dependent, just navigate without assigning role
    if (intent == UserIntent.dependent) {
      _navigateToNextScreen(intent);
      return;
    }

    // ✅ For personal and guardian, assign role first
    setState(() => _isLoading = true);

    try {
      final role = _getRoleForIntent(intent);

      if (role == null) {
        throw Exception('Role not found for selected intent');
      }

      // Assign role in backend
      await _authApiService.selectRole(role.id);

      if (!mounted) return;

      _navigateToNextScreen(intent);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select role: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  /// Navigate to appropriate screen based on intent
  // void _navigateToNextScreen(UserIntent intent) {
  //   switch (intent) {
  //     case UserIntent.personal:
  //       context.go('/personal-onboarding');
  //       break;
  //     case UserIntent.guardian:
  //       context.push('/guardian-setup');
  //       break;
  //     case UserIntent.dependent:
  //       // ✅ Navigate to dependent type selection
  //       // Role will be assigned there (child or elderly)
  //       context.push('/dependent-type-selection');
  //       break;
  //   }
  // }

void _navigateToNextScreen(UserIntent intent) {
  switch (intent) {
    case UserIntent.personal:
      context.go(AppRouter.personalOnboarding);
      break;
    case UserIntent.guardian:
      context.push(AppRouter.guardianSetup);
      break;
    case UserIntent.dependent:
      context.push(AppRouter.dependentTypeSelection);
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

                          IntentCard(
                            title: "Just for me",
                            description:
                                "Personal safety features for your own protection",
                            icon: Icons.person_outline,
                            isSelected: _selectedIntent == UserIntent.personal,
                            onTap: () => setState(
                              () => _selectedIntent = UserIntent.personal,
                            ),
                          ),
                          const SizedBox(height: 16),

                          IntentCard(
                            title: "I want to protect someone",
                            description:
                                "Help keep your loved ones safe and connected",
                            icon: Icons.shield_outlined,
                            isSelected: _selectedIntent == UserIntent.guardian,
                            onTap: () => setState(
                              () => _selectedIntent = UserIntent.guardian,
                            ),
                          ),
                          const SizedBox(height: 16),

                          IntentCard(
                            title: "I need protection",
                            description:
                                "Get support from trusted guardians when needed",
                            icon: Icons.favorite_outline,
                            isSelected: _selectedIntent == UserIntent.dependent,
                            onTap: () => setState(
                              () => _selectedIntent = UserIntent.dependent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: AnimatedBottomButton(
                      label: "Continue",
                      usePositioned: false,
                      isEnabled: _selectedIntent != null && !_isLoading,
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