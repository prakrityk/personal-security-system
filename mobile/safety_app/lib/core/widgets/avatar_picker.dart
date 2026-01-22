import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AvatarPicker extends StatelessWidget {
  final double radius;
  final ImageProvider? image;
  final VoidCallback onTap;

  const AvatarPicker({
    super.key,
    this.radius = 48,
    this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            backgroundImage: image,
            child: image == null
                ? Icon(
                    Icons.person,
                    size: radius,
                    color:
                        isDark ? AppColors.darkHint : AppColors.lightHint,
                  )
                : null,
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGreen,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(
              Icons.camera_alt,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
