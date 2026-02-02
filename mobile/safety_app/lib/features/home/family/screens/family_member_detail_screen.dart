// ===================================================================
// UPDATED: family_member_detail_screen.dart - With Profile Picture Upload
// ===================================================================
// lib/features/home/family/screens/family_member_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/widgets/profile_picture_widget.dart';
import 'package:safety_app/core/providers/dependent_provider.dart';
import 'package:safety_app/features/home/family/widgets/emergency_contatcs_section.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/services/collaborator_service.dart';
import 'package:safety_app/services/dependent_profile_service.dart';
import 'package:safety_app/features/home/family/widgets/collaborator_invitation_dialog.dart';

class FamilyMemberDetailScreen extends ConsumerStatefulWidget {
  final DependentModel dependent;

  const FamilyMemberDetailScreen({super.key, required this.dependent});

  @override
  ConsumerState<FamilyMemberDetailScreen> createState() =>
      _FamilyMemberDetailScreenState();
}

class _FamilyMemberDetailScreenState
    extends ConsumerState<FamilyMemberDetailScreen> {
  final CollaboratorService _collaboratorService = CollaboratorService();
  final DependentProfileService _profileService = DependentProfileService();

  List<Map<String, dynamic>> _collaborators = [];
  bool _isLoadingCollaborators = false;

  // Profile picture state
  String? _currentProfilePicture;
  bool _isUploadingImage = false;

  // Safety settings states
  bool _liveLocationTracking = true;
  bool _audioRecording = false;
  bool _motionDetection = true;
  bool _autoRecording = false;

  @override
  void initState() {
    super.initState();
    _currentProfilePicture = widget.dependent.profilePicture;
    _loadSafetySettings();
    _loadCollaborators();

    print('═══════════════════════════════════════════════════');
    print('📋 DEPENDENT DETAIL SCREEN INITIALIZED');
    print('═══════════════════════════════════════════════════');
    print('Dependent: ${widget.dependent.dependentName}');
    print('Guardian Type: ${widget.dependent.guardianType}');
    print('Is Primary: ${widget.dependent.isPrimary}');
    print('Is Primary Guardian: ${widget.dependent.isPrimaryGuardian}');
    print('Is Collaborator: ${widget.dependent.isCollaborator}');
    print('Profile Picture: $_currentProfilePicture');
    print('═══════════════════════════════════════════════════');
  }

  Future<void> _loadCollaborators() async {
    setState(() => _isLoadingCollaborators = true);
    try {
      final collaborators = await _collaboratorService.getCollaborators(
        widget.dependent.dependentId,
      );
      if (mounted) {
        setState(() {
          _collaborators = collaborators;
          _isLoadingCollaborators = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCollaborators = false);
      }
    }
  }

  Future<void> _loadSafetySettings() async {
    // TODO: Load actual settings from backend
    setState(() {
      _liveLocationTracking = true;
      _audioRecording = false;
      _motionDetection = true;
      _autoRecording = false;
    });
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
      print('📸 Uploading profile picture for dependent...');

      final updatedUser = await _profileService.uploadDependentProfilePicture(
        dependentId: widget.dependent.dependentId,
        imageFile: imageFile,
      );

      if (mounted) {
        // ✅ Update local state
        setState(() {
          _currentProfilePicture = updatedUser.profilePicture;
          _isUploadingImage = false;
        });

        // ✅ Update provider state for real-time updates across all screens
        ref
            .read(dependentProvider.notifier)
            .updateDependentProfilePicture(
              widget.dependent.dependentId,
              updatedUser.profilePicture,
            );

        _showSuccessSnackbar('Profile picture updated successfully!');

        print('✅ Profile picture updated in both local and provider state');
      }
    } catch (e) {
      print('❌ Error uploading profile picture: $e');

      if (mounted) {
        setState(() => _isUploadingImage = false);

        String errorMessage = 'Failed to upload picture';
        if (e.toString().contains('primary guardian')) {
          errorMessage = 'Only primary guardians can update profile pictures';
        } else if (e.toString().contains('too large')) {
          errorMessage = 'Image too large. Maximum size is 5MB';
        }

        _showErrorSnackbar(errorMessage);
      }
    }
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Picture'),
        content: Text(
          'Are you sure you want to remove ${widget.dependent.dependentName}\'s profile picture?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProfilePicture();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Delete profile picture
  Future<void> _deleteProfilePicture() async {
    setState(() => _isUploadingImage = true);

    try {
      await _profileService.deleteDependentProfilePicture(
        widget.dependent.dependentId,
      );

      if (mounted) {
        // ✅ Update local state
        setState(() {
          _currentProfilePicture = null;
          _isUploadingImage = false;
        });

        // ✅ Update provider state for real-time updates
        ref
            .read(dependentProvider.notifier)
            .removeDependentProfilePicture(widget.dependent.dependentId);

        _showSuccessSnackbar('Profile picture removed successfully');

        print('✅ Profile picture removed from both local and provider state');
      }
    } catch (e) {
      print('❌ Error deleting profile picture: $e');

      if (mounted) {
        setState(() => _isUploadingImage = false);

        String errorMessage = 'Failed to remove picture';
        if (e.toString().contains('primary guardian')) {
          errorMessage = 'Only primary guardians can remove profile pictures';
        }

        _showErrorSnackbar(errorMessage);
      }
    }
  }

  // ==================== OTHER METHODS ====================

  Future<void> _updateSafetySetting(String setting, bool value) async {
    // TODO: Update backend
    setState(() {
      switch (setting) {
        case 'location':
          _liveLocationTracking = value;
          break;
        case 'audio':
          _audioRecording = value;
          break;
        case 'motion':
          _motionDetection = value;
          break;
        case 'recording':
          _autoRecording = value;
          break;
      }
    });

    _showSuccessSnackbar('Setting updated successfully');
  }

  Future<void> _inviteCollaborator() async {
    await showCollaboratorInvitationDialog(
      context: context,
      dependentId: widget.dependent.dependentId,
      dependentName: widget.dependent.dependentName,
    );
    _loadCollaborators();
  }

  void _showRevokeCollaboratorDialog(Map<String, dynamic> collaborator) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revoke Access'),
        content: Text(
          'Are you sure you want to revoke ${collaborator['guardian_name']}\'s access to ${widget.dependent.dependentName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _revokeCollaborator(collaborator['relationship_id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeCollaborator(int relationshipId) async {
    try {
      await _collaboratorService.revokeCollaborator(relationshipId);
      _showSuccessSnackbar('Collaborator access revoked');
      _loadCollaborators();
    } catch (e) {
      _showErrorSnackbar('Failed to revoke access: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== UI BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPrimary = widget.dependent.isPrimaryGuardian;

    print('🔍 Building detail screen - isPrimary: $isPrimary');

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark, isPrimary),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileSection(isDark, isPrimary),
                const SizedBox(height: 16),
                _buildSafetyControlsSection(isDark, isPrimary),
                const SizedBox(height: 16),
                _buildGeofencingSection(isDark, isPrimary),
                const SizedBox(height: 16),
                EmergencyContactsSection(
                  dependentId: widget.dependent.dependentId,
                  isPrimaryGuardian: isPrimary,
                  dependentName: widget.dependent.dependentName,
                ),
                if (isPrimary) ...[
                  const SizedBox(height: 16),
                  _buildCollaboratorsSection(isDark),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, bool isPrimary) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.dependent.dependentName,
          style: AppTextStyles.h3.copyWith(
            color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isPrimary
                    ? AppColors.primaryGreen.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
              ],
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.primaryGreen.withOpacity(0.2)
                : Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary ? AppColors.primaryGreen : Colors.blue,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPrimary ? Icons.admin_panel_settings : Icons.groups,
                size: 16,
                color: isPrimary ? AppColors.primaryGreen : Colors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                isPrimary ? 'PRIMARY' : 'COLLABORATOR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? AppColors.primaryGreen : Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(bool isDark, bool isPrimary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
          // ✅ UPDATED: Use ProfilePictureWidget with upload functionality
          Stack(
            alignment: Alignment.center,
            children: [
              // Profile Picture Widget
              GestureDetector(
                onTap: isPrimary ? _showImagePickerOptions : null,
                child: ProfilePictureWidget(
                  profilePicturePath: _currentProfilePicture,
                  fullName: widget.dependent.dependentName,
                  radius: 50,
                  showBorder: true,
                  borderColor: isPrimary
                      ? (isDark
                            ? AppColors.darkAccentGreen1
                            : AppColors.primaryGreen)
                      : Colors.blue,
                  borderWidth: 3,
                  backgroundColor: isPrimary
                      ? AppColors.primaryGreen.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                ),
              ),

              // Loading indicator overlay
              if (_isUploadingImage)
                Container(
                  width: 106, // radius * 2 + border
                  height: 106,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),

              // ✅ Camera icon for PRIMARY guardians
              if (isPrimary && !_isUploadingImage)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Container(
                      width: 32,
                      height: 32,
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
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Status indicator for COLLABORATORS (view only)
              if (!isPrimary)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            widget.dependent.dependentName,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isPrimary
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPrimary
                    ? AppColors.primaryGreen.withOpacity(0.3)
                    : Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Text(
              widget.dependent.relationDisplay.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isPrimary ? AppColors.primaryGreen : Colors.blue,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Email
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 16,
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.dependent.dependentEmail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (widget.dependent.age != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cake_outlined,
                  size: 16,
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.dependent.age} years old',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status: Safe',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last active: 5 minutes ago',
                        style: AppTextStyles.caption.copyWith(
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
          ),

          // ✅ Info message for collaborators
          if (!isPrimary) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can view but not edit this dependent\'s profile picture',
                      style: AppTextStyles.caption.copyWith(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyControlsSection(bool isDark, bool isPrimary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.security,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Safety Controls', style: AppTextStyles.h4),
            ],
          ),

          const SizedBox(height: 16),

          _buildSafetySwitch(
            'Live Location Tracking',
            'Track real-time location',
            Icons.location_on,
            _liveLocationTracking,
            (value) => _updateSafetySetting('location', value),
            enabled: isPrimary,
            isDark: isDark,
          ),

          _buildSafetySwitch(
            'Audio Recording',
            'Record ambient audio',
            Icons.mic,
            _audioRecording,
            (value) => _updateSafetySetting('audio', value),
            enabled: isPrimary,
            isDark: isDark,
          ),

          _buildSafetySwitch(
            'Motion Detection',
            'Detect unusual movements',
            Icons.directions_walk,
            _motionDetection,
            (value) => _updateSafetySetting('motion', value),
            enabled: isPrimary,
            isDark: isDark,
          ),

          _buildSafetySwitch(
            'Auto Recording',
            'Record when motion detected',
            Icons.videocam,
            _autoRecording,
            (value) => _updateSafetySetting('recording', value),
            enabled: isPrimary,
            isDark: isDark,
          ),

          if (!isPrimary) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'As a collaborator, you can view but not modify safety settings',
                      style: AppTextStyles.caption.copyWith(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetySwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    required bool enabled,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : (isDark ? AppColors.darkDivider : AppColors.lightDivider)
                        .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: value
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkHint : AppColors.lightHint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildGeofencingSection(bool isDark, bool isPrimary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_searching,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Geofencing', style: AppTextStyles.h4),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_location_alt,
                  size: 48,
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No Safe Zones Set',
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  isPrimary
                      ? 'Add safe zones to get notified when they leave'
                      : 'Only primary guardian can set geofencing',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          if (isPrimary) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showSuccessSnackbar('Geofencing feature coming soon');
                },
                icon: const Icon(Icons.add_location),
                label: const Text('Add Safe Zone'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollaboratorsSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  const Text('Collaborators', style: AppTextStyles.h4),
                ],
              ),
              IconButton(
                onPressed: _inviteCollaborator,
                icon: const Icon(Icons.person_add),
                color: AppColors.primaryGreen,
                tooltip: 'Invite Collaborator',
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_isLoadingCollaborators)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else if (_collaborators.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
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
                  const Text(
                    'No Collaborators Yet',
                    style: AppTextStyles.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite other guardians to help monitor ${widget.dependent.dependentName}',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._collaborators.map((collaborator) {
              return _buildCollaboratorCard(collaborator, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildCollaboratorCard(
    Map<String, dynamic> collaborator,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        children: [
          ProfilePictureWidget(
            profilePicturePath: collaborator['profile_picture'],
            fullName: collaborator['guardian_name'] ?? 'Unknown',
            radius: 24,
            showBorder: true,
            borderColor: Colors.blue,
            borderWidth: 2,
            backgroundColor: Colors.blue.withOpacity(0.2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collaborator['guardian_name'] ?? 'Unknown',
                  style: AppTextStyles.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  collaborator['guardian_email'] ?? '',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showRevokeCollaboratorDialog(collaborator),
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red,
            tooltip: 'Revoke Access',
          ),
        ],
      ),
    );
  }
}
