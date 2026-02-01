import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/services/permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final permissionSummaryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final service = ref.watch(permissionServiceProvider);
  await service.initialize();
  return await service.getPermissionSummary();
});

// Helper provider to check specific permissions
final canEditDependentContactsProvider = FutureProvider.family<bool, int>((
  ref,
  dependentId,
) async {
  final service = ref.watch(permissionServiceProvider);
  await service.initialize();
  return await service.canEditDependentEmergencyContacts(dependentId);
});

final canEditDependentSafetyProvider = FutureProvider.family<bool, int>((
  ref,
  dependentId,
) async {
  final service = ref.watch(permissionServiceProvider);
  await service.initialize();
  return await service.canEditDependentSafetyFeatures(dependentId);
});

final isPrimaryGuardianProvider = FutureProvider.family<bool, int>((
  ref,
  dependentId,
) async {
  final service = ref.watch(permissionServiceProvider);
  await service.initialize();
  return await service.isPrimaryGuardianForDependent(dependentId);
});
