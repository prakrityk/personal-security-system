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

  // Camera scanner - for live scanning only
  late final mobile_scanner.MobileScannerController _cameraController;

  // ML Kit barcode scanner - for gallery images only
  late final BarcodeScanner _barcodeScanner;

  bool _isProcessing = false;
  String? _scannedCode;
  bool _cameraStarted = false;

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
            final displayText = qrCode.length > 20
                ? '${qrCode.substring(0, 20)}...'
                : qrCode;
            print('✅ QR code found in image: $displayText');
            print('🚀 Calling _handleQRScanned...');

            // Call the method and catch any errors
            try {
              await _handleQRScanned(qrCode);
            } catch (e, stackTrace) {
              print('❌ ERROR in gallery scan flow:');
              print('  Error: $e');
              print('  Stack Trace: $stackTrace');
              _handleImageScanError(
                'Failed to process QR code: ${e.toString()}',
              );
            }
          } else {
            print('❌ QR code data is empty');
            _handleImageScanError('QR code data is empty');
          }
        } else {
          print('❌ No barcodes found in image');
          _handleImageScanError(
            'No QR code found in the image. Please try a clearer image.',
          );
        }
      } catch (e) {
        print('❌ ML Kit analysis error: $e');
        _handleImageScanError('Failed to analyze image: ${e.toString()}');
      }
    } catch (e) {
      print('❌ Gallery picker error: $e');
      if (mounted) {
        _showErrorSnackbar('Failed to pick image: ${e.toString()}');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleQRScanned(String qrCode) async {
    print(
      '🔍 _handleQRScanned STARTED with QR: ${qrCode.substring(0, qrCode.length > 20 ? 20 : qrCode.length)}...',
    );

    if (_isProcessing && _scannedCode != null) {
      print('⚠️ Already processing another QR code');
      return;
    }

    print('📱 Setting processing state...');
    setState(() {
      _isProcessing = true;
      _scannedCode = qrCode;
    });

    print('📡 Attempting to call scanQRCode API...');
    print('📋 QR Code: $qrCode');

    try {
      // Add a small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 100));

      // Call API to link with guardian
      print('📞 Making API call...');
      final response = await _dependentService.scanQRCode(qrCode);

      print('✅ API Response received:');
      print('  Response type: ${response.runtimeType}');
      print('  Response: $response');

      if (mounted) {
        print('🎉 Showing success dialog...');
        _showSuccessDialog(
          guardianName: response['guardian_name'] ?? 'Guardian',
          relation: response['relation'] ?? 'guardian',
        );
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in _handleQRScanned:');
      print('  Error type: ${e.runtimeType}');
      print('  Error: $e');
      print('  Stack Trace: $stackTrace');

      if (mounted) {
        String errorMessage = 'Failed to link with guardian';

        // Try to get more specific error message
        if (e is FormatException) {
          errorMessage = 'Invalid QR code format';
        } else if (e.toString().contains('Invalid QR code')) {
          errorMessage = 'Invalid QR code. Please try again.';
        } else if (e.toString().contains('expired')) {
          errorMessage =
              'This QR code has expired. Ask your guardian for a new one.';
        } else if (e.toString().contains('already been')) {
          errorMessage = 'This QR code has already been used.';
        } else if (e.toString().contains('403')) {
          errorMessage =
              'You must have a child or elderly role to scan QR codes.';
        } else if (e.toString().contains('Network is unreachable')) {
          errorMessage = 'No internet connection. Please check your network.';
        } else if (e.toString().contains('Timeout')) {
          errorMessage = 'Connection timeout. Please try again.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'Network error. Please check your connection.';
        }

        print('⚠️ Showing error: $errorMessage');
        _showErrorSnackbar(errorMessage);

        // Restart camera
        try {
          print('🔄 Restarting camera...');
          await _cameraController.start();
        } catch (camError) {
          print('⚠️ Failed to restart camera: $camError');
        }

        if (mounted) {
          setState(() {
            _isProcessing = false;
            _scannedCode = null;
          });
        }
      }
    }
  }

  Future<void> _handleImageScanError(String error) async {
    print('❌ Image scan error: $error');
    if (mounted) {
      _showErrorSnackbar(error);
      setState(() => _isProcessing = false);

      // Restart camera if needed
      if (!_cameraController.value.isRunning) {
        try {
          await _cameraController.start();
        } catch (e) {
          print('⚠️ Failed to restart camera: $e');
        }
      }
    }
  }

  void _showSuccessDialog({
    required String guardianName,
    required String relation,
  }) {
    print(
      '🎉 Showing success dialog for guardian: $guardianName, relation: $relation',
    );

    // First, reset the processing state
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _scannedCode = null;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.primaryGreen,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text('Success!'),
          ],
        ),
        content: Text(
          'You are now linked with $guardianName as a $relation!\n\nYou can now use the safety features.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('🚀 Navigating to home...');
              Navigator.of(context).pop();
              context.go('/home');
            },
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    print('⚠️ Showing error snackbar: $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = widget.dependentType == DependentType.child
        ? "Connect with your guardian"
        : "Connect with your caregiver";

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text(
                      "Scan the QR code provided by your guardian to link your accounts",
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 40),

                    // Camera Preview with QR Scanner
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Camera container
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
                                          print(
                                            '📷 Camera detected QR: ${barcode.rawValue!.substring(0, barcode.rawValue!.length > 20 ? 20 : barcode.rawValue!.length)}...',
                                          );
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

                          // Processing overlay with better status message
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
                                  if (_scannedCode != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Code: ${_scannedCode!.substring(0, _scannedCode!.length > 12 ? 12 : _scannedCode!.length)}...',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
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

                    // Instructions
                    if (!_isProcessing)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.primaryGreen,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Position the QR code within the green frame',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14,
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
                        onPressed: _isProcessing ? null : _pickImageFromGallery,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom info
            if (!_isProcessing)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'QR codes expire after 3 days',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.orange[200]
                                : Colors.orange[800],
                          ),
                        ),
                      ),
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
      return 'Analyzing image...';
    } else {
      return 'Linking with guardian...\nPlease wait';
    }
  }
}
