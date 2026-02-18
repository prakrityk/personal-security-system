// lib/features/home/sos/widgets/personal_emergency_contacts_widget.dart
// DEDICATED WIDGET FOR PERSONAL CONTACTS - Prevents state pollution

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/personal_emergency_contact_provider.dart';
import 'package:safety_app/core/widgets/add_emergency_contact_dialog.dart';
import 'package:safety_app/features/home/sos/widgets/import_contacts_button.dart';
import 'package:safety_app/models/emergency_contact.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonalEmergencyContactsWidget extends ConsumerStatefulWidget {
  final bool canEdit;
  final bool isDependent;

  const PersonalEmergencyContactsWidget({
    super.key,
    required this.canEdit,
    this.isDependent = false,
  });

  @override
  ConsumerState<PersonalEmergencyContactsWidget> createState() =>
      _PersonalEmergencyContactsWidgetState();
}

class _PersonalEmergencyContactsWidgetState
    extends ConsumerState<PersonalEmergencyContactsWidget> {
  @override
  void initState() {
    super.initState();
    // Load personal contacts on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔄 [PersonalWidget] Initializing - loading personal contacts');
      ref.read(personalContactsNotifierProvider.notifier).loadMyContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contactsState = ref.watch(personalContactsNotifierProvider);

    print(
      '🎨 [PersonalWidget] Building with ${contactsState.contacts.length} contacts',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(isDark),

        const SizedBox(height: 20),

        // Content
        if (contactsState.isLoading)
          _buildLoadingState(isDark)
        else if (contactsState.error != null)
          _buildErrorState(isDark, contactsState.error!)
        else if (contactsState.contacts.isEmpty)
          _buildEmptyState(isDark)
        else
          _buildContactsList(isDark, contactsState.contacts),
      ],
    );
  }

  // ========================================
  // HEADER
  // ========================================

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contacts',
                    style: AppTextStyles.h4.copyWith(
                      color: isDark
                          ? AppColors.darkOnBackground
                          : AppColors.lightOnBackground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isDependent
                        ? 'SOS will be sent to these contacts'
                        : 'Add contacts to notify in emergencies',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Action buttons (only if can edit and not dependent)
        if (widget.canEdit && !widget.isDependent) ...[
          const SizedBox(height: 20),
          Row(
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
                    foregroundColor: isDark
                        ? AppColors.darkBackground
                        : Colors.white,
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
                child: ImportContactsButton(
                  isForDependent: false,
                  isDark: isDark,
                  buttonText: 'Import',
                  onImportComplete: () {
                    ref
                        .read(personalContactsNotifierProvider.notifier)
                        .loadMyContacts();
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ========================================
  // CONTACTS LIST
  // ========================================

  Widget _buildContactsList(bool isDark, List<EmergencyContact> contacts) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contacts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactCard(isDark, contact);
      },
    );
  }

  Widget _buildContactCard(bool isDark, EmergencyContact contact) {
    final isGuardianContact = contact.source == 'auto_guardian';
    final isPrimary = contact.isPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground.withOpacity(0.4)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary
              ? AppColors.primaryGreen.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.grey.shade300),
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isPrimary
                    ? [
                        AppColors.primaryGreen.withOpacity(0.2),
                        AppColors.primaryGreen.withOpacity(0.1),
                      ]
                    : [
                        Colors.blue.withOpacity(0.15),
                        Colors.blue.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGuardianContact ? Icons.shield : Icons.person,
              color: isPrimary ? AppColors.primaryGreen : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Contact Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.lightOnSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'PRIMARY',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    if (isGuardianContact) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Auto-added guardian contact',
                        child: Icon(
                          Icons.shield_outlined,
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
                  contact.phoneNumber,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
                if (contact.relationship?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    contact.relationship!,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.darkHint.withOpacity(0.7)
                          : AppColors.lightHint.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons (only if can edit and not dependent)
          if (widget.canEdit && !widget.isDependent) ...[
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => _callContact(contact.phoneNumber),
                icon: Icon(
                  Icons.phone,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => _showContactActions(context, contact),
                icon: Icon(
                  Icons.more_vert,
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.lightOnSurface,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========================================
  // EMPTY STATE
  // ========================================

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground.withOpacity(0.3)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 56,
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
          const SizedBox(height: 16),
          Text(
            'No Emergency Contacts',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.darkOnSurface
                  : AppColors.lightOnSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isDependent
                ? 'Your guardian will add emergency contacts'
                : 'Add contacts to notify in emergencies',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ========================================
  // LOADING STATE
  // ========================================

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

  // ========================================
  // ERROR STATE
  // ========================================

  Widget _buildErrorState(bool isDark, String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(
            'Failed to load contacts',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(personalContactsNotifierProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
      dependentId: null, // Personal contact
    );

    if (result == true) {
      ref.read(personalContactsNotifierProvider.notifier).loadMyContacts();
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
                  dependentId: null,
                  existingContact: contact,
                );
                if (result == true) {
                  ref
                      .read(personalContactsNotifierProvider.notifier)
                      .loadMyContacts();
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
      final success = await ref
          .read(personalContactsNotifierProvider.notifier)
          .deleteContact(contact.id);

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
    }
  }
}
