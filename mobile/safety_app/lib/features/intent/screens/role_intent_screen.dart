import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/features/dependent/screens/dependent_type_selection_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_setup_choice_screen.dart';
import 'package:safety_app/models/role_info.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/intent_card.dart';

enum UserIntent { personal, guardian, dependent }

class RoleIntentScreen extends StatefulWidget {
  const RoleIntentScreen({super.key});

  @override
  State<RoleIntentScreen> createState() => _RoleIntentScreenState();
}

class _RoleIntentScreenState extends State<RoleIntentScreen> {
  final AuthService _authService = AuthService();

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
      final user = await _authService.getCurrentUser();
      final roles = await _authService.fetchRoles();

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

  RoleInfo _getRoleForIntent(UserIntent intent) {
    switch (intent) {
      case UserIntent.personal:
        return _roles.firstWhere((r) => r.roleName == "global_user");
      case UserIntent.guardian:
        return _roles.firstWhere((r) => r.roleName == "guardian");
      case UserIntent.dependent:
        return _roles.firstWhere((r) => r.roleName == "dependent");
    }
  }

  Future<void> _navigateBasedOnIntent(UserIntent intent) async {
    setState(() => _isLoading = true);

    try {
      final role = _getRoleForIntent(intent);

      // ✅ Assign role in backend
      await _authService.selectRole(role.id);

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

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to select role")));
      setState(() => _isLoading = false);
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
