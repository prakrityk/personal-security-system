import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ─────────────────────────────────────────────
//  DEBUG TOGGLE
// ─────────────────────────────────────────────

const bool _enableDebug = true;

void _log(String msg) {
  if (_enableDebug) debugPrint(msg);
}

// ─────────────────────────────────────────────
//  DATA CLASSES
// ─────────────────────────────────────────────

class _BackgroundSample {
  _BackgroundSample({required this.time, required this.magnitude});
  final DateTime time;
  final double magnitude;
}

class _BgGyroSample {
  _BgGyroSample({required this.time, required this.rotation});
  final DateTime time;
  final double rotation;
}

// ─────────────────────────────────────────────
//  BACKGROUND SERVICE ENTRY POINT
// ─────────────────────────────────────────────

/// Background motion detection service using the same physics-based pipeline
/// as the foreground service. Invokes 'motion_detected' which is handled by
/// [MotionDetectionService] as the single API call point.
///
/// Pipeline:
///   Stable gravity baseline (10-sample average)
///   → Dynamic gravity filtering
///   → Sliding window
///   → 3-phase fall state machine
///   → Risk scoring (median gyro for robustness)
///   → invoke 'motion_detected' with correct event_type
@pragma('vm:entry-point')
Future<void> motionServiceOnStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Safety monitoring active',
      content: 'Motion-based SOS will auto-trigger if danger is detected.',
    );
  }

  _log('🎯 Motion background service started (physics engine)');

  // ── Tunable constants ──
  const double alpha = 0.8;
  const double freeFallMax = 2.5;
  const double impactMin = 18.0;
  const double postInactMax = 1.5;
  const double gyroThreshold = 5.0;
  const double tableShakeMax = 12.0;
  const int windowMs = 2000;
  const int cooldownMs = 60 * 1000;

  // ── IMPROVED: Stable gravity warm-up (10-sample average) ──
  const int gravityWarmupSamples = 10;
  int gravityWarmupCount = 0;
  double gravWarmX = 0, gravWarmY = 0, gravWarmZ = 0;
  bool gravityInitialized = false;
  double gravX = 0, gravY = 0, gravZ = 0;

  // ── State ──
  DateTime? lastTriggerAt;

  // Buffers
  final List<_BackgroundSample> accelBuffer = [];
  final List<_BgGyroSample> gyroBuffer = [];

  // 3-phase fall state: 0=idle, 1=freeFall, 2=postImpact
  int fallPhase = 0;
  DateTime? freeFallStart;
  DateTime? impactTime;
  double lastImpactMag = 0;

  // ── Risk score accumulator ──
  bool freeFallSeen = false;
  bool impactSeen = false;

  // ─────────────────────────────────────────────
  //  GYRO MEDIAN HELPER
  // ─────────────────────────────────────────────

  // IMPROVED: Returns median gyro rotation — robust to single spikes.
  double medianGyro() {
    if (gyroBuffer.isEmpty) return 0.0;
    final sorted = gyroBuffer.map((g) => g.rotation).toList()..sort();
    return sorted[sorted.length ~/ 2];
  }

  // ─────────────────────────────────────────────
  //  GYROSCOPE LISTENER
  // ─────────────────────────────────────────────

  final gyroSub = gyroscopeEvents.listen(
    (event) {
      final rotation = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final now = DateTime.now();
      gyroBuffer.add(_BgGyroSample(time: now, rotation: rotation));
      gyroBuffer.removeWhere(
        (s) => now.difference(s.time).inMilliseconds > windowMs,
      );
    },
    onError: (e) => _log('❌ [BG] Gyro error: $e'),
    cancelOnError: false,
  );

  // ─────────────────────────────────────────────
  //  ACCELEROMETER LISTENER
  // ─────────────────────────────────────────────

  final accelSub = accelerometerEvents.listen(
    (event) async {
      final now = DateTime.now();

      // ── IMPROVED: Stable gravity baseline (10-sample warm-up) ──
      // Accumulate first N samples before activating the filter.
      // This ensures the gravity vector is stable from the start.
      if (!gravityInitialized) {
        gravWarmX += event.x;
        gravWarmY += event.y;
        gravWarmZ += event.z;
        gravityWarmupCount++;

        if (gravityWarmupCount >= gravityWarmupSamples) {
          gravX = gravWarmX / gravityWarmupSamples;
          gravY = gravWarmY / gravityWarmupSamples;
          gravZ = gravWarmZ / gravityWarmupSamples;
          gravityInitialized = true;
          _log(
            '[BG] ✅ Gravity baseline: '
            '(${gravX.toStringAsFixed(2)}, '
            '${gravY.toStringAsFixed(2)}, '
            '${gravZ.toStringAsFixed(2)})',
          );
        }
        return;
      }

      // ── Dynamic gravity filtering (high-pass) ──
      gravX = alpha * gravX + (1 - alpha) * event.x;
      gravY = alpha * gravY + (1 - alpha) * event.y;
      gravZ = alpha * gravZ + (1 - alpha) * event.z;

      final linX = event.x - gravX;
      final linY = event.y - gravY;
      final linZ = event.z - gravZ;
      final magnitude = sqrt(linX * linX + linY * linY + linZ * linZ);

      // ── Sliding window ──
      accelBuffer.add(_BackgroundSample(time: now, magnitude: magnitude));
      accelBuffer.removeWhere(
        (s) => now.difference(s.time).inMilliseconds > windowMs,
      );

      // ── Cooldown guard ──
      if (lastTriggerAt != null &&
          now.difference(lastTriggerAt!).inMilliseconds < cooldownMs) {
        return;
      }

      // ── Table-shake false-positive guard (average gyro is fine here) ──
      if (magnitude < tableShakeMax) {
        final avgGyro = gyroBuffer.isEmpty
            ? 0.0
            : gyroBuffer.fold<double>(0, (s, g) => s + g.rotation) /
                  gyroBuffer.length;
        if (avgGyro < 0.3) return;
      }

      // ─────────────────────────────────────────
      //  3-PHASE FALL STATE MACHINE
      // ─────────────────────────────────────────

      switch (fallPhase) {
        case 0: // IDLE — look for free fall
          if (magnitude < freeFallMax) {
            fallPhase = 1;
            freeFallStart = now;
            freeFallSeen = true;
            _log(
              '[BG] ⬇️  Phase 1: Free fall (${magnitude.toStringAsFixed(2)})',
            );
          }
          break;

        case 1: // FREE FALL — look for impact
          final elapsed = now.difference(freeFallStart!).inMilliseconds;
          if (magnitude >= impactMin && elapsed >= 150 && elapsed <= 500) {
            fallPhase = 2;
            impactTime = now;
            lastImpactMag = magnitude;
            impactSeen = true;
            _log('[BG] 💥 Phase 2: Impact (${magnitude.toStringAsFixed(2)})');
          } else if (elapsed > 600) {
            fallPhase = 0;
            freeFallSeen = false;
          }
          break;

        case 2: // POST-IMPACT — monitor inactivity for 1.5 s
          final postElapsed = now.difference(impactTime!).inMilliseconds;
          if (postElapsed >= 1500) {
            final postSamples = accelBuffer.where(
              (s) => s.time.isAfter(impactTime!),
            );
            final avgPost = postSamples.isEmpty
                ? 0.0
                : postSamples.fold<double>(0, (s, e) => s + e.magnitude) /
                      postSamples.length;

            _log('[BG] 📊 Post-impact avg: ${avgPost.toStringAsFixed(2)}');

            if (avgPost < postInactMax) {
              // All 3 phases confirmed → score
              int score = 0;
              if (impactSeen) score += 40;
              if (freeFallSeen) score += 30;
              score += 40; // post-inactivity

              // IMPROVED: Use MEDIAN gyro for high-rotation bonus.
              // Avoids a single spike inflating the score.
              final medGyro = medianGyro();
              if (medGyro > gyroThreshold) {
                score += 30;
                _log(
                  '[BG] 📐 High median gyro: ${medGyro.toStringAsFixed(2)} (+30)',
                );
              }

              final windowAvg = accelBuffer.isEmpty
                  ? 0.0
                  : accelBuffer.fold<double>(0, (s, e) => s + e.magnitude) /
                        accelBuffer.length;
              if (windowAvg > 4.0) score += 15;

              _log('[BG] 🧮 Risk score: $score');

              // IMPROVED: Correctly forward event_type so foreground service
              // can pass 'confirmed_fall' vs 'possible_fall' to the backend.
              if (score >= 90) {
                lastTriggerAt = now;
                _log('[BG] 🚨 Confirmed fall (score=$score) → invoke');
                service.invoke('motion_detected', {
                  'trigger_type': 'motion',
                  'event_type': 'confirmed_fall',
                  'peak': lastImpactMag,
                  'score': score,
                });
              } else if (score >= 50) {
                lastTriggerAt = now;
                _log('[BG] ⚠️  Possible fall (score=$score) → invoke');
                service.invoke('motion_detected', {
                  'trigger_type': 'motion',
                  'event_type': 'possible_fall',
                  'peak': lastImpactMag,
                  'score': score,
                });
              }
            }

            // Reset state
            fallPhase = 0;
            freeFallSeen = false;
            impactSeen = false;
            lastImpactMag = 0;
          }
          break;
      }
    },
    onError: (e, st) {
      _log('❌ [BG] Sensor error: $e');
    },
    cancelOnError: false,
  );

  // ─────────────────────────────────────────────
  //  STOP HANDLER
  // ─────────────────────────────────────────────

  service.on('stop').listen((_) async {
    _log('🛑 Motion background service stopping...');
    await accelSub.cancel();
    await gyroSub.cancel();
    await service.stopSelf();
  });
}

// ─────────────────────────────────────────────
//  INIT / START / STOP
// ─────────────────────────────────────────────

Future<void> initMotionBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: motionServiceOnStart,
      isForegroundMode: true,
      autoStart: false,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

Future<void> startMotionBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.startService();
}

Future<void> stopMotionBackgroundService() async {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}
