// lib/core/providers/collaborator_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/services/collaborator_service.dart';

final collaboratorServiceProvider = Provider<CollaboratorService>((ref) {
  return CollaboratorService();
});

// Collaborators for a specific dependent
final dependentCollaboratorsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, dependentId) async {
  final service = ref.watch(collaboratorServiceProvider);
  return await service.getCollaborators(dependentId);
});

// Pending invitations for a dependent
final pendingInvitationsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, dependentId) async {
  final service = ref.watch(collaboratorServiceProvider);
  return await service.getPendingInvitations(dependentId);
});