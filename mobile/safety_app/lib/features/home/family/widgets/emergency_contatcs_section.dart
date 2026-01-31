// lib/features/home/widgets/emergency_contacts_section_universal.dart
// UNIVERSAL - Works for both personal contacts AND dependent contacts

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/emergency_contact_provider.dart';
import 'package:safety_app/core/widgets/add_emergency_contact_dialog.dart';
import 'package:safety_app/features/home/sos/widgets/import_contacts_button.dart';
import 'package:safety_app/models/emergency_contact.dart';
import 'package:url_launcher/url_launcher.dart';

/// Universal Emergency Contacts Section
///
/// Modes:
/// 1. Personal Mode (dependentId = null): Shows current user's own contacts
/// 2. Dependent Mode (dependentId provided): Shows dependent's contacts
///
/// Permissions handled automatically based on mode and user role
class EmergencyContactsSection extends ConsumerStatefulWidget {
  /// If null, shows personal contacts. If provided, shows dependent's contacts
  final int? dependentId;

  /// Required when in dependent mode
  final String? dependentName;

  /// Required when in dependent mode
  final bool? isPrimaryGuardian;

  /// Show compact header (for use in SOS screen)
  final bool compactMode;

  const EmergencyContactsSection({
    super.key,
    this.dependentId,
    this.dependentName,
    this.isPrimaryGuardian,
    this.compactMode = false,
  }) : assert(
         dependentId == null ||
             (dependentName != null && isPrimaryGuardian != null),
         'When dependentId is provided, dependentName and isPrimaryGuardian are required',
       );

  /// Factory: Personal contacts (for SOS home screen)
  factory EmergencyContactsSection.personal({
    Key? key,
    bool compactMode = false,
  }) {
    return EmergencyContactsSection(
      key: key,
      dependentId: null,
      compactMode: compactMode,
    );
  }

  /// Factory: Dependent contacts (for family detail screen)
  factory EmergencyContactsSection.dependent({
    Key? key,
    required int dependentId,
    required String dependentName,
    required bool isPrimaryGuardian,
    bool compactMode = false,
  }) {
    return EmergencyContactsSection(
      key: key,
      dependentId: dependentId,
      dependentName: dependentName,
      isPrimaryGuardian: isPrimaryGuardian,
      compactMode: compactMode,
    );
  }

  @override
  ConsumerState<EmergencyContactsSection> createState() =>
      _EmergencyContactsSectionState();
}

class _EmergencyContactsSectionState
    extends ConsumerState<EmergencyContactsSection> {
  bool get _isPersonalMode => widget.dependentId == null;
  bool get _isDependentMode => widget.dependentId != null;
  bool get _canEdit => _isPersonalMode || (widget.isPrimaryGuardian ?? false);

  @override
  void initState() {
    super.initState();

    // Load appropriate contacts based on mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isPersonalMode) {
        print('🔄 Loading personal emergency contacts');
        ref.read(emergencyContactNotifierProvider.notifier).loadMyContacts();
      } else {
        print('🔄 Loading contacts for dependent ${widget.dependentId}');
        print(
          '👤 User is ${widget.isPrimaryGuardian! ? "PRIMARY" : "COLLABORATOR"} guardian',
        );
        ref
            .read(emergencyContactNotifierProvider.notifier)
            .loadDependentContacts(widget.dependentId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contactsState = ref.watch(emergencyContactNotifierProvider);

    return Container(
      margin: widget.compactMode
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: widget.compactMode
          ? const EdgeInsets.all(16)
          : const EdgeInsets.all(20),
      decoration: widget.compactMode
          ? null
          : BoxDecoration(
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
          _buildHeader(isDark),

          // Action buttons (only if user can edit)
          if (_canEdit) ...[
            const SizedBox(height: 16),
            _buildActionButtons(context, isDark),
          ],

          // View-only banner (for collaborators viewing dependents)
          if (_isDependentMode && !_canEdit) ...[
            const SizedBox(height: 12),
            _buildViewOnlyBanner(isDark),
          ],

          const SizedBox(height: 16),

          // Contact list
          if (contactsState.isLoading)
            _buildLoadingState(isDark)
          else if (contactsState.error != null)
            _buildErrorState(isDark, contactsState.error!)
          else if (contactsState.contacts.isEmpty)
            _buildEmptyState(isDark)
          else
            _buildContactsList(isDark, contactsState.contacts),
        ],
      ),
    );
  }

  // ========================================
  // HEADER
  // ========================================

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.sosRed.withOpacity(0.15),
                AppColors.sosRed.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.sosRed.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(Icons.emergency, color: AppColors.sosRed, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _isPersonalMode
                          ? 'My Emergency Contacts'
                          : 'Emergency Contacts',
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
                  // Lock icon for collaborators viewing dependents
                  if (_isDependentMode && !_canEdit) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'View only - Primary guardian manages',
                      child: Icon(
                        Icons.lock_outline,
                        size: 18,
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
                _getSubtitleText(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSubtitleText() {
    if (_isPersonalMode) {
      return 'Contacts notified during SOS';
    } else if (_canEdit) {
      return 'Manage ${widget.dependentName}\'s emergency contacts';
    } else {
      return 'View ${widget.dependentName}\'s emergency contacts';
    }
  }

  // ========================================
  // VIEW-ONLY BANNER
  // ========================================

  Widget _buildViewOnlyBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'View only - Primary guardian manages contacts',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // ACTION BUTTONS
  // ========================================

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showAddContactDialog(context),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: _isDependentMode
                ? ImportContactsButton(
                    onContactSelected: (contact) async {
                      // Import for dependent
                      final success = await ref
                          .read(emergencyContactNotifierProvider.notifier)
                          .addDependentContact(
                            widget.dependentId!,
                            CreateEmergencyContact(
                              name: contact['name'],
                              phoneNumber: contact['phone'],
                              email: contact['email'],
                              relationship: contact['relationship'],
                            ),
                          );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Contact imported successfully'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      }
                    },
                    buttonText: 'Import',
                    isDark: isDark,
                    isCompact: true,
                  )
                : ImportContactsButton(
                    isForDependent: false,
                    onImportComplete: () {
                      ref
                          .read(emergencyContactNotifierProvider.notifier)
                          .loadMyContacts();
                    },
                    buttonText: 'Import',
                    isDark: isDark,
                    isCompact: true,
                  ),
          ),
        ),
      ],
    );
  }

  // ========================================
  // CONTACTS LIST
  // ========================================

  Widget _buildContactsList(bool isDark, List<EmergencyContact> contacts) {
    final guardianContacts = contacts
        .where((c) => c.isGuardianContact)
        .toList();
    final manualContacts = contacts.where((c) => !c.isGuardianContact).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Guardian contacts
        if (guardianContacts.isNotEmpty) ...[
          _buildContactsCategoryHeader(
            isDark,
            'Guardian Contacts',
            Icons.shield,
          ),
          const SizedBox(height: 12),
          ...guardianContacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildContactCard(
                contact,
                isDark,
                isGuardianContact: true,
              ),
            ),
          ),
          if (manualContacts.isNotEmpty) const SizedBox(height: 16),
        ],

        // Manual contacts
        if (manualContacts.isNotEmpty) ...[
          _buildContactsCategoryHeader(isDark, 'Other Contacts', Icons.person),
          const SizedBox(height: 12),
          ...manualContacts.map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildContactCard(
                contact,
                isDark,
                isGuardianContact: false,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContactsCategoryHeader(
    bool isDark,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.darkHint : AppColors.lightHint,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(
    EmergencyContact contact,
    bool isDark, {
    required bool isGuardianContact,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGuardianContact
            ? Colors.blue.withOpacity(isDark ? 0.1 : 0.05)
            : (isDark ? AppColors.darkBackground : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGuardianContact
              ? Colors.blue.withOpacity(0.3)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isGuardianContact
                    ? [
                        Colors.blue.withOpacity(0.2),
                        Colors.blue.withOpacity(0.1),
                      ]
                    : contact.isPrimary
                    ? [
                        AppColors.sosRed.withOpacity(0.2),
                        AppColors.sosRed.withOpacity(0.1),
                      ]
                    : [
                        AppColors.primaryGreen.withOpacity(0.2),
                        AppColors.primaryGreen.withOpacity(0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGuardianContact ? Icons.shield : Icons.person,
              color: isGuardianContact
                  ? Colors.blue
                  : contact.isPrimary
                  ? AppColors.sosRed
                  : AppColors.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Contact info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkOnBackground
                              : AppColors.lightOnBackground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (contact.isPrimary) ...[
                      const SizedBox(width: 6),
                      _buildBadge('PRIMARY', AppColors.sosRed),
                    ],
                    if (isGuardianContact) ...[
                      const SizedBox(width: 6),
                      _buildBadge('GUARDIAN', Colors.blue),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 14,
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        contact.phoneNumber,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (contact.relationship.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: isDark
                            ? AppColors.darkHint
                            : AppColors.lightHint,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          contact.relationship,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          if (_canEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () => _showContactActions(context, contact),
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
          ] else ...[
            // For view-only users, show call button
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.phone, size: 20),
              onPressed: () => _callContact(contact.phoneNumber),
              color: AppColors.primaryGreen,
              tooltip: 'Call',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  // ========================================
  // EMPTY/LOADING/ERROR STATES
  // ========================================

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.sosRed.withOpacity(0.1),
                  AppColors.sosRed.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emergency,
              size: 48,
              color: AppColors.sosRed.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _canEdit ? 'No Emergency Contacts Yet' : 'No Contacts Available',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkOnBackground
                  : AppColors.lightOnBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateMessage(),
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getEmptyStateMessage() {
    if (_isPersonalMode) {
      return 'Add contacts who will be notified during emergencies';
    } else if (_canEdit) {
      return 'Add contacts to ensure ${widget.dependentName} can reach help in emergencies';
    } else {
      return 'The primary guardian hasn\'t added any contacts yet';
    }
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading contacts...',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    print('❌ Error in emergency contacts: $error');

    final isAccessDenied =
        error.contains('403') ||
        error.contains('Access denied') ||
        (error.contains('Only primary guardian') && error.contains('view'));

    // For view-only collaborators, show retry instead of access denied
    if (_isDependentMode && !_canEdit && !isAccessDenied) {
      return _buildRetryError(isDark);
    }

    if (isAccessDenied) {
      return _buildAccessDeniedError(isDark);
    }

    return _buildRetryError(isDark);
  }

  Widget _buildRetryError(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
          const SizedBox(height: 12),
          Text(
            'Unable to Load Contacts',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There was a problem loading the contacts. Please try again.',
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_isPersonalMode) {
                ref
                    .read(emergencyContactNotifierProvider.notifier)
                    .loadMyContacts();
              } else {
                ref
                    .read(emergencyContactNotifierProvider.notifier)
                    .loadDependentContacts(widget.dependentId!);
              }
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedError(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(
            'Access Denied',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You do not have permission to view emergency contacts for this dependent.',
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ========================================
  // ACTIONS
  // ========================================

  Future<void> _showAddContactDialog(BuildContext context) async {
    final result = await showAddEmergencyContactDialog(
      context: context,
      dependentId: _isDependentMode ? widget.dependentId : null,
    );

    if (result == true && mounted) {
      // Refresh contacts
      if (_isPersonalMode) {
        ref.read(emergencyContactNotifierProvider.notifier).loadMyContacts();
      } else {
        ref
            .read(emergencyContactNotifierProvider.notifier)
            .loadDependentContacts(widget.dependentId!);
      }
    }
  }

  void _showContactActions(BuildContext context, EmergencyContact contact) {
    final canDelete = contact.source != 'auto_guardian';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call'),
              onTap: () {
                Navigator.pop(context);
                _callContact(contact.phoneNumber);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () async {
                Navigator.pop(context);
                final result = await showAddEmergencyContactDialog(
                  context: context,
                  dependentId: _isDependentMode ? widget.dependentId : null,
                  existingContact: contact,
                );
                if (result == true && mounted) {
                  if (_isPersonalMode) {
                    ref
                        .read(emergencyContactNotifierProvider.notifier)
                        .loadMyContacts();
                  } else {
                    ref
                        .read(emergencyContactNotifierProvider.notifier)
                        .loadDependentContacts(widget.dependentId!);
                  }
                }
              },
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteContact(context, contact);
                },
              )
            else
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Colors.grey.shade400,
                ),
                title: Text(
                  'Cannot delete guardian contact',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                enabled: false,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _deleteContact(BuildContext context, EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = _isPersonalMode
          ? await ref
                .read(emergencyContactNotifierProvider.notifier)
                .deleteContact(contact.id!)
          : await ref
                .read(emergencyContactNotifierProvider.notifier)
                .deleteDependentContact(contact.id!);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Contact deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _callContact(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch phone app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
