import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/navigation/role_based_navigation_config.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/features/home/widgets/role_based_bottom_nav_bar.dart';
import 'package:safety_app/features/home/home_app_bar.dart';
import 'package:safety_app/services/notification_service.dart';
import 'sos/screens/sos_home_screen.dart';
import 'map/screens/live_location_screen.dart';
import 'safety/screens/safety_settings_screen.dart';
import 'family/screens/smart_family_list_screen.dart';
import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';

class GeneralHomeScreen extends ConsumerStatefulWidget {
  const GeneralHomeScreen({super.key});

  @override
  ConsumerState<GeneralHomeScreen> createState() => _GeneralHomeScreenState();
}

class _GeneralHomeScreenState extends ConsumerState<GeneralHomeScreen> {
  int _currentIndex = 0;
  final SOSListenService _sosService = SOSListenService();
  bool _isLoadingRole = false;
  bool _fcmTokenRegistered = false;

  final Map<String, Widget> _screenMap = {
    'sos': const SosHomeScreen(),
    'family': const SmartFamilyListScreen(),
    'safety': const SafetySettingsScreen(),
    'map': const LiveLocationScreen(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadRole();
    });
  }

  Future<void> _checkAndLoadRole() async {
    final user = ref.read(authStateProvider).value;

    if (user != null && (!user.hasRole || user.currentRole == null)) {
      setState(() => _isLoadingRole = true);

      try {
        await ref.read(authStateProvider.notifier).refreshUser();

        final updatedUser = ref.read(authStateProvider).value;

        if (updatedUser?.isGuardian == true && !_fcmTokenRegistered) {
          await _registerGuardianNotifications(updatedUser!);
        }
      } catch (e) {
        debugPrint('❌ Error loading role: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoadingRole = false);
        }
      }
    } else if (user?.isGuardian == true && !_fcmTokenRegistered) {
      await _registerGuardianNotifications(user!);
    }
  }

  Future<void> _registerGuardianNotifications(UserModel user) async {
    try {
      await NotificationService.init();
      final success = await NotificationService.registerDeviceToken();

      if (success && mounted) {
        setState(() => _fcmTokenRegistered = true);
      }
    } catch (e, stack) {
      debugPrint('❌ Error registering guardian notifications: $e');
      debugPrint(stack.toString());
    }
  }

  @override
  void dispose() {
    _sosService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final roleName = user?.currentRole?.roleName;

    if (_isLoadingRole ||
        (user != null && (!user.hasRole || user.currentRole == null))) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Setting up your account...'),
            ],
          ),
        ),
      );
    }

    final navItems = RoleBasedNavigationConfig.getNavigationItemsForRole(
      roleName,
    );

    final screens = navItems.map((item) => _screenMap[item.route]!).toList();

    if (_currentIndex >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      });
    }

    return Scaffold(
      appBar: _currentIndex == 0 ? const HomeAppBar() : null,

      body: IndexedStack(
        index: _currentIndex < screens.length ? _currentIndex : 0,
        children: screens,
      ),

      // ✅ FIXED: Proper bottom navigation placement
      bottomNavigationBar: SafeArea(
        child: RoleBasedBottomNavBar(
          currentIndex: _currentIndex,
          navigationItems: navItems,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}
