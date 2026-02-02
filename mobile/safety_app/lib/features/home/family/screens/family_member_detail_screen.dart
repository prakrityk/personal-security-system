import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/features/home/family/widgets/emergency_contatcs_section.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/services/collaborator_service.dart';
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

  List<Map<String, dynamic>> _collaborators = [];
  bool _isLoadingCollaborators = false;

  // Safety settings states
  bool _liveLocationTracking = true;
  bool _audioRecording = false;
  bool _motionDetection = true;
  bool _autoRecording = false;

  @override
  void initState() {
    super.initState();
    _loadSafetySettings();
    _loadCollaborators();

    // 🐛 DEBUG: Print guardian type info
    print('═══════════════════════════════════════════════════');
    print('📋 DEPENDENT DETAIL SCREEN INITIALIZED');
    print('═══════════════════════════════════════════════════');
    print('Dependent: ${widget.dependent.dependentName}');
    print('Guardian Type: ${widget.dependent.guardianType}');
    print('Is Primary: ${widget.dependent.isPrimary}');
    print('Is Primary Guardian: ${widget.dependent.isPrimaryGuardian}');
    print('Is Collaborator: ${widget.dependent.isCollaborator}');
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
    // For now using dummy data
    setState(() {
      _liveLocationTracking = true;
      _audioRecording = false;
      _motionDetection = true;
      _autoRecording = false;
    });
  }

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
    _loadCollaborators(); // Refresh the list
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
      _loadCollaborators(); // Refresh the list
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ FIX: Use the dependent model's isPrimaryGuardian property directly
    // This avoids async provider issues and uses data already available
    final isPrimary = widget.dependent.isPrimaryGuardian;

    print('🔍 Building detail screen - isPrimary: $isPrimary');

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          // App Bar
          _buildSliverAppBar(isDark, isPrimary),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile Section
                _buildProfileSection(isDark, isPrimary),

                const SizedBox(height: 16),

                // Safety Controls Section
                _buildSafetyControlsSection(isDark, isPrimary),

                const SizedBox(height: 16),

                // Geofencing Section
                _buildGeofencingSection(isDark, isPrimary),
                const SizedBox(height: 16),

                // ✅ Emergency Contacts Section
                EmergencyContactsSection(
                  dependentId: widget.dependent.dependentId,
                  isPrimaryGuardian: isPrimary,
                  dependentName: widget.dependent.dependentName,
                ),
                if (isPrimary) ...[
                  const SizedBox(height: 16),

                  // Collaborators Section
                  _buildCollaboratorsSection(isDark),
                ],

                const SizedBox(height: 100), // Space for bottom padding
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
        // Guardian type indicator badge
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
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      isPrimary
                          ? AppColors.primaryGreen.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                      isPrimary
                          ? AppColors.accentGreen1.withOpacity(0.3)
                          : Colors.lightBlue.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.lightOnSurface,
                ),
              ),
              // Online/Safe status indicator
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
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
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
              Text(
                widget.dependent.dependentEmail,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
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
                  // TODO: Implement geofencing setup
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
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue.withOpacity(0.2),
            child: Icon(Icons.person, color: Colors.blue, size: 24),
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
