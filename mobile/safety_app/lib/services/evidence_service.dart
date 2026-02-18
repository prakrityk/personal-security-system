import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/evidence.dart';
import 'evidence_database_helper.dart';
import 'evidence_api_service.dart';
import 'recording_service.dart';
import 'google_drive_service.dart';

class EvidenceService {
  final EvidenceDatabaseHelper _dbHelper = EvidenceDatabaseHelper.instance;
  final EvidenceApiService _apiService = EvidenceApiService();
  final RecordingService _recordingService = RecordingService();
  final GoogleDriveService _driveService = GoogleDriveService();

  bool _isInitialized = false;

  /// Initialize all services
  /// Must be called before using any other methods
  Future<void> initialize({
    required String authToken,
    required String driveFolderId,
    required String backendUrl,
  }) async {
    if (_isInitialized) return;

    try {
      // Set auth token and base URL for API calls
      _apiService.setAuthToken(authToken);
      _apiService.setBaseUrl(backendUrl);

      // Initialize Google Drive
      await _driveService.initialize();
      _driveService.setFolderId(driveFolderId);

      // Initialize camera
      await _recordingService.initializeCamera();

      _isInitialized = true;
      print('EvidenceService initialized successfully');
    } catch (e) {
      print('Error initializing EvidenceService: $e');
      rethrow;
    }
  }

  /// Record evidence when threat is detected
  /// This is the main entry point called by threat detection
  Future<void> onThreatDetected({
    String evidenceType = 'video',
    int durationSeconds = 20,
  }) async {
    if (!_isInitialized) {
      throw Exception('EvidenceService not initialized');
    }

    try {
      print('Threat detected! Recording $evidenceType evidence...');

      // 1. Record evidence
      String? localPath;
      if (evidenceType == 'video') {
        localPath = await _recordingService.recordVideo(
          durationSeconds: durationSeconds,
        );
      } else if (evidenceType == 'audio') {
        localPath = await _recordingService.recordAudio(
          durationSeconds: durationSeconds,
        );
      }

      if (localPath == null) {
        throw Exception('Failed to record evidence');
      }

      // 2. Get file metadata
      final fileSize = await _recordingService.getFileSize(localPath);

      // 3. Save to local database immediately
      final localId = await _dbHelper.insertEvidence({
        'evidenceType': evidenceType,
        'localPath': localPath,
        'fileSize': fileSize,
        'duration': durationSeconds,
        'uploadStatus': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      print('Evidence saved locally with ID: $localId');

      // 4. Create record in backend API
      try {
        final serverId = await _apiService.createEvidence(
          evidenceType: evidenceType,
          localPath: localPath,
          fileSize: fileSize,
          duration: durationSeconds,
        );

        // Update local record with server ID
        await _dbHelper.updateEvidence(localId, {
          'serverId': serverId,
        });

        print('Evidence record created in backend: $serverId');
      } catch (e) {
        print('Failed to create backend record (will retry): $e');
      }

      // 5. Try to upload immediately (non-blocking, retried by background worker)
      unawaited(_tryUpload(localId, localPath));

      print('Evidence collection completed successfully');
    } catch (e) {
      print('Error in threat detection handler: $e');
      rethrow;
    }
  }

  /// Try to upload evidence to Google Drive
  /// Non-blocking - will retry later if fails
  Future<void> _tryUpload(int localId, String localPath) async {
    try {
      // Check WiFi connection
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first != ConnectivityResult.wifi) {
        print('Not on WiFi, skipping upload');
        return;
      }

      // Get evidence record
      final evidence = await _dbHelper.getEvidenceById(localId);
      if (evidence == null) {
        print('Evidence not found: $localId');
        return;
      }

      // Check if file exists
      final file = File(localPath);
      if (!await file.exists()) {
        print('File not found on device: $localPath — marking done so retry skips it');
        await _dbHelper.updateEvidence(localId, {
          'uploadStatus': 'uploaded', // file is gone, nothing to retry
        });
        return;
      }

      print('Uploading to Google Drive: $localPath');

      // If backend record was never created (step 4 failed), retry it now
      int? serverId = evidence['serverId'] as int?;
      if (serverId == null) {
        try {
          serverId = await _apiService.createEvidence(
            evidenceType: evidence['evidenceType'] as String,
            localPath: localPath,
            fileSize: evidence['fileSize'] as int?,
            duration: evidence['duration'] as int?,
          );
          await _dbHelper.updateEvidence(localId, {'serverId': serverId});
          print('Backend record created on retry: $serverId');
        } catch (e) {
          // Still non-fatal — file uploads to Drive either way,
          // backend sync will be attempted again next cycle
          print('Backend create retry failed: $e');
        }
      }

      // Upload to Google Drive
      final driveFileId = await _driveService.uploadFile(localPath);

      // Notify backend the file is on Drive (only if we have a server ID)
      if (serverId != null) {
        await _apiService.markUploaded(
          evidenceId: serverId,
          driveFileId: driveFileId,
        );
      }

      // Update local database
      await _dbHelper.updateEvidence(localId, {
        'fileUrl': driveFileId,
        'uploadStatus': 'uploaded',
        'uploadedAt': DateTime.now().toIso8601String(),
      });

      // Delete local file
      await file.delete();
      print('Upload successful and local file deleted');
    } catch (e) {
      // Do NOT write 'failed' — leave as 'pending' so the background worker
      // retries this on the next WiFi-connected cycle.
      print('Upload failed this cycle, will retry: $e');
    }
  }

  /// Retry all pending uploads
  /// Should be called periodically or when WiFi connects
  Future<void> retryPendingUploads() async {
    try {
      // Check WiFi connection first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first != ConnectivityResult.wifi) {
        print('Not on WiFi, skipping retry');
        return;
      }

      // Get pending uploads from local database
      final pending = await _dbHelper.getPendingEvidence();
      print('Found ${pending.length} pending uploads');

      for (final evidence in pending) {
        await _tryUpload(
          evidence['id'] as int,
          evidence['localPath'] as String,
        );

        // Add small delay between uploads
        await Future.delayed(const Duration(seconds: 2));
      }

      print('Retry cycle completed');
    } catch (e) {
      print('Error in retry cycle: $e');
    }
  }

  /// Get all evidence from local database
  Future<List<Evidence>> getLocalEvidence() async {
    final maps = await _dbHelper.getAllEvidence();
    return maps.map((map) => Evidence.fromMap(map)).toList();
  }

  /// Get pending uploads count
  Future<int> getPendingCount() async {
    final pending = await _dbHelper.getPendingEvidence();
    return pending.length;
  }

  /// Delete evidence
  Future<void> deleteEvidence(int localId, {int? serverId}) async {
    try {
      // Delete from backend if server ID exists
      if (serverId != null) {
        await _apiService.deleteEvidence(serverId);
      }

      // Get evidence to find file path
      final evidence = await _dbHelper.getEvidenceById(localId);
      if (evidence != null) {
        // Delete local file if exists
        final file = File(evidence['localPath'] as String);
        if (await file.exists()) {
          await file.delete();
        }

        // Delete from Google Drive if uploaded
        if (evidence['fileUrl'] != null) {
          await _driveService.deleteFile(evidence['fileUrl'] as String);
        }
      }

      // Delete from local database
      await _dbHelper.deleteEvidence(localId);
      print('Evidence deleted: $localId');
    } catch (e) {
      print('Error deleting evidence: $e');
      rethrow;
    }
  }

  /// Clean up old evidence (older than specified days)
  Future<void> cleanupOldEvidence({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final allEvidence = await _dbHelper.getAllEvidence();

      for (final evidence in allEvidence) {
        final createdAt = DateTime.parse(evidence['createdAt'] as String);
        if (createdAt.isBefore(cutoffDate)) {
          await deleteEvidence(
            evidence['id'] as int,
            serverId: evidence['serverId'] as int?,
          );
        }
      }

      print('Cleanup completed');
    } catch (e) {
      print('Error in cleanup: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _recordingService.dispose();
  }
}