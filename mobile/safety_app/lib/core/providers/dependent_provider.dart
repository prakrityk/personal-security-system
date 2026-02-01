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

  DependentNotifier(this._guardianService) : super(const AsyncValue.loading()) {
    loadDependents();
  }

  /// Load all approved dependents for current guardian
  Future<void> loadDependents() async {
    state = const AsyncValue.loading();
    try {
      final dependents = await _guardianService.getMyDependents();
      state = AsyncValue.data(dependents);

      print('📦 Dependent Provider: Loaded ${dependents.length} dependents');
    } catch (e, stack) {
      print('❌ Dependent Provider: Error loading dependents: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh dependents list
  Future<void> refresh() async {
    await loadDependents();
  }

  /// Get current list synchronously
  List<DependentModel>? get currentList {
    return state.value;
  }

  /// Get primary dependents only
  List<DependentModel> get primaryDependents {
    return state.value?.where((d) => d.isPrimaryGuardian).toList() ?? [];
  }

  /// Get collaborator dependents only
  List<DependentModel> get collaboratorDependents {
    return state.value?.where((d) => d.isCollaborator).toList() ?? [];
  }

  /// Check if user has any dependents
  bool get hasDependents {
    return (state.value?.isNotEmpty) ?? false;
  }

  /// Get dependent by ID
  DependentModel? getDependentById(int dependentId) {
    return state.value?.firstWhere(
      (d) => d.dependentId == dependentId,
      orElse: () => throw Exception('Dependent not found'),
    );
  }
}

/// Provider for dependents state notifier
final dependentProvider =
    StateNotifierProvider<DependentNotifier, AsyncValue<List<DependentModel>>>((
      ref,
    ) {
      final guardianService = ref.watch(guardianServiceProvider);
      return DependentNotifier(guardianService);
    });

/// Convenience provider to get just the list (without AsyncValue wrapper)
final dependentListProvider = Provider<List<DependentModel>>((ref) {
  final dependentsState = ref.watch(dependentProvider);
  return dependentsState.value ?? [];
});

/// Provider to check if user has any dependents
final hasDependentsProvider = Provider<bool>((ref) {
  final dependents = ref.watch(dependentListProvider);
  return dependents.isNotEmpty;
});
