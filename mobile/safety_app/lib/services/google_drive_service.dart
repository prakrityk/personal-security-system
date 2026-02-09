import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart' as path;

class GoogleDriveService {
  drive.DriveApi? _driveApi;
  String? _folderId;

  /// Initialize Google Drive API using the service account path from .env
  Future<void> initialize() async {
    try {
      // Read path from .env — falls back to the original default if not set
      final credentialsPath =
          dotenv.env['SERVICE_ACCOUNT_PATH'] ??
          'assets/credentials/service_account.json';

      // Load service account credentials from assets
      final jsonString = await rootBundle.loadString(credentialsPath);

      // Parse credentials
      final accountCredentials =
          ServiceAccountCredentials.fromJson(jsonString);

      // Define required scopes
      final scopes = [drive.DriveApi.driveFileScope];

      // Obtain authenticated client
      final client = await clientViaServiceAccount(accountCredentials, scopes);

      // Create Drive API instance
      _driveApi = drive.DriveApi(client);

      print('Google Drive API initialized successfully');
    } catch (e) {
      print('Error initializing Google Drive: $e');
      rethrow;
    }
  }

  /// Set the folder ID where evidence will be uploaded.
  /// Called by EvidenceService after reading GOOGLE_DRIVE_FOLDER_ID from .env.
  void setFolderId(String folderId) {
    _folderId = folderId;
  }

  /// Upload file to Google Drive.
  /// Returns the Google Drive file ID.
  Future<String> uploadFile(String filePath) async {
    if (_driveApi == null) {
      throw Exception('Google Drive not initialized. Call initialize() first');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      // Get file info
      final fileName = path.basename(filePath);
      final fileSize = await file.length();
      final mimeType = _getMimeType(fileName);

      print('Uploading file: $fileName (${_formatBytes(fileSize)})');

      // Create file metadata
      final driveFile = drive.File()
        ..name = fileName
        ..mimeType = mimeType;

      // Place file inside the configured folder
     if (_folderId != null && _folderId!.isNotEmpty) {
       driveFile.parents = [_folderId!];
      }

      // Upload file
      final media = drive.Media(file.openRead(), fileSize);
      final response = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      print('File uploaded successfully: ${response.id}');
      return response.id!;
    } catch (e) {
      print('Error uploading to Google Drive: $e');
      rethrow;
    }
  }

  /// Create a new folder in Google Drive.
  /// Returns the folder ID.
  Future<String> createFolder(String folderName) async {
    if (_driveApi == null) {
      throw Exception('Google Drive not initialized');
    }

    try {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final response = await _driveApi!.files.create(folder);
      print('Folder created: ${response.id}');
      return response.id!;
    } catch (e) {
      print('Error creating folder: $e');
      rethrow;
    }
  }

  /// Share a folder with a guardian's email (reader access).
  /// Note: the service account itself must already have editor/writer access
  /// on the folder — that is granted manually in Google Drive, not here.
  Future<void> shareFolderWithGuardian(String folderId, String email) async {
    if (_driveApi == null) {
      throw Exception('Google Drive not initialized');
    }

    try {
      final permission = drive.Permission()
        ..type = 'user'
        ..role = 'reader'
        ..emailAddress = email;

      await _driveApi!.permissions.create(permission, folderId);
      print('Folder shared (reader) with guardian: $email');
    } catch (e) {
      print('Error sharing folder: $e');
      rethrow;
    }
  }

  /// Delete file from Google Drive
  Future<void> deleteFile(String fileId) async {
    if (_driveApi == null) {
      throw Exception('Google Drive not initialized');
    }

    try {
      await _driveApi!.files.delete(fileId);
      print('File deleted from Drive: $fileId');
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }

  /// Get MIME type based on file extension
  String _getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.mp4':
        return 'video/mp4';
      case '.m4a':
        return 'audio/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  /// Format bytes to human-readable size
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}