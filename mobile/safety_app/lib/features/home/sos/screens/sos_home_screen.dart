import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/features/home/home_app_bar.dart';
import '../widgets/sos_button.dart';



class SosHomeScreen extends StatelessWidget {
  const SosHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // SOS Button with Lottie Animation Background
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Lottie Animation Background
                  Positioned.fill(
                    child: Lottie.asset(
                      'assets/lottie/SoSButtonBG.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  // SOS Button
                  SosButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOS activated!'),
                          backgroundColor: AppColors.sosRed,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 60),
          
          // Emergency Contacts Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.sosRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.emergency,
                        color: AppColors.sosRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Emergency Contacts',
                      style: AppTextStyles.h4.copyWith(
                        color: isDark
                            ? AppColors.darkOnBackground
                            : AppColors.lightOnBackground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Emergency Contact Items
                _buildEmergencyContact(
                  context,
                  name: 'Label text',
                  icon: Icons.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildEmergencyContact(
                  context,
                  name: 'Label text',
                  icon: Icons.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildEmergencyContact(
                  context,
                  name: 'Label text',
                  icon: Icons.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildEmergencyContact(
                  context,
                  name: 'Label text',
                  icon: Icons.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildEmergencyContact(
                  context,
                  name: 'Label text',
                  icon: Icons.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildEmergencyContact(
                  context,
                  name: 'Label text',
                  icon: Icons.phone,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 100), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildEmergencyContact(
    BuildContext context, {
    required String name,
    required IconData icon,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        // TODO: Implement contact action
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withOpacity(0.1),
              ),
              child: Icon(
                Icons.add_circle_outline,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurface
                      : AppColors.lightOnSurface,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  '⌘C',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}