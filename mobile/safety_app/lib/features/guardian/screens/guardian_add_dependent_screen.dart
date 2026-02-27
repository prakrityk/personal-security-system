import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    if (nameController.text.trim().isEmpty) return false;
    if (selectedType == null) return false;
    final ageText = ageController.text.trim();
    if (ageText.isEmpty) return false;
    final age = int.tryParse(ageText);
    if (age == null) return false;
    if (selectedType == 'child' && age >= 16) return false;
    if (selectedType == 'elderly' && (age < 60 || age > 120)) return false;
    return true;
  }

  /// Returns an error message if the age is invalid for the selected type, null otherwise.
  String? get ageError {
    final ageText = ageController.text.trim();
    if (ageText.isEmpty) return null;
    final age = int.tryParse(ageText);
    if (age == null) return 'Please enter a valid age';
    if (selectedType == 'child' && age >= 16) {
      return 'Child age must be below 16';
    }
    if (selectedType == 'elderly' && (age < 60 || age > 120)) {
      return 'Elderly age must be between 60 and 120';
    }
    return null;
  }

  /// Returns the appropriate label hint based on selected type.
  String get ageLabel {
    if (selectedType == 'child') return 'Age (0–15)';
    if (selectedType == 'elderly') return 'Age (60–120)';
    return 'Age';
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
      // Provide a specific error message based on the age issue
      final ageErr = dependent.ageError;
      final message = ageErr ?? 'Please fill all fields before generating QR';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
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
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'QR code generated for ${dependent.nameController.text}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.primaryGreen,
                behavior: SnackBarBehavior.floating,
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
            behavior: SnackBarBehavior.floating,
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please add at least one dependent'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
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
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
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
                    Text("Add Dependents", style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      "Add and manage the people you want to protect",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.darkHint
                            : AppColors.lightHint,
                      ),
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
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: dependent.isExpanded,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                20,
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: dependent.qrGenerated
                                          ? AppColors.primaryGreen.withOpacity(
                                              0.1,
                                            )
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      dependent.qrGenerated
                                          ? Icons.check_circle
                                          : Icons.person_add,
                                      color: dependent.qrGenerated
                                          ? AppColors.primaryGreen
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                                  onGenerateQr: () =>
                                      _generateQR(dependent, index),
                                  isLoading: _isLoading,
                                  onChanged: () => setState(() {}),
                                ),

                                if (dependent.qrGenerated &&
                                    dependent.qrToken != null) ...[
                                  const SizedBox(height: 20),
                                  _QrPreviewCard(
                                    qrToken: dependent.qrToken!,
                                    dependentName:
                                        dependent.nameController.text,
                                    dependentType:
                                        dependent.selectedType ?? 'child',
                                  ),
                                ],

                                if (index == _dependents.length - 1) ...[
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text(
                                        "Add another dependent",
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : _addAnotherDependent,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            /// Bottom button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: AnimatedBottomButton(
                label: "Continue",
                usePositioned: false,
                isEnabled: !_isLoading && _dependents.any((d) => d.qrGenerated),
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
  final VoidCallback onChanged;

  const _DependentForm({
    required this.dependent,
    required this.onGenerateQr,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  State<_DependentForm> createState() => _DependentFormState();
}

class _DependentFormState extends State<_DependentForm> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ageError = widget.dependent.ageError;

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
                    // Clear age when type changes to avoid stale invalid values
                    widget.dependent.ageController.clear();
                  });
                  widget.onChanged();
                },
          isDark: isDark,
        ),

        const SizedBox(height: 16),

        /// Age field — label and error change based on selected type
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: widget.dependent.ageLabel,
              keyboardType: TextInputType.number,
              controller: widget.dependent.ageController,
              enabled: !widget.dependent.qrGenerated,
              onChanged: (_) => setState(() {}),
            ),
            if (ageError != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      ageError,
                      style: const TextStyle(fontSize: 10, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 24),
        if (!widget.dependent.qrGenerated)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : widget.onGenerateQr,
              icon: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_2),
              label: const Text("Generate QR Code"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
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
        Text(
          "Dependent type",
          style: AppTextStyles.labelSmall.copyWith(
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
        ),
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
                DropdownMenuItem(
                  value: "child",
                  child: Row(
                    children: [
                      Icon(Icons.child_care, size: 20),
                      SizedBox(width: 8),
                      Text("Child"),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: "elderly",
                  child: Row(
                    children: [
                      Icon(Icons.elderly, size: 20),
                      SizedBox(width: 8),
                      Text("Elderly"),
                    ],
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// 🔹 QR Preview with actual QR code and Share functionality
class _QrPreviewCard extends StatefulWidget {
  final String qrToken;
  final String dependentName;
  final String dependentType;

  const _QrPreviewCard({
    required this.qrToken,
    required this.dependentName,
    required this.dependentType,
  });

  @override
  State<_QrPreviewCard> createState() => _QrPreviewCardState();
}

class _QrPreviewCardState extends State<_QrPreviewCard> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareInvitation() async {
    setState(() => _isSharing = true);

    try {
      // Create a composite image with QR code and invitation details
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.white;

      // Canvas dimensions
      const width = 600.0;
      const height = 900.0;

      // Draw white background
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

      // Draw gradient header
      final gradientPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(0, 150),
          [AppColors.primaryGreen, AppColors.accentGreen1],
        );
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, 150), gradientPaint);

      // Draw header text
      final titlePainter = TextPainter(
        text: const TextSpan(
          text: '👨‍👩‍👧 Dependent Invitation',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      titlePainter.layout(maxWidth: width - 40);
      titlePainter.paint(canvas, const Offset(20, 40));

      final subtitlePainter = TextPainter(
        text: TextSpan(
          text: 'For ${widget.dependentName}',
          style: const TextStyle(fontSize: 18, color: Colors.white70),
        ),
        textDirection: TextDirection.ltr,
      );
      subtitlePainter.layout(maxWidth: width - 40);
      subtitlePainter.paint(canvas, const Offset(20, 85));

      // Capture QR code
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not capture QR code');
      }

      final qrImage = await boundary.toImage(pixelRatio: 2.0);
      final qrByteData = await qrImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final qrPngBytes = qrByteData?.buffer.asUint8List();

      if (qrPngBytes == null) {
        throw Exception('Could not convert QR code to image');
      }

      // Decode QR image and draw it on canvas
      final codec = await ui.instantiateImageCodec(qrPngBytes);
      final frame = await codec.getNextFrame();
      final qrImageUI = frame.image;

      // Draw QR code centered with larger size
      const qrSize = 360.0;
      const qrX = (width - qrSize) / 2;
      const qrY = 170.0;
      canvas.drawImageRect(
        qrImageUI,
        Rect.fromLTWH(
          0,
          0,
          qrImageUI.width.toDouble(),
          qrImageUI.height.toDouble(),
        ),
        const Rect.fromLTWH(qrX, qrY, qrSize, qrSize),
        Paint(),
      );

      // Draw info box
      const infoBoxY = qrY + qrSize + 30;
      final infoBoxPaint = Paint()
        ..color = AppColors.primaryGreen.withOpacity(0.1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, infoBoxY, width - 80, 120),
          const Radius.circular(12),
        ),
        infoBoxPaint,
      );

      // Draw border for info box
      final borderPaint = Paint()
        ..color = AppColors.primaryGreen.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, infoBoxY, width - 80, 120),
          const Radius.circular(12),
        ),
        borderPaint,
      );

      // Draw dependent info
      final typeLabelPainter = TextPainter(
        text: const TextSpan(
          text: 'Dependent Type',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      );
      typeLabelPainter.layout();
      typeLabelPainter.paint(
        canvas,
        Offset((width - typeLabelPainter.width) / 2, infoBoxY + 20),
      );

      // Draw dependent type
      final typeIcon = widget.dependentType.toLowerCase() == 'child'
          ? '👶'
          : '👴';
      final typeText =
          widget.dependentType[0].toUpperCase() +
          widget.dependentType.substring(1);
      final typePainter = TextPainter(
        text: TextSpan(
          text: '$typeIcon $typeText',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      typePainter.layout();
      typePainter.paint(
        canvas,
        Offset((width - typePainter.width) / 2, infoBoxY + 55),
      );

      // Draw expiry note
      final expiryPainter = TextPainter(
        text: const TextSpan(
          text: 'Expires in 3 days',
          style: TextStyle(
            fontSize: 13,
            color: Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      expiryPainter.layout();
      expiryPainter.paint(
        canvas,
        Offset((width - expiryPainter.width) / 2, infoBoxY + 90),
      );

      // Draw instructions
      const instructionsY = infoBoxY + 150;
      final instructionsPainter = TextPainter(
        text: const TextSpan(
          text:
              'Steps to Join:\n'
              '1. Download Safety App\n'
              '2. Select "Dependent" role\n'
              '3. Scan this QR code\n'
              '4. Complete registration\n\n'
              'Keep this QR code safe!',
          style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      instructionsPainter.layout(maxWidth: width - 80);
      instructionsPainter.paint(
        canvas,
        Offset((width - instructionsPainter.width) / 2, instructionsY),
      );

      // Convert canvas to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final imgByteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final imgPngBytes = imgByteData!.buffer.asUint8List();

      // Save composite image
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'SafetyApp_Dependent_${widget.dependentName.replaceAll(' ', '_')}_$timestamp.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imgPngBytes);

      // Create message (for apps that support it)
      final message =
          '''
👨‍👩‍👧 Dependent Invitation

You've been invited to join Safety App as a dependent!

Dependent Name: ${widget.dependentName}
Type: ${widget.dependentType[0].toUpperCase()}${widget.dependentType.substring(1)}

📱 Steps to join:
1. Download the Safety App
2. Select "Dependent" role
3. Scan the QR code (in the image)
4. Complete your registration

⏰ This QR code expires in 3 days

Download the Safety App and scan the code to get started!
''';

      // Share with both text message AND composite image
      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
        subject:
            'Safety App - Dependent Invitation for ${widget.dependentName}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Invitation shared successfully!'),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withOpacity(0.1),
            AppColors.accentGreen1.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Success icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Actual QR Code
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: widget.qrToken,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.primaryGreen,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "QR Code Generated Successfully!",
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Scan now or save for later",
            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "This QR code will expire in 3 days",
            style: AppTextStyles.caption.copyWith(
              color: Colors.grey,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Share Invitation Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSharing ? null : _shareInvitation,
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.share_rounded, size: 20),
              label: Text(_isSharing ? 'Preparing...' : 'Share Invitation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                disabledBackgroundColor: AppColors.primaryGreen.withOpacity(
                  0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
