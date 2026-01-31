// lib/features/home/sos/widgets/emergency_contacts_header.dart
// Modern header for emergency contacts section with role-based actions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/widgets/add_emergency_contact_dialog.dart';
import 'package:safety_app/core/providers/emergency_contact_provider.dart';
import 'package:safety_app/features/home/sos/widgets/import_contacts_button.dart';

class EmergencyContactsHeader extends ConsumerWidget {
  final bool canEdit;
  final bool isDependent;
  final int? dependentId;
  final String? dependentName;
  final bool showLockIcon;

  const EmergencyContactsHeader({
    super.key,
    required this.canEdit,
    this.isDependent = false,
    this.dependentId,
    this.dependentName,
    this.showLockIcon = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Description
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.sosRed.withOpacity(0.15),
                    AppColors.sosRed.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.sosRed.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.emergency,
                color: AppColors.sosRed,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // Title and subtitle - Flexible to prevent overflow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Emergency Contacts',
                          style: AppTextStyles.h4.copyWith(
                            color: isDark
                                ? AppColors.darkOnBackground
                                : AppColors.lightOnBackground,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showLockIcon) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'View only - Primary guardian manages',
                          child: Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getSubtitle(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Action Buttons (only for users who can edit, not dependents)
        if (canEdit && !isDependent) ...[
          const SizedBox(height: 20),
          _buildActionButtons(context, ref, isDark),
        ],
      ],
    );
  }

  String _getSubtitle() {
    if (isDependent) {
      return 'SOS will be sent to these contacts';
    } else if (dependentName != null) {
      return canEdit
          ? 'Manage $dependentName\'s emergency contacts'
          : 'View $dependentName\'s emergency contacts';
    } else {
      return 'Add contacts to notify in emergencies';
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use compact layout for narrow screens
        final isNarrow = constraints.maxWidth < 350;

        return Row(
          children: [
            // Add Contact Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddContactDialog(context, ref),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(isNarrow ? 'Add' : 'Add Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkAccentGreen1
                      : AppColors.primaryGreen,
                  foregroundColor: isDark
                      ? AppColors.darkBackground
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Import Contacts Button
            Expanded(
              child: ImportContactsButton(
                isForDependent: dependentId != null,
                dependentId: dependentId,
                onImportComplete: () {
                  if (dependentId != null) {
                    ref
                        .read(emergencyContactNotifierProvider.notifier)
                        .loadDependentContacts(dependentId!);
                  } else {
                    ref
                        .read(emergencyContactNotifierProvider.notifier)
                        .loadMyContacts();
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddContactDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showAddEmergencyContactDialog(
      context: context,
      dependentId: dependentId,
    );

    if (result == true) {
      // Contact was added, refresh will happen automatically via provider
      if (dependentId != null) {
        ref
            .read(emergencyContactNotifierProvider.notifier)
            .loadDependentContacts(dependentId!);
      } else {
        ref.read(emergencyContactNotifierProvider.notifier).loadMyContacts();
      }
    }
  }
}
