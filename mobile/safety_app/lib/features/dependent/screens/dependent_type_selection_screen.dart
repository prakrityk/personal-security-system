// ========================================
// IMPROVED DEPENDENT_TYPE_SELECTION_SCREEN.DART
// ========================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/models/role_info.dart';
import 'package:safety_app/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/intent_card.dart';

enum DependentType { child, elderly }

class DependentTypeSelectionScreen extends StatefulWidget {
  const DependentTypeSelectionScreen({super.key});

  @override
  State<DependentTypeSelectionScreen> createState() =>
      _DependentTypeSelectionScreenState();
}

class _DependentTypeSelectionScreenState
    extends State<DependentTypeSelectionScreen> {
  final AuthService _authService = AuthService();

  List<RoleInfo> _roles = [];
  DependentType? _selectedType;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _authService.fetchRoles();
      if (!mounted) return;

      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load roles');
      }
    }
  }

  RoleInfo? _getRoleForType(DependentType type) {
    try {
      switch (type) {
        case DependentType.child:
          return _roles.firstWhere((r) => r.roleName == "child");
        case DependentType.elderly:
          return _roles.firstWhere((r) => r.roleName == "elderly");
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedType == null) return;

    setState(() => _isSubmitting = true);

    try {
      final role = _getRoleForType(_selectedType!);

      if (role == null) {
        throw Exception('Role not found for selected type');
      }

      await _authService.selectRole(role.id);

      if (!mounted) return;

      _showSuccess('Role assigned successfully!');
      context.push('/scan-qr', extra: _selectedType);
    } catch (e) {
      if (!mounted) return;

      _showError('Failed to assign role: ${e.toString()}');
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
            : Column(
                children: [
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
                                    color: AppColors.primaryGreen.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.how_to_reg,
                                    color: AppColors.primaryGreen,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Who needs protection?",
                                  style: AppTextStyles.h2,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Choose the option that best describes you",
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

                          IntentCard(
                            title: "I am a child",
                            description: "Protected by parents or guardians",
                            icon: Icons.child_care,
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
                            icon: Icons.elderly,
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

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: AnimatedBottomButton(
                      label: _isSubmitting ? "Assigning role..." : "Continue",
                      usePositioned: false,
                      isEnabled: _selectedType != null && !_isSubmitting,
                      onPressed: _handleContinue,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
