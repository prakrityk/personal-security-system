import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/home/bottom_nav_bar.dart';
import 'package:safety_app/features/home/home_app_bar.dart';
import 'sos/screens/sos_home_screen.dart';
import 'map/screens/live_location_screen.dart';
import 'safety/screens/safety_settings_screen.dart';
import 'family/screens/family_list_screen.dart';
import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';

class GeneralHomeScreen extends ConsumerStatefulWidget {
  const GeneralHomeScreen({super.key});

  @override
  ConsumerState<GeneralHomeScreen> createState() => _GeneralHomeScreenState();
}

class _GeneralHomeScreenState extends ConsumerState<GeneralHomeScreen> {
  int _currentIndex = 0;
  final SOSListenService _sosService = SOSListenService();

  final List<Widget> _screens = const [
    SosHomeScreen(),
    LiveLocationScreen(),
    SafetySettingsScreen(),
    FamilyListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initSOSListener();
  }

  /// ✅ Initialize SOS listener if user is logged in and voice is registered
  void _initSOSListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).value;
      _startListeningIfEligible(user);
    });
  }

  /// ✅ Start listener only if user exists, voice registered, and not already listening
  void _startListeningIfEligible(UserModel? user) {
    if (user != null &&
        user.isVoiceRegistered &&
        !_sosService.isCurrentlyListening) {
      _startSOSListening(user);
    } else if (user != null && !user.isVoiceRegistered) {
      print("ℹ️ Voice not registered → SOS not started");
    }
  }

  Future<void> _startSOSListening(UserModel user) async {
    final int? userId = int.tryParse(user.id);
    if (userId == null) return;

    // ✅ Ask microphone permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        print("⚠️ Mic permission denied");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone needed for SOS")),
          );
        }
        return;
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));

    print("👤 SOS Listener started for user: $userId");

    await _sosService.startListening(
      userId: userId,
      onSOSConfirmed: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(" SOS ACTIVATED!"),
            backgroundColor: Colors.red,
          ),
        );
      },
      onStatusChange: (status) => print(" SOS Status: $status"),
    );
  }

  @override
  void dispose() {
    _sosService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ React to login changes dynamically
    ref.listen<AsyncValue<UserModel?>>(authStateProvider, (previous, next) {
      final user = next.value;
      _startListeningIfEligible(user);
    });

    return Scaffold(
      appBar: _currentIndex == 0
          ? const HomeAppBar(notificationCount: 3, onNotificationTap: null)
          : null,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: XRBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}
