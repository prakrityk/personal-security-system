// lib/features/guardian/screens/collaborator_join_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mobile_scanner;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:safety_app/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:safety_app/services/collaborator_service.dart';

class CollaboratorJoinScreen extends StatefulWidget {
  const CollaboratorJoinScreen({super.key});

  @override
  State<CollaboratorJoinScreen> createState() => _CollaboratorJoinScreenState();
}

class _CollaboratorJoinScreenState extends State<CollaboratorJoinScreen> {
  final CollaboratorService _collaboratorService = CollaboratorService();
  final TextEditingController _codeController = TextEditingController();

  // Camera scanner - for live scanning only
  late final mobile_scanner.MobileScannerController _cameraController;

  // ML Kit barcode scanner - for gallery images only
  late final BarcodeScanner _barcodeScanner;

  bool _isProcessing = false;
  bool _cameraStarted = false;
  bool _showManualEntry = false;
  String? _scannedCode;

  @override
  void initState() {
    super.initState();

    // Initialize camera scanner
    _cameraController = mobile_scanner.MobileScannerController(
      detectionSpeed: mobile_scanner.DetectionSpeed.noDuplicates,
      formats: [mobile_scanner.BarcodeFormat.qrCode],
    );

    // Initialize ML Kit barcode scanner for gallery images
    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

    _startCamera();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _barcodeScanner.close();
    _codeController.dispose();
    super.dispose();
  }

  void _startCamera() {
    setState(() => _cameraStarted = true);
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;

    try {
      final ImagePicker picker = ImagePicker();

      print('🖼️ Opening gallery...');
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );

      if (image == null) {
        print('❌ User cancelled image selection');
        return;
      }

      setState(() => _isProcessing = true);

      print('🔍 Analyzing image: ${image.path}');

      try {
        final inputImage = InputImage.fromFilePath(image.path);
        final List<Barcode> barcodes = await _barcodeScanner.processImage(
          inputImage,
        );

        if (barcodes.isNotEmpty) {
          final String? qrCode = barcodes.first.rawValue;

          if (qrCode != null && qrCode.isNotEmpty) {
            print('✅ QR code found in image');
            await _handleCodeScanned(qrCode);
          } else {
            print('❌ QR code data is empty');
            _showError('QR code data is empty');
          }
        } else {
          print('❌ No barcodes found in image');
          _showError(
            'No QR code found in the image. Please try a clearer image.',
          );
        }
      } catch (e) {
        print('❌ ML Kit analysis error: $e');
        _showError('Failed to analyze image: ${e.toString()}');
      }
    } catch (e) {
      print('❌ Gallery picker error: $e');
      if (mounted) {
        _showError('Failed to pick image: ${e.toString()}');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleCodeScanned(String code) async {
    print(
      '🔍 Processing code: ${code.substring(0, code.length > 20 ? 20 : code.length)}...',
    );

    if (_isProcessing && _scannedCode != null) {
      print('⚠️ Already processing another code');
      return;
    }

    setState(() {
      _isProcessing = true;
      _scannedCode = code;
    });

    try {
      // Strip "COLLAB:" prefix if present
      final cleanCode = code.replaceAll('COLLAB:', '').trim();

      // Validate invitation first
      print('📞 Validating invitation...');
      final validationResponse = await _collaboratorService.validateInvitation(
        cleanCode,
      );

      if (mounted) {
        // Check if valid
        final bool isValid = validationResponse['valid'] ?? false;

        if (!isValid) {
          final String message =
              validationResponse['message'] ?? 'Invalid invitation code';
          throw Exception(message);
        }

        // Show confirmation dialog with dependent info
        final bool? confirmed = await _showConfirmationDialog(
          validationResponse,
        );

        if (confirmed == true) {
          // Accept the invitation
          print('📞 Accepting invitation...');
          final acceptResponse = await _collaboratorService.acceptInvitation(
            cleanCode,
          );

          if (mounted) {
            _showSuccessDialog(acceptResponse);
          }
        } else {
          setState(() {
            _isProcessing = false;
            _scannedCode = null;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in _handleCodeScanned:');
      print('  Error: $e');
      print('  Stack Trace: $stackTrace');

      if (mounted) {
        String errorMessage = 'Failed to process invitation code';

        if (e.toString().contains('Invalid invitation')) {
          errorMessage = 'Invalid invitation code. Please try again.';
        } else if (e.toString().contains('expired')) {
          errorMessage =
              'This invitation has expired. Please ask for a new one.';
        } else if (e.toString().contains('already been used')) {
          errorMessage = 'This invitation has already been used.';
        } else if (e.toString().contains('already a guardian')) {
          errorMessage = 'You are already a guardian for this dependent.';
        } else if (e.toString().contains('Network is unreachable')) {
          errorMessage = 'No internet connection. Please check your network.';
        }

        print('⚠️ Showing error: $errorMessage');
        _showError(errorMessage);

        setState(() {
          _isProcessing = false;
          _scannedCode = null;
        });
      }
    }
  }

  Future<bool?> _showConfirmationDialog(
    Map<String, dynamic> validationData,
  ) async {
    final String dependentName = validationData['dependent_name'] ?? 'Unknown';
    final int? age = validationData['dependent_age'];
    final String? relation = validationData['relation'];
    final String primaryGuardianName =
        validationData['primary_guardian_name'] ?? 'Unknown';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Join as Collaborator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to join as a collaborator guardian for:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Dependent:', value: dependentName),
                  if (age != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Age:', value: '$age years old'),
                  ],
                  if (relation != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Type:', value: relation.toUpperCase()),
                  ],
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Primary Guardian:',
                    value: primaryGuardianName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'As a collaborator, you\'ll have view-only access to safety features.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Join as Collaborator'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> acceptResponse) {
    final String dependentName =
        acceptResponse['dependent_name'] ?? 'dependent';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.primaryGreen,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Success!')),
          ],
        ),
        content: Text(
          'You\'ve successfully joined as a collaborator guardian for $dependentName!',
          style: AppTextStyles.body,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(
                AppRouter.home,
              ); // ✅ Uses AppRouter constant/ Navigate to home with Family tab
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Go to Family'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitManualCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showError('Please enter an invitation code');
      return;
    }

    await _handleCodeScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Join as Collaborator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Join as Collaborator Guardian",
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Scan the QR code or enter the invitation code shared by the primary guardian",
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 32),

                    // Tab selector
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              label: 'Scan QR',
                              icon: Icons.qr_code_scanner,
                              isSelected: !_showManualEntry,
                              onTap: () {
                                setState(() => _showManualEntry = false);
                              },
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              label: 'Enter Code',
                              icon: Icons.edit,
                              isSelected: _showManualEntry,
                              onTap: () {
                                setState(() => _showManualEntry = true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (!_showManualEntry) ...[
                      // QR Scanner
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryGreen,
                                  width: 3,
                                ),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: _cameraStarted
                                  ? mobile_scanner.MobileScanner(
                                      controller: _cameraController,
                                      onDetect: (capture) {
                                        if (_isProcessing) return;

                                        final List<mobile_scanner.Barcode>
                                        barcodes = capture.barcodes;
                                        for (final barcode in barcodes) {
                                          if (barcode.rawValue != null) {
                                            print('📷 Camera detected code');
                                            _handleCodeScanned(
                                              barcode.rawValue!,
                                            );
                                            break;
                                          }
                                        }
                                      },
                                    )
                                  : Container(
                                      color: Colors.black,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                    ),
                            ),

                            // Processing overlay
                            if (_isProcessing)
                              Container(
                                width: 300,
                                height: 300,
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _getProcessingMessage(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                            // Scanning frame indicator
                            if (!_isProcessing && _cameraStarted)
                              IgnorePointer(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.primaryGreen,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Upload from gallery option
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text("Upload QR from gallery"),
                          onPressed: _isProcessing
                              ? null
                              : _pickImageFromGallery,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Manual code entry
                      Text(
                        "Enter Invitation Code",
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: 'Enter code (e.g., ABC123XYZ789)',
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                Clipboard.kTextPlain,
                              );
                              if (data?.text != null) {
                                _codeController.text = data!.text!;
                              }
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_isProcessing,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _submitManualCode,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Join'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProcessingMessage() {
    if (_scannedCode == null) {
      return 'Analyzing...';
    } else {
      return 'Validating invitation...\nPlease wait';
    }
  }
}

// Helper widget for tab buttons
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for info rows in confirmation dialog
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
