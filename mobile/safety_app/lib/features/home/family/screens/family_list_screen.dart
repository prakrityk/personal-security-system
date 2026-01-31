// ===================================================================
// UPDATED: family_list_screen.dart - With Profile Pictures
// ===================================================================
// lib/features/home/family/screens/family_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/features/home/widgets/home_section_header.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/services/guardian_service.dart';
import '../widgets/family_card.dart';

final myDependentsProvider = FutureProvider<List<DependentModel>>((ref) async {
  final guardianService = GuardianService();
  return guardianService.getMyDependents();
});

class FamilyListScreen extends ConsumerWidget {
  const FamilyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dependentsAsync = ref.watch(myDependentsProvider);

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myDependentsProvider);
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
                  title: 'My Family',
                  subtitle: 'Manage your family members',
                ),
                const SizedBox(height: 24),
                dependentsAsync.when(
                  data: (dependents) {
                    if (dependents.isEmpty) {
                      return _buildEmptyState(context, isDark);
                    }
                    return _buildDependentsList(context, dependents);
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

  Widget _buildDependentsList(
    BuildContext context,
    List<DependentModel> dependents,
  ) {
    return Column(
      children: [
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
              itemCount: dependents.length,
              itemBuilder: (context, index) {
                final dependent = dependents[index];

                // ✅ UPDATED: Pass profile picture to FamilyCard
                return FamilyCard(
                  name: dependent.dependentName,
                  role: dependent.relationDisplay,
                  isPrimary: dependent.isPrimaryGuardian,
                  guardianType: dependent.guardianType,
                  profilePicture: dependent.profilePicture, // ✅ Add this
                  onTap: () {
                    context.pushNamed(
                      'dependentDetailScreen',
                      extra: dependent,
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddFamilyOptions(context),
            icon: const Icon(Icons.add),
            label: const Text('Add/Join Family Member'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
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
            'No Family Members Yet',
            style: AppTextStyles.h3.copyWith(
              color: isDark
                  ? AppColors.darkOnBackground
                  : AppColors.lightOnBackground,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add your family members to start monitoring their safety',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/guardian-add-dependent');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add as Primary Guardian'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/collaborator-join');
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Join as Collaborator'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load family members',
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
                ref.invalidate(myDependentsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFamilyOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Add Family Member', style: AppTextStyles.h4),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primaryGreen,
                  ),
                ),
                title: const Text('Add as Primary Guardian'),
                subtitle: const Text('Create new dependent profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/guardian-add-dependent');
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_add, color: Colors.blue),
                ),
                title: const Text('Join as Collaborator'),
                subtitle: const Text('Use invitation code'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/collaborator-join');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
