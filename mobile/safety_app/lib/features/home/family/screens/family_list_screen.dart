import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import '../widgets/family_card.dart';

class FamilyListScreen extends StatelessWidget {
  const FamilyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // TODO: Replace with actual data
    final hasDependents = true; // Set to false to see empty state

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people,
                      color: AppColors.primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Family',
                          style: AppTextStyles.h3.copyWith(
                            color: isDark
                                ? AppColors.darkOnBackground
                                : AppColors.lightOnBackground,
                          ),
                        ),
                        Text(
                          'Manage your family members',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (hasDependents)
                // Grid of Family Members
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    FamilyCard(
                      name: 'John Doe',
                      role: 'child 1',
                      onTap: () {
                        // TODO: Navigate to family member detail
                      },
                    ),
                    FamilyCard(
                      name: 'Alice',
                      role: 'child 2',
                      onTap: () {
                        // TODO: Navigate to family member detail
                      },
                    ),
                    FamilyCard(
                      name: 'Bob',
                      role: 'Elderly',
                      onTap: () {
                        // TODO: Navigate to family member detail
                      },
                    ),
                  ],
                )
              else
                // Empty State
                _buildEmptyState(context, isDark),
              
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 80,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Family Members Yet',
            style: AppTextStyles.h4.copyWith(
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
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to add family member screen
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Dependent'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}