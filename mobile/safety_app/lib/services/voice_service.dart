import 'package:dio/dio.dart';
import 'package:safety_app/core/network/dio_client.dart';
import 'package:safety_app/core/network/api_endpoints.dart'; 

class VoiceService {
  final DioClient _dioClient = DioClient();

  /// Verifies the user's voice for SOS activation
  Future<bool> verifyVoiceSos({
    required int userId,
    required String filePath,
  }) async {

    try {
      print('📤 Uploading voice for verification (User: $userId)...');
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: 'sos_verify.wav',
        ),
        'user_id': userId, 
      });

      final response = await _dioClient.post(
        ApiEndpoints.voiceverify, 
        data: formData,
        // queryParameters removed
      );

      if (response.statusCode == 200) {
        print('Voice Verified Successfully');
        return true;
      } else {
        print('Voice Mismatch: ${response.data}');
        return false;
      }
    } catch (e) {
      print('Voice Service Error: $e');
      return false;
    }
  }
}
