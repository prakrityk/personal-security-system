// lib/services/motion_detection_gate.dart
//
// Single source of truth for deciding whether motion detection should run.
//
// Motion detection is enabled ONLY when BOTH of the following are true:
//
//   1. LOCAL toggle is ON
//      • Personal / Guardian user → SharedPreferences key 'motion_detection_enabled'
//        (written by SafetySettingsScreen)
//      • Dependent user        → SharedPreferences key 'motion_detection_enabled'
//        (written by this gate after reading DB setting on login)
//
//   2. REMOTE setting is ON (for dependent role only)
//      • Fetched from DependentSafetyService.getMySafetySettings()
//      • Cached in SharedPreferences key 'remote_motion_detection_enabled'
//        so it survives app restarts without an extra network hit.
//
// For personal / guardian users the remote check is skipped — their DB
// safety settings are managed through the guardian → dependent flow, not
// their own profile.
//
// Usage
// ─────
//   // Once after login / session restore:
//   await MotionDetectionGate.instance.evaluate(ref);
//
//   // After the user flips the in-app toggle:
//   await MotionDetectionGate.instance.setLocalToggle(enabled, ref);
//
//   // After the guardian changes a dependent's remote setting:
//   await MotionDetectionGate.instance.refreshRemoteSetting(ref);

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/providers/shared_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/services/dependent_safety_service.dart';
import 'package:safety_app/services/motion_detection_service.dart';

// ── SharedPreferences keys ──────────────────────────────────────────────────

/// Written by SafetySettingsScreen (personal/guardian) and by this gate
/// after evaluating the remote DB setting (dependent).
const String kMotionDetectionEnabled = 'motion_detection_enabled';

/// Cached copy of the backend's motion_detection flag for dependent users.
/// Updated every time [MotionDetectionGate.evaluate] or
/// [MotionDetectionGate.refreshRemoteSetting] is called.
const String kRemoteMotionDetectionEnabled = 'remote_motion_detection_enabled';

// ── Gate ────────────────────────────────────────────────────────────────────

class MotionDetectionGate {
  MotionDetectionGate._();
  static final MotionDetectionGate instance = MotionDetectionGate._();

  final DependentSafetyService _safetyService = DependentSafetyService();

  // ── Role helpers ──────────────────────────────────────────────────────────

  /// Returns true when the logged-in user has an active dependent role
  /// (they are being monitored by guardians). In this case we must also
  /// honour the remote safety settings configured by those guardians.
  bool _isDependent(WidgetRef ref) {
    final user = ref.read(authStateProvider).value;
    if (user == null) return false;
    final roles = user.roles ?? [];
    return roles.any(
      (r) => r.roleName.toLowerCase() == 'dependent',
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Full evaluation: reads local toggle + (for dependents) fetches remote
  /// setting, then starts or stops motion detection accordingly.
  ///
  /// Call this:
  ///   • On login / session restore (from main.dart / SOSApp)
  ///   • Any time the user's role might have changed
  Future<void> evaluate(WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final user = ref.read(authStateProvider).value;

    if (user == null) {
      _stop('no authenticated user');
      return;
    }

    // 1. Read local toggle ──────────────────────────────────────────────────
    final localEnabled = prefs.getBool(kMotionDetectionEnabled) ?? false;

    if (!localEnabled) {
      _stop('local toggle is OFF');
      return;
    }

    // 2. For dependent users, also check the remote DB setting ──────────────
    if (_isDependent(ref)) {
      final remoteEnabled = await _fetchAndCacheRemoteSetting(prefs);
      if (!remoteEnabled) {
        _stop('remote (guardian) setting is OFF');
        return;
      }
    }

    // 3. Both conditions satisfied → start ──────────────────────────────────
    _start();
  }

  /// Called when the user flips the in-app motion detection toggle.
  /// Persists the value and immediately re-evaluates.
  Future<void> setLocalToggle(bool enabled, WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(kMotionDetectionEnabled, enabled);
    debugPrint(
      '🔧 [Gate] Local motion toggle → $enabled',
    );
    await evaluate(ref);
  }

  /// Re-fetches the remote setting for dependent users and re-evaluates.
  /// Call this after a guardian changes the dependent's safety settings so
  /// the dependent device reacts without needing an app restart.
  Future<void> refreshRemoteSetting(WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (_isDependent(ref)) {
      await _fetchAndCacheRemoteSetting(prefs);
    }
    await evaluate(ref);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<bool> _fetchAndCacheRemoteSetting(SharedPreferences prefs) async {
    try {
      final settings = await _safetyService.getMySafetySettings();
      final enabled = settings.motionDetection;
      await prefs.setBool(kRemoteMotionDetectionEnabled, enabled);
      debugPrint(
        '📡 [Gate] Remote motion setting fetched → $enabled',
      );
      return enabled;
    } catch (e) {
      // Network failure: fall back to last cached value (defaults to false
      // if never fetched — safe default).
      final cached = prefs.getBool(kRemoteMotionDetectionEnabled) ?? false;
      debugPrint(
        '⚠️  [Gate] Remote fetch failed ($e) — using cached value: $cached',
      );
      return cached;
    }
  }

  void _start() {
    if (!MotionDetectionService.instance.isRunning) {
      debugPrint('✅ [Gate] Conditions met → starting MotionDetectionService');
      MotionDetectionService.instance.start();
    } else {
      debugPrint('ℹ️  [Gate] MotionDetectionService already running');
    }
  }

  void _stop(String reason) {
    if (MotionDetectionService.instance.isRunning) {
      debugPrint('🛑 [Gate] Stopping MotionDetectionService — $reason');
      MotionDetectionService.instance.stop();
    }
  }
}