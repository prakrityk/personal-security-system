// lib/features/home/live_location_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safety_app/services/location_api_service.dart';
import 'package:safety_app/services/dependent_location_service.dart';

class LiveLocationScreen extends ConsumerStatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  ConsumerState<LiveLocationScreen> createState() =>
      _LiveLocationScreenState();
}

class _LiveLocationScreenState extends ConsumerState<LiveLocationScreen> {
  StreamSubscription<Position>? _positionStream;
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};
  DateTime? _lastSentTime;
  Timer? _locationsRefreshTimer;
  bool _cameraMovedOnce = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _startLocationsRefresh();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _locationsRefreshTimer?.cancel();
    super.dispose();
  }

  /// Ask permission and start streaming guardian location
  Future<void> _initLocation() async {
    final status = await Permission.location.request();

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission denied")),
      );
      return;
    }

    // Stream guardian's own location
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _maybeSendLocation(position);
    });

    await _updateMarkers(); // Initial load
  }

  /// Send guardian location every 5 seconds
  void _maybeSendLocation(Position position) {
    final now = DateTime.now();

    if (_lastSentTime == null ||
        now.difference(_lastSentTime!) > const Duration(seconds: 5)) {
      _lastSentTime = now;
      final locationService = ref.read(locationApiServiceProvider);
      locationService.sendLocation(position);
    }
  }

  /// Refresh all dependent locations every 10 seconds
  void _startLocationsRefresh() {
    _locationsRefreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      await _updateMarkers();
    });
  }

  /// Fetch dependents from backend + guardian's own location
  Future<void> _updateMarkers() async {
    if (!mounted) return;

    final service = ref.read(dependentLocationServiceProvider);
    final dependents = await service.fetchDependentsLocations();

    final Set<Marker> newMarkers = {};
    LatLng? guardianLatLng;

    // 1️⃣ Add guardian location (red)
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      guardianLatLng = LatLng(position.latitude, position.longitude);

      newMarkers.add(
        Marker(
          markerId: const MarkerId("guardian_self"),
          position: guardianLatLng,
          infoWindow: const InfoWindow(title: "You (Guardian)"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    } catch (e) {
      debugPrint("Failed to get guardian location: $e");
    }

    // 2️⃣ Add dependents (blue) with names
    for (final loc in dependents) {
      final lat = (loc['latitude'] as num).toDouble();
      final lng = (loc['longitude'] as num).toDouble();

      final dependentName = loc['dependent_name']?.toString().isNotEmpty == true
          ? loc['dependent_name']
          : "Dependent";

      final updatedAt = loc['updated_at'] ?? "";

      newMarkers.add(
        Marker(
          markerId: MarkerId("dependent_${loc['user_id']}"),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: dependentName,
            snippet: "Last updated: $updatedAt",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });

    // 3️⃣ Move camera to guardian location initially
    if (!_cameraMovedOnce && guardianLatLng != null) {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(guardianLatLng, 17),
      );
      _cameraMovedOnce = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Location")),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(27.7172, 85.3240), // Kathmandu fallback
          zoom: 17,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        onMapCreated: (controller) => _mapController.complete(controller),
      ),
    );
  }
}