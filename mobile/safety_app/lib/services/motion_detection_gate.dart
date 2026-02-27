// lib/services/motion_detection_gate.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safety_app/services/dependent_safety_service.dart';
import 'package:safety_app/services/motion_detection_service.dart';

// ── SharedPreferences keys ──────────────────────────────────────────────────

const String kMotionDetectionEnabled = 'motion_detection_enabled';
const String kRemoteMotionDetectionEnabled = 'remote_motion_detection_enabled';

// ── Minimal user info needed by the gate ─────────────────────────────────────

class GateUser {
  final List<String> roleNames;
  GateUser(this.roleNames);
  bool get isDependent => roleNames.any((r) {
  final role = r.toLowerCase();
  return role == 'dependent' || role == 'child';
});
}

// ── Gate ─────────────────────────────────────────────────────────────────────
//
// Decision table:
//
// ┌─────────────┬────────────────────────────────────────────────────────────┐
// │ Role        │ Logic                                                      │
// ├─────────────┼────────────────────────────────────────────────────────────┤
// │ Guardian    │ Local SharedPreferences toggle is the sole authority.      │
// │             │ ON → start sensor. OFF → stop sensor.                     │
// ├─────────────┼────────────────────────────────────────────────────────────┤
// │ Dependent   │ Guardian's remote DB setting is the sole authority.        │
// │             │ No local toggle exists on dependent's device.              │
// │             │ Remote ON → start. Remote OFF → stop.                     │
// └─────────────┴────────────────────────────────────────────────────────────┘

class MotionDetectionGate {
  MotionDetectionGate._();
  static final MotionDetectionGate instance = MotionDetectionGate._();

  final DependentSafetyService _safetyService = DependentSafetyService();

  /// Full evaluation — pass prefs and user directly, no WidgetRef needed.
  Future<void> evaluate(SharedPreferences prefs, GateUser? user) async {
    if (user == null) {
      _stop('no authenticated user');
      return;
    }

    if (user.isDependent) {
      // ── Dependent: remote DB value set by guardian is the sole authority ──
      // No local toggle exists on the dependent's device.
      final remoteEnabled = await _fetchAndCacheRemoteSetting(prefs);
      if (remoteEnabled) {
        _start();
      } else {
        _stop('guardian has disabled motion detection');
      }
    } else {
      // ── Guardian: local SharedPreferences toggle is the sole authority ──
      final localEnabled = prefs.getBool(kMotionDetectionEnabled) ?? false;
      if (localEnabled) {
        _start();
      } else {
        _stop('local toggle is OFF');
      }
    }
  }

  /// Called when the guardian flips their own motion toggle
  /// in safety_settings_screen.dart. Only relevant for guardians —
  /// dependents have no toggle.
  Future<void> setLocalToggle(
    bool enabled,
    SharedPreferences prefs,
    GateUser? user,
  ) async {
    await prefs.setBool(kMotionDetectionEnabled, enabled);
    debugPrint('🔧 [Gate] Local motion toggle → $enabled');
    await evaluate(prefs, user);
  }

  /// Called after guardian updates the dependent's motion setting via
  /// safety_settings_section_widget.dart. Re-fetches from DB and re-evaluates.
  Future<void> refreshRemoteSetting(
    SharedPreferences prefs,
    GateUser? user,
  ) async {
    if (user?.isDependent == true) {
      await _fetchAndCacheRemoteSetting(prefs);
    }
    await evaluate(prefs, user);
  }

  Future<bool> _fetchAndCacheRemoteSetting(SharedPreferences prefs) async {
    try {
      final settings = await _safetyService.getMySafetySettings();
      final enabled = settings.motionDetection;
      await prefs.setBool(kRemoteMotionDetectionEnabled, enabled);
      debugPrint('📡 [Gate] Remote motion setting fetched → $enabled');
      return enabled;
    } catch (e) {
      final cached = prefs.getBool(kRemoteMotionDetectionEnabled) ?? false;
      debugPrint('⚠️  [Gate] Remote fetch failed ($e) — using cached: $cached');
      return cached;
    }
  }

  void _start() {
    if (!MotionDetectionService.instance.isRunning) {
      debugPrint('✅ [Gate] Starting MotionDetectionService');
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
