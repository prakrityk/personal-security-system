import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';

class GuardianAddDependentScreen extends StatefulWidget {
  const GuardianAddDependentScreen({super.key});

  @override
  State<GuardianAddDependentScreen> createState() =>
      _GuardianAddDependentScreenState();
}

/// MODEL to hold each dependent form state
class DependentEntry {
  bool isExpanded;
  bool qrGenerated;

  DependentEntry({this.isExpanded = false, this.qrGenerated = false});
}

class _GuardianAddDependentScreenState
    extends State<GuardianAddDependentScreen> {
  final List<DependentEntry> _dependents = [DependentEntry(isExpanded: true)];

  void _addAnotherDependent() {
    setState(() {
      _dependents.add(DependentEntry(isExpanded: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
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
                            title: Text(
                              "Dependent ${index + 1}",
                              style: AppTextStyles.labelLarge,
                            ),
                            onExpansionChanged: (expanded) {
                              dependent.isExpanded = expanded;
                            },
                            children: [
                              _DependentForm(
                                onGenerateQr: () {
                                  setState(() {
                                    dependent.qrGenerated = true;
                                  });
                                },
                              ),

                              if (dependent.qrGenerated) ...[
                                const SizedBox(height: 20),
                                const _QrPreviewCard(),
                              ],

                              if (index == _dependents.length - 1) ...[
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text("Add another dependent"),
                                    onPressed: _addAnotherDependent,
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
                onPressed: () {
                  // TODO: Validation & navigation
                },
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
  final VoidCallback onGenerateQr;

  const _DependentForm({required this.onGenerateQr});

  @override
  State<_DependentForm> createState() => _DependentFormState();
}

class _DependentFormState extends State<_DependentForm> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        AppTextField(label: "Dependent name"),
        const SizedBox(height: 16),

        /// Dependent type dropdown
        _DependentTypeDropdown(
          value: _selectedType,
          onChanged: (value) {
            setState(() {
              _selectedType = value;
            });
          },
          isDark: isDark,
        ),

        const SizedBox(height: 16),
        AppTextField(label: "Age", keyboardType: TextInputType.number),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onGenerateQr,
            child: const Text("Generate QR"),
          ),
        ),
      ],
    );
  }
}

/// 🔹 Dropdown (Child / Elderly)
class _DependentTypeDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
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

/// 🔹 QR Preview
class _QrPreviewCard extends StatelessWidget {
  const _QrPreviewCard();

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
          const Icon(Icons.qr_code_2, size: 120, color: AppColors.primaryGreen),
          const SizedBox(height: 12),
          Text(
            "Scan now or save for later",
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
