// lib/features/home/family/widgets/collaborator_invitation_dialog.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/services/collaborator_service.dart';

class CollaboratorInvitationDialog extends StatefulWidget {
  final int dependentId;
  final String dependentName;

  const CollaboratorInvitationDialog({
    super.key,
    required this.dependentId,
    required this.dependentName,
  });

  @override
  State<CollaboratorInvitationDialog> createState() =>
      _CollaboratorInvitationDialogState();
}

class _CollaboratorInvitationDialogState
    extends State<CollaboratorInvitationDialog> {
  final CollaboratorService _collaboratorService = CollaboratorService();
  final GlobalKey _qrKey = GlobalKey();

  bool _isLoading = true;
  bool _isSavingQr = false;
  String? _invitationCode;
  String? _qrData;
  DateTime? _expiresAt;
  String? _errorMessage;

  Timer? _countdownTimer;
  Duration? _timeRemaining;

  @override
  void initState() {
    super.initState();
    _generateInvitation();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateInvitation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _collaboratorService.createInvitation(
        widget.dependentId,
      );

      if (mounted) {
        setState(() {
          _invitationCode = response['invitation_code'];
          _qrData = response['qr_data'];
          _expiresAt = DateTime.parse(response['expires_at']);
          _isLoading = false;
        });

        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to generate invitation: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _startCountdown() {
    if (_expiresAt == null) return;

    _updateTimeRemaining();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _updateTimeRemaining();

      if (_timeRemaining != null && _timeRemaining!.isNegative) {
        timer.cancel();
        setState(() {
          _errorMessage = 'Invitation expired';
        });
      }
    });
  }

  void _updateTimeRemaining() {
    if (_expiresAt == null) return;

    setState(() {
      _timeRemaining = _expiresAt!.difference(DateTime.now());
    });
  }

  String _formatTimeRemaining() {
    if (_timeRemaining == null || _timeRemaining!.isNegative) {
      return 'Expired';
    }

    final days = _timeRemaining!.inDays;
    final hours = _timeRemaining!.inHours % 24;
    final minutes = _timeRemaining!.inMinutes % 60;

    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''} ${hours}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _copyCode() {
    if (_invitationCode != null) {
      Clipboard.setData(ClipboardData(text: _invitationCode!));
      _showSnackbar('Code copied to clipboard', Icons.check_circle);
    }
  }

  Future<void> _saveQrToGallery() async {
    if (_qrData == null) return;

    setState(() => _isSavingQr = true);

    try {
      // Capture QR code as image
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not capture QR code');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception('Could not convert QR code to image');
      }

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'collaborator_qr_${widget.dependentName}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      // Share the file (this will allow user to save to gallery)
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'QR Code for ${widget.dependentName} - Collaborator Invitation');

      if (mounted) {
        _showSnackbar('QR code ready to save', Icons.download_done);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Failed to save QR code: ${e.toString()}',
          Icons.error_outline,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQr = false);
      }
    }
  }

  Future<void> _shareInvitation() async {
    if (_invitationCode == null || _qrData == null) return;

    setState(() => _isSavingQr = true);

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
          text: '👨‍👩‍👧 Collaborator Invitation',
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
          style: const TextStyle(fontSize: 18, color: Colors.white),
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

      // Draw invitation code box
      const codeBoxY = qrY + qrSize + 30;
      final codeBoxPaint = Paint()
        ..color = AppColors.primaryGreen.withOpacity(0.1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, codeBoxY, width - 80, 100),
          const Radius.circular(12),
        ),
        codeBoxPaint,
      );

      // Draw border for code box
      final borderPaint = Paint()
        ..color = AppColors.primaryGreen.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, codeBoxY, width - 80, 100),
          const Radius.circular(12),
        ),
        borderPaint,
      );

      // Draw "Invitation Code" label
      final codeLabelPainter = TextPainter(
        text: const TextSpan(
          text: 'Invitation Code',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      );
      codeLabelPainter.layout();
      codeLabelPainter.paint(
        canvas,
        Offset((width - codeLabelPainter.width) / 2, codeBoxY + 20),
      );

      // Draw invitation code
      final codePainter = TextPainter(
        text: TextSpan(
          text: _invitationCode,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      codePainter.layout();
      codePainter.paint(
        canvas,
        Offset((width - codePainter.width) / 2, codeBoxY + 50),
      );

      // Draw instructions
      const instructionsY = codeBoxY + 130;
      final instructionsPainter = TextPainter(
        text: TextSpan(
          text:
              'Steps to Join:\n'
              '1. Open Safety App\n'
              '2. Select "Guardian" role\n'
              '3. Choose "Join as Collaborator"\n'
              '4. Enter code or scan QR\n\n'
              'Expires in ${_formatTimeRemaining()}',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            height: 1.6,
          ),
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
          'SafetyApp_Invitation_${widget.dependentName.replaceAll(' ', '_')}_$timestamp.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imgPngBytes);

      // Create message (for apps that support it)
      final message =
          '''
👨‍👩‍👧 Join as Collaborator Guardian

You've been invited to monitor ${widget.dependentName}'s safety!

📋 Invitation Code: $_invitationCode

📱 Steps to join:
1. Open the Safety App
2. Select "Guardian" role
3. Choose "Join as Collaborator"
4. Enter the code or scan the QR code (in the image)

⏰ Expires in ${_formatTimeRemaining()}

Download the Safety App to get started!
''';

      // Share with both text message AND composite image
      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
        subject:
            'Safety App - Collaborator Invitation for ${widget.dependentName}',
      );

      if (mounted) {
        _showSnackbar('Invitation shared successfully!', Icons.check_circle);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Failed to share: ${e.toString()}',
          Icons.error_outline,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQr = false);
      }
    }
  }

  void _showSnackbar(String message, IconData icon, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primaryGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenHeight * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Header
            _buildHeader(isDark),

            // Scrollable Content
            Flexible(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                  ? _buildErrorState()
                  : _buildInvitationContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.15),
                  AppColors.accentGreen1.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              color: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite Collaborator',
                  style: AppTextStyles.h4.copyWith(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'For ${widget.dependentName}',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateInvitation,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          // QR Code with Long Press to Save
          GestureDetector(
            onLongPress: _isSavingQr ? null : _saveQrToGallery,
            child: RepaintBoundary(
              key: _qrKey,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrData ?? '',
                  version: QrVersions.auto,
                  size: 200,
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
          ),

          const SizedBox(height: 24),

          // Invitation Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.08),
                  AppColors.accentGreen1.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Invitation Code',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _invitationCode ?? '',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isDark
                              ? AppColors.darkAccentGreen1
                              : AppColors.primaryGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      color: isDark
                          ? AppColors.darkAccentGreen1
                          : AppColors.primaryGreen,
                      onPressed: _copyCode,
                      tooltip: 'Copy code',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Expiration Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Expires in ${_formatTimeRemaining()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSavingQr ? null : _shareInvitation,
              icon: _isSavingQr
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.share_rounded, size: 20),
              label: Text(_isSavingQr ? 'Preparing...' : 'Share Invitation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.darkAccentGreen1
                    : AppColors.primaryGreen,
                foregroundColor: isDark
                    ? AppColors.darkBackground
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                disabledBackgroundColor:
                    (isDark
                            ? AppColors.darkAccentGreen1
                            : AppColors.primaryGreen)
                        .withOpacity(0.6),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Collaborators have view-only access to safety features',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the dialog
Future<void> showCollaboratorInvitationDialog({
  required BuildContext context,
  required int dependentId,
  required String dependentName,
}) {
  return showDialog(
    context: context,
    builder: (context) => CollaboratorInvitationDialog(
      dependentId: dependentId,
      dependentName: dependentName,
    ),
  );
}
