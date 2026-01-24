// lib/features/home/general_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/features/home/bottom_nav_bar.dart';
import 'package:safety_app/features/home/home_app_bar.dart';
import 'sos/screens/sos_home_screen.dart';
import 'map/screens/live_location_screen.dart';
import 'safety/screens/safety_settings_screen.dart';
import 'family/screens/family_list_screen.dart';

class GeneralHomeScreen extends ConsumerStatefulWidget {
  const GeneralHomeScreen({super.key});

  @override
  ConsumerState<GeneralHomeScreen> createState() => _GeneralHomeScreenState();
}

class _GeneralHomeScreenState extends ConsumerState<GeneralHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    SosHomeScreen(),
    LiveLocationScreen(),
    SafetySettingsScreen(),
    FamilyListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
            index: _currentIndex,
            children: _screens,
          ),

          // Floating Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: XRBottomNavBar(
              currentIndex: _currentIndex,
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