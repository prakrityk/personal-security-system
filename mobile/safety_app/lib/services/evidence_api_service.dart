import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import '../models/evidence.dart';

class EvidenceApiService {
  String? _baseUrl;
  String? _authToken;

  /// Set the backend base URL explicitly (called by EvidenceService.initialize).
  /// Trailing slash is stripped so URL interpolation stays clean.
  void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/$'), '');
  }

  /// Returns the stored URL, or reads .env as fallback. Trailing slash always stripped.
String get baseUrl => (_baseUrl ?? dotenv.env['BACKEND_URL'] ?? 'http://127.0.0.1:8000').replaceAll(RegExp(r'/$'), '');

  void setAuthToken(String token) {
    _authToken = token;
  }
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  /// Create new evidence record in backend
  Future<int> createEvidence({
    required String evidenceType,
    required String localPath,
    int? fileSize,
    int? duration,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/evidence/create'),
        headers: _headers,
        body: jsonEncode({
          'evidence_type': evidenceType,
          'local_path': localPath,
          'file_size': fileSize,
          'duration': duration,
        }),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] as int;
      } else if (response.statusCode == 403) {
        throw Exception('Evidence collection only available for dependents');
      } else {
        throw Exception('Failed to create evidence: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating evidence: $e');
      rethrow;
    }
  }

  /// Mark evidence as uploaded with Google Drive file ID
  Future<void> markUploaded({
    required int evidenceId,
    required String driveFileId,
    String uploadStatus = 'uploaded',
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/evidence/$evidenceId/uploaded'),
        headers: _headers,
        body: jsonEncode({
          'file_url': driveFileId,
          'upload_status': uploadStatus,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark uploaded: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking uploaded: $e');
      rethrow;
    }
  }

  /// Get list of pending uploads from backend
  Future<List<Evidence>> getPendingUploads() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/evidence/pending'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Evidence.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get pending: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting pending uploads: $e');
      return [];
    }
  }

  /// Get all evidence for current user
  Future<List<Evidence>> getMyEvidence() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/evidence/my-evidence'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Evidence.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get evidence: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting evidence: $e');
      return [];
    }
  }

  /// Delete evidence record
  Future<void> deleteEvidence(int evidenceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/evidence/$evidenceId'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete evidence: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting evidence: $e');
      rethrow;
    }
  }
}