// ===================================================================
// dependent_profile_service.dart - Service for managing dependent profile pictures
// ===================================================================
// lib/services/dependent_profile_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/user_model.dart';

/// Service for managing dependent profile pictures
class DependentProfileService {
  final DioClient _dioClient = DioClient();

  /// Upload profile picture for a dependent (Primary Guardian only)
  /// 
  /// Parameters:
  /// - dependentId: ID of the dependent user
  /// - imageFile: Image file to upload
  /// 
  /// Returns: Updated user model with new profile picture
  /// 
  /// Throws:
  /// - Exception if user is not primary guardian
  /// - Exception if file is too large (>5MB)
  /// - Exception if file type is invalid
  Future<UserModel> uploadDependentProfilePicture({
    required int dependentId,
    required File imageFile,
  }) async {
    try {
      print('═══════════════════════════════════════════════════');
      print('📸 UPLOADING DEPENDENT PROFILE PICTURE');
      print('═══════════════════════════════════════════════════');
      print('Dependent ID: $dependentId');
      print('File path: ${imageFile.path}');

      // Validate file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      // Check file size (5MB limit)
      final fileSize = await imageFile.length();
      const maxSize = 5 * 1024 * 1024; // 5MB
      
      print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
      
      if (fileSize > maxSize) {
        throw Exception('File too large. Maximum size is 5MB');
      }

      // Prepare multipart file
      final fileName = imageFile.path.split('/').last;
      final fileExtension = fileName.split('.').last.toLowerCase();
      
      // Determine content type
      String contentType;
      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        default:
          throw Exception('Invalid file type. Allowed: JPG, PNG, WEBP');
      }

      print('Content type: $contentType');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      });

      // Upload to backend
      final endpoint = '${ApiEndpoints.uploadDependentProfilePicture}/$dependentId/profile-picture';
      print('Endpoint: $endpoint');

      final response = await _dioClient.post(
        endpoint,
        data: formData,
      );

      print('✅ Upload successful');
      print('Response: ${response.data}');

      // Parse response
      final updatedUser = UserModel.fromJson(response.data);

      print('═══════════════════════════════════════════════════');
      print('✅ DEPENDENT PROFILE PICTURE UPLOADED');
      print('═══════════════════════════════════════════════════');
      print('Dependent: ${updatedUser.fullName}');
      print('Picture path: ${updatedUser.profilePicture}');
      print('═══════════════════════════════════════════════════');

      return updatedUser;
      
    } on DioException catch (e) {
      print('❌ DioException uploading dependent profile picture');
      print('Status code: ${e.response?.statusCode}');
      print('Response: ${e.response?.data}');

      if (e.response?.statusCode == 403) {
        throw Exception(
          e.response?.data['detail'] ?? 
          'Only primary guardians can update dependent profile pictures'
        );
      } else if (e.response?.statusCode == 404) {
        throw Exception('Dependent not found');
      } else if (e.response?.statusCode == 413) {
        throw Exception('File too large. Maximum size is 5MB');
      } else if (e.response?.statusCode == 400) {
        throw Exception(
          e.response?.data['detail'] ?? 'Invalid image file'
        );
      }

      rethrow;
    } catch (e) {
      print('❌ Unexpected error uploading dependent profile picture: $e');
      rethrow;
    }
  }

  /// Delete profile picture for a dependent (Primary Guardian only)
  Future<void> deleteDependentProfilePicture(int dependentId) async {
    try {
      print('═══════════════════════════════════════════════════');
      print('🗑️ DELETING DEPENDENT PROFILE PICTURE');
      print('═══════════════════════════════════════════════════');
      print('Dependent ID: $dependentId');

      final endpoint = '${ApiEndpoints.uploadDependentProfilePicture}/$dependentId/profile-picture';
      
      await _dioClient.delete(endpoint);

      print('✅ Dependent profile picture deleted successfully');
      print('═══════════════════════════════════════════════════');
      
    } on DioException catch (e) {
      print('❌ DioException deleting dependent profile picture');
      print('Status code: ${e.response?.statusCode}');
      print('Response: ${e.response?.data}');

      if (e.response?.statusCode == 403) {
        throw Exception(
          'Only primary guardians can delete dependent profile pictures'
        );
      } else if (e.response?.statusCode == 404) {
        throw Exception('Dependent not found');
      } else if (e.response?.statusCode == 400) {
        throw Exception('Dependent has no profile picture to delete');
      }

      rethrow;
    } catch (e) {
      print('❌ Unexpected error deleting dependent profile picture: $e');
      rethrow;
    }
  }
}