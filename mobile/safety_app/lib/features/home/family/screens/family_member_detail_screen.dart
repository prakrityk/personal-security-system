// lib/features/home/family/screens/family_member_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/providers/dependent_provider.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/features/home/family/widgets/emergency_contatcs_section.dart';
import 'package:safety_app/features/home/family/widgets/profile_section_widget.dart';
import 'package:safety_app/features/home/family/widgets/safety_settings_section_widget.dart';
import 'package:safety_app/features/home/family/widgets/guardians_section_widget.dart';
import 'package:safety_app/models/dependent_model.dart';

class FamilyMemberDetailScreen extends ConsumerStatefulWidget {
  final DependentModel dependent;

  const FamilyMemberDetailScreen({super.key, required this.dependent});

  @override
  ConsumerState<FamilyMemberDetailScreen> createState() =>
      _FamilyMemberDetailScreenState();
}

class _FamilyMemberDetailScreenState
    extends ConsumerState<FamilyMemberDetailScreen> {
  @override
  void initState() {
    super.initState();
    _logAccessLevel();
  }

  void _logAccessLevel() {
    print('═══════════════════════════════════════════════════');
    print('📋 DEPENDENT DETAIL SCREEN INITIALIZED');
    print('═══════════════════════════════════════════════════');
    print('Dependent: ${widget.dependent.dependentName}');
    print('Dependent ID: ${widget.dependent.dependentId}');
    print('Relationship ID: ${widget.dependent.id}');
    print('───────────────────────────────────────────────────');
    print('📊 Backend Values:');
    print('   guardian_type: "${widget.dependent.guardianType}"');
    print('   is_primary: ${widget.dependent.isPrimary}');
    print('───────────────────────────────────────────────────');
    print('🎯 Computed Properties:');
    print('   isPrimaryGuardian: ${widget.dependent.isPrimaryGuardian}');
    print('   isCollaborator: ${widget.dependent.isCollaborator}');
    print('───────────────────────────────────────────────────');
    if (widget.dependent.isPrimaryGuardian) {
      print('✅ ACCESS LEVEL: PRIMARY GUARDIAN (Full Control)');
      print('   ✓ Can edit profile');
      print('   ✓ Can toggle safety settings');
      print('   ✓ Can manage emergency contacts');
      print('   ✓ Can invite/remove collaborators');
    } else {
      print('🔒 ACCESS LEVEL: COLLABORATOR (View Only)');
      print('   ✓ Can view profile');
      print('   ✓ Can view safety settings (read-only)');
      print('   ✓ Can view emergency contacts (read-only)');
      print('   ✓ Can view guardians list (read-only)');
      print('   ✗ Cannot edit anything');
      print('   ✗ Cannot manage collaborators');
    }
    print('═══════════════════════════════════════════════════');
  }

  void _editProfile() {
    print(
      '🔍 Navigating to profile editor - isPrimary: ${widget.dependent.isPrimaryGuardian}',
    );

    context.push(
      '/dependent-profile-editor',
      extra: {
        'dependentId': widget.dependent.dependentId,
        'dependentName': widget.dependent.dependentName,
        'isPrimaryGuardian': widget.dependent.isPrimaryGuardian,
      },
    );
  }

  void _navigateToEmergencyContacts() {
    print(
      '🔍 Navigating to emergency contacts - isPrimary: ${widget.dependent.isPrimaryGuardian}',
    );

    context.push(
      '/dependent-emergency-contacts',
      extra: {
        'dependentId': widget.dependent.dependentId,
        'dependentName': widget.dependent.dependentName,
        'isPrimaryGuardian': widget.dependent.isPrimaryGuardian,
      },
    );
  }

  void _refreshDependentData() {
    // Refresh the dependent data from provider
    ref.invalidate(dependentProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(widget.dependent.dependentName),
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        foregroundColor: isDark
            ? AppColors.darkOnBackground
            : AppColors.lightOnBackground,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshDependentData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                ProfileSectionWidget(
                  dependent: widget.dependent,
                  onProfileUpdated: _refreshDependentData,
                  onEditProfile: _editProfile,
                ),

                const SizedBox(height: 16),

                // Safety Settings Section
                SafetySettingsSectionWidget(dependent: widget.dependent),

                const SizedBox(height: 16),

                // Emergency Contacts Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.sosRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.contact_emergency,
                                    color: AppColors.sosRed,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text(
                                    'Emergency Contacts',
                                    style: AppTextStyles.h4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!widget.dependent.isPrimaryGuardian)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.visibility,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View Only',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.orange,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      EmergencyContactsSection.dependent(
                        dependentId: widget.dependent.dependentId,
                        dependentName: widget.dependent.dependentName,
                        isPrimaryGuardian: widget.dependent.isPrimaryGuardian,
                        compactMode: true,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _navigateToEmergencyContacts,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkDivider
                                  : AppColors.lightDivider,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('View All Emergency Contacts'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Guardians/Collaborators Section
                GuardiansSectionWidget(
                  dependent: widget.dependent,
                  onGuardiansChanged: _refreshDependentData,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
