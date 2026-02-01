// lib/widgets/emergency_contacts/add_emergency_contact_dialog.dart
// ✅ CORRECTED VERSION
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/emergency_contact_provider.dart';
import 'package:safety_app/models/emergency_contact.dart';

class AddEmergencyContactDialog extends ConsumerStatefulWidget {
  final int? dependentId;
  final EmergencyContact? existingContact;

  const AddEmergencyContactDialog({
    super.key,
    this.dependentId,
    this.existingContact,
  });

  @override
  ConsumerState<AddEmergencyContactDialog> createState() =>
      _AddEmergencyContactDialogState();
}

class _AddEmergencyContactDialogState
    extends ConsumerState<AddEmergencyContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedRelationship = 'Friend';
  bool _isSubmitting = false;

  final List<String> _relationships = [
    'Friend',
    'Family Member',
    'Parent',
    'Sibling',
    'Spouse',
    'Child',
    'Colleague',
    'Neighbor',
    'Doctor',
    'Caregiver',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingContact != null) {
      _nameController.text = widget.existingContact!.name;
      _phoneController.text = widget.existingContact!.phoneNumber;
      _emailController.text = widget.existingContact!.email ?? '';
      // ✅ FIXED: Check for null and non-empty
      if (widget.existingContact!.relationship != null &&
          widget.existingContact!.relationship!.isNotEmpty) {
        _selectedRelationship = widget.existingContact!.relationship!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a phone number';
    }

    final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+')) {
      if (cleaned.length < 10) {
        return 'Please enter a valid phone number';
      }
    } else {
      if (cleaned.length < 10) {
        return 'Phone number must be at least 10 digits';
      }
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    if (cleaned.startsWith('977') && cleaned.length > 10) {
      return '+$cleaned';
    }

    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    return '+977$cleaned';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(emergencyContactNotifierProvider.notifier);
      final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

      if (widget.existingContact != null) {
        // Update existing contact
        final updateData = UpdateEmergencyContact(
          id: widget.existingContact!.id, // ✅ FIXED: Removed ! after id
          name: _nameController.text.trim(),
          phoneNumber: formattedPhone,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          relationship: _selectedRelationship,
        );

        final success = widget.dependentId != null
            ? await notifier.updateDependentContact(updateData)
            : await notifier.updateContact(updateData);

        if (success && mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Contact updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Add new contact
        final contactData = CreateEmergencyContact(
          name: _nameController.text.trim(),
          phoneNumber: formattedPhone,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          relationship: _selectedRelationship,
          dependentId: widget.dependentId,
        );

        final success = widget.dependentId != null
            ? await notifier.addDependentContact(
                widget.dependentId!,
                contactData,
              )
            : await notifier.addMyContact(contactData);

        if (success && mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Contact added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.existingContact != null ? Icons.edit : Icons.add,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existingContact != null
                            ? 'Edit Emergency Contact'
                            : 'Add Emergency Contact',
                        style: AppTextStyles.h4,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Enter contact name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateName,
                  textCapitalization: TextCapitalization.words,
                  enabled: !_isSubmitting,
                ),

                const SizedBox(height: 16),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '+977 98XXXXXXXX',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Will be formatted with country code (+977)',
                    helperMaxLines: 2,
                  ),
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  enabled: !_isSubmitting,
                ),

                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email (Optional)',
                    hintText: 'contact@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isSubmitting,
                ),

                const SizedBox(height: 16),

                // Relationship Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRelationship,
                  decoration: InputDecoration(
                    labelText: 'Relationship',
                    prefixIcon: const Icon(Icons.people_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _relationships.map((relationship) {
                    return DropdownMenuItem(
                      value: relationship,
                      child: Text(relationship),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _selectedRelationship = value!;
                          });
                        },
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.existingContact != null
                                    ? 'Update'
                                    : 'Add',
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
    );
  }
}

// Helper function
Future<bool?> showAddEmergencyContactDialog({
  required BuildContext context,
  int? dependentId,
  EmergencyContact? existingContact,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AddEmergencyContactDialog(
      dependentId: dependentId,
      existingContact: existingContact,
    ),
  );
}