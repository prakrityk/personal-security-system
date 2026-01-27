import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/models/pending_dependent_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/guardian_provider.dart';

class GuardianAddDependentScreen extends ConsumerStatefulWidget {
  const GuardianAddDependentScreen({super.key});

  @override
  ConsumerState<GuardianAddDependentScreen> createState() =>
      _GuardianAddDependentScreenState();
}

/// MODEL to hold each dependent form state
class DependentEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  String? selectedType;
  bool isExpanded;
  bool qrGenerated;
  String? qrToken;
  int? pendingDependentId;

  DependentEntry({this.isExpanded = false, this.qrGenerated = false});

  void dispose() {
    nameController.dispose();
    ageController.dispose();
  }

  bool get isValid {
    return nameController.text.trim().isNotEmpty &&
        selectedType != null &&
        ageController.text.trim().isNotEmpty &&
        int.tryParse(ageController.text.trim()) != null;
  }

  PendingDependentCreate toModel() {
    return PendingDependentCreate(
      dependentName: nameController.text.trim(),
      relation: selectedType!,
      age: int.parse(ageController.text.trim()),
    );
  }
}

class _GuardianAddDependentScreenState
    extends ConsumerState<GuardianAddDependentScreen> {
  final List<DependentEntry> _dependents = [DependentEntry(isExpanded: true)];
  bool _isLoading = false;

  @override
  void dispose() {
    for (var dependent in _dependents) {
      dependent.dispose();
    }
    super.dispose();
  }

  void _addAnotherDependent() {
    setState(() {
      _dependents.add(DependentEntry(isExpanded: true));
    });
  }

  void _removeDependent(int index) {
    setState(() {
      _dependents[index].dispose();
      _dependents.removeAt(index);
    });
  }

  Future<void> _generateQR(DependentEntry dependent, int index) async {
    if (!dependent.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields before generating QR'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(pendingDependentsNotifierProvider.notifier);

      // Create pending dependent first
      final response = await notifier.createDependent(dependent.toModel());

      if (response != null) {
        // Generate QR code
        final qrResponse = await notifier.generateQR(response.id);

        if (qrResponse != null) {
          setState(() {
            dependent.qrGenerated = true;
            dependent.qrToken = qrResponse.qrToken;
            dependent.pendingDependentId = response.id;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'QR code generated for ${dependent.nameController.text}',
                ),
                backgroundColor: AppColors.primaryGreen,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continue() async {
    // Check if at least one dependent has been added
    final hasAtLeastOne = _dependents.any((d) => d.qrGenerated);

    if (!hasAtLeastOne) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one dependent'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to next screen (e.g., guardian home or dashboard)
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Add Dependents'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            /// Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add Dependents", style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text(
                      "Add and manage the people you want to protect",
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 32),

                    /// Dependents list
                    ListView.builder(
                      itemCount: _dependents.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final dependent = _dependents[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: dependent.isExpanded,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              16,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dependent.nameController.text.isEmpty
                                        ? "Dependent ${index + 1}"
                                        : dependent.nameController.text,
                                    style: AppTextStyles.labelLarge,
                                  ),
                                ),
                                if (_dependents.length > 1 &&
                                    !dependent.qrGenerated)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () => _removeDependent(index),
                                    color: Colors.red,
                                  ),
                              ],
                            ),
                            onExpansionChanged: (expanded) {
                              setState(() {
                                dependent.isExpanded = expanded;
                              });
                            },
                            children: [
                              _DependentForm(
                                dependent: dependent,
                                onGenerateQr: () => _generateQR(dependent, index),
                                isLoading: _isLoading,
                              ),

                              if (dependent.qrGenerated &&
                                  dependent.qrToken != null) ...[
                                const SizedBox(height: 20),
                                _QrPreviewCard(qrToken: dependent.qrToken!),
                              ],

                              if (index == _dependents.length - 1) ...[
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text("Add another dependent"),
                                    onPressed:
                                        _isLoading ? null : _addAnotherDependent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            /// Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: "Continue",
                usePositioned: false,
                isEnabled: !_isLoading &&
                    _dependents.any((d) => d.qrGenerated),
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 Dependent Form
class _DependentForm extends StatefulWidget {
  final DependentEntry dependent;
  final VoidCallback onGenerateQr;
  final bool isLoading;

  const _DependentForm({
    required this.dependent,
    required this.onGenerateQr,
    required this.isLoading,
  });

  @override
  State<_DependentForm> createState() => _DependentFormState();
}

class _DependentFormState extends State<_DependentForm> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        AppTextField(
          label: "Dependent name",
          controller: widget.dependent.nameController,
          enabled: !widget.dependent.qrGenerated,
        ),
        const SizedBox(height: 16),

        /// Dependent type dropdown
        _DependentTypeDropdown(
          value: widget.dependent.selectedType,
          onChanged: widget.dependent.qrGenerated
              ? null
              : (value) {
                  setState(() {
                    widget.dependent.selectedType = value;
                  });
                },
          isDark: isDark,
        ),

        const SizedBox(height: 16),
        AppTextField(
          label: "Age",
          keyboardType: TextInputType.number,
          controller: widget.dependent.ageController,
          enabled: !widget.dependent.qrGenerated,
        ),

        const SizedBox(height: 24),
        if (!widget.dependent.qrGenerated)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onGenerateQr,
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Generate QR"),
            ),
          ),
      ],
    );
  }
}

/// 🔹 Dropdown (Child / Elderly)
class _DependentTypeDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool isDark;

  const _DependentTypeDropdown({
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Dependent type", style: AppTextStyles.labelSmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                "Select type",
                style: TextStyle(
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: "child", child: Text("Child")),
                DropdownMenuItem(value: "elderly", child: Text("Elderly")),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// 🔹 QR Preview with actual QR code
class _QrPreviewCard extends StatelessWidget {
  final String qrToken;

  const _QrPreviewCard({required this.qrToken});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.primaryGreen.withOpacity(0.08),
      ),
      child: Column(
        children: [
          // Actual QR Code
          QrImageView(
            data: qrToken,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            "Scan now or save for later",
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "This QR code will expire in 3 days",
            style: AppTextStyles.caption.copyWith(
              color: Colors.grey,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}