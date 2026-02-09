import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/services/family_service.dart';

final familyServiceProvider = Provider<FamilyService>((ref) {
  return FamilyService();
});

final familyMembersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(familyServiceProvider);
  return await service.getFamilyMembers();
});

final familyStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(familyServiceProvider);
  return await service.getFamilyStats();
});