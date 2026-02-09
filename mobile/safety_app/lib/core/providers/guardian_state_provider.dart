// ===================================================================
// guardian_state_provider.dart - State management for guardians (dependent view)
// ===================================================================
// lib/core/providers/guardian_state_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/models/guardian_model.dart';
import 'package:safety_app/services/dependent_service.dart';

/// Provider for DependentService instance
final dependentServiceProvider = Provider<DependentService>((ref) {
  return DependentService();
});

/// State notifier for managing guardians (for dependent users)
/// Provides real-time updates for guardian profile pictures
class GuardianNotifier extends StateNotifier<AsyncValue<List<GuardianModel>>> {
  final DependentService _dependentService;

  GuardianNotifier(this._dependentService) : super(const AsyncValue.loading()) {
    // Initial load (no local data to preserve yet)
    loadGuardians(preserveLocalUpdates: false);
  }

  /// Load all guardians for current dependent
  /// [preserveLocalUpdates] keeps locally updated data (e.g. profile pictures)
  Future<void> loadGuardians({bool preserveLocalUpdates = true}) async {
    try {
      final current = state.value ?? [];
      final remote = await _dependentService.getMyGuardians();

      // First load OR no local data → just use backend
      if (!preserveLocalUpdates || current.isEmpty) {
        state = AsyncValue.data(remote);
        print('📦 Guardian Provider: Loaded ${remote.length} guardians');
        return;
      }

      // Merge backend data with local state
      final merged = remote.map((remoteGuardian) {
        final localGuardian = current.firstWhere(
          (g) => g.guardianId == remoteGuardian.guardianId,
          orElse: () => remoteGuardian,
        );

        // 🔒 Preserve locally updated profile picture if backend is stale
        if (remoteGuardian.profilePicture == null ||
            remoteGuardian.profilePicture!.isEmpty) {
          return localGuardian;
        }

        return remoteGuardian;
      }).toList();

      state = AsyncValue.data(merged);
      print('📦 Guardian Provider: Merged ${merged.length} guardians');
    } catch (e, stack) {
      print('❌ Guardian Provider: Error loading guardians: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh guardians list (safe, no flicker, no overwrite)
  Future<void> refresh() async {
    await loadGuardians(preserveLocalUpdates: true);
  }

  /// Get current list synchronously
  List<GuardianModel>? get currentList => state.value;

  /// Get primary guardian
  GuardianModel? get primaryGuardian {
    try {
      return state.value?.firstWhere(
        (g) => g.isPrimaryGuardian,
        orElse: () => throw Exception('No primary guardian'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get collaborator guardians only
  List<GuardianModel> get collaboratorGuardians =>
      state.value?.where((g) => g.isCollaborator).toList() ?? [];

  /// Check if user has any guardians
  bool get hasGuardians => (state.value?.isNotEmpty) ?? false;

  /// Get guardian by ID
  GuardianModel? getGuardianById(int guardianId) {
    try {
      return state.value?.firstWhere(
        (g) => g.guardianId == guardianId,
        orElse: () => throw Exception('Guardian not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// ✅ Real-time guardian profile picture update (optimistic UI)
  void updateGuardianProfilePicture(int guardianId, String? newProfilePicture) {
    final current = state.value;
    if (current == null) return;

    final updatedList = current.map((guardian) {
      if (guardian.guardianId == guardianId) {
        // ✅ Create new GuardianModel with ALL fields
        return GuardianModel(
          id: guardian.id,
          guardianId: guardian.guardianId,
          guardianName: guardian.guardianName,
          guardianEmail: guardian.guardianEmail,
          phoneNumber: guardian.phoneNumber,
          relation: guardian.relation,
          isPrimary: guardian.isPrimary,
          guardianType: guardian.guardianType,
          profilePicture: newProfilePicture, // ✅ Updated field
          linkedAt: guardian.linkedAt,
        );
      }
      return guardian;
    }).toList();

    state = AsyncValue.data(updatedList);

    print(
      '✅ Guardian Provider: Profile picture updated for guardian $guardianId',
    );
  }

  /// Remove guardian profile picture immediately
  void removeGuardianProfilePicture(int guardianId) {
    updateGuardianProfilePicture(guardianId, null);
  }

  /// Remove guardian from list (after deletion)
  void removeGuardian(int relationshipId) {
    final current = state.value;
    if (current == null) return;

    // ✅ Use 'id' field which is the relationship ID
    final updatedList = current
        .where((guardian) => guardian.id != relationshipId)
        .toList();

    state = AsyncValue.data(updatedList);

    print(
      '✅ Guardian Provider: Removed guardian with relationship $relationshipId',
    );
  }
}

/// Provider for guardian state notifier
final guardianStateProvider =
    StateNotifierProvider<GuardianNotifier, AsyncValue<List<GuardianModel>>>((
      ref,
    ) {
      final dependentService = ref.watch(dependentServiceProvider);
      return GuardianNotifier(dependentService);
    });

/// Convenience provider to get just the list (without AsyncValue wrapper)
final guardianListProvider = Provider<List<GuardianModel>>((ref) {
  return ref.watch(guardianStateProvider).value ?? [];
});

/// Provider to check if user has any guardians
final hasGuardiansProvider = Provider<bool>((ref) {
  return ref.watch(guardianListProvider).isNotEmpty;
});

/// Provider to get primary guardian
final primaryGuardianProvider = Provider<GuardianModel?>((ref) {
  final guardians = ref.watch(guardianListProvider);
  try {
    return guardians.firstWhere((g) => g.isPrimaryGuardian);
  } catch (e) {
    return null;
  }
});

/// Provider to get collaborator guardians
final collaboratorGuardiansProvider = Provider<List<GuardianModel>>((ref) {
  final guardians = ref.watch(guardianListProvider);
  return guardians.where((g) => g.isCollaborator).toList();
});
