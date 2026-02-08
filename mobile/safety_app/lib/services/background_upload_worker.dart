import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:safety_app/services/evidence_service.dart';

class BackgroundUploadWorker {
  final EvidenceService _evidenceService;
  Timer? _periodicTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isRunning = false;

  BackgroundUploadWorker(this._evidenceService);

  /// Start the background worker.
  /// Checks for pending uploads every [intervalMinutes] minutes.
  void start({int intervalMinutes = 30}) {
    if (_isRunning) {
      print('Background worker already running');
      return;
    }

    _isRunning = true;
    print('Starting background upload worker (interval: $intervalMinutes min)');

    // Set up periodic timer for retry attempts
    _periodicTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => _retryPendingUploads(),
    );

    // Set up connectivity listener for instant retry when WiFi connects
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // Do initial check immediately on start
    _retryPendingUploads();
  }

  /// Stop the background worker
  void stop() {
    if (!_isRunning) return;

    print('Stopping background upload worker');
    _periodicTimer?.cancel();
    _periodicTimer = null;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _isRunning = false;
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final result = results.first;
    print('Connectivity changed: $result');

    if (result == ConnectivityResult.wifi) {
      print('WiFi connected, triggering upload retry');
      _retryPendingUploads();
    }
  }

  /// Retry pending uploads
  Future<void> _retryPendingUploads() async {
    try {
      print('Background worker: Checking for pending uploads...');
      await _evidenceService.retryPendingUploads();
    } catch (e) {
      print('Background worker error: $e');
    }
  }

  /// Get current running status
  bool get isRunning => _isRunning;

  /// Manually trigger a retry (useful for testing)
  Future<void> triggerRetry() async {
    await _retryPendingUploads();
  }
}