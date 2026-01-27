// lib/core/providers/guardian_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/models/pending_dependent_model.dart';
import 'package:safety_app/services/guardian_service.dart';

/// Provider for GuardianService instance
final guardianServiceProvider = Provider<GuardianService>((ref) {
  return GuardianService();
});

/// Provider for pending dependents list
final pendingDependentsProvider =
    FutureProvider<List<PendingDependentWithQR>>((ref) async {
  final guardianService = ref.watch(guardianServiceProvider);
  return await guardianService.getPendingDependents();
});

/// State notifier for managing pending dependents
class PendingDependentsNotifier
    extends StateNotifier<AsyncValue<List<PendingDependentWithQR>>> {
  final GuardianService _guardianService;

  PendingDependentsNotifier(this._guardianService)
      : super(const AsyncValue.loading()) {
    loadDependents();
  }

  /// Load all pending dependents
  Future<void> loadDependents() async {
    state = const AsyncValue.loading();
    try {
      final dependents = await _guardianService.getPendingDependents();
      state = AsyncValue.data(dependents);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Create a new pending dependent
  Future<PendingDependentResponse?> createDependent(
    PendingDependentCreate dependentData,
  ) async {
    try {
      final newDependent =
          await _guardianService.createPendingDependent(dependentData);

      // Reload the list to include the new dependent
      await loadDependents();

      return newDependent;
    } catch (e) {
      print('❌ Error creating dependent: $e');
      rethrow;
    }
  }

  /// Generate QR for a pending dependent
  Future<GenerateQRResponse?> generateQR(int pendingDependentId) async {
    try {
      final qrResponse = await _guardianService.generateQR(pendingDependentId);

      // Reload to update QR status
      await loadDependents();

      return qrResponse;
    } catch (e) {
      print('❌ Error generating QR: $e');
      rethrow;
    }
  }

  /// Delete a pending dependent
  Future<void> deleteDependent(int pendingDependentId) async {
    try {
      await _guardianService.deletePendingDependent(pendingDependentId);

      // Reload the list
      await loadDependents();
    } catch (e) {
      print('❌ Error deleting dependent: $e');
      rethrow;
    }
  }

  /// Get current list synchronously
  List<PendingDependentWithQR>? get currentList {
    return state.value;
  }
}

/// Provider for pending dependents state notifier
final pendingDependentsNotifierProvider = StateNotifierProvider<
    PendingDependentsNotifier, AsyncValue<List<PendingDependentWithQR>>>((ref) {
  final guardianService = ref.watch(guardianServiceProvider);
  return PendingDependentsNotifier(guardianService);
});