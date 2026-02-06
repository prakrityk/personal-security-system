// lib/features/home/family/widgets/profile_section_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/widgets/profile_picture_widget.dart';
import 'package:safety_app/core/providers/dependent_provider.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/services/dependent_profile_service.dart';

class ProfileSectionWidget extends ConsumerStatefulWidget {
  final DependentModel dependent;
  final VoidCallback onProfileUpdated;
  final VoidCallback onEditProfile;

  const ProfileSectionWidget({
    super.key,
    required this.dependent,
    required this.onProfileUpdated,
    required this.onEditProfile,
  });

  @override
  ConsumerState<ProfileSectionWidget> createState() =>
      _ProfileSectionWidgetState();
}

class _ProfileSectionWidgetState extends ConsumerState<ProfileSectionWidget> {
  final DependentProfileService _profileService = DependentProfileService();
  String? _currentProfilePicture;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _currentProfilePicture = widget.dependent.profilePicture;
  }

  @override
  void didUpdateWidget(ProfileSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dependent.profilePicture != widget.dependent.profilePicture) {
      setState(() {
        _currentProfilePicture = widget.dependent.profilePicture;
      });
    }
  }

  // ==================== PROFILE PICTURE METHODS ====================

  /// Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        Navigator.pop(context); // Close bottom sheet
        await _uploadProfilePicture(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to pick image: ${e.toString()}');
      }
    }
  }

  /// Show image picker options
  void _showImagePickerOptions() {
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
              Text('Update Profile Picture', style: AppTextStyles.h4),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              if (_currentProfilePicture != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.sosRed),
                  title: const Text(
                    'Remove Picture',
                    style: TextStyle(color: AppColors.sosRed),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Upload profile picture to backend
  Future<void> _uploadProfilePicture(File imageFile) async {
    setState(() => _isUploadingImage = true);

    try {
      print('📸 Uploading profile picture for ${widget.dependent.dependentId}');

      // The service returns the updated user model
      final updatedUser = await _profileService.uploadDependentProfilePicture(
        dependentId: widget.dependent.dependentId,
        imageFile: imageFile,
      );

      if (!mounted) return;

      setState(() {
        _currentProfilePicture = updatedUser.profilePicture;
        _isUploadingImage = false;
      });

      // Update the provider
      ref
          .read(dependentProvider.notifier)
          .updateDependentProfilePicture(
            widget.dependent.dependentId,
            updatedUser.profilePicture,
          );

      _showSuccessSnackbar('Profile picture updated successfully');
      widget.onProfileUpdated();

      print('✅ Profile picture uploaded: $_currentProfilePicture');
    } catch (e) {
      print('❌ Failed to upload profile picture: $e');

      if (!mounted) return;

      setState(() => _isUploadingImage = false);
      _showErrorSnackbar('Failed to upload profile picture');
    }
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text(
          'Are you sure you want to remove this profile picture?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProfilePicture();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.sosRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Delete profile picture from backend
  Future<void> _deleteProfilePicture() async {
    setState(() => _isUploadingImage = true);

    try {
      print('🗑️ Deleting profile picture for ${widget.dependent.dependentId}');

      await _profileService.deleteDependentProfilePicture(
        dependentId: widget.dependent.dependentId,
      );

      if (!mounted) return;

      setState(() {
        _currentProfilePicture = null;
        _isUploadingImage = false;
      });

      // Update the provider
      ref
          .read(dependentProvider.notifier)
          .removeDependentProfilePicture(widget.dependent.dependentId);

      _showSuccessSnackbar('Profile picture removed successfully');
      widget.onProfileUpdated();

      print('✅ Profile picture deleted');
    } catch (e) {
      print('❌ Failed to delete profile picture: $e');

      if (!mounted) return;

      setState(() => _isUploadingImage = false);
      _showErrorSnackbar('Failed to remove profile picture');
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

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
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
        children: [
          // Profile Picture - consistent for both primary and collaborator
          Stack(
            children: [
              ProfilePictureWidget(
                profilePicturePath: _currentProfilePicture,
                fullName: widget.dependent.dependentName,
                radius: 60,
                showBorder: true,
                borderColor: widget.dependent.isPrimaryGuardian
                    ? AppColors.primaryGreen
                    : Colors.blue,
                borderWidth: 3,
              ),
              // Edit button only for primary guardians
              if (widget.dependent.isPrimaryGuardian)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploadingImage ? null : _showImagePickerOptions,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          width: 3,
                        ),
                      ),
                      child: _isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            widget.dependent.dependentName,
            style: AppTextStyles.h3.copyWith(
              color: isDark
                  ? AppColors.darkOnBackground
                  : AppColors.lightOnBackground,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.dependent.isPrimaryGuardian
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              // mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.dependent.isPrimaryGuardian
                      ? Icons.admin_panel_settings
                      : Icons.supervisor_account,
                  size: 16,
                  color: widget.dependent.isPrimaryGuardian
                      ? AppColors.primaryGreen
                      : Colors.blue,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.dependent.isPrimaryGuardian
                      ? 'Primary Guardian'
                      : 'Collaborator',
                  style: AppTextStyles.caption.copyWith(
                    color: widget.dependent.isPrimaryGuardian
                        ? AppColors.primaryGreen
                        : Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (widget.dependent.isPrimaryGuardian) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onEditProfile,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
