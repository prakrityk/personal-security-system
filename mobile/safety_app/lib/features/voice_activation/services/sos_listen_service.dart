import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

typedef SOSCallback = void Function(double confidence);
typedef StatusCallback = void Function(String status);

class SOSListenService {
  final AudioRecorder _recorder = AudioRecorder();
  Interpreter? _interpreter;
  bool _isListening = false;

  static const int sampleRate = 16000;

  // =========================
  // LOAD MODEL
  // =========================
  Future<void> loadModel(String assetPath) async {
    _interpreter ??= await Interpreter.fromAsset(assetPath);
    print("✅ RAW SOS TFLite model loaded");
  }

  // =========================
  // MIC PERMISSION
  // =========================
  Future<bool> hasPermission() async => await _recorder.hasPermission();

  // =========================
  // START LISTENING
  // =========================
  Future<void> startListening({
    required SOSCallback onSOSDetected,
    StatusCallback? onStatusChange,
  }) async {
    if (_isListening) return;
    _isListening = true;

    if (!await hasPermission()) {
      onStatusChange?.call("Microphone permission required");
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

      // Convert PCM16 → float [-1,1]
      for (int i = 0; i < data.length; i += 2) {
        int sample = data[i] | (data[i + 1] << 8);
        if (sample > 32767) sample -= 65536;
        buffer.add(sample / 32768.0);
      }

      // Process every 1 second with overlap
      while (buffer.length >= sampleRate) {
        final segment = buffer.sublist(0, sampleRate);
        _runModel(segment, onSOSDetected);

        // 50% overlap for better detection
        buffer.removeRange(0, sampleRate ~/ 2);
      }
    });
  }

  
  // =========================
  // RUN MODEL (RAW AUDIO)
  // =========================
  void _runModel(List<double> samples, SOSCallback onSOSDetected) {
    if (_interpreter == null) return;

    // Model expects: [1, 16000]
    var input = [samples];
    var output = List.generate(1, (_) => List.filled(2, 0.0));

    _interpreter!.run(input, output);

    double helpScore = output[0][1];

    if (helpScore > 0.8) {
      print("🚨 HELP detected! Confidence: $helpScore");
      onSOSDetected(helpScore);
    } else if (helpScore > 0.5) {
      print("⚠️ Possible HELP detected. Confidence: $helpScore");
    }
    else {
      print("Audio processed. HELP score: $helpScore");
    }
  }
}
