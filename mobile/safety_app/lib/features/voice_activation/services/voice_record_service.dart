import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'dart:math';
// import 'dart:typed_data';


class VoiceRecordService {
  final AudioRecorder _recorder = AudioRecorder();
    // Interpreter? _interpreter;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String> startRecording(int sampleNo) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/voice_sample_$sampleNo.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
      ),
      path: path,
    );

    return path;
  }

  Future<void> stopRecording() async {
    await _recorder.stop();
  }


//   //  sos 
//   bool _isSOSListening = false;

//  Future<void> startSOSListening({
//   required Function(double confidence) onSOSDetected,
//   Function(String status)? onStatusChange,
// }) async {
//   if (_isSOSListening) return;
//   _isSOSListening = true;

//   bool allowed = await hasPermission();
//   if (!allowed) {
//     onStatusChange?.call("Microphone permission required");
//     return;
//   }

//   onStatusChange?.call('🟢 Protection Active - Listening...');

//   try {
//     // Start streaming raw PCM audio
//     final stream = await _recorder.startStream(
//       const RecordConfig(
//         encoder: AudioEncoder.pcm16bits,
//         sampleRate: 16000,
//         numChannels: 1,
//       ),
//     );

//     List<double> buffer = [];

//     stream.listen((Uint8List data) {
//       if (!_isSOSListening) return;

//       // Convert bytes to normalized audio samples (-1.0 to 1.0)
//       for (int i = 0; i < data.length; i += 2) {
//         int sample = data[i] | (data[i + 1] << 8);
//         if (sample > 32767) sample -= 65536;
//         buffer.add(sample / 32768.0);
//       }

//       // Check every 1 second of audio (16,000 samples)
//       while (buffer.length >= 16000) {
//         final segment = buffer.sublist(0, 16000);
//         _runModel(segment, onSOSDetected);

//         // Remove 50% for sliding window
//         buffer.removeRange(0, 8000);
//       }
//     });
//   } catch (e) {
//     print("SOS listening error: $e");
//     onStatusChange?.call("Error starting SOS listening");
//   }
// }


//   /// Run TFLite model on 1-second audio segment
//   void _runModel(List<double> samples, Function(double) onSOSDetected) {
//     if (_interpreter == null) return;

//     var input = [samples];
//     var output = List.generate(1, (_) => List.filled(2, 0.0));

//     _interpreter!.run(input, output);

//     double helpScore = output[0][1];

//     if (helpScore > 0.8) {
//       print("🚨 HELP detected: $helpScore");
//       onSOSDetected(helpScore);
//     }
//   }


//   //  Future<Map<String, dynamic>> _detectKeyword(String wavPath) async {
//   //   try {
//   //     if (_interpreter == null) {
//   //       print("Model not loaded");
//   //       return {"detected": false, "confidence": 0.0};
//   //     }

//   //     // Convert WAV → samples
//   //     final samples = await _readWavSamples(wavPath);

//   //     // Extract MFCC
//   //     final mfcc = _extractMFCC(samples);

//   //     // Run model
//   //     var input = [mfcc];
//   //     var output = List.generate(1, (_) => List.filled(2, 0.0));

//   //     _interpreter!.run(input, output);

//   //     double helpScore = output[0][1];
//   //     print("HELP probability: $helpScore");

//   //     return {
//   //       "detected": helpScore > 0.65,
//   //       "confidence": helpScore,
//   //     };
//   //   } catch (e) {
//   //     print("Keyword detection error: $e");
//   //     return {"detected": false, "confidence": 0.0};
//   //   }
//   // }

//   // // ================= WAV READER =================
//   // Future<List<double>> _readWavSamples(String path) async {
//   //   final file = File(path);
//   //   final bytes = await file.readAsBytes();

//   //   // Skip WAV header (44 bytes)
//   //   final pcmBytes = bytes.sublist(44);

//   //   List<double> samples = [];
//   //   for (int i = 0; i < pcmBytes.length; i += 2) {
//   //     int sample = pcmBytes[i] | (pcmBytes[i + 1] << 8);
//   //     if (sample > 32767) sample -= 65536;
//   //     samples.add(sample / 32768.0);
//   //   }
//   //   return samples;
//   // }

//   // // ================= SIMPLE MFCC =================
//   // List<double> _extractMFCC(List<double> samples) {
//   //   const int nMfcc = 13;
//   //   List<double> mfcc = List.filled(nMfcc, 0);

//   //   double mean =
//   //       samples.reduce((a, b) => a + b) / max(samples.length, 1);

//   //   for (int i = 0; i < nMfcc; i++) {
//   //     mfcc[i] = mean * (i + 1) / 10;
//   //   }

//   //   return mfcc;
//   // }

//   void stopSOSListening(){
//     _isSOSListening= false;
//     _recorder.stop();
//   }


// }
}