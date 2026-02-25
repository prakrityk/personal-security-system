// lib/core/providers/dependent_guardian_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/models/guardian_model.dart';
import 'package:safety_app/services/dependent_service.dart';

/// Provider for DependentService instance
final dependentServiceProvider = Provider<DependentService>((ref) {
  return DependentService();
});

/// Provider for fetching guardians for a dependent
final myGuardiansProvider = FutureProvider<List<GuardianModel>>((ref) async {
  final dependentService = ref.watch(dependentServiceProvider);
  return dependentService.getMyGuardians();
});

/// Provider to check if user has any guardians
final hasGuardiansProvider = Provider<bool>((ref) {
  final guardiansAsync = ref.watch(myGuardiansProvider);
  return guardiansAsync.value?.isNotEmpty ?? false;
});