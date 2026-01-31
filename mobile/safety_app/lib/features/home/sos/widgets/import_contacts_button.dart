// lib/features/home/sos/widgets/import_contacts_button.dart
// FIXED - Import Contacts Button with callback support

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/features/home/sos/screens/contact_picker_screen.dart';
import 'package:safety_app/services/contact_import_service.dart';
import 'package:safety_app/core/providers/emergency_contact_provider.dart';

class ImportContactsButton extends ConsumerWidget {
  // ✅ ADDED: Support for both old and new usage patterns
  final bool isForDependent;
  final int? dependentId;
  final VoidCallback? onImportComplete;

  // ✅ NEW: Direct callback for individual contact selection
  final Function(Map<String, dynamic>)? onContactSelected;

  // ✅ NEW: Custom button styling
  final String? buttonText;
  final bool isDark;
  final bool isCompact;

  const ImportContactsButton({
    super.key,
    this.isForDependent = false,
    this.dependentId,
    this.onImportComplete,
    this.onContactSelected,
    this.buttonText,
    this.isDark = false,
    this.isCompact = false,
  });

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final contactService = ContactImportService();

    // Check permission
    final hasPermission = await contactService.checkContactsPermission();

    if (!hasPermission) {
      // Show permission explanation dialog
      final shouldRequest = await _showPermissionDialog(context);
      if (shouldRequest != true) return;

      // Request permission
      final granted = await contactService.requestContactsPermission();
      if (!granted) {
        if (!context.mounted) return;
        _showPermissionDeniedDialog(context);
        return;
      }
    }

    // Get existing contacts
    final state = ref.read(emergencyContactNotifierProvider);
    final existingContacts = state.contacts;

    // Navigate to contact picker
    if (!context.mounted) return;

    // ✅ NEW: If using direct callback, pass it through
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactPickerScreen(
          isForDependent: isForDependent,
          dependentId: dependentId,
          existingContacts: existingContacts,
          onContactSelected: onContactSelected, // ✅ Pass the callback
        ),
      ),
    );

    // Refresh contacts if import was successful
    if (result == true) {
      final notifier = ref.read(emergencyContactNotifierProvider.notifier);
      await notifier.refresh();
      onImportComplete?.call();
    }
  }

  Future<bool?> _showPermissionDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDarkMode
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.contacts, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Access Contacts',
                style: TextStyle(
                  color: isDarkMode
                      ? AppColors.darkOnSurface
                      : AppColors.lightOnSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This app needs access to your contacts to import them as emergency contacts.\n\n'
          'Your contacts are only used locally and are not shared with anyone.',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.darkOnSurface
                : AppColors.lightOnSurface,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode
                  ? AppColors.darkOnSurface
                  : AppColors.lightOnSurface,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              foregroundColor: isDarkMode
                  ? AppColors.darkBackground
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDarkMode
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Permission Denied',
                style: TextStyle(
                  color: isDarkMode
                      ? AppColors.darkOnSurface
                      : AppColors.lightOnSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Contacts permission is required to import contacts.\n\n'
          'Please enable it in your device settings:\n'
          'Settings → Apps → Safety App → Permissions → Contacts',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.darkOnSurface
                : AppColors.lightOnSurface,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              foregroundColor: isDarkMode
                  ? AppColors.darkBackground
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode =
        isDark || Theme.of(context).brightness == Brightness.dark;

    // ✅ Support compact mode for use in rows
    if (isCompact) {
      return OutlinedButton.icon(
        onPressed: () => _handleImport(context, ref),
        icon: const Icon(Icons.contact_phone, size: 18),
        label: Text(buttonText ?? 'Import'),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDarkMode
              ? AppColors.darkAccentGreen1
              : AppColors.primaryGreen,
          side: BorderSide(
            color: isDarkMode
                ? AppColors.darkAccentGreen1
                : AppColors.primaryGreen,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    // Default full-width button
    return OutlinedButton.icon(
      onPressed: () => _handleImport(context, ref),
      icon: const Icon(Icons.contact_phone, size: 18),
      label: Text(buttonText ?? 'Import'),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDarkMode
            ? AppColors.darkAccentGreen1
            : AppColors.primaryGreen,
        side: BorderSide(
          color: isDarkMode
              ? AppColors.darkAccentGreen1
              : AppColors.primaryGreen,
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
