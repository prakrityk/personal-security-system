// lib/features/home/family/widgets/collaborator_invitation_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
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

  bool _isLoading = true;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Code copied to clipboard'),
            ],
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareInvitation() {
    if (_invitationCode == null) return;

    final message =
        '''
👨‍👩‍👧 Join as Collaborator Guardian

You've been invited to monitor ${widget.dependentName}'s safety!

Invitation Code: $_invitationCode

Steps to join:
1. Open the Safety App
2. Select "Guardian" role
3. Choose "Join as Collaborator"
4. Enter the code above or scan the QR code

This invitation expires in ${_formatTimeRemaining()}.
    ''';

    Share.share(message, subject: 'Safety App - Collaborator Invitation');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryGreen.withOpacity(0.2),
                        AppColors.accentGreen1.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2,
                    color: AppColors.primaryGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite Collaborator', style: AppTextStyles.h4),
                      Text(
                        'For ${widget.dependentName}',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
            else if (_errorMessage != null)
              _buildErrorState()
            else
              _buildInvitationContent(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _generateInvitation,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationContent(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Info text
          Text(
            'Share this invitation with another guardian',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
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

          const SizedBox(height: 24),

          // Invitation Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.1),
                  AppColors.accentGreen1.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Invitation Code',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _invitationCode ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.primaryGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      color: AppColors.primaryGreen,
                      onPressed: _copyCode,
                      tooltip: 'Copy code',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Expiration countdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Expires in ${_formatTimeRemaining()}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareInvitation,
              icon: const Icon(Icons.share),
              label: const Text('Share Invitation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Collaborators have view-only access to safety features',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
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
