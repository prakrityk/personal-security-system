// lib/features/home/family/widgets/guardians_section_widget.dart

import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/widgets/profile_picture_widget.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/services/collaborator_service.dart';
import 'package:safety_app/features/home/family/widgets/collaborator_invitation_dialog.dart';

class GuardiansSectionWidget extends StatefulWidget {
  final DependentModel dependent;
  final VoidCallback onGuardiansChanged;

  const GuardiansSectionWidget({
    super.key,
    required this.dependent,
    required this.onGuardiansChanged,
  });

  @override
  State<GuardiansSectionWidget> createState() => _GuardiansSectionWidgetState();
}

class _GuardiansSectionWidgetState extends State<GuardiansSectionWidget> {
  final CollaboratorService _collaboratorService = CollaboratorService();
  List<Map<String, dynamic>> _allGuardians = [];
  bool _isLoadingGuardians = false;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    setState(() => _isLoadingGuardians = true);
    try {
      print(
        '🔄 Loading guardians for dependent ${widget.dependent.dependentId}',
      );
      print(
        '   Current user is primary: ${widget.dependent.isPrimaryGuardian}',
      );

      // ✅ SIMPLIFIED: Just one call to get everything!
      final allGuardians = await _collaboratorService.getAllGuardians(
        widget.dependent.dependentId,
      );

      // Sort: primary first, then collaborators
      allGuardians.sort((a, b) {
        final aIsPrimary = a['is_primary'] == true;
        final bIsPrimary = b['is_primary'] == true;
        if (aIsPrimary && !bIsPrimary) return -1;
        if (!aIsPrimary && bIsPrimary) return 1;
        return 0;
      });

      print('📊 Total guardians to display: ${allGuardians.length}');

      if (mounted) {
        setState(() {
          _allGuardians = allGuardians;
          _isLoadingGuardians = false;
        });
      }
    } catch (e) {
      print('❌ Error loading guardians: $e');
      if (mounted) {
        setState(() => _isLoadingGuardians = false);
      }
    }
  }

  void _inviteGuardian() async {
    await showCollaboratorInvitationDialog(
      context: context,
      dependentId: widget.dependent.dependentId,
      dependentName: widget.dependent.dependentName,
    );

    if (mounted) {
      await _loadGuardians();
      widget.onGuardiansChanged();
    }
  }

  void _showRemoveGuardianDialog(Map<String, dynamic> guardian) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Guardian'),
        content: Text(
          'Are you sure you want to remove ${guardian['guardian_name']} as a guardian?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeGuardian(guardian['relationship_id']);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.sosRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeGuardian(int relationshipId) async {
    try {
      final success = await _collaboratorService.revokeCollaborator(
        relationshipId,
      );

      if (success && mounted) {
        _showSuccessSnackbar('Guardian removed successfully');
        await _loadGuardians();
        widget.onGuardiansChanged();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to remove guardian');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.sosRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrimary = widget.dependent.isPrimaryGuardian;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.group,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Guardians',
                        style: AppTextStyles.h4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Primary guardian can add more guardians
              if (isPrimary)
                IconButton(
                  onPressed: _inviteGuardian,
                  icon: const Icon(Icons.person_add),
                  color: AppColors.primaryGreen,
                  tooltip: 'Add Guardian',
                )
              // Collaborator sees view-only badge
              else
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

          const SizedBox(height: 16),

          // Guardians list
          if (_isLoadingGuardians)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else if (_allGuardians.isEmpty)
            _buildEmptyState(isDark)
          else
            ..._allGuardians.map((guardian) {
              return _buildGuardianCard(guardian, isDark, isPrimary);
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_add,
            size: 48,
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
          const SizedBox(height: 8),
          Text('No Guardians', style: AppTextStyles.labelMedium),
          const SizedBox(height: 4),
          Text(
            'Add guardians to help monitor ${widget.dependent.dependentName}',
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianCard(
    Map<String, dynamic> guardian,
    bool isDark,
    bool currentUserIsPrimary,
  ) {
    final isGuardianPrimary = guardian['is_primary'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGuardianPrimary
            ? AppColors.primaryGreen.withOpacity(isDark ? 0.1 : 0.05)
            : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGuardianPrimary
              ? AppColors.primaryGreen.withOpacity(0.3)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          width: isGuardianPrimary ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Profile picture
          ProfilePictureWidget(
            profilePicturePath: guardian['profile_picture'],
            fullName: guardian['guardian_name'] ?? 'Unknown',
            radius: 24,
            showBorder: true,
            borderColor: isGuardianPrimary
                ? AppColors.primaryGreen
                : Colors.blue,
            borderWidth: 2,
            backgroundColor: isGuardianPrimary
                ? AppColors.primaryGreen.withOpacity(0.2)
                : Colors.blue.withOpacity(0.2),
          ),
          const SizedBox(width: 12),

          // Guardian info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        guardian['guardian_name'] ?? 'Unknown',
                        style: AppTextStyles.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isGuardianPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRIMARY',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        guardian['guardian_email'] ?? '',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
             ],
                ),
              ],
            ),
          ),

          // Remove button (only for primary user removing collaborators)
          if (currentUserIsPrimary && !isGuardianPrimary)
            IconButton(
              onPressed: () => _showRemoveGuardianDialog(guardian),
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.red,
              tooltip: 'Remove Guardian',
            ),
        ],
      ),
    );
  }
}
