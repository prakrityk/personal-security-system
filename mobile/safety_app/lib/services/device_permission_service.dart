// lib/services/device_permission_service.dart
import 'package:permission_handler/permission_handler.dart';
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

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request all SOS-related permissions
  static Future<Map<Permission, PermissionStatus>> requestSOSPermissions() async {
    return await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.sensors,
    ].request();
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

  /// Check if location permission is granted
  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted;
  }

  /// Check if all SOS permissions are granted
  static Future<bool> hasAllSOSPermissions() async {
    final camera = await Permission.camera.isGranted;
    final mic = await Permission.microphone.isGranted;
    final location = await Permission.location.isGranted;
    final sensors = await Permission.sensors.isGranted;
    
    return camera && mic && location && sensors;
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
                    final results = await requestSOSPermissions();
                    granted = results.values.every((status) => status.isGranted);
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
                'Camera & mic permissions needed for evidence recording',
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
}