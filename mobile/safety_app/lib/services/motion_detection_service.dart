import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../background/motion_background_service.dart';
import 'voice_message_service.dart';
import '../core/network/dio_client.dart';

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
  static const int doubleJerk = 25;
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
  final double freeFallMax; // m/s²
  final double impactMin; // m/s²
  final double postInactivityMax; // m/s²
  final double runningPeakMin;
  final double runningPeakMax;
  final int runningMinPeaks;
  final double gyroThreshold; // rad/s
  final double
  tableShakeMax; // below this + no gyro = ignore (anti-table-shake)

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
    freeFallMax: 3.0, // slightly more lenient free-fall detection
    impactMin: 14.0, // lower impact threshold — elderly fall softer
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
///     → Dynamic gravity filtering (high-pass)
///     → Sliding window buffer (2 s)
///     → Feature extraction (peaks, cadence, inactivity)
///     → 3-phase fall state machine
///     → Risk scoring engine
///     → Decision layer (SOS / Guardian alert / Ignore)
///
/// Supports three user modes with different sensitivity profiles.
class MotionDetectionService {
  MotionDetectionService._internal();
  static final MotionDetectionService instance =
      MotionDetectionService._internal();

  VoiceMessageService? _voiceService;

  // ── Subscriptions ──
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription? _bgMotionSub;

  // ── State ──
  MotionState _state = MotionState.idle;
  UserMode userMode = UserMode.normal;
  DateTime? _lastTriggerAt;
  final int _cooldownMs = 60 * 1000;

  // ── Dynamic gravity filter (high-pass) ──
  static const double _alpha = 0.8;
  double _gravX = 0, _gravY = 0, _gravZ = 0;
  bool _gravityInitialized = false;

  // ── Sliding window buffers (2 s) ──
  static const int _windowMs = 2000;
  final List<_Sample> _accelBuffer = [];
  final List<_GyroSample> _gyroBuffer = [];

  // ── 3-phase fall detection ──
  DateTime? _freeFallStart;
  DateTime? _impactTime;
  Timer? _postImpactTimer;
  Timer? _inactivitySosTimer;

  // ── Double-jerk detection ──
  DateTime? _lastJerkTime;
  int _jerkCount = 0;

  // ── Running cadence ──
  final List<DateTime> _runningPeakTimes = [];

  bool get isRunning => _accelSub != null;

  // ─────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────

  /// Call once from main.dart before start()
  void initialize({required DioClient dioClient}) {
    _voiceService = VoiceMessageService(dioClient: dioClient);
    debugPrint('✅ MotionDetectionService: initialized');
  }

  void dispose() {
    stop();
    _voiceService?.dispose();
    _voiceService = null;
    debugPrint('🗑️ MotionDetectionService: disposed');
  }

  void start() {
    if (_accelSub != null) return;

    debugPrint(
      '🎯 MotionDetectionService: starting (${userMode.name} mode)...',
    );

    _initBackgroundService();
    _startGyroscope();
    _startAccelerometer();
  }

  void stop() {
    debugPrint('🛑 MotionDetectionService: stopping...');
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _bgMotionSub?.cancel();
    _bgMotionSub = null;
    _postImpactTimer?.cancel();
    _inactivitySosTimer?.cancel();
    _state = MotionState.idle;
    unawaited(stopMotionBackgroundService());
  }

  // ─────────────────────────────────────────────
  //  BACKGROUND SERVICE
  // ─────────────────────────────────────────────

  void _initBackgroundService() {
    unawaited(initMotionBackgroundService());
    unawaited(startMotionBackgroundService());

    _bgMotionSub = FlutterBackgroundService().on('motion_detected').listen((
      data,
    ) async {
      final now = DateTime.now();
      if (_isCooldownActive(now)) return;
      _lastTriggerAt = now;
      debugPrint('🚨 [BG] motion received → creating SOS event');
      await _fireSos('background', 'possible_fall');
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
      onError: (e) => debugPrint('❌ Gyro error: $e'),
      cancelOnError: false,
    );
  }

  // ─────────────────────────────────────────────
  //  ACCELEROMETER + MAIN PIPELINE
  // ─────────────────────────────────────────────

  void _startAccelerometer() {
    _accelSub = accelerometerEvents.listen(
      (event) async {
        final now = DateTime.now();
        final t = _thresholds[userMode]!;

        // ── STEP 1: Dynamic gravity filtering (high-pass) ──
        if (!_gravityInitialized) {
          _gravX = event.x;
          _gravY = event.y;
          _gravZ = event.z;
          _gravityInitialized = true;
          return;
        }

        _gravX = _alpha * _gravX + (1 - _alpha) * event.x;
        _gravY = _alpha * _gravY + (1 - _alpha) * event.y;
        _gravZ = _alpha * _gravZ + (1 - _alpha) * event.z;

        final linX = event.x - _gravX;
        final linY = event.y - _gravY;
        final linZ = event.z - _gravZ;

        final magnitude = sqrt(linX * linX + linY * linY + linZ * linZ);

        // ── STEP 2: Sliding window buffer ──
        _accelBuffer.add(_Sample(time: now, magnitude: magnitude));
        _accelBuffer.removeWhere(
          (s) => now.difference(s.time).inMilliseconds > _windowMs,
        );

        // ── False-positive guard: table shake / vibration ──
        // Table shake: high accel but near-zero gyro → ignore
        if (_isTableShake(magnitude, t)) return;

        // ── STEP 4: Running detection (cadence) ──
        _detectRunning(magnitude, now, t);

        // ── STEP 5+3: State machine for 3-phase fall detection ──
        await _runFallStateMachine(magnitude, now, t);

        // ── STEP: Double-jerk manual trigger ──
        // NOTE: Runs AFTER state machine so it can cancel pending timers
        _detectDoubleJerk(magnitude, now, t);
      },
      onError: (e) => debugPrint('❌ Accel error: $e'),
      cancelOnError: false,
    );
  }

  // ─────────────────────────────────────────────
  //  FALSE-POSITIVE: TABLE SHAKE GUARD
  // ─────────────────────────────────────────────

  bool _isTableShake(double magnitude, _ModeThresholds t) {
    // If acceleration is moderate (below tableShakeMax) AND gyro is near-zero
    // for the entire window → device is resting on table, not a person falling.
    if (magnitude > t.tableShakeMax) {
      return false; // too large, let fall logic handle
    }

    if (_gyroBuffer.isEmpty) return false;

    final avgGyro =
        _gyroBuffer.fold<double>(0, (s, g) => s + g.rotation) /
        _gyroBuffer.length;

    // Very low rotation + moderate accel = table vibration (phone buzzing, knocking)
    if (avgGyro < 0.3 && magnitude < t.tableShakeMax) {
      debugPrint(
        '🔇 Table shake suppressed (accel=${magnitude.toStringAsFixed(2)}, gyro=${avgGyro.toStringAsFixed(2)})',
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
        // Detect phase 1: free fall (low acceleration = weightlessness)
        if (magnitude < t.freeFallMax) {
          _freeFallStart = now;
          _state = MotionState.freeFall;
          debugPrint(
            '⬇️  Phase 1: FREE FALL detected (mag=${magnitude.toStringAsFixed(2)})',
          );
        }
        break;

      case MotionState.freeFall:
        final freeFallDuration = now.difference(_freeFallStart!).inMilliseconds;

        if (magnitude >= t.impactMin) {
          // Free fall must last 150–500 ms to be valid
          if (freeFallDuration >= 150 && freeFallDuration <= 500) {
            _impactTime = now;
            _state = MotionState.impact;
            debugPrint(
              '💥 Phase 2: IMPACT detected (mag=${magnitude.toStringAsFixed(2)}, '
              'fallDuration=${freeFallDuration}ms)',
            );
            await _onImpact(magnitude, t);
          } else {
            // Duration out of range — reset
            _state = MotionState.idle;
          }
        } else if (freeFallDuration > 600) {
          // Too long without impact — reset (device was just placed gently)
          _state = MotionState.idle;
          debugPrint('🔄 Free fall timeout → reset');
        }
        break;

      case MotionState.impact:
        // Handled by _onImpact which transitions to postImpactMonitoring
        break;

      case MotionState.postImpactMonitoring:
        // Continuously feed magnitude into post-impact window (timer already running)
        break;

      case MotionState.confirmedFall:
        // Already handled
        break;
    }
  }

  Future<void> _onImpact(double impactMagnitude, _ModeThresholds t) async {
    _state = MotionState.postImpactMonitoring;

    // Monitor 1.5 s post-impact for inactivity
    _postImpactTimer?.cancel();
    _postImpactTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_state != MotionState.postImpactMonitoring) return;

      // Compute avg magnitude in last 1.5 s
      final now = DateTime.now();
      final recentSamples = _accelBuffer.where(
        (s) => now.difference(s.time).inMilliseconds <= 1500,
      );

      if (recentSamples.isEmpty) return;

      final avgMag =
          recentSamples.fold<double>(0, (s, e) => s + e.magnitude) /
          recentSamples.length;

      debugPrint('📊 Post-impact avg: ${avgMag.toStringAsFixed(2)} m/s²');

      if (avgMag < t.postInactivityMax) {
        // Phase 3 confirmed → compute risk score
        _state = MotionState.confirmedFall;
        debugPrint('🛑 Phase 3: POST-IMPACT INACTIVITY confirmed');
        await _computeAndDecide(impactMagnitude, t, hasPostInactivity: true);
      } else {
        // Person moved — possible recovery
        debugPrint('🚶 Movement after impact — no fall confirmed');
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
    bool isDoubleJerk = false,
    bool isRunning = false,
  }) async {
    if (_isCooldownActive(DateTime.now())) return;

    int score = 0;
    final List<String> reasons = [];

    // Impact
    score += _Score.impact;
    reasons.add('impact(+${_Score.impact})');

    // Free fall detected (we're in 3-phase, so yes)
    score += _Score.freeFall;
    reasons.add('freeFall(+${_Score.freeFall})');

    // Post-impact inactivity
    if (hasPostInactivity) {
      score += _Score.postInactivity;
      reasons.add('postInactivity(+${_Score.postInactivity})');
    }

    // High rotation (gyro)
    final maxGyro = _gyroBuffer.isEmpty
        ? 0.0
        : _gyroBuffer.fold<double>(0, (m, g) => max(m, g.rotation));
    if (maxGyro > t.gyroThreshold) {
      score += _Score.highRotation;
      reasons.add('highRotation(+${_Score.highRotation})');
    }

    // Double jerk
    if (isDoubleJerk) {
      score += _Score.doubleJerk;
      reasons.add('doubleJerk(+${_Score.doubleJerk})');
    }

    // Running cadence (reduces SOS likelihood)
    if (isRunning) {
      score += _Score.runningCadence;
      reasons.add('running(+${_Score.runningCadence})');
    }

    // Sustained vibration check
    final windowAvg = _accelBuffer.isEmpty
        ? 0.0
        : _accelBuffer.fold<double>(0, (s, e) => s + e.magnitude) /
              _accelBuffer.length;
    if (windowAvg > 4.0) {
      score += _Score.sustainedVibration;
      reasons.add('sustainedVibration(+${_Score.sustainedVibration})');
    }

    debugPrint('🧮 Risk score: $score [${reasons.join(', ')}]');

    if (isRunning && score < _Score.sosThreshold) {
      // Running alone → guardian alert, not SOS
      debugPrint('🏃 Running detected → Guardian Alert');
      _lastTriggerAt = DateTime.now();
      await _fireSos('foreground', 'running_detected');
      _state = MotionState.idle;
      return;
    }

    if (score >= _Score.sosThreshold) {
      _lastTriggerAt = DateTime.now();

      // ✅ Fire IMMEDIATELY on high score — don't wait 10s
      await _fireSos('foreground', 'possible_fall');

      // Then start confirmation timer for escalation
      _startInactivityConfirmationTimer();
    }
  }

  // ─────────────────────────────────────────────
  //  INACTIVITY CONFIRMATION (STEP 8)
  // ─────────────────────────────────────────────

  void _startInactivityConfirmationTimer() {
    debugPrint('⏳ Starting 10s inactivity confirmation timer...');
    _inactivitySosTimer?.cancel();
    _inactivitySosTimer = Timer(const Duration(seconds: 10), () async {
      if (_state != MotionState.confirmedFall) return;

      // Check if person has moved in last 10 s
      final now = DateTime.now();
      final recent = _accelBuffer.where(
        (s) => now.difference(s.time).inMilliseconds <= 5000,
      );
      final recentAvg = recent.isEmpty
          ? 0.0
          : recent.fold<double>(0, (s, e) => s + e.magnitude) / recent.length;

      if (recentAvg < 1.0) {
        debugPrint('🚨 Inactivity confirmed → AUTO SOS');
        await _fireSos('foreground', 'confirmed_fall');
      } else {
        debugPrint(
          '🚶 Movement detected in confirmation window — SOS cancelled',
        );
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

    // Keep only peaks in last 2 s
    _runningPeakTimes.removeWhere(
      (pt) => now.difference(pt).inMilliseconds > 2000,
    );

    if (_runningPeakTimes.length >= t.runningMinPeaks) {
      debugPrint(
        '🏃 Running cadence detected '
        '(${_runningPeakTimes.length} peaks in 2s)',
      );
      _runningPeakTimes.clear();
      // Running event is evaluated through risk scoring not direct trigger
    }
  }

  // ─────────────────────────────────────────────
  //  DOUBLE-JERK MANUAL TRIGGER
  // ─────────────────────────────────────────────

  void _detectDoubleJerk(double magnitude, DateTime now, _ModeThresholds t) {
    // A jerk is a sharp spike above impact threshold
    if (magnitude >= t.impactMin) {
      if (_lastJerkTime != null &&
          now.difference(_lastJerkTime!).inMilliseconds <= 800) {
        _jerkCount++;
        if (_jerkCount >= 2) {
          _jerkCount = 0;
          _lastJerkTime = null;
          debugPrint(
            '✊ Double-jerk manual trigger detected → immediate SOS (no wait)',
          );
          if (!_isCooldownActive(now)) {
            // ✅ Cancel ALL pending timers immediately — no delay for demo/testing
            _postImpactTimer?.cancel();
            _inactivitySosTimer?.cancel();
            // Reset state machine so it doesn't interfere or double-fire
            _state = MotionState.idle;

            _lastTriggerAt = now;
            unawaited(_fireSos('foreground', 'double_jerk'));
          }
        }
      } else {
        _jerkCount = 1;
        _lastJerkTime = now;
      }
    }
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────

  bool _isCooldownActive(DateTime now) {
    if (_lastTriggerAt == null) return false;
    return now.difference(_lastTriggerAt!).inMilliseconds < _cooldownMs;
  }

  Future<void> _fireSos(String appState, String eventType) async {
    if (_voiceService == null) {
      debugPrint(
        '❌ MotionDetectionService not initialized — call initialize() first',
      );
      return;
    }
    try {
      debugPrint('🎙️ Starting auto recording + SOS: $eventType ($appState)');
      await _voiceService!.startAutoRecordingAndSendSOS(
        triggerType: 'motion',
        eventType: eventType,
        onComplete: (eventId, voiceUrl) {
          debugPrint('✅ SOS created! Event ID: $eventId, Voice URL: $voiceUrl');
        },
        onError: (error) {
          debugPrint('❌ Failed to create SOS with voice: $error');
        },
      );
    } catch (e, st) {
      debugPrint('❌ Failed to fire SOS: $e');
      debugPrint(st.toString());
    }
  }
}
