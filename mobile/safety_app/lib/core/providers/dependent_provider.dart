// lib/core/providers/dependent_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/services/guardian_service.dart';
import 'package:safety_app/core/providers/guardian_provider.dart';

/// State notifier for managing approved dependents
class DependentNotifier
    extends StateNotifier<AsyncValue<List<DependentModel>>> {
  final GuardianService _guardianService;

  DependentNotifier(this._guardianService)
      : super(const AsyncValue.loading()) {
    // Initial load (no local data to preserve yet)
    loadDependents(preserveLocalUpdates: false);
  }

  /// Load all approved dependents for current guardian
  /// [preserveLocalUpdates] keeps locally updated data (e.g. profile pictures)
  Future<void> loadDependents({
    bool preserveLocalUpdates = true,
  }) async {
    try {
      final current = state.value ?? [];
      final remote = await _guardianService.getMyDependents();

      // First load OR no local data → just use backend
      if (!preserveLocalUpdates || current.isEmpty) {
        state = AsyncValue.data(remote);
        print('📦 Dependent Provider: Loaded ${remote.length} dependents');
        return;
      }

      // Merge backend data with local state
      final merged = remote.map((remoteDep) {
        final localDep = current.firstWhere(
          (d) => d.dependentId == remoteDep.dependentId,
          orElse: () => remoteDep,
        );

        // 🔑 Preserve locally updated profile picture if backend is stale
        if (remoteDep.profilePicture == null ||
            remoteDep.profilePicture!.isEmpty) {
          return localDep;
        }

        return remoteDep;
      }).toList();

      state = AsyncValue.data(merged);
      print('📦 Dependent Provider: Merged ${merged.length} dependents');
    } catch (e, stack) {
      print('❌ Dependent Provider: Error loading dependents: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh dependents list (safe, no flicker, no overwrite)
  Future<void> refresh() async {
    await loadDependents(preserveLocalUpdates: true);
  }

  /// Get current list synchronously
  List<DependentModel>? get currentList => state.value;

  /// Get primary dependents only
  List<DependentModel> get primaryDependents =>
      state.value?.where((d) => d.isPrimaryGuardian).toList() ?? [];

  /// Get collaborator dependents only
  List<DependentModel> get collaboratorDependents =>
      state.value?.where((d) => d.isCollaborator).toList() ?? [];

  /// Check if user has any dependents
  bool get hasDependents => (state.value?.isNotEmpty) ?? false;

  /// Get dependent by ID
  DependentModel? getDependentById(int dependentId) {
    return state.value?.firstWhere(
      (d) => d.dependentId == dependentId,
      orElse: () => throw Exception('Dependent not found'),
    );
  }

  /// ✅ Real-time profile picture update (optimistic UI)
  void updateDependentProfilePicture(
    int dependentId,
    String? newProfilePicture,
  ) {
    final current = state.value;
    if (current == null) return;

    final updatedList = current.map((dependent) {
      if (dependent.dependentId == dependentId) {
        return DependentModel(
          id: dependent.id,
          dependentId: dependent.dependentId,
          dependentName: dependent.dependentName,
          dependentEmail: dependent.dependentEmail,
          phoneNumber: dependent.phoneNumber,
          relation: dependent.relation,
          age: dependent.age,
          isPrimary: dependent.isPrimary,
          guardianType: dependent.guardianType,
          profilePicture: newProfilePicture,
          linkedAt: dependent.linkedAt,
        );
      }
      return dependent;
    }).toList();

    state = AsyncValue.data(updatedList);

    print(
      '✅ Dependent Provider: Profile picture updated for dependent $dependentId',
    );
  }

  /// Remove dependent profile picture immediately
  void removeDependentProfilePicture(int dependentId) {
    updateDependentProfilePicture(dependentId, null);
  }
}

/// Provider for dependents state notifier
final dependentProvider =
    StateNotifierProvider<DependentNotifier, AsyncValue<List<DependentModel>>>(
  (ref) {
    final guardianService = ref.watch(guardianServiceProvider);
    return DependentNotifier(guardianService);
  },
);

/// Convenience provider to get just the list (without AsyncValue wrapper)
final dependentListProvider = Provider<List<DependentModel>>((ref) {
  return ref.watch(dependentProvider).value ?? [];
});

/// Provider to check if user has any dependents
final hasDependentsProvider = Provider<bool>((ref) {
  return ref.watch(dependentListProvider).isNotEmpty;
});
