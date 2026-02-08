import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safety_app/services/auth_service.dart';
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

    bool allowed = await _recordService.hasPermission();
    if (!allowed) {
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

    setState(() {
      isRecording = false;

      //  Increase count ONLY if not retaking
      if (!isRetaking) {
        sampleCount++;
      }

      if (sampleCount == 3) {
        registrationCompleted = true;
        statusText = "Voice registration completed!";
      } else {
        statusText =
            "Sample $sampleCount saved. You may play or retake the latest sample.";
      }

      isRetaking = false; // reset
      
    });
    if (latestSamplePath != null) {
      final user = await AuthService().getCurrentUser();
      if (user != null) {
        final userId = int.tryParse(user.id) ?? 0; // fix user.id red line safely

        try{
          final response = await AuthService().uploadVoice(
            userId: userId,
            sampleNumber: sampleCount,
            filePath: latestSamplePath!,
         );
        setState(() {
          statusText = response
              ? "Sample $sampleCount uploaded successfully"
              : "Upload failed for sample $sampleCount";
        });
        }catch(e){
           setState(() {
            statusText = "Upload failed for sample $sampleCount: $e";
          });
        }
      } else {
        setState(() {
          statusText = "Error: User not found for upload";
        });
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
