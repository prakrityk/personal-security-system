// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_theme.dart';
import 'package:safety_app/routes/app_router.dart';
import 'package:safety_app/core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        // Override the SharedPreferences provider with actual instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const SOSApp(),
    ),
  );
}

class SOSApp extends ConsumerStatefulWidget {
  const SOSApp({super.key});


  @override
  ConsumerState<SOSApp> createState() => _SOSAppState();
}

class _SOSAppState extends ConsumerState<SOSApp> {
  final SOSListenService _sosService = SOSListenService();

  @override
  void initState() {
    super.initState();
    //start sos listener 
    _startSOSListening();
  }

  void _startSOSListening() async {
    await _sosService.startListening(
      onSOSDetected: (confidence) {
        // Called when "HELP" is detected
        print("🚨 SOS DETECTED with confidence $confidence");
        // TODO: Trigger your SOS functionality here
      },
      onStatusChange: (status){
        print(" STATUS: $status");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme mode from provider
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SOS App',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode, // Now controlled by Riverpod
      // GoRouter configuration
      routerConfig: AppRouter.router,
    );
  }
}
