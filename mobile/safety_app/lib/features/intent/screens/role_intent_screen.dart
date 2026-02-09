import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/models/role_info.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_api_service.dart';
import 'package:safety_app/services/biometric_service.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/intent_card.dart';
import 'package:safety_app/routes/app_router.dart';

enum UserIntent { personal, guardian, dependent }

class RoleIntentScreen extends ConsumerStatefulWidget {
  const RoleIntentScreen({super.key});

  @override
  ConsumerState<RoleIntentScreen> createState() => _RoleIntentScreenState();
}

class _RoleIntentScreenState extends ConsumerState<RoleIntentScreen> {
class _RoleIntentScreenState extends ConsumerState<RoleIntentScreen> {
  final AuthApiService _authApiService = AuthApiService();
  final BiometricService _biometricService = BiometricService();
  final SecureStorageService _secureStorage = SecureStorageService();

  List<RoleInfo> _roles = [];
  UserIntent? _selectedIntent;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// Load user + roles + biometric availability
  /// Load user + roles + biometric availability
  Future<void> _initData() async {
    try {
      final user = await _authApiService.getCurrentUser();
      final roles = await _authApiService.fetchRoles();
      final bioAvailable = await _biometricService.isBiometricAvailable();

      if (!mounted) return;

      setState(() {
        _currentUser = user;
        _roles = roles;
        _isBiometricAvailable = bioAvailable;
        _isLoading = false;
      });

      print('✅ Biometric available: $bioAvailable');
    } catch (e) {
      print('❌ Error loading data: $e');
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
          // ❌ DON'T assign role here for dependent
          // User needs to choose child/elderly on next screen
          return null;
      }
    } catch (e) {
      print('Error finding role: $e');
      print('Error finding role: $e');
      return null;
    }
  }

  /// Handle role selection and navigation based on intent
  /// Handle role selection and navigation based on intent
  Future<void> _navigateBasedOnIntent(UserIntent intent) async {
    setState(() => _isLoading = true);

    try {
      // ========================================================================
      // DEPENDENT FLOW - Navigate without assigning role
      // ========================================================================
      // ========================================================================
      // DEPENDENT FLOW - Navigate without assigning role
      // ========================================================================
      if (intent == UserIntent.dependent) {
        print('👶 Dependent flow - navigating to type selection');
        setState(() => _isLoading = false);
        context.go(AppRouter.dependentTypeSelection);
        context.go(AppRouter.dependentTypeSelection);
        return;
      }

      // ========================================================================
      // PERSONAL & GUARDIAN - Get role first
      // ========================================================================
      // ========================================================================
      // PERSONAL & GUARDIAN - Get role first
      // ========================================================================
      final role = _getRoleForIntent(intent);


      if (role == null) {
        throw Exception('Role not found for selected intent');
        throw Exception('Role not found for selected intent');
      }

      print('📋 Selected role: ${role.roleName} (ID: ${role.id})');
      print('📋 Selected role: ${role.roleName} (ID: ${role.id})');

      // ========================================================================
      // GUARDIAN FLOW - BIOMETRIC REQUIRED
      // ========================================================================
      if (intent == UserIntent.guardian) {
        print('🔐 Guardian role detected - initiating biometric flow');

        // Check if device supports biometric
        if (!_isBiometricAvailable) {
          _showDeviceNotSupportedDialog();
          setState(() => _isLoading = false);
          return;
        }

        // Step 1: Tell backend guardian role is selected
        // Step 1: Tell backend guardian role is selected
        print('📤 Step 1: Notifying backend of guardian role selection');
        final response = await _authApiService.selectRole(role.id);


        print('📥 Backend response: $response');

        // Check if biometric is required
        if (response['biometric_required'] == true) {
          print('🔐 Biometric required - showing setup dialog');


          // Step 2: Show biometric setup dialog and authenticate
          final biometricSuccess = await _showBiometricSetupDialog();


          if (biometricSuccess) {
            // Step 3: Enable biometric on backend
            print('📤 Step 3: Enabling biometric on backend');
            final updatedUser = await _authApiService.enableBiometric();

            // 🔥 CRITICAL: Save biometric flag to secure storage
            print('💾 Setting biometric enabled flag to TRUE');
            await _secureStorage.setBiometricEnabled(true);

            // 🔥 VERIFY it was saved
            final isEnabled = await _secureStorage.isBiometricEnabled();
            print('✅ Biometric flag verification: $isEnabled');

            print('✅ Biometric enabled and guardian role assigned');
            print('👤 Updated user: ${updatedUser.fullName}');
            print('🎭 Roles: ${updatedUser.roles.map((r) => r.roleName).join(", ")}');

            // Step 4: Navigate to guardian setup
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showSuccess('Guardian account activated with biometric security!');

            // Small delay to show success message
            await Future.delayed(const Duration(milliseconds: 500));
            if (!mounted) return;

            context.go(AppRouter.guardianSetup);
          } else {
            // Step 3: Enable biometric on backend
            print('📤 Step 3: Enabling biometric on backend');
            final updatedUser = await _authApiService.enableBiometric();

            // 🔥 CRITICAL: Save biometric flag to secure storage
            print('💾 Setting biometric enabled flag to TRUE');
            await _secureStorage.setBiometricEnabled(true);

            // 🔥 VERIFY it was saved
            final isEnabled = await _secureStorage.isBiometricEnabled();
            print('✅ Biometric flag verification: $isEnabled');

            print('✅ Biometric enabled and guardian role assigned');
            print('👤 Updated user: ${updatedUser.fullName}');
            print(
              '🎭 Roles: ${updatedUser.roles.map((r) => r.roleName).join(", ")}',
            );

            // Step 4: Navigate to guardian setup
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showSuccess('Guardian account activated with biometric security!');

            // Small delay to show success message
            await Future.delayed(const Duration(milliseconds: 500));
            if (!mounted) return;

            context.go(AppRouter.guardianSetup);
          } else {
            // User cancelled biometric setup
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showError('Biometric authentication is required for guardian accounts');

            _showError(
              'Biometric authentication is required for guardian accounts',
            );

            // Reset selection
            setState(() => _selectedIntent = null);
          }
        } else {
          // Shouldn't happen, but handle gracefully
          print('⚠️ Unexpected: Guardian role did not require biometric');
          setState(() => _isLoading = false);
          context.go(AppRouter.guardianSetup);
          context.go(AppRouter.guardianSetup);
        }
      }

      // ========================================================================
      // PERSONAL FLOW - Assign immediately
      // PERSONAL FLOW - Assign immediately
      // ========================================================================
      else if (intent == UserIntent.personal) {
        print('👤 Personal role - assigning immediately');


        final response = await _authApiService.selectRole(role.id);
        print('✅ Role assigned: $response');

        print('✅ Role assigned: $response');

        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSuccess('Personal account activated!');


        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        _navigateToNextScreen(intent);

        _navigateToNextScreen(intent);
      }
    } catch (e) {
      if (!mounted) return;

      print('❌ Error in role selection flow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select role: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
        _selectedIntent = null; // Reset selection on error
      });
    }
  }

  /// Navigate to appropriate screen based on intent
  void _navigateToNextScreen(UserIntent intent) {
    switch (intent) {
      case UserIntent.personal:
        // ✅ For personal users, go directly to home after role is assigned
        print('🚀 Navigating to home for personal user...');
        context.go(AppRouter.home);
        break;
      case UserIntent.guardian:
        // ✅ For guardians, go to setup screen
        print('🚀 Navigating to guardian setup...');
        context.go(AppRouter.guardianSetup);
        break;
      case UserIntent.dependent:
        // ✅ For dependents, go to type selection
        print('🚀 Navigating to dependent type selection...');
        context.go(AppRouter.dependentTypeSelection);
        break;
    }
  }

  }

  /// Show MANDATORY biometric setup dialog for guardians
  /// Returns true if biometric was successfully authenticated, false otherwise
  Future<bool> _showBiometricSetupDialog() async {
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false, // Can't dismiss by tapping outside
          builder: (dialogContext) => AlertDialog(
            title: const Text('Biometric Login Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.fingerprint,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(height: 16),
                Text(
                  'Secure Your Guardian Account',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Biometric authentication is required for guardian accounts to ensure the security and safety of your protected family members.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✅ Your fingerprint/face will be used only for login authentication and remains secure on your device.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                onPressed: () async {
                  // Authenticate with biometric
                  try {
                    print('🔐 Requesting biometric authentication...');

                    final authenticated = await _biometricService.authenticate(
                      reason: 'Verify your identity to enable guardian account',
                    );
          context: context,
          barrierDismissible: false, // Can't dismiss by tapping outside
          builder: (dialogContext) => AlertDialog(
            title: const Text('Biometric Login Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.fingerprint,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(height: 16),
                Text(
                  'Secure Your Guardian Account',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Biometric authentication is required for guardian accounts to ensure the security and safety of your protected family members.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✅ Your fingerprint/face will be used only for login authentication and remains secure on your device.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                ),
                onPressed: () async {
                  // Authenticate with biometric
                  try {
                    print('🔐 Requesting biometric authentication...');

                    final authenticated = await _biometricService.authenticate(
                      reason: 'Verify your identity to enable guardian account',
                    );

                    if (!mounted) return;
                    if (!mounted) return;

                    if (authenticated) {
                      print('✅ Biometric authentication successful');
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      print('❌ Biometric authentication failed or cancelled');
                      Navigator.of(dialogContext).pop(false);
                    }
                  } catch (e) {
                    print('❌ Biometric authentication error: $e');
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Biometric error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );

                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('Enable Biometric'),
              ),
            ],
          ),
        ) ??
        false; // Return false if dialog is dismissed
                    if (authenticated) {
                      print('✅ Biometric authentication successful');
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      print('❌ Biometric authentication failed or cancelled');
                      Navigator.of(dialogContext).pop(false);
                    }
                  } catch (e) {
                    print('❌ Biometric authentication error: $e');
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Biometric error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );

                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('Enable Biometric'),
              ),
            ],
          ),
        ) ??
        false; // Return false if dialog is dismissed
  }

  /// Show error dialog when device doesn't support biometric
  void _showDeviceNotSupportedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometric Not Supported'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_iphone, size: 40, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              'Your device does not support biometric authentication.',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Guardian accounts require biometric login for security.\n\nPlease use a device with fingerprint or face recognition.',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Return to role selection
              setState(() => _selectedIntent = null);
            },
            child: const Text('Back to Roles'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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

                          // Info Box for Guardians about biometric requirement
                          // Info Box for Guardians about biometric requirement
                          if (_selectedIntent == UserIntent.guardian) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                border: Border.all(
                                  color: AppColors.primaryGreen,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shield_sharp,
                                    color: AppColors.primaryGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Biometric login is required for guardian accounts',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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