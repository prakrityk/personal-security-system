// // lib/services/voice_message_service.dart
// //
// // Handles voice message recording for SOS events.
// // Used by:
// //   - Manual SOS: long press start/end (can release early)
// //   - Voice activation & motion detection: auto 20s recording (fixed duration)

// import 'dart:async';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:record/record.dart';
// import 'package:dio/dio.dart';
// import 'package:http_parser/http_parser.dart';
// import 'package:safety_app/core/network/dio_client.dart';

// class VoiceMessageService {
//   final AudioRecorder _recorder = AudioRecorder();
//   final DioClient _dioClient;

//   bool _isRecording = false;
//   String? _currentFilePath;
//   Timer? _autoStopTimer;

//   static const int maxRecordingSeconds = 20;

//   bool get isRecording => _isRecording;
//   String? get lastFilePath => _currentFilePath;

//   // Constructor with DioClient injection
//   VoiceMessageService({required DioClient dioClient}) : _dioClient = dioClient;

//   // ── Manual recording (long press) ────────────────────────────────────────
//   // ✅ User can release early to stop recording
//   // ✅ Permission checks removed - handled at login

//   Future<void> startManualRecording({
//     required void Function(String filePath) onComplete,
//     required void Function(String error) onError,
//   }) async {
//     if (_isRecording) return;

//     try {
//       final path = await _buildFilePath();
//       await _recorder.start(
//         const RecordConfig(
//           encoder: AudioEncoder.aacLc,
//           bitRate: 64000,
//           sampleRate: 44100,
//         ),
//         path: path,
//       );

//       _isRecording = true;
//       _currentFilePath = path;

//       // Auto-stop after 20s as safety net
//       _autoStopTimer = Timer(
//         const Duration(seconds: maxRecordingSeconds),
//         () => stopRecording(onComplete: onComplete, onError: onError),
//       );

//       print('🎙️ [VoiceMessage] Manual recording started - can release early');
//     } catch (e) {
//       onError('Failed to start recording: $e');
//     }
//   }

//   Future<void> stopRecording({
//     required void Function(String filePath) onComplete,
//     required void Function(String error) onError,
//   }) async {
//     if (!_isRecording) return;

//     _autoStopTimer?.cancel();
//     _autoStopTimer = null;

//     try {
//       final path = await _recorder.stop();
//       _isRecording = false;

//       if (path != null && path.isNotEmpty) {
//         _currentFilePath = path;
//         print('🎙️ [VoiceMessage] Manual recording stopped early');
//         onComplete(path);
//       } else {
//         onError('Recording produced no file.');
//       }
//     } catch (e) {
//       _isRecording = false;
//       onError('Failed to stop recording: $e');
//     }
//   }

//   // ── Auto recording (voice activation & motion detection) ─────────────────
//   // ✅ Fixed 20s duration - CANNOT be stopped early
//   // ✅ Permission checks removed - handled at login

//   Future<void> startAutoRecording({
//     required void Function(String filePath) onComplete,
//     required void Function(String error) onError,
//   }) async {
//     if (_isRecording) return;

//     try {
//       final path = await _buildFilePath();
//       await _recorder.start(
//         const RecordConfig(
//           encoder: AudioEncoder.aacLc,
//           bitRate: 64000,
//           sampleRate: 44100,
//         ),
//         path: path,
//       );

//       _isRecording = true;
//       _currentFilePath = path;

//       print('⏰ [VoiceMessage] Auto recording started - WILL run full 20s');

//       // ⚠️ NO stopRecording callback - this runs full 20s automatically
//       _autoStopTimer = Timer(
//         const Duration(seconds: maxRecordingSeconds),
//         () async {
//           try {
//             final resultPath = await _recorder.stop();
//             _isRecording = false;

//             if (resultPath != null && resultPath.isNotEmpty) {
//               _currentFilePath = resultPath;
//               print('✅ [VoiceMessage] Auto recording completed (20s)');
//               onComplete(resultPath);
//             } else {
//               onError('Auto recording produced no file.');
//             }
//           } catch (e) {
//             _isRecording = false;
//             onError('Failed to stop auto recording: $e');
//           }
//         },
//       );
//     } catch (e) {
//       onError('Failed to start auto recording: $e');
//     }
//   }

//   // ── Combined method for auto triggers that also sends SOS ────────────────

//   Future<void> startAutoRecordingAndSendSOS({
//     required String triggerType,
//     required String eventType,
//     double? latitude,
//     double? longitude,
//     required void Function(int eventId, String? voiceUrl) onComplete,
//     required void Function(String error) onError,
//   }) async {
//     // ✅ Use the fixed-duration auto recording
//     await startAutoRecording(
//       onComplete: (filePath) async {
//         final result = await createSosWithVoice(
//           filePath: filePath,
//           triggerType: triggerType,
//           eventType: eventType,
//           latitude: latitude,
//           longitude: longitude,
//         );

//         if (result != null) {
//           onComplete(result['event_id'], result['voice_url']);
//         } else {
//           onError('Failed to create SOS with voice');
//         }
//       },
//       onError: onError,
//     );
//   }

//   // ── Unified SOS + Voice Upload ───────────────────────────────────────────

//   Future<Map<String, dynamic>?> createSosWithVoice({
//     required String? filePath,
//     required String triggerType,
//     required String eventType,
//     double? latitude,
//     double? longitude,
//     String? appState,
//   }) async {
//     try {
//       print('📤 [VoiceMessage] Creating SOS with voice - trigger: $triggerType');

//       // Build base form data
//       final formData = FormData.fromMap({
//         'trigger_type': triggerType,
//         'event_type': eventType,
//         'latitude': latitude?.toString(),
//         'longitude': longitude?.toString(),
//         'app_state': appState ?? 'foreground',
//         'timestamp': DateTime.now().toIso8601String(),
//       });

//       // Add file only if it exists and is not null
//       if (filePath != null) {
//         final file = File(filePath);
//         if (await file.exists()) {
//           formData.files.add(MapEntry(
//             'voice_message',
//             await MultipartFile.fromFile(
//               filePath,
//               filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.aac',
//               contentType: MediaType('audio', 'aac'),
//             ),
//           ));
//           print('✅ [VoiceMessage] File attached: $filePath');
//         } else {
//           print('⚠️ [VoiceMessage] File not found, proceeding without voice: $filePath');
//         }
//       } else {
//         print('ℹ️ [VoiceMessage] No file provided - sending SOS without voice');
//       }

//       final response = await _dioClient.post(
//         '/sos/with-voice',
//         data: formData,
//       );

//       if (response.data != null) {
//         final eventId = response.data['event_id'] as int?;
//         final voiceUrl = response.data['voice_message_url'] as String?;

//         print('✅ [VoiceMessage] SOS created! Event ID: $eventId, Voice URL: $voiceUrl');

//         // Only delete file if it was uploaded successfully and file exists
//         if (filePath != null && voiceUrl != null) {
//           await deleteLocalFile(filePath);
//         }

//         return {
//           'event_id': eventId,
//           'voice_url': voiceUrl,
//         };
//       } else {
//         print('❌ [VoiceMessage] Response missing data');
//         return null;
//       }
//     } on DioException catch (e) {
//       print('❌ [VoiceMessage] Dio error: ${e.response?.data ?? e.message}');
//       return null;
//     } catch (e) {
//       print('❌ [VoiceMessage] Error: $e');
//       return null;
//     }
//   }

//   // ── Cleanup ───────────────────────────────────────────────────────────────

//   Future<void> deleteLocalFile(String filePath) async {
//     try {
//       final file = File(filePath);
//       if (await file.exists()) {
//         await file.delete();
//         print('🗑️ [VoiceMessage] Local file deleted: $filePath');
//       }
//     } catch (e) {
//       print('⚠️ [VoiceMessage] Could not delete local file: $e');
//     }
//   }

//   Future<void> dispose() async {
//     _autoStopTimer?.cancel();
//     if (_isRecording) await _recorder.stop();
//     _recorder.dispose();
//   }

//   // ── Private ───────────────────────────────────────────────────────────────

//   Future<String> _buildFilePath() async {
//     final dir = await getApplicationDocumentsDirectory();
//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     return '${dir.path}/voice_sos_$timestamp.aac';
//   }
// }
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

  // ── Manual recording (long press) ────────────────────────────────────────
  // ✅ User can release early to stop recording
  // ✅ Permission checks removed - handled at login

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
        print('🎙️ [VoiceMessage] Manual recording stopped early');
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
  // ✅ Permission checks removed - handled at login

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
  // ✅ FIXED: Sends SOS IMMEDIATELY (no voice), then uploads voice recording
  // in background once the 20s completes. Guardian gets the alert right away.
  // The SOS event is then patched with the voice URL after upload.

  Future<void> startAutoRecordingAndSendSOS({
    required String triggerType,
    required String eventType,
    double? latitude,
    double? longitude,
    required void Function(int eventId, String? voiceUrl) onComplete,
    required void Function(String error) onError,
  }) async {
    // ── STEP 1: Fire SOS immediately without voice ───────────────────────────
    // Guardian is notified RIGHT NOW — no waiting for recording
    print(
      '🚨 [VoiceMessage] Firing SOS immediately (no voice yet): $eventType',
    );
    final immediateResult = await createSosWithVoice(
      filePath: null, // ← no voice yet
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

    // Notify caller immediately — guardian has already been pinged
    onComplete(eventId, null);
    print('✅ [VoiceMessage] Immediate SOS fired! Event ID: $eventId');

    // ── STEP 2: Start 20s voice recording in background ─────────────────────
    // If recording is already in progress, skip — don't overlap
    if (_isRecording) {
      print(
        '⚠️ [VoiceMessage] Already recording — skipping background voice for this SOS',
      );
      return;
    }

    await startAutoRecording(
      onComplete: (filePath) async {
        // ── STEP 3: Upload voice and patch the existing SOS event ────────────
        print(
          '🎙️ [VoiceMessage] Recording done — uploading voice for event $eventId',
        );
        await _uploadVoiceForEvent(
          eventId: eventId,
          filePath: filePath,
          triggerType: triggerType,
          eventType: eventType,
          latitude: latitude,
          longitude: longitude,
        );
      },
      onError: (err) {
        // Voice failed — SOS was already sent, just log it
        print(
          '⚠️ [VoiceMessage] Background voice recording failed (SOS already sent): $err',
        );
      },
    );
  }

  // ── Upload voice for an existing SOS event ───────────────────────────────
  // Calls the same /sos/with-voice endpoint — backend creates a new linked
  // voice-only update. If your backend supports PATCH /sos/events/{id}/voice,
  // replace this with that call instead.
  Future<void> _uploadVoiceForEvent({
    required int eventId,
    required String filePath,
    required String triggerType,
    required String eventType,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('⚠️ [VoiceMessage] Voice file not found for upload: $filePath');
        return;
      }

      final fields = <String, dynamic>{
        'trigger_type': triggerType,
        'event_type': '${eventType}_voice_followup',
        'app_state': 'foreground',
        'timestamp': DateTime.now().toIso8601String(),
        'linked_event_id': eventId.toString(),
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      };

      final formData = FormData.fromMap(fields);
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

      final response = await _dioClient.post('/sos/with-voice', data: formData);

      if (response.data != null) {
        final voiceUrl = response.data['voice_message_url'] as String?;
        print('✅ [VoiceMessage] Voice uploaded for event $eventId: $voiceUrl');
        await deleteLocalFile(filePath);
      }
    } catch (e) {
      print(
        '⚠️ [VoiceMessage] Voice follow-up upload failed (SOS already sent): $e',
      );
      // Non-fatal — SOS was already delivered
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
      print(
        '📤 [VoiceMessage] Creating SOS with voice - trigger: $triggerType',
      );

      // ✅ FIX Bug#8: Only include lat/lng if non-null — never send literal 'null' string
      // FastAPI Form(Optional[float]) will 422 if it receives the string "null"
      final fields = <String, dynamic>{
        'trigger_type': triggerType,
        'event_type': eventType,
        'app_state': appState ?? 'foreground',
        'timestamp': DateTime.now().toIso8601String(),
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      };
      final formData = FormData.fromMap(fields);

      // Add file only if it exists and is not null
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
          print(
            '⚠️ [VoiceMessage] File not found, proceeding without voice: $filePath',
          );
        }
      } else {
        print('ℹ️ [VoiceMessage] No file provided - sending SOS without voice');
      }

      final response = await _dioClient.post('/sos/with-voice', data: formData);

      if (response.data != null) {
        final eventId = response.data['event_id'] as int?;
        final voiceUrl = response.data['voice_message_url'] as String?;

        print(
          '✅ [VoiceMessage] SOS created! Event ID: $eventId, Voice URL: $voiceUrl',
        );

        // Only delete file if it was uploaded successfully and file exists
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
