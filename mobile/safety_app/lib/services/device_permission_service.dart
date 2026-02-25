// lib/services/device_permission_service.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class DevicePermissionService {
  static final DevicePermissionService _instance = DevicePermissionService._internal();
  factory DevicePermissionService() => _instance;
  DevicePermissionService._internal();

  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request camera and microphone together
  static Future<Map<Permission, PermissionStatus>> requestCameraAndMic() async {
    return await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  /// Request motion sensors permission
  static Future<bool> requestSensorsPermission() async {
    final status = await Permission.sensors.request();
    return status.isGranted;
  }

  /// Request location permission using Geolocator
  static Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('⚠️ Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('⚠️ Location permission permanently denied');
      return false;
    }
    
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  /// Request all SOS-related permissions (microphone, location, sensors)
  static Future<bool> requestAllSOSPermissions() async {
    print('🔐 [DevicePermission] Requesting all SOS permissions...');
    
    bool allGranted = true;
    
    // 1. Request Microphone Permission
    final micStatus = await Permission.microphone.request();
    final micGranted = micStatus.isGranted;
    print('🎤 Microphone: ${micGranted ? 'GRANTED' : 'DENIED'}');
    if (!micGranted) allGranted = false;
    
    // 2. Request Location Permission
    final locationGranted = await requestLocationPermission();
    print('📍 Location: ${locationGranted ? 'GRANTED' : 'DENIED'}');
    if (!locationGranted) allGranted = false;
    
    // 3. Request Sensors Permission (optional - for motion detection)
    final sensorsStatus = await Permission.sensors.request();
    final sensorsGranted = sensorsStatus.isGranted;
    print('📱 Sensors: ${sensorsGranted ? 'GRANTED' : 'DENIED'}');
    // Sensors are optional, don't fail if not granted
    
    return allGranted;
  }

  /// Check if camera permission is granted
  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Check if microphone permission is granted
  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if sensors permission is granted
  static Future<bool> hasSensorsPermission() async {
    return await Permission.sensors.isGranted;
  }

  /// Check if location permission is granted (using Geolocator)
  static Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  /// Check if all SOS permissions are granted
  static Future<bool> hasAllSOSPermissions() async {
    final mic = await Permission.microphone.isGranted;
    final location = await hasLocationPermission();
    final sensors = await Permission.sensors.isGranted;
    
    print('🔍 [DevicePermission] Current status - Mic: $mic, Location: $location, Sensors: $sensors');
    return mic && location; // Sensors are optional
  }

  /// Show permission rationale dialog
  static Future<void> showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String permissionType,
    required Function() onGranted,
    required Function() onDenied,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDenied();
              },
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                bool granted = false;
                
                switch (permissionType) {
                  case 'camera':
                    granted = await requestCameraPermission();
                    break;
                  case 'microphone':
                    granted = await requestMicrophonePermission();
                    break;
                  case 'sensors':
                    granted = await requestSensorsPermission();
                    break;
                  case 'location':
                    granted = await requestLocationPermission();
                    break;
                  case 'all':
                    granted = await requestAllSOSPermissions();
                    break;
                }
                
                if (granted) {
                  onGranted();
                } else {
                  _showSettingsDialog(context, permissionType);
                }
              },
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to open app settings
  static Future<void> _showSettingsDialog(BuildContext context, String permissionType) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: Text(
            '$permissionType permission is permanently denied. '
            'Please enable it in app settings to use this feature.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Show a simple snackbar when permissions are missing during SOS
  static void showPermissionSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Microphone & location permissions needed for SOS alerts',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () => openAppSettings(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
              child: const Text('SETTINGS'),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Ensure permissions are granted (shows dialog if needed)
  static Future<bool> ensureSOSPermissions(BuildContext context) async {
    final hasPermissions = await hasAllSOSPermissions();
    
    if (hasPermissions) {
      print('✅ [DevicePermission] All SOS permissions already granted');
      return true;
    }
    
    // Show dialog explaining why permissions are needed
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SOS Permissions Required'),
        content: const Text(
          'To use SOS features, we need:\n\n'
          '🎤 Microphone - to record voice messages\n'
          '📍 Location - to share your location with guardians\n\n'
          'You can also grant these later from app settings.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
    
    if (shouldRequest == true) {
      return await requestAllSOSPermissions();
    }
    
    return false;
  }
}