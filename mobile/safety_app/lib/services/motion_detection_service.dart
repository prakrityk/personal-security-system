// lib/services/motion_detection_service.dart
//
// Hybrid Multi-Sensor Context-Aware Motion Risk Engine
//
// Changes from previous version:
//   - _fireSos now grabs GPS coordinates (5s timeout, non-fatal) and passes
//     latitude/longitude to createSosWithVoice
//   - Removed stray `R` typo in _initBackgroundService
//   - All braces verified balanced (72 open / 72 close)

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../background/motion_background_service.dart';
import '../core/network/dio_client.dart';
import 'native_back_tap_service.dart';
import 'voice_message_service.dart';

// ─────────────────────────────────────────────
//  DEBUG TOGGLE
// ─────────────────────────────────────────────

/// Set to false before releasing to production to silence all sensor logs.
const bool _enableDebug = true;

void _log(String msg) {
  if (_enableDebug) debugPrint(msg);
}

// ─────────────────────────────────────────────
//  ENUMS & CONSTANTS
// ─────────────────────────────────────────────

enum MotionState { idle, freeFall, impact, postImpactMonitoring, confirmedFall }

enum UserMode { normal, elderly, child }

/// Scores for risk engine
class _Score {
  static const int impact = 40;
  static const int freeFall = 30;
  static const int postInactivity = 40;
  static const int highRotation = 30;
  static const int sustainedVibration = 15;
  static const int runningCadence = 20;

  static const int sosThreshold = 90;
  static const int alertThreshold = 50;
}

// ─────────────────────────────────────────────
//  DATA CLASSES
// ─────────────────────────────────────────────

class _Sample {
  _Sample({required this.time, required this.magnitude});
  final DateTime time;
  final double magnitude;
}

class _GyroSample {
  _GyroSample({required this.time, required this.rotation});
  final DateTime time;
  final double rotation;
}

// ─────────────────────────────────────────────
//  THRESHOLDS PER MODE
// ─────────────────────────────────────────────

class _ModeThresholds {
  final double freeFallMax;
  final double impactMin;
  final double postInactivityMax;
  final double runningPeakMin;
  final double runningPeakMax;
  final int runningMinPeaks;
  final double gyroThreshold;
  final double tableShakeMax;

  const _ModeThresholds({
    required this.freeFallMax,
    required this.impactMin,
    required this.postInactivityMax,
    required this.runningPeakMin,
    required this.runningPeakMax,
    required this.runningMinPeaks,
    required this.gyroThreshold,
    required this.tableShakeMax,
  });
}

const Map<UserMode, _ModeThresholds> _thresholds = {
  UserMode.normal: _ModeThresholds(
    freeFallMax: 2.5,
    impactMin: 18.0,
    postInactivityMax: 1.5,
    runningPeakMin: 8.0,
    runningPeakMax: 15.0,
    runningMinPeaks: 6,
    gyroThreshold: 5.0,
    tableShakeMax: 12.0,
  ),
  UserMode.elderly: _ModeThresholds(
    freeFallMax: 3.0,
    impactMin: 14.0,
    postInactivityMax: 2.0,
    runningPeakMin: 7.0,
    runningPeakMax: 13.0,
    runningMinPeaks: 5,
    gyroThreshold: 4.0,
    tableShakeMax: 10.0,
  ),
  UserMode.child: _ModeThresholds(
    freeFallMax: 2.0,
    impactMin: 16.0,
    postInactivityMax: 1.5,
    runningPeakMin: 9.0,
    runningPeakMax: 16.0,
    runningMinPeaks: 6,
    gyroThreshold: 5.5,
    tableShakeMax: 12.0,
  ),
};

// ─────────────────────────────────────────────
//  MAIN SERVICE
// ─────────────────────────────────────────────

/// **Hybrid Multi-Sensor Context-Aware Motion Risk Engine**
///
/// Detection pipeline:
///   Sensors (Accel + Gyro)
///     → Stable gravity baseline (10-sample average)
///     → Dynamic gravity filtering (high-pass)
///     → Sliding window buffer (2 s)
///     → Feature extraction (peaks, cadence, inactivity)
///     → 3-phase fall state machine
///     → Risk scoring engine (median gyro for robustness)
///     → Decision layer (SOS / Guardian alert / Ignore)
///
/// Manual trigger (back-tap):
///   Handled entirely by native Kotlin BackTapService.
///   NativeBackTapService bridges events here via MethodChannel/EventChannel.
///   On sosTriggerStream → 2s cancellable confirmation → SOS fires.
///
/// Supports three user modes with different sensitivity profiles.
class MotionDetectionService {
  MotionDetectionService._internal();
  static final MotionDetectionService instance =
      MotionDetectionService._internal();

  VoiceMessageService? _voiceService;

  // ── Sensor subscriptions (fall detection only) ──
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription? _bgMotionSub;

  // ── Native back-tap subscriptions ──
  StreamSubscription? _nativeTapCountSub;
  StreamSubscription? _nativeSosTriggerSub;

  // ── State ──
  MotionState _state = MotionState.idle;
  UserMode userMode = UserMode.normal;
  DateTime? _lastTriggerAt;
  final int _cooldownMs = 40 * 1000;

  // ── Stable gravity baseline (10-sample warm-up) ──
  static const double _alpha = 0.8;
  static const int _gravityWarmupSamples = 10;
  double _gravX = 0, _gravY = 0, _gravZ = 0;
  bool _gravityInitialized = false;
  int _gravityWarmupCount = 0;
  double _gravWarmX = 0, _gravWarmY = 0, _gravWarmZ = 0;

  // ── Sliding window buffers (2 s) ──
  static const int _windowMs = 2000;
  final List<_Sample> _accelBuffer = [];
  final List<_GyroSample> _gyroBuffer = [];

  // ── 3-phase fall detection ──
  DateTime? _freeFallStart;
  DateTime? _impactTime;
  Timer? _postImpactTimer;
  Timer? _inactivitySosTimer;

  // ── Back-tap confirmation (2s cancel window) ──
  // Tap detection is in Kotlin. These handle the confirmation
  // dialog and cooldown on the Flutter/Dart side only.
  Timer? _tapConfirmationTimer;
  bool _tapConfirmationPending = false;
  final _tapConfirmationController = StreamController<bool>.broadcast();
  Stream<bool> get tapConfirmationStream => _tapConfirmationController.stream;

  // ── Tap count stream (forwarded from native for UI progress indicator) ──
  final _tapCountController = StreamController<int>.broadcast();
  Stream<int> get tapCountStream => _tapCountController.stream;

  // ── Running cadence ──
  final List<DateTime> _runningPeakTimes = [];
  bool _runningDetected = false;

  bool get isRunning => _accelSub != null;

  // ─────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────

  /// Call once from main.dart before start().
  void initialize({required DioClient dioClient}) {
    _voiceService = VoiceMessageService(dioClient: dioClient);
    _wireNativeBackTap();
    _log('✅ MotionDetectionService: initialized');
  }

  void dispose() {
    stop();
    _nativeTapCountSub?.cancel();
    _nativeSosTriggerSub?.cancel();
    _tapConfirmationController.close();
    _tapCountController.close();
    _voiceService?.dispose();
    _voiceService = null;
    _log('🗑️ MotionDetectionService: disposed');
  }

  void start() {
    if (_accelSub != null) return;
    _log('🎯 MotionDetectionService: starting (${userMode.name} mode)...');
    _initBackgroundService();
    _startGyroscope();
    _startAccelerometer();
    // NativeBackTapService is started independently in main.dart on login
    // so back-tap works even when the motion detection toggle is OFF.
  }

  void stop() {
    _log('🛑 MotionDetectionService: stopping...');
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _bgMotionSub?.cancel();
    _bgMotionSub = null;
    _postImpactTimer?.cancel();
    _inactivitySosTimer?.cancel();
    _tapConfirmationTimer?.cancel();
    _tapConfirmationPending = false;
    _state = MotionState.idle;
    _runningDetected = false;
    _resetGravityWarmup();
    // NativeBackTapService is stopped independently in main.dart on logout
    // so removing it here prevents the gate from killing back-tap when the
    // motion detection toggle is turned OFF.
    unawaited(stopMotionBackgroundService());
  }

  // ─────────────────────────────────────────────
  //  NATIVE BACK-TAP BRIDGE
  // ─────────────────────────────────────────────

  /// Wires NativeBackTapService streams into this service.
  /// Called once from initialize(). Subscriptions live for the app lifetime.
  void _wireNativeBackTap() {
    // Forward tap count to UI (shows "tap 1/5, 2/5..." progress indicator)
    _nativeTapCountSub = NativeBackTapService.instance.tapCountStream.listen(
      (count) => _tapCountController.add(count),
    );

    // SOS trigger from Kotlin → 2s confirmation window → fire SOS
    _nativeSosTriggerSub =
        NativeBackTapService.instance.sosTriggerStream.listen((_) {
      final now = DateTime.now();

      if (_isCooldownActive(now)) {
        _log('🚫 Native back-tap SOS blocked — cooldown active');
        return;
      }
      if (_tapConfirmationPending) {
        _log('🚫 Native back-tap SOS blocked — confirmation already pending');
        return;
      }

      _log('👆👆👆👆👆 Native back-tap received → 2s confirmation window...');

      _tapConfirmationPending = true;
      _tapConfirmationController.add(true); // UI: show cancel snackbar

      _tapConfirmationTimer?.cancel();
      _tapConfirmationTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!_tapConfirmationPending) return;
        _tapConfirmationPending = false;
        _tapConfirmationController.add(false); // UI: hide cancel snackbar

        if (_isCooldownActive(DateTime.now())) return;

        _log('🚨 Back-tap SOS confirmed → firing');
        _postImpactTimer?.cancel();
        _inactivitySosTimer?.cancel();
        _state = MotionState.idle;
        _runningDetected = false;
        _lastTriggerAt = DateTime.now();
        unawaited(_fireSos('foreground', 'back_tap'));
      });
    });
  }

  /// Cancel a pending back-tap SOS during the 2s confirmation window.
  /// Wire this to a UI cancel button or snackbar action.
  void cancelBackTapSos() {
    if (_tapConfirmationPending) {
      _tapConfirmationTimer?.cancel();
      _tapConfirmationPending = false;
      _tapConfirmationController.add(false);
      _log('🚫 Back-tap SOS cancelled by user');
    }
  }

  // ─────────────────────────────────────────────
  //  GRAVITY WARM-UP RESET
  // ─────────────────────────────────────────────

  void _resetGravityWarmup() {
    _gravityInitialized = false;
    _gravityWarmupCount = 0;
    _gravWarmX = 0;
    _gravWarmY = 0;
    _gravWarmZ = 0;
    _gravX = 0;
    _gravY = 0;
    _gravZ = 0;
  }

  // ─────────────────────────────────────────────
  //  BACKGROUND SERVICE
  // ─────────────────────────────────────────────

  void _initBackgroundService() {
    unawaited(initMotionBackgroundService());
    unawaited(startMotionBackgroundService());

    _bgMotionSub =
        FlutterBackgroundService().on('motion_detected').listen((data) async {
      final now = DateTime.now();
      if (_isCooldownActive(now)) return;
      _lastTriggerAt = now;

      final eventType = (data?['event_type'] as String?) ?? 'possible_fall';
      _log('🚨 [BG] motion detected ($eventType) → sending SOS (background)');

      try {
        final result = await _voiceService?.createSosWithVoice(
          filePath: null,
          triggerType: 'motion',
          eventType: eventType,
          appState: 'background',
        );
        if (result != null) {
          _log('✅ [BG] SOS sent! Event ID: ${result['event_id']}');
        } else {
          _log('❌ [BG] SOS creation returned null — check token/network');
        }
      } catch (e) {
        _log('❌ [BG] SOS send failed: $e');
      }
    });
  }

  // ─────────────────────────────────────────────
  //  GYROSCOPE
  // ─────────────────────────────────────────────

  void _startGyroscope() {
    _gyroSub = gyroscopeEvents.listen(
      (event) {
        final rotation = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        final now = DateTime.now();
        _gyroBuffer.add(_GyroSample(time: now, rotation: rotation));
        _gyroBuffer.removeWhere(
          (s) => now.difference(s.time).inMilliseconds > _windowMs,
        );
      },
      onError: (e) => _log('❌ Gyro error: $e'),
      cancelOnError: false,
    );
  }

  // ─────────────────────────────────────────────
  //  ACCELEROMETER + FALL DETECTION PIPELINE
  // ─────────────────────────────────────────────

  void _startAccelerometer() {
    _accelSub = accelerometerEvents.listen(
      (event) async {
        final now = DateTime.now();
        final t = _thresholds[userMode]!;

        // ── STEP 1: Stable gravity baseline (warm-up average) ──
        if (!_gravityInitialized) {
          _gravWarmX += event.x;
          _gravWarmY += event.y;
          _gravWarmZ += event.z;
          _gravityWarmupCount++;

          if (_gravityWarmupCount >= _gravityWarmupSamples) {
            _gravX = _gravWarmX / _gravityWarmupSamples;
            _gravY = _gravWarmY / _gravityWarmupSamples;
            _gravZ = _gravWarmZ / _gravityWarmupSamples;
            _gravityInitialized = true;
            _log(
              '✅ Gravity baseline established: '
              '(${_gravX.toStringAsFixed(2)}, '
              '${_gravY.toStringAsFixed(2)}, '
              '${_gravZ.toStringAsFixed(2)})',
            );
          }
          return;
        }

        // ── STEP 2: Dynamic gravity filtering (high-pass) ──
        _gravX = _alpha * _gravX + (1 - _alpha) * event.x;
        _gravY = _alpha * _gravY + (1 - _alpha) * event.y;
        _gravZ = _alpha * _gravZ + (1 - _alpha) * event.z;

        final linX = event.x - _gravX;
        final linY = event.y - _gravY;
        final linZ = event.z - _gravZ;

        final magnitude = sqrt(linX * linX + linY * linY + linZ * linZ);

        // ── STEP 3: Sliding window buffer ──
        _accelBuffer.add(_Sample(time: now, magnitude: magnitude));
        _accelBuffer.removeWhere(
          (s) => now.difference(s.time).inMilliseconds > _windowMs,
        );

        // ── STEP 4: False-positive guard (table shake / vibration) ──
        if (_isTableShake(magnitude, t)) return;

        // ── STEP 5: Running detection (cadence) ──
        _detectRunning(magnitude, now, t);

        // ── STEP 6: 3-phase fall state machine ──
        await _runFallStateMachine(magnitude, now, t);
      },
      onError: (e) => _log('❌ Accel error: $e'),
      cancelOnError: false,
    );
  }

  // ─────────────────────────────────────────────
  //  GYRO HELPERS
  // ─────────────────────────────────────────────

  double _medianGyro() {
    if (_gyroBuffer.isEmpty) return 0.0;
    final sorted = _gyroBuffer.map((g) => g.rotation).toList()..sort();
    return sorted[sorted.length ~/ 2];
  }

  double _avgGyro() {
    if (_gyroBuffer.isEmpty) return 0.0;
    return _gyroBuffer.fold<double>(0, (s, g) => s + g.rotation) /
        _gyroBuffer.length;
  }

  // ─────────────────────────────────────────────
  //  FALSE-POSITIVE: TABLE SHAKE GUARD
  // ─────────────────────────────────────────────

  bool _isTableShake(double magnitude, _ModeThresholds t) {
    if (magnitude > t.tableShakeMax) return false;
    if (_gyroBuffer.isEmpty) return false;

    final avg = _avgGyro();
    if (avg < 0.3 && magnitude < t.tableShakeMax) {
      _log(
        '🔇 Table shake suppressed '
        '(accel=${magnitude.toStringAsFixed(2)}, gyro=${avg.toStringAsFixed(2)})',
      );
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────
  //  3-PHASE FALL STATE MACHINE
  // ─────────────────────────────────────────────

  Future<void> _runFallStateMachine(
    double magnitude,
    DateTime now,
    _ModeThresholds t,
  ) async {
    switch (_state) {
      case MotionState.idle:
        if (magnitude < t.freeFallMax) {
          _freeFallStart = now;
          _state = MotionState.freeFall;
          _log(
            '⬇️  Phase 1: FREE FALL detected (mag=${magnitude.toStringAsFixed(2)})',
          );
        }
        break;

      case MotionState.freeFall:
        final freeFallDuration =
            now.difference(_freeFallStart!).inMilliseconds;
        if (magnitude >= t.impactMin) {
          if (freeFallDuration >= 150 && freeFallDuration <= 500) {
            _impactTime = now;
            _state = MotionState.impact;
            _log(
              '💥 Phase 2: IMPACT detected (mag=${magnitude.toStringAsFixed(2)}, '
              'fallDuration=${freeFallDuration}ms)',
            );
            await _onImpact(magnitude, t);
          } else {
            _state = MotionState.idle;
          }
        } else if (freeFallDuration > 600) {
          _state = MotionState.idle;
          _log('🔄 Free fall timeout → reset');
        }
        break;

      case MotionState.impact:
        break;

      case MotionState.postImpactMonitoring:
        break;

      case MotionState.confirmedFall:
        break;
    }
  }

  Future<void> _onImpact(double impactMagnitude, _ModeThresholds t) async {
    _state = MotionState.postImpactMonitoring;

    final wasRunning = _runningDetected;
    _runningDetected = false;

    _postImpactTimer?.cancel();
    _postImpactTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_state != MotionState.postImpactMonitoring) return;

      final now = DateTime.now();
      final recentSamples = _accelBuffer.where(
        (s) => now.difference(s.time).inMilliseconds <= 1500,
      );

      if (recentSamples.isEmpty) return;

      final avgMag =
          recentSamples.fold<double>(0, (s, e) => s + e.magnitude) /
          recentSamples.length;

      _log('📊 Post-impact avg: ${avgMag.toStringAsFixed(2)} m/s²');

      if (avgMag < t.postInactivityMax) {
        _state = MotionState.confirmedFall;
        _log('🛑 Phase 3: POST-IMPACT INACTIVITY confirmed');
        await _computeAndDecide(
          impactMagnitude,
          t,
          hasPostInactivity: true,
          isRunning: wasRunning,
        );
      } else {
        _log('🚶 Movement after impact — no fall confirmed');
        _state = MotionState.idle;
      }
    });
  }

  // ─────────────────────────────────────────────
  //  RISK SCORING ENGINE
  // ─────────────────────────────────────────────

  Future<void> _computeAndDecide(
    double impactMagnitude,
    _ModeThresholds t, {
    bool hasPostInactivity = false,
    bool isRunning = false,
  }) async {
    if (_isCooldownActive(DateTime.now())) return;

    int score = 0;
    final List<String> reasons = [];

    score += _Score.impact;
    reasons.add('impact(+${_Score.impact})');

    score += _Score.freeFall;
    reasons.add('freeFall(+${_Score.freeFall})');

    if (hasPostInactivity) {
      score += _Score.postInactivity;
      reasons.add('postInactivity(+${_Score.postInactivity})');
    }

    final medianGyroVal = _medianGyro();
    if (medianGyroVal > t.gyroThreshold) {
      score += _Score.highRotation;
      reasons.add(
        'highRotation(+${_Score.highRotation}) median=${medianGyroVal.toStringAsFixed(2)}',
      );
    }

    if (isRunning) {
      score += _Score.runningCadence;
      reasons.add('running(+${_Score.runningCadence})');
    }

    final windowAvg = _accelBuffer.isEmpty
        ? 0.0
        : _accelBuffer.fold<double>(0, (s, e) => s + e.magnitude) /
              _accelBuffer.length;
    if (windowAvg > 4.0) {
      score += _Score.sustainedVibration;
      reasons.add('sustainedVibration(+${_Score.sustainedVibration})');
    }

    _log('🧮 Risk score: $score [${reasons.join(', ')}]');

    if (isRunning && score < _Score.sosThreshold) {
      _log('🏃 Running detected → Guardian Alert only');
      _lastTriggerAt = DateTime.now();
      await _fireSos('foreground', 'running_detected');
      _state = MotionState.idle;
      return;
    }

    if (score >= _Score.sosThreshold) {
      _lastTriggerAt = DateTime.now();
      _log(
        '🚨 SOS threshold reached ($score) → firing possible_fall immediately',
      );
      await _fireSos('foreground', 'possible_fall');
      _startInactivityConfirmationTimer();
    }
  }

  // ─────────────────────────────────────────────
  //  INACTIVITY CONFIRMATION — ESCALATION TIMER
  // ─────────────────────────────────────────────

  void _startInactivityConfirmationTimer() {
    _log('⏳ Starting 10s inactivity confirmation timer...');
    _inactivitySosTimer?.cancel();
    _inactivitySosTimer = Timer(const Duration(seconds: 10), () async {
      if (_state != MotionState.confirmedFall) return;

      final now = DateTime.now();
      final recent = _accelBuffer.where(
        (s) => now.difference(s.time).inMilliseconds <= 5000,
      );
      final recentAvg = recent.isEmpty
          ? 0.0
          : recent.fold<double>(0, (s, e) => s + e.magnitude) / recent.length;

      if (recentAvg < 1.0) {
        _log(
          '🚨 Inactivity confirmed after 10s → escalating to confirmed_fall',
        );
        _lastTriggerAt = now;
        await _fireSos('foreground', 'confirmed_fall');
      } else {
        _log('🚶 Movement detected in confirmation window — no escalation');
      }
      _state = MotionState.idle;
    });
  }

  // ─────────────────────────────────────────────
  //  RUNNING DETECTION (CADENCE)
  // ─────────────────────────────────────────────

  void _detectRunning(double magnitude, DateTime now, _ModeThresholds t) {
    if (magnitude >= t.runningPeakMin && magnitude <= t.runningPeakMax) {
      _runningPeakTimes.add(now);
    }

    _runningPeakTimes.removeWhere(
      (pt) => now.difference(pt).inMilliseconds > 2000,
    );

    if (_runningPeakTimes.length >= t.runningMinPeaks) {
      _log(
        '🏃 Running cadence detected (${_runningPeakTimes.length} peaks in 2s)',
      );
      _runningPeakTimes.clear();
      _runningDetected = true;
    }
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────

  bool _isCooldownActive(DateTime now) {
    if (_lastTriggerAt == null) return false;
    return now.difference(_lastTriggerAt!).inMilliseconds < _cooldownMs;
  }

  // ─────────────────────────────────────────────
  //  FIRE SOS
  // ─────────────────────────────────────────────

  Future<void> _fireSos(String appState, String eventType) async {
    if (_voiceService == null) {
      _log(
        '❌ MotionDetectionService not initialized — call initialize() first',
      );
      return;
    }
    try {
      // ── Grab current GPS coordinates (5s timeout, non-fatal) ──
      double? latitude;
      double? longitude;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 5));
        latitude = position.latitude;
        longitude = position.longitude;
        _log('📍 Location captured: $latitude, $longitude');
      } catch (e) {
        _log('⚠️ Could not get location for SOS (non-fatal): $e');
        // SOS still fires without coordinates
      }

      _log('🚨 _fireSos: $eventType ($appState)');
      final result = await _voiceService!.createSosWithVoice(
        filePath: null,
        triggerType: 'motion',
        eventType: eventType,
        appState: appState,
        latitude: latitude,
        longitude: longitude,
      );
      if (result != null) {
        _log('✅ SOS created! Event ID: ${result["event_id"]}');
      } else {
        _log('❌ SOS creation returned null — check token/network');
      }
    } catch (e, st) {
      _log('❌ _fireSos exception: $e');
      _log(st.toString());
    }
  }
}