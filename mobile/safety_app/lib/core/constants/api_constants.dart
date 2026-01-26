/// API Constants
class ApiConstants {
  // Base URL - Change this for production
  static const String baseUrl = 'http://127.0.0.1:8000';
  
  // For Android Emulator, use: 'http://10.0.2.2:8000'
  // For iOS Simulator, use: 'http://127.0.0.1:8000'
  // For Real Device on same network, use: 'http://YOUR_COMPUTER_IP:8000'
  
  // Timeout durations
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String userDataKey = 'user_data';
}