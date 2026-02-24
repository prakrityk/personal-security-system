// lib/services/voice_message_service.dart
//
// Handles voice message recording for SOS events.
// Used by:
//   - Manual SOS: long press start/end (can release early)
//   - Voice activation & motion detection: auto 20s recording (fixed duration)

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:safety_app/core/network/dio_client.dart';

class VoiceMessageService {
  final AudioRecorder _recorder = AudioRecorder();
  final DioClient _dioClient;

  bool _isRecording = false;
  String? _currentFilePath;
  Timer? _autoStopTimer;

  static const int maxRecordingSeconds = 20;

  bool get isRecording => _isRecording;
  String? get lastFilePath => _currentFilePath;

  // Constructor with DioClient injection
  VoiceMessageService({required DioClient dioClient}) : _dioClient = dioClient;

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Manual recording (long press) ────────────────────────────────────────
  // ✅ User can release early to stop recording

  Future<void> startManualRecording({
    required void Function(String filePath) onComplete,
    required void Function(String error) onError,
  }) async {
    if (_isRecording) return;

    final hasPermission = await _requestMicPermission();
    if (!hasPermission) {
      onError('Microphone permission denied.');
      return;
    }

    try {
      final path = await _buildFilePath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _isRecording = true;
      _currentFilePath = path;

      // Auto-stop after 20s as safety net
      _autoStopTimer = Timer(
        const Duration(seconds: maxRecordingSeconds),
        () => stopRecording(onComplete: onComplete, onError: onError),
      );
      
      print('🎙️ [VoiceMessage] Manual recording started - can release early');
    } catch (e) {
      onError('Failed to start recording: $e');
    }
  }

  Future<void> stopRecording({
    required void Function(String filePath) onComplete,
    required void Function(String error) onError,
  }) async {
    if (!_isRecording) return;

    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        _currentFilePath = path;
        print('🎙️ [VoiceMessage] Manual recording stopped early after ${_getRecordingDuration(path)}');
        onComplete(path);
      } else {
        onError('Recording produced no file.');
      }
    } catch (e) {
      _isRecording = false;
      onError('Failed to stop recording: $e');
    }
  }

  // ── Auto recording (voice activation & motion detection) ─────────────────
  // ✅ Fixed 20s duration - CANNOT be stopped early

  Future<void> startAutoRecording({
    required void Function(String filePath) onComplete,
    required void Function(String error) onError,
  }) async {
    if (_isRecording) return;

    final hasPermission = await _requestMicPermission();
    if (!hasPermission) {
      onError('Microphone permission denied.');
      return;
    }

    try {
      final path = await _buildFilePath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _isRecording = true;
      _currentFilePath = path;

      print('⏰ [VoiceMessage] Auto recording started - WILL run full 20s');

      // ⚠️ NO stopRecording callback - this runs full 20s automatically
      _autoStopTimer = Timer(
        const Duration(seconds: maxRecordingSeconds),
        () async {
          try {
            final resultPath = await _recorder.stop();
            _isRecording = false;
            
            if (resultPath != null && resultPath.isNotEmpty) {
              _currentFilePath = resultPath;
              print('✅ [VoiceMessage] Auto recording completed (20s)');
              onComplete(resultPath);
            } else {
              onError('Auto recording produced no file.');
            }
          } catch (e) {
            _isRecording = false;
            onError('Failed to stop auto recording: $e');
          }
        },
      );
    } catch (e) {
      onError('Failed to start auto recording: $e');
    }
  }

  // ── Combined method for auto triggers that also sends SOS ────────────────

  Future<void> startAutoRecordingAndSendSOS({
    required String triggerType,
    required String eventType,
    double? latitude,
    double? longitude,
    required void Function(int eventId, String? voiceUrl) onComplete,
    required void Function(String error) onError,
  }) async {
    // ✅ Use the new fixed-duration auto recording
    await startAutoRecording(
      onComplete: (filePath) async {
        final result = await createSosWithVoice(
          filePath: filePath,
          triggerType: triggerType,
          eventType: eventType,
          latitude: latitude,
          longitude: longitude,
        );
        
        if (result != null) {
          onComplete(result['event_id'], result['voice_url']);
        } else {
          onError('Failed to create SOS with voice');
        }
      },
      onError: onError,
    );
  }

  // ── Unified SOS + Voice Upload ───────────────────────────────────────────

  Future<Map<String, dynamic>?> createSosWithVoice({
    required String? filePath,
    required String triggerType,
    required String eventType,
    double? latitude,
    double? longitude,
    String? appState,
  }) async {
    try {
      print('📤 [VoiceMessage] Creating SOS with voice - trigger: $triggerType');
      
      // Build base form data
      final formData = FormData.fromMap({
        'trigger_type': triggerType,
        'event_type': eventType,
        'latitude': latitude?.toString(),
        'longitude': longitude?.toString(),
        'app_state': appState ?? 'foreground',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Add file only if it exists and is not null
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          formData.files.add(MapEntry(
            'voice_message',
            await MultipartFile.fromFile(
              filePath,
              filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.aac',
              contentType: MediaType('audio', 'aac'),
            ),
          ));
          print('✅ [VoiceMessage] File attached: $filePath');
        } else {
          print('⚠️ [VoiceMessage] File not found, proceeding without voice: $filePath');
        }
      } else {
        print('ℹ️ [VoiceMessage] No file provided - sending SOS without voice');
      }

      final response = await _dioClient.post(
        '/sos/with-voice',
        data: formData,
      );

      if (response.data != null) {
        final eventId = response.data['event_id'] as int?;
        final voiceUrl = response.data['voice_message_url'] as String?;
        
        print('✅ [VoiceMessage] SOS created! Event ID: $eventId, Voice URL: $voiceUrl');
        
        // Only delete file if it was uploaded successfully and file exists
        if (filePath != null && voiceUrl != null) {
          await deleteLocalFile(filePath);
        }
        
        return {
          'event_id': eventId,
          'voice_url': voiceUrl,
        };
      } else {
        print('❌ [VoiceMessage] Response missing data');
        return null;
      }
    } on DioException catch (e) {
      print('❌ [VoiceMessage] Dio error: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      print('❌ [VoiceMessage] Error: $e');
      return null;
    }
  }

  // ── Helper to get recording duration ─────────────────────────────────────

  String _getRecordingDuration(String filePath) {
    // This is a placeholder - you'd need a proper audio file reader
    // For now, just return a placeholder
    return 'some seconds';
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> deleteLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ [VoiceMessage] Local file deleted: $filePath');
      }
    } catch (e) {
      print('⚠️ [VoiceMessage] Could not delete local file: $e');
    }
  }

  Future<void> dispose() async {
    _autoStopTimer?.cancel();
    if (_isRecording) await _recorder.stop();
    _recorder.dispose();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<String> _buildFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/voice_sos_$timestamp.aac';
  }
}