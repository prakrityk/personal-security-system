import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'sos_event_service.dart';
import '../background/motion_background_service.dart';

/// Lightweight, on-device motion detection that can auto-trigger SOS.
///
/// - Listens to accelerometer data (no camera/mic, no continuous logging)
/// - Detects sudden spikes that may indicate a fall or violent movement
/// - When threshold exceeded, sends a single "motion" SOS event
/// - Debounced with a cooldown to avoid spamming the backend
///
/// ARCHITECTURE NOTE:
/// This class is the SOLE owner of POST /sos/events for motion triggers.
/// The background service (motion_background_service.dart) only detects
/// motion and invokes 'motion_detected' — it never calls the API directly.
class MotionDetectionService {
  MotionDetectionService._internal();
  static final MotionDetectionService instance =
      MotionDetectionService._internal();

  final SosEventService _sosService = SosEventService();

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription? _bgMotionSub;
  DateTime? _lastTriggerAt;

  /// Whether motion detection is currently running.
  bool get isRunning => _accelerometerSub != null;

  /// Configuration (can later be made user-specific if needed).
  ///
  /// [thresholdG]  Acceleration magnitude in g-units that is considered dangerous.
  /// [windowMs]    Detection window; if any sample in this window exceeds threshold, we trigger.
  /// [cooldownMs]  Minimum time between two automatic SOS triggers.
  double thresholdG = 2.8;
  int windowMs = 500;
  int cooldownMs = 60 * 1000; // 60 seconds

  /// Start listening to accelerometer and auto-trigger motion SOS on spikes.
  ///
  /// Safe to call multiple times; subsequent calls while already running
  /// will be ignored.
  void start() {
    if (_accelerometerSub != null) {
      return;
    }

    debugPrint(
      '🎯 MotionDetectionService: starting (foreground + background)...',
    );

    // Start background service for when app is backgrounded.

    unawaited(initMotionBackgroundService());
    unawaited(startMotionBackgroundService());

    // ✅ Listen for background service detections.
    // The background service invokes 'motion_detected' instead of calling
    // the API itself — this is the single place that calls POST /sos/events
    // for background motion triggers.
    _bgMotionSub = FlutterBackgroundService().on('motion_detected').listen((
      data,
    ) async {
      final now = DateTime.now();

      // Shared cooldown guard — prevents double-firing if foreground and
      // background detect the same event within the cooldown window.
      if (_lastTriggerAt != null &&
          now.difference(_lastTriggerAt!).inMilliseconds < cooldownMs) {
        debugPrint(
          '⏭️ MotionDetectionService: BG motion ignored — cooldown active',
        );
        return;
      }

      _lastTriggerAt = now;
      debugPrint(
        '🚨 MotionDetectionService: BG motion received, creating SOS event',
      );

      try {
        await _sosService.createSosEvent(
          triggerType: 'motion',
          eventType: 'possible_fall',
          appState: 'background',
        );
        debugPrint('✅ MotionDetectionService: BG motion SOS event created');
      } catch (e, st) {
        debugPrint('❌ MotionDetectionService: BG motion SOS failed: $e');
        debugPrint(st.toString());
      }
    });

    // ✅ Foreground accelerometer listener.
    final List<_Sample> buffer = [];

    _accelerometerSub = accelerometerEvents.listen(
      (event) async {
        final now = DateTime.now();
        final magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );

        // Keep only samples within the last [windowMs].
        buffer.add(_Sample(time: now, magnitude: magnitude));
        buffer.removeWhere(
          (s) => now.difference(s.time).inMilliseconds > windowMs,
        );

        // Cooldown guard — shared with BG listener via _lastTriggerAt.
        if (_lastTriggerAt != null) {
          final diff = now.difference(_lastTriggerAt!).inMilliseconds;
          if (diff < cooldownMs) {
            return;
          }
        }

        final peak = buffer.fold<double>(0, (p, s) => max(p, s.magnitude));

        if (peak >= thresholdG) {
          _lastTriggerAt = now;
          debugPrint(
            '🚨 MotionDetectionService: dangerous motion detected (peak=${peak.toStringAsFixed(2)}g)',
          );

          try {
            await _sosService.createSosEvent(
              triggerType: 'motion',
              eventType: 'possible_fall',
              appState: 'foreground',
            );
            debugPrint(
              '✅ MotionDetectionService: motion SOS event created successfully',
            );
          } catch (e, st) {
            debugPrint(
              '❌ MotionDetectionService: failed to create motion SOS event: $e',
            );
            debugPrint(st.toString());
          }
        }
      },
      onError: (e, st) {
        debugPrint('❌ MotionDetectionService: sensor error: $e');
        debugPrint(st.toString());
      },
      cancelOnError: false,
    );
  }

  /// Stop listening to motion events.
  void stop() {
    debugPrint('🛑 MotionDetectionService: stopping...');
    _accelerometerSub?.cancel();
    _accelerometerSub = null;
    _bgMotionSub?.cancel();
    _bgMotionSub = null;
    unawaited(stopMotionBackgroundService());
  }
}

class _Sample {
  _Sample({required this.time, required this.magnitude});

  final DateTime time;
  final double magnitude;
}
