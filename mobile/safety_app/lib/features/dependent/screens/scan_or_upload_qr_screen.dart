import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as mobile_scanner;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:safety_app/services/dependent_service.dart';
import 'package:safety_app/features/dependent/screens/dependent_type_selection_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ScanOrUploadQrScreen extends StatefulWidget {
  final DependentType dependentType;

  const ScanOrUploadQrScreen({super.key, required this.dependentType});

  @override
  State<ScanOrUploadQrScreen> createState() => _ScanOrUploadQrScreenState();
}

class _ScanOrUploadQrScreenState extends State<ScanOrUploadQrScreen> {
  final DependentService _dependentService = DependentService();

  late final mobile_scanner.MobileScannerController _cameraController;
  late final BarcodeScanner _barcodeScanner;

  bool _isProcessing = false;
  String? _scannedCode;
  bool _cameraStarted = false;

  @override
  void initState() {
    super.initState();

    _cameraController = mobile_scanner.MobileScannerController(
      detectionSpeed: mobile_scanner.DetectionSpeed.noDuplicates,
      formats: [mobile_scanner.BarcodeFormat.qrCode],
    );

    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    _startCamera();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  void _startCamera() {
    setState(() => _cameraStarted = true);
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isProcessing = true);

      try {
        final inputImage = InputImage.fromFilePath(image.path);
        final List<Barcode> barcodes = await _barcodeScanner.processImage(
          inputImage,
        );

        if (barcodes.isNotEmpty) {
          final String? qrCode = barcodes.first.rawValue;

          if (qrCode != null && qrCode.isNotEmpty) {
            await _handleQRScanned(qrCode);
          } else {
            _handleImageScanError('QR code data is empty');
          }
        } else {
          _handleImageScanError(
            'No QR code found. Please try a clearer image.',
          );
        }
      } catch (e) {
        _handleImageScanError('Failed to analyze image: ${e.toString()}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to pick image: ${e.toString()}');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleQRScanned(String qrCode) async {
    if (_isProcessing && _scannedCode != null) return;

    setState(() {
      _isProcessing = true;
      _scannedCode = qrCode;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final response = await _dependentService.scanQRCode(qrCode);

      if (mounted) {
        _showSuccessDialog(
          guardianName: response['guardian_name'] ?? 'Guardian',
          relation: response['relation'] ?? 'guardian',
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to link with guardian';

        if (e.toString().contains('Invalid QR code')) {
          errorMessage = 'Invalid QR code. Please try again.';
        } else if (e.toString().contains('expired')) {
          errorMessage =
              'This QR code has expired. Ask your guardian for a new one.';
        } else if (e.toString().contains('already been')) {
          errorMessage = 'This QR code has already been used.';
        } else if (e.toString().contains('Network is unreachable')) {
          errorMessage = 'No internet connection. Please check your network.';
        }

        _showErrorSnackbar(errorMessage);
        setState(() {
          _isProcessing = false;
          _scannedCode = null;
        });
      }
    }
  }

  void _handleImageScanError(String message) {
    if (mounted) {
      _showErrorSnackbar(message);
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog({
    required String guardianName,
    required String relation,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen.withOpacity(0.2),
                      AppColors.accentGreen1.withOpacity(0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.primaryGreen,
                  size: 64,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Successfully Linked!',
                style: AppTextStyles.h3.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.lightOnSurface,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'You are now protected by',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      guardianName,
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      relation,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkHint
                            : AppColors.lightHint,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                  child: const Text('Go to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
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
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryGreen.withOpacity(0.1),
                            AppColors.accentGreen1.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner,
                              color: AppColors.primaryGreen,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Scan Guardian QR Code',
                            style: AppTextStyles.h3,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Position the QR code from your guardian within the frame',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.darkHint
                                  : AppColors.lightHint,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Camera Scanner
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primaryGreen,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: _cameraStarted
                                ? mobile_scanner.MobileScanner(
                                    controller: _cameraController,
                                    onDetect: (capture) {
                                      if (_isProcessing) return;

                                      final barcodes = capture.barcodes;
                                      for (final barcode in barcodes) {
                                        if (barcode.rawValue != null) {
                                          _handleQRScanned(barcode.rawValue!);
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
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _scannedCode == null
                                        ? 'Analyzing...'
                                        : 'Linking with guardian...',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                          // Scanning frame
                          if (!_isProcessing && _cameraStarted)
                            IgnorePointer(
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.primaryGreen,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Upload button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload QR from Gallery'),
                        onPressed: _isProcessing ? null : _pickImageFromGallery,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'QR codes expire after 3 days. Ask your guardian for a new one if needed.',
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? AppColors.darkHint
                                    : AppColors.lightHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getProcessingMessage() {
    if (_scannedCode == null) {
      return 'Analyzing image...';
    } else {
      return 'Linking with guardian...\nPlease wait';
    }
  }
}
