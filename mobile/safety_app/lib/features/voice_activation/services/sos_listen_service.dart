import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safety_app/services/voice_service.dart';
import 'package:safety_app/core/utils/wav_header.dart';
import 'package:safety_app/services/voice_message_service.dart';
import 'package:safety_app/core/network/dio_client.dart';

typedef SOSCallback = void Function();
typedef StatusCallback = void Function(String status);

class SOSListenService {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceService _voiceService = VoiceService();
  late final VoiceMessageService _voiceMessageService;

  Interpreter? _interpreter;
  bool _isListening = false;
  bool _isVerifying = false;

  bool get isCurrentlyListening => _isListening;

  static const int sampleRate = 16000;
  static const int requiredFrames = 2;
  static const int cooldownSeconds = 10;
  static const int detectionWindowSeconds = 5;

  int _positiveFrames = 0;
  DateTime? _lastTrigger;
  DateTime? _firstDetectionTime;
  bool _lastFrameWasPositive = false;

  SOSListenService() {
    _voiceMessageService = VoiceMessageService(
      dioClient: DioClient(),
    );
  }

  Future<void> loadModel(String assetPath) async {
    _interpreter ??= await Interpreter.fromAsset(assetPath);
    print("✅ RAW SOS TFLite model loaded");
  }

  Future<bool> hasPermission() async => await _recorder.hasPermission();

  // ─────────────────────────────────────────────────────────────
  // LOCATION HELPER (same logic as SosHomeScreen)
  // ─────────────────────────────────────────────────────────────
  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Location error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // START LISTENING
  // ─────────────────────────────────────────────────────────────
  Future<void> startListening({
    required int userId,
    required SOSCallback onSOSConfirmed,
    StatusCallback? onStatusChange,
  }) async {
    if (_isListening) return;
    _isListening = true;

    if (!await hasPermission()) {
      onStatusChange?.call("Microphone permission required");
      _isListening = false;
      return;
    }

    onStatusChange?.call("🟢 SOS Listening Active");

    if (_interpreter == null) {
      await loadModel('assets/tflite/help_raw_model.tflite');
    }

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );

    List<double> buffer = [];

    stream.listen((Uint8List data) {
      if (!_isListening) return;

      for (int i = 0; i < data.length; i += 2) {
        int sample = data[i] | (data[i + 1] << 8);
        if (sample > 32767) sample -= 65536;
        buffer.add(sample / 32768.0);
      }

      while (buffer.length >= sampleRate) {
        final segment = buffer.sublist(0, sampleRate);
        _runModel(segment, userId, onSOSConfirmed, onStatusChange);
        buffer.removeRange(0, sampleRate ~/ 2);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // MODEL INFERENCE
  // ─────────────────────────────────────────────────────────────
  void _runModel(
    List<double> samples,
    int userId,
    SOSCallback onSOSConfirmed,
    StatusCallback? onStatusChange,
  ) async {
    if (_interpreter == null || _isVerifying) return;

    var input = [Float32List.fromList(samples)];
    var output = List.generate(1, (_) => List.filled(2, 0.0));

    _interpreter!.run(input, output);

    double helpScore = output[0][1];
    final now = DateTime.now();

    print(
      " HELP score: $helpScore, Confidence: ${(helpScore * 100).toStringAsFixed(2)}%",
    );

    if (helpScore > 0.8) {
      if (!_lastFrameWasPositive) {
        // reset if outside detection window
        if (_firstDetectionTime == null ||
            now.difference(_firstDetectionTime!).inSeconds >
                detectionWindowSeconds) {
          _positiveFrames = 1;
          _firstDetectionTime = now;
        } else {
          _positiveFrames++;
        }
        _lastFrameWasPositive = true;

        // Print which help frame detected
        if (_positiveFrames == 1) {
          print(" First HELP detected!");
        } else if (_positiveFrames == 2) {
          print(" Second HELP detected!");
        } else {
          print(" HELP detected - Frame #$_positiveFrames");
        }
      }
    } else {
      _lastFrameWasPositive = false;
    }

    if (helpScore > 0.8 && _positiveFrames >= requiredFrames) {
      if (_lastTrigger == null ||
          now.difference(_lastTrigger!).inSeconds > cooldownSeconds) {
        _lastTrigger = now;
        print(" SOS TRIGGERED!");
        _verifyVoiceInternal(samples, userId, onSOSConfirmed, onStatusChange);
      }
      _positiveFrames = 0;
      _firstDetectionTime = null;
      _lastFrameWasPositive = false;
    }
  }

  Future<void> _verifyVoiceInternal(
    List<double> audioSamples,
    int userId,
    SOSCallback onConfirmed,
    StatusCallback? onStatusChange,
  ) async {
    _isVerifying = true;
    onStatusChange?.call("Verifying Voice...");

    try {
      final wavBytes = WavHeader.addHeader(audioSamples);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/voice_sos.wav');
      await file.writeAsBytes(wavBytes);

      bool isVerified = await _voiceService.verifyVoiceSos(
        userId: userId,
        filePath: file.path,
      );

      if (isVerified) {
        onStatusChange?.call("SOS Activated!");
        onConfirmed();

        // 🔴 GET LOCATION AT TRIGGER TIME
        final position = await _getCurrentLocation();

        try {
          final result = await _voiceMessageService.createSosWithVoice(
            filePath: file.path, // Voice file included
            triggerType: 'voice',
            eventType: 'voice_activation',
            latitude: position?.latitude,
            longitude: position?.longitude,
            appState: 'foreground',
          );

          if (result != null && result['event_id'] != null) {
            print("✅ Voice SOS event created: ${result['event_id']}");
          } else {
            throw Exception("Failed to create Voice SOS");
          }
        } catch (e) {
          print("❌ Failed to create Voice SOS: $e");
        }
      } else {
        onStatusChange?.call("Voice Mismatch - Ignored");
      }
    } catch (e) {
      print("Verification Error: $e");
    } finally {
      _isVerifying = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STOP LISTENING
  // ─────────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _recorder.stop();
    print("🛑 SOS Listener stopped.");
  }

  void dispose() {
    _voiceMessageService.dispose();
  }
}