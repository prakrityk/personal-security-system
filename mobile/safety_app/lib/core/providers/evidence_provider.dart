import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:safety_app/services/evidence_service.dart';
import 'package:safety_app/services/background_upload_worker.dart';
import 'package:safety_app/services/firebase/firebase_auth_service.dart';

/// Provider for Firebase Auth Service
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

/// Provider for EvidenceService instance
final evidenceServiceProvider = Provider<EvidenceService>((ref) {
  final service = EvidenceService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for BackgroundUploadWorker instance
final uploadWorkerProvider = Provider<BackgroundUploadWorker>((ref) {
  final evidenceService = ref.watch(evidenceServiceProvider);
  final worker = BackgroundUploadWorker(evidenceService);

  ref.onDispose(() {
    worker.stop();
  });

  return worker;
});

/// Async notifier — supports invalidation so the token can be refreshed
/// without restarting the app. Call ref.invalidate(evidenceInitNotifierProvider)
/// anywhere a token refresh is needed.
class EvidenceInitNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final evidenceService = ref.watch(evidenceServiceProvider);
    final authService = ref.watch(firebaseAuthServiceProvider);

    // 1. Get Firebase ID token
    final authToken = await authService.getFirebaseIdToken(forceRefresh: false);

    if (authToken == null || authToken.isEmpty) {
      print('⚠️ No auth token available');
      return false;
    }

    // 2. Initialize evidence service with correct .env keys
    await evidenceService.initialize(
      authToken: authToken,
      driveFolderId: dotenv.env['GOOGLE_DRIVE_FOLDER_ID'] ?? '',
      backendUrl: dotenv.env['BACKEND_URL'] ?? '',
    );

    // 3. Start background worker with correct .env key
    final interval =
        int.tryParse(dotenv.env['EVIDENCE_UPLOAD_INTERVAL_MINUTES'] ?? '30') ??
        30;
    final worker = ref.watch(uploadWorkerProvider);
    worker.start(intervalMinutes: interval);

    return true;
  }

  /// Call this when you know the Firebase token has expired.
  /// It will re-run build() with a fresh token automatically.
  Future<void> refreshToken() async {
    ref.invalidateSelf();
  }
}

final evidenceInitNotifierProvider =
    AsyncNotifierProvider<EvidenceInitNotifier, bool>(EvidenceInitNotifier.new);

/// Helper to trigger evidence recording from anywhere in the app
class EvidenceController {
  final EvidenceService _service;

  EvidenceController(this._service);

  Future<void> onThreatDetected({
    String evidenceType = 'video',
    int? durationSeconds,
  }) async {
    // Correct .env key
    final defaultDuration =
        int.tryParse(dotenv.env['DEFAULT_RECORDING_DURATION_SECONDS'] ?? '20') ??
        20;

    return _service.onThreatDetected(
      evidenceType: evidenceType,
      durationSeconds: durationSeconds ?? defaultDuration,
    );
  }

  Future<int> getPendingCount() => _service.getPendingCount();
  Future<void> retryUploads() => _service.retryPendingUploads();
}

final evidenceControllerProvider = Provider<EvidenceController>((ref) {
  final service = ref.watch(evidenceServiceProvider);
  return EvidenceController(service);
});