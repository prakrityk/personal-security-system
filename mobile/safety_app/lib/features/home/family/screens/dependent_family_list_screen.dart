// ===================================================================
// UPDATED: dependent_family_list_screen.dart - With Profile Pictures
// ===================================================================
// lib/features/home/family/screens/dependent_family_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/dependent_guardian_provider.dart';
import 'package:safety_app/features/home/widgets/home_section_header.dart';
import 'package:safety_app/models/guardian_model.dart';
import 'package:safety_app/core/widgets/profile_picture_widget.dart'; // ✅ Import

class DependentFamilyListScreen extends ConsumerWidget {
  const DependentFamilyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final guardiansAsync = ref.watch(myGuardiansProvider);

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myGuardiansProvider);
          },
          color: AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeSectionHeader(
                  icon: Icons.people,
                  title: 'My Guardians',
                  subtitle: 'People who help keep you safe',
                ),
                const SizedBox(height: 24),
                guardiansAsync.when(
                  data: (guardians) {
                    if (guardians.isEmpty) {
                      return _buildEmptyState(context, isDark);
                    }
                    return _buildGuardiansList(context, guardians, isDark);
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  error: (error, stack) =>
                      _buildErrorState(context, isDark, error.toString(), ref),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuardiansList(
    BuildContext context,
    List<GuardianModel> guardians,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'These are the people monitoring your safety',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 16) / 2;
            final aspectRatio = cardWidth / 200;

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: aspectRatio,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: guardians.length,
              itemBuilder: (context, index) {
                final guardian = guardians[index];
                return _buildGuardianCard(context, guardian, isDark);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildGuardianCard(
    BuildContext context,
    GuardianModel guardian,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: guardian.isPrimary
              ? [
                  AppColors.primaryGreen.withOpacity(0.1),
                  AppColors.accentGreen1.withOpacity(0.1),
                ]
              : [
                  Colors.blue.shade50.withOpacity(isDark ? 0.1 : 1),
                  Colors.blue.shade100.withOpacity(isDark ? 0.1 : 1),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: guardian.isPrimary
              ? AppColors.primaryGreen.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showGuardianDetails(context, guardian, isDark);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ UPDATED: Use ProfilePictureWidget
                ProfilePictureWidget(
                  profilePicturePath: guardian.profilePicture,
                  fullName: guardian.guardianName,
                  radius: 30,
                  showBorder: true,
                  borderColor: guardian.isPrimary
                      ? AppColors.primaryGreen
                      : Colors.blue.shade600,
                  borderWidth: 2,
                  backgroundColor: guardian.isPrimary
                      ? AppColors.primaryGreen.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                ),
                const SizedBox(height: 12),

                // Name
                Text(
                  guardian.guardianName,
                  style: AppTextStyles.h4.copyWith(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: guardian.isPrimary
                        ? AppColors.primaryGreen.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    guardian.isPrimary ? 'Primary' : 'Collaborator',
                    style: AppTextStyles.caption.copyWith(
                      color: guardian.isPrimary
                          ? AppColors.primaryGreen
                          : Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),

                // Contact info
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        guardian.phoneNumber,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuardianDetails(
    BuildContext context,
    GuardianModel guardian,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ UPDATED: Profile picture in detail sheet
              ProfilePictureWidget(
                profilePicturePath: guardian.profilePicture,
                fullName: guardian.guardianName,
                radius: 50,
                showBorder: true,
                borderWidth: 3,
              ),
              const SizedBox(height: 16),

              Text(
                guardian.guardianName,
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: guardian.isPrimary
                      ? AppColors.primaryGreen.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  guardian.isPrimary ? 'Primary Guardian' : 'Collaborator',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: guardian.isPrimary
                        ? AppColors.primaryGreen
                        : Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Contact Information
              _buildDetailRow(
                Icons.phone,
                'Phone',
                guardian.phoneNumber,
                isDark,
              ),
              // const SizedBox(height: 12),
              // _buildDetailRow(Icons.email, 'Email', guardian.email, isDark),
              const SizedBox(height: 24),

              // Emergency Call Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement call functionality
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Guardian'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
              ),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen.withOpacity(0.1),
                    AppColors.accentGreen1.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 80,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Guardians Yet',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You don\'t have any guardians assigned yet. Please contact your family member to add you.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    bool isDark,
    String error,
    WidgetRef ref,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load guardians',
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(myGuardiansProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
