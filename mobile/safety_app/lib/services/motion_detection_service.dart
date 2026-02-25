import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:safety_app/core/network/dio_client.dart';

import 'voice_message_service.dart';  // ✅ Use VoiceMessageService instead of SosEventService
import '../background/motion_background_service.dart';

/// Lightweight, on-device motion detection that can auto-trigger SOS with voice.
///
/// - Listens to accelerometer data (no camera/mic, no continuous logging)
/// - Detects sudden spikes that may indicate a fall or violent movement
/// - When threshold exceeded, starts 20s voice recording and sends SOS with voice
/// - Debounced with a cooldown to avoid spamming the backend
///
/// ARCHITECTURE NOTE:
/// This class now uses VoiceMessageService for unified SOS+voice flow.
class MotionDetectionService {
  MotionDetectionService._internal();
  static final MotionDetectionService instance =
      MotionDetectionService._internal();

  late VoiceMessageService _voiceMessageService;  // ✅ Will be initialized with DioClient

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription? _bgMotionSub;
  DateTime? _lastTriggerAt;

  /// Whether motion detection is currently running.
  bool get isRunning => _accelerometerSub != null;

  /// Configuration
  double thresholdG = 2.8;
  int windowMs = 500;
  int cooldownMs = 60 * 1000; // 60 seconds

  /// Initialize with DioClient (call this before using)
  void initialize({required DioClient dioClient}) {
    _voiceMessageService = VoiceMessageService(dioClient: dioClient);
  }

  /// Start listening to motion events and auto-trigger SOS with voice.
  void start() {
    if (_accelerometerSub != null) {
      return;
    }

    debugPrint('🎯 MotionDetectionService: starting (foreground + background)...');

    // Start background service for when app is backgrounded.
    if (!kIsWeb) {
      unawaited(initMotionBackgroundService());
      unawaited(startMotionBackgroundService());
    }

    // ✅ Listen for background service detections.
    _bgMotionSub = FlutterBackgroundService().on('motion_detected').listen((
      data,
    ) async {
      final now = DateTime.now();

      if (_lastTriggerAt != null &&
          now.difference(_lastTriggerAt!).inMilliseconds < cooldownMs) {
        debugPrint('⏭️ MotionDetectionService: BG motion ignored — cooldown active');
        return;
      }

      _lastTriggerAt = now;
      debugPrint('🚨 MotionDetectionService: BG motion received, starting 20s voice recording');

      try {
        // ✅ Use VoiceMessageService for auto recording (fixed 20s)
        await _voiceMessageService.startAutoRecordingAndSendSOS(
          triggerType: 'motion',
          eventType: 'possible_fall',
          // appState: 'background',
          latitude: null, // Location will be captured by the service
          longitude: null,
          onComplete: (eventId, voiceUrl) {
            debugPrint('✅ MotionDetectionService: BG motion SOS created! Event: $eventId, Voice: $voiceUrl');
          },
          onError: (error) {
            debugPrint('❌ MotionDetectionService: BG motion SOS failed: $error');
          },
        );
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

        buffer.add(_Sample(time: now, magnitude: magnitude));
        buffer.removeWhere(
          (s) => now.difference(s.time).inMilliseconds > windowMs,
        );

        if (_lastTriggerAt != null) {
          final diff = now.difference(_lastTriggerAt!).inMilliseconds;
          if (diff < cooldownMs) {
            return;
          }
        }

        final peak = buffer.fold<double>(0, (p, s) => max(p, s.magnitude));

        if (peak >= thresholdG) {
          _lastTriggerAt = now;
          debugPrint('🚨 MotionDetectionService: dangerous motion detected (peak=${peak.toStringAsFixed(2)}g)');

          try {
            // ✅ Get current location for foreground detection
            // You'll need to implement/get location here
            double? lat, lng;
            
            // TODO: Get current location using Geolocator
            // final position = await Geolocator.getCurrentPosition();
            // lat = position.latitude;
            // lng = position.longitude;

            // ✅ Use VoiceMessageService for auto recording (fixed 20s)
            await _voiceMessageService.startAutoRecordingAndSendSOS(
              triggerType: 'motion',
              eventType: 'possible_fall',
              // appState: 'foreground',
              latitude: lat,
              longitude: lng,
              onComplete: (eventId, voiceUrl) {
                debugPrint('✅ MotionDetectionService: motion SOS created! Event: $eventId, Voice: $voiceUrl');
              },
              onError: (error) {
                debugPrint('❌ MotionDetectionService: motion SOS failed: $error');
              },
            );
          } catch (e, st) {
            debugPrint('❌ MotionDetectionService: failed to create motion SOS: $e');
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
    if (!kIsWeb) {
      unawaited(stopMotionBackgroundService());
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
    _voiceMessageService.dispose();
  }
}

class _Sample {
  _Sample({required this.time, required this.magnitude});
  final DateTime time;
  final double magnitude;
}