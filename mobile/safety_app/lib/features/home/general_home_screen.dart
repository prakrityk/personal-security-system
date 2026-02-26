import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/navigation/role_based_navigation_config.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/features/home/widgets/role_based_bottom_nav_bar.dart';
import 'package:safety_app/features/home/home_app_bar.dart';
import 'package:safety_app/services/notification_service.dart';
import 'sos/screens/sos_home_screen.dart';
import 'map/screens/live_location_screen.dart';
import 'safety/screens/safety_settings_screen.dart';
import 'family/screens/smart_family_list_screen.dart';
import 'package:safety_app/core/network/dio_client.dart';

import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';

class GeneralHomeScreen extends ConsumerStatefulWidget {
  const GeneralHomeScreen({super.key});

  @override
  ConsumerState<GeneralHomeScreen> createState() => _GeneralHomeScreenState();
}

class _GeneralHomeScreenState extends ConsumerState<GeneralHomeScreen> {
  int _currentIndex = 0;
  late final SOSListenService _sosService;
  bool _isLoadingRole = false;
  bool _fcmTokenRegistered = false;

  final Map<String, Widget> _screenMap =  { //const{}
    'sos': SosHomeScreen(),
    'family': SmartFamilyListScreen(),
    'safety': SafetySettingsScreen(),
    'map': LiveLocationScreen(),
  };

  @override
  void initState() {
    super.initState();
        _sosService = SOSListenService(dioClient: DioClient());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadRole();
      // _initSOSListener();
    });
  }

  Future<void> _checkAndLoadRole() async {
    final user = ref.read(authStateProvider).value;

    // If user exists but has no role, fetch the user data from backend
    if (user != null && (!user.hasRole || user.currentRole == null)) {
      setState(() => _isLoadingRole = true);

      try {
        // Fetch fresh user data with role
        await ref.read(authStateProvider.notifier).refreshUser();

        // ✅ After role is loaded, register FCM token for guardians
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
      // User already has role, just register FCM token
      await _registerGuardianNotifications(user!);
    }
  }

  /// ✅ IMPROVED: Register FCM token for guardian users
  /// Uses the improved NotificationService which handles everything internally
  Future<void> _registerGuardianNotifications(UserModel user) async {
    try {
      debugPrint('👮 Guardian detected: ${user.fullName}');
      debugPrint('📱 Initializing notification service...');

      // 1️⃣ Initialize notifications (permission + handlers)
      await NotificationService.init();

      // 2️⃣ Register FCM token with backend (NEW VERSION)
      final success = await NotificationService.registerDeviceToken();

      if (success) {
        setState(() => _fcmTokenRegistered = true);
        debugPrint('✅ Guardian FCM token registered successfully');
        debugPrint('🎉 Guardian is now ready to receive SOS notifications!');
      } else {
        debugPrint(
          '⚠️ Failed to register FCM token — will retry on next login',
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Error registering guardian notifications: $e');
      debugPrint(stack.toString());
    }
  }


  /// ✅ Initialize SOS listener if user is logged in and voice is registered
  // void _initSOSListener() {
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     final user = ref.read(authStateProvider).value;
  //     _startListeningIfEligible(user);
  //   });
  // }

  // /// ✅ Start listener only if user exists, voice registered, and not already listening
  // void _startListeningIfEligible(UserModel? user) {
  //   if (user != null &&
  //       user.isVoiceRegistered &&
  //       !_sosService.isCurrentlyListening) {
  //     _startSOSListening(user);
  //   } else if (user != null && !user.isVoiceRegistered) {
  //     print("ℹ️ Voice not registered → SOS not started");
  //   }
  // }

  // Future<void> _startSOSListening(UserModel user) async {
  //   final int? userId = int.tryParse(user.id);
  //   if (userId == null) return;

  //   // ✅ Ask microphone permission
  //   var status = await Permission.microphone.status;
  //   if (!status.isGranted) {
  //     status = await Permission.microphone.request();
  //     if (!status.isGranted) {
  //       print("⚠️ Mic permission denied");
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text("Microphone needed for SOS")),
  //         );
  //       }
  //       return;
  //     }
  //   }

  //   await Future.delayed(const Duration(milliseconds: 500));

  //   print("👤 SOS Listener started for user: $userId");

  //   await _sosService.startListening(
  //     userId: userId,
  //     onSOSConfirmed: () {
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text(" SOS ACTIVATED!"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     },
  //     onStatusChange: (status) => print(" SOS Status: $status"),
  //   );
  // }

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

    // Show loading if we're actively fetching the role
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

    // ✅ React to login changes dynamically
  //   ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) {
  //   final user = next.value;
  //   if (user != null &&
  //       user.isVoiceRegistered &&
  //       !_sosService.isCurrentlyListening) {
  //     _startSOSListening(user);
  //   }
  // });

    return Scaffold(
      appBar: _currentIndex == 0
          ? const HomeAppBar()
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
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}
