// lib/features/home/general_home_screen.dart

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
import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';
import 'package:safety_app/services/dependent_safety_service.dart';

class GeneralHomeScreen extends ConsumerStatefulWidget {
  const GeneralHomeScreen({super.key});

  @override
  ConsumerState<GeneralHomeScreen> createState() => _GeneralHomeScreenState();
}

class _GeneralHomeScreenState extends ConsumerState<GeneralHomeScreen> {
  int _currentIndex = 0;
  SOSListenService? _sosService;
  bool _isLoadingRole = false;
  bool _fcmTokenRegistered = false;

  // ✅ FIXED: const constructors so IndexedStack preserves widget state
  final Map<String, Widget> _screenMap = {
    'sos': const SosHomeScreen(),
    'family': const SmartFamilyListScreen(),
    'safety': const SafetySettingsScreen(),
    'map': const LiveLocationScreen(),
  };

  @override
  void initState() {
    super.initState();
    _sosService = SOSListenService();
  }

  /// ===========================
  /// ROLE + FCM HANDLING
  /// ===========================

  Future<void> _checkAndLoadRole(UserModel user) async {
    if (!user.hasRole || user.currentRole == null) {
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
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } else if (user.isGuardian && !_fcmTokenRegistered) {
      await _registerGuardianNotifications(user);
    }
  }

  Future<void> _registerGuardianNotifications(UserModel user) async {
    try {
      await NotificationService.init();
      final success = await NotificationService.registerDeviceToken();
      if (success && mounted) {
        setState(() => _fcmTokenRegistered = true);
      }
    } catch (e) {
      debugPrint('❌ Error registering FCM: $e');
    }
  }

  /// ===========================
  /// SOS LISTENING
  /// ===========================

  void _startListeningIfEligible(UserModel user) {
    if (_sosService == null) return;

    if (user.isGuardian) {
      if (user.isVoiceRegistered && !_sosService!.isCurrentlyListening) {
        _startSOSListening(user);
      }
    } else if (user.isChild || user.isElderly) {
      _checkDependentAudioSettingAndStart(user);
    }
  }

  Future<void> _startSOSListening(UserModel user) async {
    if (_sosService == null) return;

    final int? userId = int.tryParse(user.id);
    if (userId == null) return;

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    await _sosService!.startListening(
      userId: userId,
      onSOSConfirmed: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS ACTIVATED!'),
            backgroundColor: Colors.red,
          ),
        );
      },
      onStatusChange: (_) {},
    );
  }

  Future<void> _checkDependentAudioSettingAndStart(UserModel user) async {
    if (_sosService == null) return;

    try {
      final safetyService = DependentSafetyService();
      final int dependentId = int.tryParse(user.id) ?? 0;
      if (dependentId == 0) return;

      final settings = await safetyService.getDependentSafetySettings(dependentId);

      if (settings.audioRecording) {
        var status = await Permission.microphone.status;
        if (!status.isGranted) {
          status = await Permission.microphone.request();
          if (!status.isGranted) return;
        }

        await _sosService!.startListening(
          userId: dependentId,
          onSOSConfirmed: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🚨 SOS ACTIVATED!'),
                backgroundColor: Colors.red,
              ),
            );
          },
          onStatusChange: (_) {},
        );
      } else {
        if (_sosService!.isCurrentlyListening) {
          await _sosService!.stopListening();
        }
      }
    } catch (e) {
      debugPrint('❌ Dependent setting error: $e');
    }
  }

  @override
  void dispose() {
    // ✅ FIXED: SOSListenService only has stopListening(), not dispose()
    // Calling dispose() would throw NoSuchMethodError at runtime
    _sosService?.stopListening();
    super.dispose();
  }

  /// ===========================
  /// BUILD
  /// ===========================

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final roleName = user?.currentRole?.roleName;

    // ✅ CORRECT: ref.listen must be inside build(), not didChangeDependencies()
    ref.listen<AsyncValue<UserModel?>>(
      authStateProvider,
      (previous, next) {
        final updatedUser = next.value;
        if (updatedUser != null) {
          _checkAndLoadRole(updatedUser);
          _startListeningIfEligible(updatedUser);
        }
      },
    );

    if (_isLoadingRole ||
        (user != null && (!user.hasRole || user.currentRole == null))) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final navItems = RoleBasedNavigationConfig.getNavigationItemsForRole(roleName);
    final screens = navItems.map((item) => _screenMap[item.route]!).toList();

    if (_currentIndex >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = 0);
      });
    }

    return Scaffold(
      appBar: _currentIndex == 0 ? const HomeAppBar() : null,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex < screens.length ? _currentIndex : 0,
            children: screens,
          ),
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