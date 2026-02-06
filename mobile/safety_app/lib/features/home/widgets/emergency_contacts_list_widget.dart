// lib/features/home/sos/widgets/emergency_contacts_list_widget.dart
// Modern, minimal emergency contacts list with role-based access

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/emergency_contact_provider.dart';
import 'package:safety_app/core/widgets/add_emergency_contact_dialog.dart';
import 'package:safety_app/models/emergency_contact.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsListWidget extends ConsumerWidget {
  final bool canEdit;
  final bool isDependent;
  final int? dependentId;
  final VoidCallback? onRefresh;

  const EmergencyContactsListWidget({
    super.key,
    required this.canEdit,
    this.isDependent = false,
    this.dependentId,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contactsState = ref.watch(emergencyContactNotifierProvider);

    // Listen for changes and auto-refresh
    ref.listen<EmergencyContactsState>(emergencyContactNotifierProvider, (
      previous,
      next,
    ) {
      // Show success message when contacts change
      if (previous != null &&
          previous.contacts.length != next.contacts.length &&
          !next.isLoading &&
          next.error == null) {
        if (next.contacts.length > previous.contacts.length) {
          _showSnackbar(context, '✅ Contact added successfully', Colors.green);
        } else if (next.contacts.length < previous.contacts.length) {
          _showSnackbar(
            context,
            '✅ Contact removed successfully',
            Colors.orange,
          );
        }
      }

      // Show error if any
      if (next.error != null && previous?.error != next.error) {
        _showSnackbar(context, '❌ ${next.error}', Colors.red);
      }
    });

    if (contactsState.isLoading) {
      return _buildLoadingState(isDark);
    }

    if (contactsState.error != null) {
      return _buildErrorState(context, isDark, contactsState.error!, ref);
    }

    if (contactsState.contacts.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return _buildContactsList(context, isDark, contactsState.contacts, ref);
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              strokeWidth: 3,
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

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withOpacity(0.3)
            : AppColors.lightSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkDivider.withOpacity(0.5)
              : AppColors.lightDivider,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  (isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen)
                      .withOpacity(0.1),
                  (isDark ? AppColors.darkAccentGreen2 : AppColors.accentGreen1)
                      .withOpacity(0.05),
                ],
              ),
            ),
            child: Icon(
              Icons.contacts_outlined,
              size: 48,
              color: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isDependent ? 'No Emergency Contacts' : 'No Contacts Added',
            style: AppTextStyles.h4.copyWith(
              color: isDark
                  ? AppColors.darkOnSurface
                  : AppColors.lightOnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isDependent
                  ? 'Your guardian will add emergency contacts for you. They will be notified when you activate SOS.'
                  : 'Add emergency contacts to receive SOS alerts. They will be notified immediately in case of emergency.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.darkHint : AppColors.lightHint,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    bool isDark,
    String error,
    WidgetRef ref,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.1),
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Contacts',
            style: AppTextStyles.labelLarge.copyWith(
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              if (dependentId != null) {
                ref
                    .read(emergencyContactNotifierProvider.notifier)
                    .loadDependentContacts(dependentId!);
              } else {
                ref
                    .read(emergencyContactNotifierProvider.notifier)
                    .loadMyContacts();
              }
              onRefresh?.call();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList(
    BuildContext context,
    bool isDark,
    List<EmergencyContact> contacts,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        // Contacts count indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkAccentGreen1.withOpacity(0.1)
                      : AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkAccentGreen1.withOpacity(0.3)
                        : AppColors.primaryGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: isDark
                          ? AppColors.darkAccentGreen1
                          : AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${contacts.length} Contact${contacts.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkAccentGreen1
                            : AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Contact cards with animation
        ...contacts.asMap().entries.map((entry) {
          final index = entry.key;
          final contact = entry.value;

          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 200 + (index * 50)),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildContactCard(context, isDark, contact, ref),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    bool isDark,
    EmergencyContact contact,
    WidgetRef ref,
  ) {
    final isGuardianContact = contact.source == 'auto_guardian';
    final isPhoneImport = contact.source == 'phone_contacts';
    final isManual = contact.source == 'manual';

    return Container(
      decoration: BoxDecoration(
        gradient: contact.isPrimary
            ? LinearGradient(
                colors: [
                  (isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen)
                      .withOpacity(0.05),
                  (isDark ? AppColors.darkAccentGreen2 : AppColors.accentGreen1)
                      .withOpacity(0.02),
                ],
              )
            : null,
        color: !contact.isPrimary
            ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: contact.isPrimary
              ? (isDark
                    ? AppColors.darkAccentGreen1.withOpacity(0.5)
                    : AppColors.primaryGreen.withOpacity(0.5))
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          width: contact.isPrimary ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canEdit && !isGuardianContact
              ? () => _showContactActions(context, contact, isDark, ref)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar/Icon
                _buildContactAvatar(
                  isDark,
                  contact,
                  isGuardianContact,
                  isPhoneImport,
                ),
                const SizedBox(width: 14),

                // Contact Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name with badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.name,
                              style: AppTextStyles.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.lightOnSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isPrimary) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    isDark
                                        ? AppColors.darkAccentGreen1
                                        : AppColors.primaryGreen,
                                    isDark
                                        ? AppColors.darkAccentGreen2
                                        : AppColors.accentGreen1,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkBackground
                                      : Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Phone number
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              contact.phoneNumber,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.darkHint
                                    : AppColors.lightHint,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Relationship and source
                      if (contact.relationship?.isNotEmpty == true ||
                          isGuardianContact) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isGuardianContact)
                              Icon(
                                Icons.shield,
                                size: 12,
                                color: isDark
                                    ? AppColors.darkAccentGreen1
                                    : AppColors.primaryGreen,
                              )
                            else
                              Icon(
                                Icons.label_outline,
                                size: 12,
                                color: isDark
                                    ? AppColors.darkHint
                                    : AppColors.lightHint,
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isGuardianContact
                                    ? 'Guardian (Auto-added)'
                                    : contact.relationship!,
                                style: AppTextStyles.caption.copyWith(
                                  color: isGuardianContact
                                      ? (isDark
                                            ? AppColors.darkAccentGreen1
                                            : AppColors.primaryGreen)
                                      : (isDark
                                            ? AppColors.darkHint
                                            : AppColors.lightHint),
                                  fontWeight: isGuardianContact
                                      ? FontWeight.w600
                                      : FontWeight.normal,
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

                // Action button
                if (canEdit)
                  _buildActionButton(
                    context,
                    isDark,
                    contact,
                    isGuardianContact,
                    ref,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactAvatar(
    bool isDark,
    EmergencyContact contact,
    bool isGuardianContact,
    bool isPhoneImport,
  ) {
    Color backgroundColor;
    Color iconColor;
    IconData icon;

    if (isGuardianContact) {
      backgroundColor =
          (isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen)
              .withOpacity(0.15);
      iconColor = isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen;
      icon = Icons.shield;
    } else if (isPhoneImport) {
      backgroundColor = Colors.purple.withOpacity(0.15);
      iconColor = Colors.purple;
      icon = Icons.contact_phone;
    } else {
      backgroundColor = Colors.blue.withOpacity(0.15);
      iconColor = Colors.blue;
      icon = Icons.person;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor, backgroundColor.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
      ),
      child: Center(child: Icon(icon, color: iconColor, size: 24)),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    bool isDark,
    EmergencyContact contact,
    bool isGuardianContact,
    WidgetRef ref,
  ) {
    if (isGuardianContact) {
      // Guardian contacts can only be called
      return IconButton(
        icon: Icon(
          Icons.phone,
          color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
          size: 22,
        ),
        onPressed: () => _callContact(contact.phoneNumber),
        tooltip: 'Call ${contact.name}',
        style: IconButton.styleFrom(
          backgroundColor:
              (isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen)
                  .withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    // Regular contacts can be edited/deleted
    return IconButton(
      icon: Icon(
        Icons.more_vert,
        color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
        size: 22,
      ),
      onPressed: () => _showContactActions(context, contact, isDark, ref),
      tooltip: 'Options',
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? AppColors.darkDivider.withOpacity(0.3)
            : AppColors.lightDivider,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showContactActions(
    BuildContext context,
    EmergencyContact contact,
    bool isDark,
    WidgetRef ref,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Contact name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  contact.name,
                  style: AppTextStyles.h4.copyWith(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              _buildActionTile(
                context,
                isDark,
                icon: Icons.phone,
                title: 'Call',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _callContact(contact.phoneNumber);
                },
              ),
              _buildActionTile(
                context,
                isDark,
                icon: Icons.edit,
                title: 'Edit Contact',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  final result = await showAddEmergencyContactDialog(
                    context: context,
                    dependentId: dependentId,
                    existingContact: contact,
                  );
                  if (result == true) {
                    ref
                        .read(emergencyContactNotifierProvider.notifier)
                        .refresh();
                  }
                },
              ),
              _buildActionTile(
                context,
                isDark,
                icon: Icons.delete,
                title: 'Delete Contact',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deleteContact(context, contact, ref);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  void _deleteContact(
    BuildContext context,
    EmergencyContact contact,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${contact.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = dependentId != null
          ? await ref
                .read(emergencyContactNotifierProvider.notifier)
                .deleteDependentContact(contact.id)
          : await ref
                .read(emergencyContactNotifierProvider.notifier)
                .deleteContact(contact.id);

      // Success message is handled by the listener
    }
  }

  void _callContact(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showSnackbar(BuildContext context, String message, Color color) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                  ? Icons.error
                  : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
