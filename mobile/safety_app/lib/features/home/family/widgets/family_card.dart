// lib/features/home/family/widgets/family_card.dart

import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/widgets/profile_picture_widget.dart';

class FamilyCard extends StatelessWidget {
  final String name;
  final String role;
  final bool isPrimary;
  final String guardianType;
  final String? profilePicture;
  final VoidCallback onTap;

  const FamilyCard({
    super.key,
    required this.name,
    required this.role,
    this.isPrimary = true,
    this.guardianType = 'primary',
    this.profilePicture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollaborator = guardianType == 'collaborator';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with status indicator
            // Stack(
            //   alignment: Alignment.bottomRight,
            //   children: [
            //     CircleAvatar(
            //       radius: 28,
            //       backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
            //       child: Icon(
            //         Icons.person,
            //         size: 32,
            //         color: isDark
            //             ? AppColors.darkAccentGreen1
            //             : AppColors.primaryGreen,
            //       ),
            //     ),
            //     // Online/Safe status indicator
            //     Container(
            //       width: 14,
            //       height: 14,
            //       decoration: BoxDecoration(
            //         color: Colors.green,
            //         shape: BoxShape.circle,
            //         border: Border.all(
            //           color: isDark
            //               ? AppColors.darkSurface
            //               : AppColors.lightSurface,
            //           width: 2,
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            ProfilePictureWidget(
              profilePicturePath: profilePicture,
              fullName: name,
              radius: 32,
              showBorder: true,
              borderColor: isPrimary
                  ? AppColors.primaryGreen
                  : Colors.blue.shade600,
              borderWidth: 2,
              backgroundColor: isPrimary
                  ? AppColors.primaryGreen.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.2),
            ),
            const SizedBox(height: 10),

            // Name
            Text(
              name,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            // Role
            Text(
              role.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Guardian type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isCollaborator
                    ? Colors.blue.withOpacity(0.1)
                    : AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCollaborator
                      ? Colors.blue.withOpacity(0.3)
                      : AppColors.primaryGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCollaborator ? Icons.groups : Icons.admin_panel_settings,
                    size: 10,
                    color: isCollaborator
                        ? Colors.blue
                        : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCollaborator ? 'COLLAB' : 'PRIMARY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isCollaborator
                          ? Colors.blue
                          : AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 3),

            // Safe status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 10, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Safe',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
