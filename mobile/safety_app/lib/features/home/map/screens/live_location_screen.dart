// lib/features/home/live_location_screen.dart

import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/features/home/widgets/home_section_header.dart';

class LiveLocationScreen extends StatelessWidget {
  const LiveLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Static map image URL
    const mapImageUrl =
        'https://cdn.mos.cms.futurecdn.net/jz58vQg4pyzq9LuhSGTPSk.jpg.webp';

    // Sample user locations
    final users = [
      UserMarker(
        name: 'You',
        avatarUrl: null,
        position: const Offset(0.5, 0.3),
        isCurrentUser: true,
      ),
      UserMarker(
        name: 'John',
        avatarUrl: null,
        position: const Offset(0.3, 0.4),
      ),
      UserMarker(
        name: 'Alice',
        avatarUrl: null,
        position: const Offset(0.7, 0.5),
      ),
      UserMarker(
        name: 'Bob',
        avatarUrl: null,
        position: const Offset(0.4, 0.7),
      ),
      UserMarker(
        name: 'Sarah',
        avatarUrl: null,
        position: const Offset(0.8, 0.3),
      ),
    ];

    return Stack(
      children: [
        // Map Background (Full Screen)
        Positioned.fill(
          child: Image.network(
            mapImageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: isDark ? AppColors.darkBackground : Colors.grey[300],
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: isDark ? AppColors.darkBackground : Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.map,
                    size: 100,
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              );
            },
          ),
        ),

        // User Markers
        ...users.map((user) => _buildUserMarker(context, user)),

        // Consistent Header (same style as other tabs)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: HomeSectionHeader(
              icon: Icons.map,
              title: 'Live Locations',
              subtitle: 'Track family members in real-time',
              transparent: true,
              iconColor: AppColors.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMarker(BuildContext context, UserMarker user) {
    final size = MediaQuery.of(context).size;

    // Use SOS red for current user, primary green for others
    final markerColor = user.isCurrentUser
        ? AppColors.sosRed
        : AppColors.primaryGreen;

    return Positioned(
      left: size.width * user.position.dx - 25,
      top: size.height * user.position.dy - 25,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.name}\'s location'),
              backgroundColor: markerColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: markerColor,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: markerColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: user.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(user.avatarUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.person, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: markerColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                user.name,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserMarker {
  final String name;
  final String? avatarUrl;
  final Offset position;
  final bool isCurrentUser;

  UserMarker({
    required this.name,
    this.avatarUrl,
    required this.position,
    this.isCurrentUser = false,
  });
}
