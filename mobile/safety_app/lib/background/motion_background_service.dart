import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/sos_event_service.dart';

@pragma('vm:entry-point')
Future<void> motionServiceOnStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Safety monitoring active',
      content: 'Motion-based SOS will auto-trigger if danger is detected.',
    );
  }

 // final sosService = SosEventService();

  DateTime? lastTriggerAt;

  // --- TUNABLE CONSTANTS ---
  const double gravity = 9.8; // Earth's gravity in m/s²
  const double threshold = 18.0; // ~1.8g sudden impact
  const int windowMs = 400; // detection window
  const int cooldownMs = 60 * 1000; // 1 minute cooldown
  const int minSpikeCount = 2; // require consecutive spikes

  final List<_BackgroundSample> buffer = [];
  int spikeCount = 0;

  debugPrint('🎯 Motion background service started');

  final sub = accelerometerEvents.listen(
    (event) async {
      final now = DateTime.now();

      // 1️⃣ Compute total acceleration magnitude
      final total = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // 2️⃣ Remove gravity to get linear acceleration
      final linearAcceleration = (total - gravity).abs();

      // 3️⃣ Add to rolling buffer
      buffer.add(_BackgroundSample(time: now, magnitude: linearAcceleration));

      buffer.removeWhere(
        (s) => now.difference(s.time).inMilliseconds > windowMs,
      );

      // 4️⃣ Cooldown protection
      if (lastTriggerAt != null) {
        final diff = now.difference(lastTriggerAt!).inMilliseconds;
        if (diff < cooldownMs) {
          return;
        }
      }

      // 5️⃣ Find peak in window
      final peak = buffer.fold<double>(0, (prev, s) => max(prev, s.magnitude));

      // 6️⃣ Require consecutive spikes (reduces noise triggers)
      if (peak >= threshold) {
        spikeCount++;
      } else {
        spikeCount = 0;
      }

      if (spikeCount >= minSpikeCount) {
        lastTriggerAt = now;
        spikeCount = 0;

        debugPrint(
          '🚨 [BG] Dangerous motion detected '
          '(peak=${peak.toStringAsFixed(2)} m/s²)',
        );
        service.invoke('motion_detected', {
          'trigger_type': 'motion',
          'event_type': 'possible_fall',
          'peak': peak,
        });

        // try {
        //   await sosService.createSosEvent(
        //     triggerType: 'motion',
        //     eventType: 'possible_fall',
        //     appState: 'background',
        //   );
        //   debugPrint('✅ [BG] Motion SOS event created');
        // } catch (e, st) {
        //   debugPrint('❌ [BG] Failed to create motion SOS event: $e');
        //   debugPrint(st.toString());
        // }
      }
    },
    onError: (e, st) {
      debugPrint('❌ [BG] Sensor error: $e');
      debugPrint(st.toString());
    },
    cancelOnError: false,
  );

  service.on('stop').listen((event) async {
    debugPrint('🛑 Motion background service stopping...');
    await sub.cancel();
    await service.stopSelf();
  });
}

/// Configure the background service (call once in main()).
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

/// Start background motion detection.
Future<void> startMotionBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.startService();
}

/// Stop background motion detection.
Future<void> stopMotionBackgroundService() async {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}

class _BackgroundSample {
  _BackgroundSample({required this.time, required this.magnitude});

  final DateTime time;
  final double magnitude;
}
