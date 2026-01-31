// ===================================================================
// PROFILE PICTURE HELPER WIDGET
// ===================================================================
// lib/core/widgets/profile_picture_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/network/api_endpoints.dart';

/// Reusable profile picture widget that handles:
/// - Network images with caching
/// - Fallback to initials
/// - Loading and error states
/// - Customizable size and styling
class ProfilePictureWidget extends StatelessWidget {
  final String? profilePicturePath;
  final String fullName;
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;

  const ProfilePictureWidget({
    super.key,
    this.profilePicturePath,
    required this.fullName,
    this.radius = 40,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasProfilePicture =
        profilePicturePath != null && profilePicturePath!.isNotEmpty;

    // Get initials for fallback
    final initials = _getInitials(fullName);

    return Container(
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    borderColor ??
                    (isDark
                        ? AppColors.darkAccentGreen1
                        : AppColors.primaryGreen),
                width: borderWidth,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor:
            backgroundColor ?? AppColors.primaryGreen.withOpacity(0.15),
        child: hasProfilePicture
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: _getFullImageUrl(profilePicturePath!),
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildLoadingIndicator(),
                  errorWidget: (context, url, error) =>
                      _buildInitialsWidget(initials, isDark),
                ),
              )
            : _buildInitialsWidget(initials, isDark),
      ),
    );
  }

  Widget _buildInitialsWidget(String initials, bool isDark) {
    return Text(
      initials,
      style: TextStyle(
        fontSize: radius * 0.8,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: SizedBox(
        width: radius * 0.5,
        height: radius * 0.5,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getFullImageUrl(String path) {
    // If path already starts with http, check if it has /api
    if (path.startsWith('http')) {
      // If it has /api/uploads, remove /api
      if (path.contains('/api/uploads')) {
        return path.replaceAll('/api/uploads', '/uploads');
      }
      return path;
    }

    // Remove /api from baseUrl if present
    final baseUrl = ApiEndpoints.baseUrl.replaceAll('/api', '');

    // Ensure path starts with /
    final cleanPath = path.startsWith('/') ? path : '/$path';

    return '$baseUrl$cleanPath';
  }
}
