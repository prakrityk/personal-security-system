// lib/services/voice_message_service.dart

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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

  VoiceMessageService({required DioClient dioClient}) : _dioClient = dioClient;

  // ── Manual recording (long press) ────────────────────────────────────────

  Future<void> startManualRecording({
    required void Function(String filePath) onComplete,
    required void Function(String error) onError,
  }) async {
    if (_isRecording) return;

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

      // ── DEBUG ────────────────────────────────────────────────────────────
      print('🎙️ [DEBUG] Recorder returned path: $path');
      if (path != null) {
        final file = File(path);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        print('🎙️ [DEBUG] File exists: $exists, size: $size bytes');
      }
      final dir = await getApplicationDocumentsDirectory();
      print('📁 [DEBUG] App docs dir: ${dir.path}');
      final files = dir.listSync();
      print('📁 [DEBUG] Files in dir: ${files.map((f) => f.path).toList()}');
      // ── END DEBUG ────────────────────────────────────────────────────────

      if (path != null && path.isNotEmpty) {
        _currentFilePath = path;
        print('🎙️ [VoiceMessage] Manual recording stopped');
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

  Future<void> startAutoRecording({
    required void Function(String filePath) onComplete,
    required void Function(String error) onError,
  }) async {
    if (_isRecording) return;

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

      print('⏰ [VoiceMessage] Auto recording started - full 20s');

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

  // ── Auto SOS: fire immediately, patch voice after 20s ───────────────────

  Future<void> startAutoRecordingAndSendSOS({
    required String triggerType,
    required String eventType,
    double? latitude,
    double? longitude,
    required void Function(int eventId, String? voiceUrl) onComplete,
    required void Function(String error) onError,
  }) async {
    print('🚨 [VoiceMessage] Firing SOS immediately (no voice yet): $eventType');
    final immediateResult = await createSosWithVoice(
      filePath: null,
      triggerType: triggerType,
      eventType: eventType,
      latitude: latitude,
      longitude: longitude,
      appState: 'foreground',
    );

    if (immediateResult == null) {
      onError('Failed to create immediate SOS');
      return;
    }

    final eventId = immediateResult['event_id'] as int?;
    if (eventId == null) {
      onError('SOS created but event_id missing');
      return;
    }

    onComplete(eventId, null);
    print('✅ [VoiceMessage] Immediate SOS fired! Event ID: $eventId');

    if (_isRecording) {
      print('⚠️ [VoiceMessage] Already recording — skipping background voice');
      return;
    }

    await startAutoRecording(
      onComplete: (filePath) async {
        print('🎙️ [VoiceMessage] Recording done — patching voice onto event $eventId');
        await _patchVoiceOntoEvent(eventId: eventId, filePath: filePath);
      },
      onError: (err) {
        print('⚠️ [VoiceMessage] Background recording failed (SOS already sent): $err');
      },
    );
  }

  // ── PATCH voice onto an existing SOS event ───────────────────────────────

  Future<void> _patchVoiceOntoEvent({
    required int eventId,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('⚠️ [VoiceMessage] Voice file not found for patch: $filePath');
        return;
      }

      final formData = FormData.fromMap({
        'voice_message': await MultipartFile.fromFile(
          filePath,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.aac',
          contentType: MediaType('audio', 'aac'),
        ),
      });

      final response = await _dioClient.patch(
        '/sos/events/$eventId/voice',
        data: formData,
      );

      if (response.data != null) {
        final voiceUrl = response.data['voice_message_url'] as String?;
        print('✅ [VoiceMessage] Voice patched onto event $eventId: $voiceUrl');
        await deleteLocalFile(filePath);
      } else {
        print('❌ [VoiceMessage] Patch response missing data');
      }
    } catch (e) {
      print('⚠️ [VoiceMessage] Voice patch failed (SOS already sent): $e');
    }
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
      print('📤 [VoiceMessage] Creating SOS - trigger: $triggerType');

      final fields = <String, dynamic>{
        'trigger_type': triggerType,
        'event_type': eventType,
        'app_state': appState ?? 'foreground',
        'timestamp': DateTime.now().toIso8601String(),
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      };
      final formData = FormData.fromMap(fields);

      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          formData.files.add(
            MapEntry(
              'voice_message',
              await MultipartFile.fromFile(
                filePath,
                filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.aac',
                contentType: MediaType('audio', 'aac'),
              ),
            ),
          );
          print('✅ [VoiceMessage] File attached: $filePath');
        } else {
          print('⚠️ [VoiceMessage] File not found, proceeding without voice: $filePath');
        }
      } else {
        print('ℹ️ [VoiceMessage] No file — sending SOS without voice');
      }

      final response = await _dioClient.post('/sos/with-voice', data: formData);

      if (response.data != null) {
        final eventId = response.data['event_id'] as int?;
        final voiceUrl = response.data['voice_message_url'] as String?;

        print('✅ [VoiceMessage] SOS created! Event ID: $eventId, Voice URL: $voiceUrl');

        if (filePath != null && voiceUrl != null) {
          await deleteLocalFile(filePath);
        }

        return {'event_id': eventId, 'voice_url': voiceUrl};
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