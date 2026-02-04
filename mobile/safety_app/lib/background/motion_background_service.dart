import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/sos_event_service.dart';

/// Background entrypoint for motion detection.
///
/// This runs in a separate Dart isolate managed by flutter_background_service.
/// It keeps listening to accelerometer events even if the main Flutter UI
/// is closed, as long as the foreground service is running.
@pragma('vm:entry-point')
Future<void> motionServiceOnStart(ServiceInstance service) async {
  // Configure Android-specific foreground notification
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Safety monitoring active',
      content: 'Motion-based SOS will auto-trigger if danger is detected.',
    );
  }

  final sosService = SosEventService();

  DateTime? lastTriggerAt;
  const double thresholdG = 2.8;
  const int windowMs = 500;
  const int cooldownMs = 60 * 1000;

  final List<_BackgroundSample> buffer = [];

  debugPrint('🎯 Motion background service started');

  final sub = accelerometerEvents.listen(
    (event) async {
      final now = DateTime.now();
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      buffer.add(_BackgroundSample(time: now, magnitude: magnitude));
      buffer.removeWhere(
        (s) => now.difference(s.time).inMilliseconds > windowMs,
      );

      if (lastTriggerAt != null) {
        final diff = now.difference(lastTriggerAt!).inMilliseconds;
        if (diff < cooldownMs) {
          return;
        }
      }

      final peak =
          buffer.fold<double>(0, (prev, s) => max(prev, s.magnitude));

      if (peak >= thresholdG) {
        lastTriggerAt = now;
        debugPrint(
          '🚨 [BG] Dangerous motion detected (peak=${peak.toStringAsFixed(2)}g)',
        );

        try {
          await sosService.createSosEvent(
            triggerType: 'motion',
            eventType: 'possible_fall',
            appState: 'background',
          );
          debugPrint('✅ [BG] Motion SOS event created');
        } catch (e, st) {
          debugPrint('❌ [BG] Failed to create motion SOS event: $e');
          debugPrint(st.toString());
        }
      }
    },
    onError: (e, st) {
      debugPrint('❌ [BG] Sensor error: $e');
      debugPrint(st.toString());
    },
    cancelOnError: false,
  );

  // Handle stop command from main isolate
  service.on('stop').listen((event) async {
    debugPrint('🛑 Motion background service stopping...');
    await sub.cancel();
    await service.stopSelf();
  });
}

/// Configure the background service. Call once at app startup.
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

/// Start the background motion service (Android).
Future<void> startMotionBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.startService();
}

/// Stop the background motion service (Android).
Future<void> stopMotionBackgroundService() async {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}

class _BackgroundSample {
  _BackgroundSample({required this.time, required this.magnitude});

  final DateTime time;
  final double magnitude;
}

