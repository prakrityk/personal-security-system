// lib/features/home/general_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/navigation/role_based_navigation_config.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/home/widgets/role_based_bottom_nav_bar.dart';
import 'package:safety_app/features/home/home_app_bar.dart';
import 'sos/screens/sos_home_screen.dart';
import 'map/screens/live_location_screen.dart';
import 'safety/screens/safety_settings_screen.dart';
import 'family/screens/smart_family_list_screen.dart'; // ✅ FIX: Use smart wrapper

class GeneralHomeScreen extends ConsumerStatefulWidget {
  const GeneralHomeScreen({super.key});

  @override
  ConsumerState<GeneralHomeScreen> createState() => _GeneralHomeScreenState();
}

class _GeneralHomeScreenState extends ConsumerState<GeneralHomeScreen> {
  int _currentIndex = 0;

  // ✅ FIX: Use SmartFamilyListScreen which routes to correct screen based on role
  final Map<String, Widget> _screenMap = const {
    'sos': SosHomeScreen(),
    'family':
        SmartFamilyListScreen(), // ✅ This handles guardian vs dependent routing
    'safety': SafetySettingsScreen(),
    'map': LiveLocationScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final roleName = user?.currentRole?.roleName;

    // Get navigation items based on user role
    final navItems = RoleBasedNavigationConfig.getNavigationItemsForRole(
      roleName,
    );

    // Build screens list based on allowed navigation items
    final screens = navItems.map((item) => _screenMap[item.route]!).toList();

    // Ensure current index is within bounds
    if (_currentIndex >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      });
    }

    return Scaffold(
      // Only show app bar for Home tab (index 0)
      appBar: _currentIndex == 0
          ? const HomeAppBar(
              notificationCount: 3,
              onNotificationTap: null, // TODO: Navigate to notifications
            )
          : null,
      body: Stack(
        children: [
          // Main Content
          IndexedStack(
            index: _currentIndex < screens.length ? _currentIndex : 0,
            children: screens,
          ),

          // Floating Bottom Navigation (Role-based)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RoleBasedBottomNavBar(
              currentIndex: _currentIndex,
              navigationItems: navItems,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
