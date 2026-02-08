import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  CameraController? _cameraController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Initialize camera for video recording
  Future<void> initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use front camera (index 1) if available, otherwise back camera (index 0)
      final camera = cameras.length > 1 ? cameras[1] : cameras[0];

      // Initialize camera controller
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium, // Medium quality to balance size and quality
        enableAudio: true,
      );

      await _cameraController!.initialize();
      print('Camera initialized successfully');
    } catch (e) {
      print('Error initializing camera: $e');
      rethrow;
    }
  }

  /// Record video for specified duration
  /// Returns the file path where video was saved
  Future<String?> recordVideo({int durationSeconds = 20}) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized. Call initializeCamera() first');
    }

    try {
      _isRecording = true;

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/video_$timestamp.mp4';

      print('Starting video recording: $filePath');
      await _cameraController!.startVideoRecording();

      // Record for specified duration
      await Future.delayed(Duration(seconds: durationSeconds));

      // Stop recording
      final video = await _cameraController!.stopVideoRecording();
      print('Video recording stopped');

      // Move to final location (XFile already saved)
      final File videoFile = File(video.path);
      final File finalFile = await videoFile.copy(filePath);
      
      // Delete temp file if different
      if (video.path != filePath) {
        await videoFile.delete();
      }

      _isRecording = false;
      return finalFile.path;
    } catch (e) {
      _isRecording = false;
      print('Error recording video: $e');
      return null;
    }
  }

  /// Record audio for specified duration
  /// Returns the file path where audio was saved
  Future<String?> recordAudio({int durationSeconds = 20}) async {
    try {
      _isRecording = true;

      // Check and request permission
      if (await _audioRecorder.hasPermission() == false) {
        throw Exception('Audio recording permission not granted');
      }

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/audio_$timestamp.m4a';

      print('Starting audio recording: $filePath');

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      // Record for specified duration
      await Future.delayed(Duration(seconds: durationSeconds));

      // Stop recording
      final path = await _audioRecorder.stop();
      print('Audio recording stopped: $path');

      _isRecording = false;
      return path;
    } catch (e) {
      _isRecording = false;
      print('Error recording audio: $e');
      return null;
    }
  }

  /// Stop any ongoing recording
  Future<void> stopRecording() async {
    if (_cameraController?.value.isRecordingVideo == true) {
      await _cameraController!.stopVideoRecording();
    }
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    _isRecording = false;
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _cameraController?.dispose();
    await _audioRecorder.dispose();
    _cameraController = null;
  }
}