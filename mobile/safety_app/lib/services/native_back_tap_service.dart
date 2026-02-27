import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  native_back_tap_service.dart
//
//  Flutter side of the native back-tap bridge.
//
//  IMPORTANT — Token management (required for killed-app SOS):
//
//  Call saveToken(token) whenever your auth token changes
//  (after login, after token refresh). This stores the token
//  in SharedPreferences so BackTapService can fire SOS via
//  HTTP even when the Flutter app is completely killed.
//
//  Call clearToken() on logout so a logged-out user's token
//  is not left on disk.
//
//  Usage:
//    // After login:
//    await NativeBackTapService.instance.saveToken(accessToken);
//
//    // On token refresh:
//    await NativeBackTapService.instance.saveToken(newToken);
//
//    // On logout:
//    await NativeBackTapService.instance.clearToken();
//
//    // Start service (called by MotionDetectionService.start()):
//    await NativeBackTapService.instance.start();
//
//    // Listen to tap count for UI:
//    NativeBackTapService.instance.tapCountStream.listen((count) {
//      setState(() => _tapCount = count);
//    });
//
//    // Listen for SOS trigger (handled by MotionDetectionService):
//    NativeBackTapService.instance.sosTriggerStream.listen((_) { ... });
// ─────────────────────────────────────────────

class NativeBackTapService {
  NativeBackTapService._internal();
  static final NativeBackTapService instance = NativeBackTapService._internal();

  static const _methodChannel = MethodChannel('com.example.safety_app/backtap');
  static const _eventChannel = EventChannel(
    'com.example.safety_app/backtap/events',
  );

  // ── Streams ──
  final _tapCountController = StreamController<int>.broadcast();
  final _sosTriggerController = StreamController<void>.broadcast();

  Stream<int> get tapCountStream => _tapCountController.stream;
  Stream<void> get sosTriggerStream => _sosTriggerController.stream;

  StreamSubscription? _eventSub;
  bool _running = false;

  // ─────────────────────────────────────────────
  //  TOKEN MANAGEMENT
  // ─────────────────────────────────────────────

  /// Save the auth token to SharedPreferences so BackTapService
  /// can fire SOS directly when the app is killed.
  ///
  /// Call this:
  ///   - After successful login
  ///   - After token refresh (interceptor or auth provider)
  ///   - Anytime the token changes
  Future<void> saveToken(String token) async {
    try {
      await _methodChannel.invokeMethod('saveToken', {'token': token});
      debugPrint('✅ NativeBackTapService: token saved to SharedPreferences');
    } catch (e) {
      debugPrint('❌ NativeBackTapService.saveToken() failed: $e');
    }
  }

  /// Clear the auth token from SharedPreferences on logout.
  /// Prevents a stale token from being used after the user logs out.
  Future<void> clearToken() async {
    try {
      await _methodChannel.invokeMethod('clearToken');
      debugPrint(
        '✅ NativeBackTapService: token cleared from SharedPreferences',
      );
    } catch (e) {
      debugPrint('❌ NativeBackTapService.clearToken() failed: $e');
    }
  }

  /// Save the backend base URL to SharedPreferences so BackTapService
  /// always uses the correct URL when firing SOS in the killed-app path.
  ///
  /// Call this once at app startup (before or after login). Whenever
  /// [ApiEndpoints.baseUrl] changes (e.g. ngrok rotation, prod switch),
  /// call this again so the native service picks up the new value.
  Future<void> saveBaseUrl(String url) async {
    try {
      await _methodChannel.invokeMethod('saveBaseUrl', {'url': url});
      debugPrint('✅ NativeBackTapService: base URL saved → $url');
    } catch (e) {
      debugPrint('❌ NativeBackTapService.saveBaseUrl() failed: $e');
    }
  }

  /// Notify Kotlin of the current app lifecycle state.
  /// Call with 'foreground' when app resumes, 'background' when it pauses.
  /// BackTapService writes this into the SOS POST body so the backend
  /// knows whether the direct HTTP call came from background or killed state.
  Future<void> saveAppState(String state) async {
    try {
      await _methodChannel.invokeMethod('saveAppState', {'state': state});
      debugPrint('✅ NativeBackTapService: app state saved → $state');
    } catch (e) {
      debugPrint('❌ NativeBackTapService.saveAppState() failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  START
  // ─────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;

    try {
      // Tell Kotlin to start the foreground BackTapService
      await _methodChannel.invokeMethod('startService');

      // Listen to EventChannel for tap events from Kotlin
      _eventSub = _eventChannel.receiveBroadcastStream().listen((
        dynamic event,
      ) {
        if (event is! Map) return;
        final type = event['type'] as String? ?? '';
        final count = event['count'] as int? ?? 0;

        if (type == 'tap_count') {
          _tapCountController.add(count);
          debugPrint('👆 Native tap $count/5');
        } else if (type == 'sos_trigger') {
          _tapCountController.add(0); // reset UI counter
          debugPrint('🚨 Native back-tap SOS triggered');
          _sosTriggerController.add(null);
        }
      }, onError: (e) => debugPrint('❌ BackTap EventChannel error: $e'));

      _running = true;
      debugPrint('✅ NativeBackTapService started');
    } catch (e) {
      debugPrint('❌ NativeBackTapService.start() failed: $e');
    }
  }
  // In native_back_tap_service.dart, add:

  /// Verify token exists in SharedPreferences (for debugging)
  Future<bool> hasToken() async {
    try {
      final hasToken = await _methodChannel.invokeMethod('hasToken');
      return hasToken ?? false;
    } catch (e) {
      debugPrint('❌ NativeBackTapService.hasToken() failed: $e');
      return false;
    }
  }
  // ─────────────────────────────────────────────
  //  STOP
  // ─────────────────────────────────────────────

  Future<void> stop() async {
    if (!_running) return;
    try {
      await _eventSub?.cancel();
      _eventSub = null;
      await _methodChannel.invokeMethod('stopService');
      _running = false;
      debugPrint('🛑 NativeBackTapService stopped');
    } catch (e) {
      debugPrint('❌ NativeBackTapService.stop() failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  DISPOSE
  // ─────────────────────────────────────────────

  Future<void> dispose() async {
    await stop();
    await _tapCountController.close();
    await _sosTriggerController.close();
  }
}
