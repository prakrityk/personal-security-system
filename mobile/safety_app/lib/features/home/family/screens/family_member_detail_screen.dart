// lib/features/home/family/screens/family_member_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/providers/permission_provider.dart';
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

    if (mounted) {
      _loadCollaborators();
    }
  }

  Future<void> _revokeCollaborator(int relationshipId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildRevokeDialog(name),
    );

    if (confirmed == true) {
      try {
        await _collaboratorService.revokeCollaborator(relationshipId);

        if (mounted) {
          _showSuccessSnackbar('$name removed successfully');
          _loadCollaborators();
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Failed to remove collaborator: ${e.toString()}');
        }
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showViewOnlyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Only primary guardian can modify settings'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // final isPrimary = widget.dependent.isPrimaryGuardian;
    final canEditAsync = ref.watch(
      canEditDependentContactsProvider(widget.dependent.dependentId),
    );

    final isPrimary = canEditAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

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

                // ✅ NEW: Emergency Contacts Section
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
      expandedHeight: 200,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryGreen.withOpacity(0.3),
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primaryGreen.withOpacity(
                          0.1,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: isDark
                              ? AppColors.darkAccentGreen1
                              : AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.all(8),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showOptionsMenu(context, isDark, isPrimary),
        ),
      ],
    );
  }

  Widget _buildProfileSection(bool isDark, bool isPrimary) {
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
        children: [
          Text(
            widget.dependent.dependentName,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.dependent.relationDisplay.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
          ),
          const SizedBox(height: 16),

          // Guardian Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPrimary
                    ? [
                        AppColors.primaryGreen.withOpacity(0.2),
                        AppColors.accentGreen1.withOpacity(0.2),
                      ]
                    : [
                        Colors.blue.withOpacity(0.2),
                        Colors.blue.withOpacity(0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPrimary
                    ? AppColors.primaryGreen.withOpacity(0.5)
                    : Colors.blue.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPrimary ? Icons.admin_panel_settings : Icons.groups,
                  size: 20,
                  color: isPrimary ? AppColors.primaryGreen : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  isPrimary ? 'PRIMARY GUARDIAN' : 'COLLABORATOR GUARDIAN',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isPrimary ? AppColors.primaryGreen : Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusChip(
                icon: Icons.check_circle,
                label: 'Safe',
                color: Colors.green,
                isDark: isDark,
              ),
              _buildStatusChip(
                icon: Icons.location_on,
                label: 'Tracking',
                color: Colors.blue,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen.withOpacity(0.2),
                      AppColors.accentGreen1.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safety Controls', style: AppTextStyles.h4),
                    if (!isPrimary)
                      Text(
                        'View only',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isPrimary)
                Icon(
                  Icons.lock,
                  size: 20,
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Live Location Tracking
          _buildSafetyToggle(
            icon: Icons.my_location,
            title: 'Live Location Tracking',
            subtitle: 'Real-time location monitoring',
            value: _liveLocationTracking,
            onChanged: isPrimary
                ? (value) => _updateSafetySetting('location', value)
                : null,
            color: Colors.blue,
            isDark: isDark,
            isPrimary: isPrimary,
          ),

          const Divider(height: 32),

          // Audio Recording
          _buildSafetyToggle(
            icon: Icons.mic,
            title: 'Audio Recording',
            subtitle: 'Record audio during emergencies',
            value: _audioRecording,
            onChanged: isPrimary
                ? (value) => _updateSafetySetting('audio', value)
                : null,
            color: Colors.orange,
            isDark: isDark,
            isPrimary: isPrimary,
          ),

          const Divider(height: 32),

          // Motion Detection
          _buildSafetyToggle(
            icon: Icons.sensors,
            title: 'Motion Detection',
            subtitle: 'Detect unusual movement patterns',
            value: _motionDetection,
            onChanged: isPrimary
                ? (value) => _updateSafetySetting('motion', value)
                : null,
            color: Colors.purple,
            isDark: isDark,
            isPrimary: isPrimary,
          ),

          const Divider(height: 32),

          // Auto Recording
          _buildSafetyToggle(
            icon: Icons.videocam,
            title: 'Auto Evidence Recording',
            subtitle: 'Record video/audio as evidence',
            value: _autoRecording,
            onChanged: isPrimary
                ? (value) => _updateSafetySetting('recording', value)
                : null,
            color: Colors.red,
            isDark: isDark,
            isPrimary: isPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color color,
    required bool isDark,
    required bool isPrimary,
  }) {
    return InkWell(
      onTap: onChanged == null ? _showViewOnlyMessage : () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.lightOnSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
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
              onChanged: onChanged,
              activeColor: AppColors.primaryGreen,
              inactiveThumbColor: Colors.grey,
            ),
          ],
        ),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.2),
                      Colors.lightGreen.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_city,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Geofencing', style: AppTextStyles.h4),
                    Text(
                      '3 safe zones configured',
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
          const SizedBox(height: 16),

          // Safe Zones List
          _buildSafeZoneItem(
            name: 'Home',
            address: '123 Main Street, City',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSafeZoneItem(
            name: 'School',
            address: 'ABC School, Downtown',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSafeZoneItem(
            name: 'Park',
            address: 'Central Park Area',
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Add Safe Zone Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isPrimary
                  ? () {
                      // TODO: Navigate to add geofence screen
                    }
                  : _showViewOnlyMessage,
              icon: const Icon(Icons.add_location),
              label: const Text('Add Safe Zone'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeZoneItem({
    required String name,
    required String address,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.place, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  address,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.2),
                      Colors.lightBlue.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Collaborator Guardians', style: AppTextStyles.h4),
                    Text(
                      '${_collaborators.length} collaborator(s)',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkHint
                            : AppColors.lightHint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primaryGreen,
                onPressed: _inviteCollaborator,
                tooltip: 'Invite Collaborator',
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_isLoadingCollaborators)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_collaborators.isEmpty)
            _buildEmptyCollaborators(isDark)
          else
            Column(
              children: _collaborators
                  .map(
                    (collab) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCollaboratorTile(
                        name: collab['guardian_name'] ?? 'Unknown',
                        email: collab['guardian_email'] ?? '',
                        joinedAt: collab['joined_at'] != null
                            ? DateTime.parse(collab['joined_at'])
                            : DateTime.now(),
                        relationshipId: collab['relationship_id'] ?? 0,
                        isDark: isDark,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCollaborators(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_outlined,
            size: 48,
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
          const SizedBox(height: 12),
          Text(
            'No collaborators yet',
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to invite another guardian',
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorTile({
    required String name,
    required String email,
    required DateTime joinedAt,
    required int relationshipId,
    required bool isDark,
  }) {
    final daysAgo = DateTime.now().difference(joinedAt).inDays;
    final timeText = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
        ? 'Yesterday'
        : '$daysAgo days ago';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.2),
            child: const Icon(Icons.person, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Joined: $timeText',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkHint
                            : AppColors.lightHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            onPressed: () => _revokeCollaborator(relationshipId, name),
            tooltip: 'Remove Collaborator',
          ),
        ],
      ),
    );
  }

  Widget _buildRevokeDialog(String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      title: Text('Remove Collaborator', style: AppTextStyles.h4),
      content: Text(
        'Are you sure you want to remove $name as a collaborator guardian?',
        style: AppTextStyles.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Remove'),
        ),
      ],
    );
  }

  void _showOptionsMenu(BuildContext context, bool isDark, bool isPrimary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primaryGreen),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to edit profile
              },
            ),
            if (isPrimary)
              ListTile(
                leading: const Icon(Icons.group_add, color: Colors.blue),
                title: const Text('Invite Collaborator'),
                onTap: () {
                  Navigator.pop(context);
                  _inviteCollaborator();
                },
              ),
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.orange),
              title: const Text('Notification Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to notification settings
              },
            ),
            const Divider(),
            if (isPrimary)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Dependent',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show remove confirmation
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
