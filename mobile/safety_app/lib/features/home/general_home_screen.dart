// lib/features/home/general_home_screen.dart


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safety_app/core/navigation/role_based_navigation_config.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/features/home/widgets/role_based_bottom_nav_bar.dart';
import 'package:safety_app/features/home/home_app_bar.dart';
import 'package:safety_app/services/notification_service.dart';
import 'package:safety_app/services/dependent_foreground_services.dart';
import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sos/screens/sos_home_screen.dart';
import 'map/screens/live_location_screen.dart';
import 'safety/screens/safety_settings_screen.dart';
import 'family/screens/smart_family_list_screen.dart';
import 'package:safety_app/services/dependent_safety_service.dart';


// Key for storing voice activation preference
const String kVoiceActivationEnabled = 'voice_activation_enabled';


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
  bool _dependentTrackingStarted = false;
  bool _isVoiceActivationEnabled = false;


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
      _initializeUserState();
    });
  }


  // 🔥 Unified initialization logic
  Future<void> _initializeUserState() async {
    UserModel? user = ref.read(authStateProvider).value;


    print('🔍 USER: ${user?.fullName}');
    print('🔍 HAS ROLE: ${user?.hasRole}');
    print('🔍 CURRENT ROLE: ${user?.currentRole?.roleName}');
    print('🔍 IS GUARDIAN: ${user?.isGuardian}');
    print('🔍 IS CHILD: ${user?.isChild}');
    print('🔍 IS ELDERLY: ${user?.isElderly}');
    print('🔍 IS VOICE REGISTERED: ${user?.isVoiceRegistered}');


    // Load voice activation preference
    await _loadVoiceActivationPreference();


    // Refresh role if missing
    if (user != null && (!user.hasRole || user.currentRole == null)) {
      setState(() => _isLoadingRole = true);


      try {
        await ref.read(authStateProvider.notifier).refreshUser();


        final updatedUser = ref.read(authStateProvider).value;
        if (updatedUser?.isGuardian == true && !_fcmTokenRegistered) {
          await _registerGuardianNotifications(updatedUser!);
        }
      } catch (e) {
        debugPrint("❌ Error refreshing user: $e");
      } finally {
        if (mounted) setState(() => _isLoadingRole = false);
      }


      user = ref.read(authStateProvider).value;
    }


    if (user == null) return;


    // 🚀 Start dependent foreground tracking
    if (user.isDependent && !_dependentTrackingStarted) {
      _dependentTrackingStarted = true;


      ref
          .read(dependentForegroundServiceProvider.notifier)
          .start()
          .then((_) => debugPrint("📡 Dependent tracking started"))
          .catchError(
            (e) => debugPrint("❌ Error starting dependent tracking: $e"),
          );
    }


    // 👮 Register guardian FCM
    if (user.isGuardian && !_fcmTokenRegistered) {
      await _registerGuardianNotifications(user);
    }
   
    // Start listening only if eligible AND voice activation is enabled
    _startListeningIfEligibleAndEnabled(user);
  }


  Future<void> _loadVoiceActivationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isVoiceActivationEnabled = prefs.getBool(kVoiceActivationEnabled) ?? false;
        });
      }
      debugPrint('🎤 Voice activation preference loaded: $_isVoiceActivationEnabled');
    } catch (e) {
      debugPrint('❌ Error loading voice activation preference: $e');
    }
  }


  Future<void> _registerGuardianNotifications(UserModel user) async {
    try {
      debugPrint('👮 Guardian detected: ${user.fullName}');
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
  /// SOS LISTENING - ONLY WHEN VOICE ACTIVATION ENABLED
  /// ===========================


  void _startListeningIfEligibleAndEnabled(UserModel user) {
    // Only start if voice activation is enabled in settings
    if (!_isVoiceActivationEnabled) {
      debugPrint('🎤 Voice activation is disabled, not starting SOS listening');
     
      // Make sure to stop listening if it was previously running
      if (_sosService.isCurrentlyListening) {
        _sosService.stopListening();
      }
      return;
    }


    if (user.isGuardian) {
      if (user.isVoiceRegistered && !_sosService.isCurrentlyListening) {
        _startSOSListening(user);
      }
    } else if (user.isChild || user.isElderly) {
      _checkDependentAudioSettingAndStart(user);
    }
  }


  Future<void> _startSOSListening(UserModel user) async {
    final int? userId = int.tryParse(user.id);
    if (userId == null) return;


    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }


    await _sosService.startListening(
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


        await _sosService.startListening(
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
        if (_sosService.isCurrentlyListening) {
          await _sosService.stopListening();
        }
      }
    } catch (e) {
      debugPrint('❌ Dependent setting error: $e');
    }
  }


  // Method to refresh voice activation state when returning to home
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when dependencies change (like when returning from settings)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVoiceActivationPreference().then((_) {
        final user = ref.read(authStateProvider).value;
        if (user != null) {
          _startListeningIfEligibleAndEnabled(user);
        }
      });
    });
  }


  @override
  void dispose() {
    _sosService.stopListening();
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


    // Listen for auth state changes
    ref.listen<AsyncValue<UserModel?>>(
      authStateProvider,
      (previous, next) {
        final updatedUser = next.value;
        if (updatedUser != null) {
          _initializeUserState();
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
      body: IndexedStack(
        index: _currentIndex < screens.length ? _currentIndex : 0,
        children: screens,
      ),
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
