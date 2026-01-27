import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_record_service.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceRegistrationScreen extends StatefulWidget {
  const VoiceRegistrationScreen({super.key});

  @override
  State<VoiceRegistrationScreen> createState() =>
      _VoiceRegistrationScreenState();
}

class _VoiceRegistrationScreenState extends State<VoiceRegistrationScreen> {
  final VoiceRecordService _recordService = VoiceRecordService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isRecording = false;
  int sampleCount = 0; // total samples recorded
  String? lastSamplePath; // path of the latest recorded sample
  String statusText = "Press record & speak clearly";

  bool registrationCompleted = false; // ✅ tracks completion

  @override
  void initState() {
    super.initState();
    Permission.microphone.request();
  }

  void startRecording() async {
    if (sampleCount >= 3) return; // max 3 samples

    bool allowed = await _recordService.hasPermission();
    if (!allowed) {
      setState(() {
        statusText = "Microphone permission denied";
      });
      return;
    }

    // Start recording the next sample
    final path = await _recordService.startRecording(sampleCount + 1);

    setState(() {
      isRecording = true;
      lastSamplePath = path; // always update latest sample
      statusText = "Recording sample ${sampleCount + 1}... Speak now";
    });
  }

  void stopRecording() async {
    await _recordService.stopRecording();

    setState(() {
      isRecording = false;
      sampleCount++; // increment total samples
      if (sampleCount == 3) {
        registrationCompleted = true; // ✅ all 3 samples done
        statusText = "✅ All 3 samples recorded. Registration completed!";
      } else {
        statusText =
            "Sample $sampleCount recorded. You can play or retake the latest sample.";
      }
    });
  }

  void playLatestSample() async {
    if (lastSamplePath != null) {
      await _audioPlayer.play(DeviceFileSource(lastSamplePath!));
      setState(() {
        statusText = "Playing latest sample...";
      });
    }
  }

  void retakeLatestSample() async {
    if (lastSamplePath != null && sampleCount > 0) {
      setState(() {
        statusText = "Retaking latest sample...";
      });

      // Start recording again for the same sample number (overwrite)
      final path = await _recordService.startRecording(sampleCount);
      setState(() {
        isRecording = true;
        lastSamplePath = path; // overwrite latest sample
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Registration"),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Voice Samples Recorded: $sampleCount / 3",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (!registrationCompleted)
              ElevatedButton(
                onPressed: isRecording ? stopRecording : startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording ? Colors.grey : Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                ),
                child: Text(isRecording ? "Stop Recording" : "Start Recording"),
              ),
            const SizedBox(height: 20),
            if (lastSamplePath != null && !registrationCompleted)
              Column(
                children: [
                  const Text(
                    "Latest Sample Actions",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: playLatestSample,
                        style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text("Play Latest Sample"),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: retakeLatestSample,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        child: const Text("Retake Latest Sample"),
                      ),
                    ],
                  ),
                ],
              ),
            if (registrationCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  "🎉 Voice Registration Completed!",
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
