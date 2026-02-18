import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safety_app/services/auth_service.dart';
import '../services/voice_record_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:safety_app/core/providers/auth_provider.dart'; // ✅ Required for authStateProvider
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Required for ConsumerState
class VoiceRegistrationScreen extends ConsumerStatefulWidget {  const VoiceRegistrationScreen({super.key});

  @override
 ConsumerState<VoiceRegistrationScreen> createState() => 
 _VoiceRegistrationScreenState();}

class _VoiceRegistrationScreenState extends ConsumerState<VoiceRegistrationScreen> {
    final VoiceRecordService _recordService = VoiceRecordService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isRecording = false;
  bool isRetaking = false; // IMPORTANT FLAG

  int sampleCount = 0; // total finalized samples (max 3)
  String? latestSamplePath;

  bool registrationCompleted = false;

  String statusText = "Press record & speak clearly";

  @override
  void initState() {
    super.initState();
    Permission.microphone.request();
  }

  //  START RECORDING 
  void startRecording() async {
    if (sampleCount >= 3) return;

     final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      setState(() {
        statusText = "Microphone permission denied";
      });
      return;
    }

    isRetaking = false; //  this is a NEW sample

    final path = await _recordService.startRecording(sampleCount + 1);

    setState(() {
      isRecording = true;
      latestSamplePath = path;
      statusText = "Recording sample ${sampleCount + 1}...";
    });
  }

  //STOP RECORDING 
  void stopRecording() async {
  await _recordService.stopRecording();
  if (!mounted) return; // ✅ Initial safety check

  setState(() {
    isRecording = false;
    if (!isRetaking) sampleCount++;
  });

  if (latestSamplePath != null) {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final response = await AuthService().uploadVoice(
        userId: int.parse(user.id),
        sampleNumber: sampleCount,
        filePath: latestSamplePath!,
      );

      if (!mounted) return; // ✅ Check again after network call

      if (sampleCount == 3 && response) {
      // ✅ Pass 'true' to indicate registration is successful
      await ref.read(authStateProvider.notifier).updateVoiceRegistrationStatus(true);
      
      if (mounted) {
        setState(() {
          registrationCompleted = true;
          statusText = "🎉 Registration Successful!";
        });
      }
        Navigator.pop(context, true);

    }
      
    }
  }
}

  // PLAY LATEST SAMPLE 
  void playLatestSample() async {
    if (latestSamplePath == null) return;

    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(latestSamplePath!));

    setState(() {
      statusText = "Playing latest sample...";
    });
  }

  // RETAKE LATEST SAMPLE
  void retakeLatestSample() async {
    if (sampleCount == 0 || latestSamplePath == null) return;

    isRetaking = true;

    final path = await _recordService.startRecording(sampleCount);

    setState(() {
      isRecording = true;
      latestSamplePath = path; // overwrite same file
      statusText = "Retaking sample $sampleCount...";
    });
  }

  // UI 
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
              "Samples: $sampleCount / 3",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            //  RECORD BUTTON 
            if (!registrationCompleted)
              ElevatedButton(
                onPressed: isRecording ? stopRecording : startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording ? Colors.grey : Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child:
                    Text(isRecording ? "Stop Recording" : "Start Recording"),
              ),

            const SizedBox(height: 20),

            //  LATEST SAMPLE ACTIONS 
            if (latestSamplePath != null && !registrationCompleted)
              Column(
                children: [
                  const Text(
                    "Latest Sample Only",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: playLatestSample,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue),
                        child: const Text("Play"),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: retakeLatestSample,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        child: const Text("Retake"),
                      ),
                    ],
                  ),
                ],
              ),

            //  COMPLETION MESSAGE 
            if (registrationCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Text(
                  "🎉 Voice Registration Completed",
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}