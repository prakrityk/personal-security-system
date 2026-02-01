// ===================================================================
// UPDATED: profile_edit_screen.dart with Profile Picture Upload
// ===================================================================
// lib/features/account/screens/profile_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/auth_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  bool _isLoading = false;
  bool _hasChanges = false;

  // Profile picture state
  File? _selectedImage;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _nameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final user = ref.read(authStateProvider).value;
    final hasChanges =
        _nameController.text != (user?.fullName ?? '') ||
        _selectedImage != null;

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ==================== IMAGE PICKER ====================

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
        setState(() {
          _selectedImage = File(pickedFile.path);
          _hasChanges = true;
        });

        // Close bottom sheet
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to pick image: ${e.toString()}');
      }
    }
  }

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
              Text('Choose Profile Picture', style: AppTextStyles.h4),
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
              if (_selectedImage != null ||
                  ref.read(authStateProvider).value?.profilePicture != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.sosRed),
                  title: const Text(
                    'Remove Picture',
                    style: TextStyle(color: AppColors.sosRed),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                      _hasChanges = true;
                    });
                    Navigator.pop(context);
                    _deleteProfilePicture();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UPDATE PROFILE ====================

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    print('');
    print('═══════════════════════════════════════════════');
    print('🚀 STARTING PROFILE UPDATE');
    print('═══════════════════════════════════════════════');

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final authNotifier = ref.read(authStateProvider.notifier);

      // Step 1: Upload profile picture if selected
      if (_selectedImage != null) {
        print('');
        print('📸 Step 1: Uploading profile picture...');
        setState(() => _isUploadingImage = true);

        final updatedUser = await authService.uploadProfilePicture(
          _selectedImage!,
        );

        setState(() => _isUploadingImage = false);
        print('✅ Profile picture uploaded');
        print('   Picture path: ${updatedUser.profilePicture}');

        // ✅ Immediately update provider state
        print('   🔄 Updating provider state...');
        authNotifier.updateUserData(updatedUser);
        print('   ✅ Provider updated with new picture');
      }

      // Step 2: Update name if changed
      print('');
      print('✏️ Step 2: Checking if name needs update...');

      final user = ref.read(authStateProvider).value;
      final newName = _nameController.text.trim();

      print('   Current name in provider: "${user?.fullName}"');
      print('   New name from input: "$newName"');

      if (newName != user?.fullName) {
        print('   ⚠️ Names are different - updating...');
        print('');

        final updatedUser = await authService.updateProfile(fullName: newName);

        print('');
        print('✅ Name updated successfully on backend');
        print('   Backend returned user:');
        print('      - ID: ${updatedUser.id}');
        print('      - Name: "${updatedUser.fullName}"');
        print('      - Email: ${updatedUser.email}');

        // ✅ CRITICAL: Immediately update provider state with returned user
        print('');
        print('   🔄 Updating provider state with new name...');
        authNotifier.updateUserData(updatedUser);

        print('   ✅ Provider state updated');

        // Verify the update
        final verifyUser = ref.read(authStateProvider).value;
        print('   🔍 Verification - Provider now has:');
        print('      - Name: "${verifyUser?.fullName}"');
        print('      - Email: ${verifyUser?.email}');
      } else {
        print('   ℹ️ Names are the same - skipping update');
      }

      // Step 3: Force refresh from API to ensure everything is in sync
      print('');
      print('🔄 Step 3: Forcing user refresh from API...');
      await authNotifier.refreshUser();

      // Final verification
      final finalUser = ref.read(authStateProvider).value;
      print('');
      print('✅ Final verification - Provider state:');
      print('   - Name: "${finalUser?.fullName}"');
      print('   - Email: ${finalUser?.email}');
      print('   - Picture: ${finalUser?.profilePicture}');

      print('');
      print('═══════════════════════════════════════════════');
      print('✅ PROFILE UPDATE COMPLETE');
      print('═══════════════════════════════════════════════');
      print('');

      if (mounted) {
        _showSuccessSnackBar(
          'Profile Updated!',
          'Your changes have been saved successfully',
        );

        // Reset state
        setState(() {
          _selectedImage = null;
          _hasChanges = false;
        });

        // Go back after short delay to allow user to see success message
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.pop();
      }
    } catch (e, stackTrace) {
      print('');
      print('═══════════════════════════════════════════════');
      print('❌ PROFILE UPDATE FAILED');
      print('═══════════════════════════════════════════════');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('');

      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _deleteProfilePicture() async {
    try {
      setState(() => _isUploadingImage = true);

      final authService = ref.read(authServiceProvider);
      final authNotifier = ref.read(authStateProvider.notifier);

      await authService.deleteProfilePicture();

      // Refresh user data
      await authNotifier.refreshUser();

      if (mounted) {
        _showSuccessSnackBar(
          'Picture Removed',
          'Profile picture deleted successfully',
        );
      }
    } catch (e) {
      print('❌ Error deleting profile picture: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to delete picture: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  // ==================== UI BUILDERS ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              _showUnsavedChangesDialog();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _updateProfile,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              _buildProfilePictureSection(user, isDark),

              const SizedBox(height: 32),

              // Loading indicator
              if (_isUploadingImage)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Uploading image...'),
                      ],
                    ),
                  ),
                ),

              // Name Field
              _buildNameField(isDark),

              const SizedBox(height: 20),

              // Email Field (Read-only)
              _buildReadOnlyField(
                label: 'Email',
                value: user?.email ?? 'Not set',
                icon: Icons.email,
                lockMessage: 'Email cannot be changed for security reasons',
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // Phone Field (Read-only)
              _buildReadOnlyField(
                label: 'Phone Number',
                value: user?.phoneNumber ?? 'Not set',
                icon: Icons.phone,
                lockMessage: 'Phone number cannot be changed',
                isDark: isDark,
              ),

              const SizedBox(height: 32),

              // Save Button
              _buildSaveButton(isDark),

              if (!_hasChanges)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Text(
                      'No changes to save',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkHint
                            : AppColors.lightHint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection(dynamic user, bool isDark) {
    return Center(
      child: GestureDetector(
        onTap: _showImagePickerOptions,
        child: Stack(
          children: [
            // Profile picture circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkAccentGreen1
                      : AppColors.primaryGreen,
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 57,
                backgroundColor: AppColors.primaryGreen.withOpacity(0.15),
                backgroundImage: _getProfileImage(user),
                child: _getProfileImage(user) == null
                    ? Text(
                        user?.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkAccentGreen1
                              : AppColors.primaryGreen,
                        ),
                      )
                    : null,
              ),
            ),

            // Camera icon overlay
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkAccentGreen1
                      : AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage(dynamic user) {
    // Priority: Selected image > User's profile picture
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    if (user?.profilePicture != null && user!.profilePicture!.isNotEmpty) {
      // Remove '/api' from base URL since static files are served at /uploads
      final baseUrl = ref.read(authServiceProvider).baseUrl;
      final cleanBaseUrl = baseUrl.replaceAll('/api', '');
      final imageUrl = '$cleanBaseUrl${user.profilePicture}';
      return NetworkImage(imageUrl);
    }

    return null;
  }

  Widget _buildNameField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Name',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: const Icon(Icons.person),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required String lockMessage,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withOpacity(0.5)
                : AppColors.lightSurface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline,
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
                size: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lockMessage,
          style: AppTextStyles.caption.copyWith(
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_isLoading || !_hasChanges) ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? AppColors.darkAccentGreen1
              : AppColors.primaryGreen,
          foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // ==================== DIALOGS & SNACKBARS ====================

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.sosRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
