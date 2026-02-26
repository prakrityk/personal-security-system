import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safety_app/services/location_api_service.dart';

final dependentForegroundServiceProvider =
    NotifierProvider<DependentForegroundServiceNotifier, bool>(
  () => DependentForegroundServiceNotifier(),
);

class DependentForegroundServiceNotifier extends Notifier<bool> {
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  bool _isRunning = false;
  final Duration _sendInterval;

  DependentForegroundServiceNotifier(
      {Duration sendInterval = const Duration(seconds: 5)})
      : _sendInterval = sendInterval;

  @override
  bool build() => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    state = _isRunning;

    final status = await Permission.location.request();
    if (!status.isGranted) {
      print("❌ Location permission denied.");
      _isRunning = false;
      state = _isRunning;
      return;
    }

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _sendLocation(initialPosition);
    } catch (e) {
      print("❌ Error getting initial location: $e");
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) => _sendLocation(pos));

    _timer = Timer.periodic(_sendInterval, (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _sendLocation(pos);
      } catch (e) {
        print("❌ Error fetching location in timer: $e");
      }
    });

    print("✅ Dependent foreground service started.");
  }

  Future<void> stop() async {
    await _positionStream?.cancel();
    _timer?.cancel();
    _isRunning = false;
    state = _isRunning;
    print("🛑 Dependent foreground service stopped.");
  }

  void _sendLocation(Position position) {
    try {
      final locationService = ref.read(locationApiServiceProvider);
      locationService.sendLocation(position);
    } catch (e) {
      print("❌ Error sending location: $e");
    }
  }
}