// lib/screens/emergency_contacts/contact_picker_screen.dart
// UPDATED - Supports both bulk selection and individual callback

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/services/contact_import_service.dart';
import 'package:safety_app/core/providers/emergency_contact_provider.dart';

class ContactPickerScreen extends ConsumerStatefulWidget {
  final bool isForDependent;
  final int? dependentId;
  final List<dynamic> existingContacts;

  // ✅ NEW: Optional callback for individual contact selection
  // When provided, screen behaves differently (single-select mode)
  final Function(Map<String, dynamic>)? onContactSelected;

  const ContactPickerScreen({
    super.key,
    this.isForDependent = false,
    this.dependentId,
    this.existingContacts = const [],
    this.onContactSelected, // ✅ NEW parameter
  });

  @override
  ConsumerState<ContactPickerScreen> createState() =>
      _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final ContactImportService _contactService = ContactImportService();
  final TextEditingController _searchController = TextEditingController();

  List<PhoneContactModel> _allContacts = [];
  List<PhoneContactModel> _filteredContacts = [];
  Set<PhoneContactModel> _selectedContacts = {};

  bool _isLoading = true;
  String _errorMessage = '';
  bool _showDuplicatesOnly = false;

  // ✅ NEW: Check if in single-select mode (callback provided)
  bool get _isSingleSelectMode => widget.onContactSelected != null;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final contacts = await _contactService.getPhoneContacts();
      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredContacts = _allContacts.where((contact) {
          return contact.displayName.toLowerCase().contains(lowerQuery) ||
              (contact.phoneNumber?.contains(lowerQuery) ?? false) ||
              (contact.email?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }

      if (_showDuplicatesOnly) {
        _filteredContacts = _filteredContacts.where((contact) {
          return !_contactService.isDuplicate(contact, widget.existingContacts);
        }).toList();
      }
    });
  }

  void _toggleDuplicateFilter() {
    setState(() {
      _showDuplicatesOnly = !_showDuplicatesOnly;
      _filterContacts(_searchController.text);
    });
  }

  bool _isDuplicate(PhoneContactModel contact) {
    return _contactService.isDuplicate(contact, widget.existingContacts);
  }

  void _toggleSelection(PhoneContactModel contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  // ✅ NEW: Handle contact tap (different behavior based on mode)
  void _handleContactTap(PhoneContactModel contact) {
    if (_isDuplicate(contact)) return; // Don't allow selecting duplicates

    if (_isSingleSelectMode) {
      // Single-select mode: immediately use callback and close
      _handleSingleSelection(contact);
    } else {
      // Multi-select mode: toggle checkbox
      _toggleSelection(contact);
    }
  }

  // ✅ NEW: Handle single contact selection with callback
  Future<void> _handleSingleSelection(PhoneContactModel contact) async {
    final relationship = await _showRelationshipDialog();
    if (relationship == null) return;

    final contactMap = {
      'name': contact.displayName,
      'phone': contact.phoneNumber ?? '',
      'email': contact.email ?? '',
      'relationship': relationship,
    };

    // Send data to parent (parent will handle API)
    widget.onContactSelected!(contactMap);

    // Close picker WITHOUT returning true
    if (mounted) {
      Navigator.of(context).pop(); // ✅ FIX
    }
  }

  void _selectAll() {
    setState(() {
      _selectedContacts = Set.from(
        _filteredContacts.where((contact) => !_isDuplicate(contact)),
      );
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedContacts.clear();
    });
  }

  Future<void> _importSelected() async {
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    // Show relationship dialog
    final relationship = await _showRelationshipDialog();
    if (relationship == null) return;

    // Convert to emergency contact format
    final contactsToImport = _selectedContacts.map((contact) {
      return contact.toEmergencyContactJson(
        relationship: relationship,
        priority: 2,
      );
    }).toList();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Import contacts
      final notifier = ref.read(emergencyContactNotifierProvider.notifier);
      final success = await notifier.bulkImportContacts(contactsToImport);

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        // Close picker screen
        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Imported ${_selectedContacts.length} contacts'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to import contacts'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _showRelationshipDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String selectedRelationship = 'Friend';
        final relationships = [
          'Friend',
          'Family Member',
          'Colleague',
          'Neighbor',
          'Other',
        ];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Relationship'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: relationships.map((relationship) {
                  return RadioListTile<String>(
                    title: Text(relationship),
                    value: relationship,
                    groupValue: selectedRelationship,
                    onChanged: (value) {
                      setState(() {
                        selectedRelationship = value!;
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(selectedRelationship),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSingleSelectMode ? 'Select Contact' : 'Import Contacts'),
        actions: [
          // ✅ Only show clear button in multi-select mode
          if (!_isSingleSelectMode && _selectedContacts.isNotEmpty)
            TextButton.icon(
              onPressed: _deselectAll,
              icon: const Icon(Icons.clear, color: Colors.white),
              label: Text(
                'Clear (${_selectedContacts.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterContacts('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _filterContacts,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Hide duplicates'),
                      selected: _showDuplicatesOnly,
                      onSelected: (_) => _toggleDuplicateFilter(),
                    ),
                    // ✅ Only show select all in multi-select mode
                    if (!_isSingleSelectMode) ...[
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _filteredContacts.isEmpty
                            ? null
                            : _selectAll,
                        icon: const Icon(Icons.select_all),
                        label: const Text('Select All'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Contact list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _filteredContacts.isEmpty
                ? _buildEmptyState()
                : _buildContactList(),
          ),
        ],
      ),
      // ✅ Only show import button in multi-select mode
      bottomNavigationBar: !_isSingleSelectMode && _selectedContacts.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _importSelected,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Text(
                    'Import ${_selectedContacts.length} Contact${_selectedContacts.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContactList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final isSelected = _selectedContacts.contains(contact);
        final isDuplicate = _isDuplicate(contact);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isSelected
                ? Theme.of(context).primaryColor
                : (isDark ? Colors.grey[700] : Colors.grey[300]),
            child: Text(
              contact.displayName[0].toUpperCase(),
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            contact.displayName,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDuplicate
                  ? Colors.grey
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.phoneNumber != null)
                Text(
                  contact.phoneNumber!,
                  style: TextStyle(
                    color: isDuplicate
                        ? Colors.grey
                        : (isDark ? Colors.grey[400] : Colors.black54),
                  ),
                ),
              if (contact.email != null)
                Text(
                  contact.email!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDuplicate
                        ? Colors.grey
                        : (isDark ? Colors.grey[500] : Colors.black45),
                  ),
                ),
              if (isDuplicate)
                const Text(
                  'Already in emergency contacts',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          // ✅ Show arrow in single-select mode, checkbox in multi-select mode
          trailing: _isSingleSelectMode
              ? (isDuplicate
                    ? null
                    : const Icon(Icons.arrow_forward_ios, size: 16))
              : Checkbox(
                  value: isSelected,
                  onChanged: isDuplicate
                      ? null
                      : (_) => _handleContactTap(contact),
                ),
          onTap: isDuplicate ? null : () => _handleContactTap(contact),
          enabled: !isDuplicate,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts found',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try a different search'
                : 'No contacts available to import',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDark ? Colors.red[400] : Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading contacts',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadContacts,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
