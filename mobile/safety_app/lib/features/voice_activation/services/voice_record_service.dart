import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecordService {
  final AudioRecorder _recorder = AudioRecorder();

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
    try {
      await _recorder.stop();
      print(' Voice recording stopped.');
    } catch (e) {
      print(' Stop recording error (safe to ignore): $e');
    }
  }
}
