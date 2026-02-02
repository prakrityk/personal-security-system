// lib/features/home/family/screens/smart_family_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/home/family/screens/family_list_screen.dart';
import 'package:safety_app/features/home/family/screens/dependent_family_list_screen.dart';

/// Smart wrapper that shows the appropriate Family screen based on user role
/// - Guardian/Personal: Shows dependents they manage (family_list_screen.dart)
/// - Dependent (Child/Elderly): Shows their guardians (dependent_family_list_screen.dart)
class SmartFamilyListScreen extends ConsumerWidget {
  const SmartFamilyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final roleName = user?.currentRole?.roleName.toLowerCase();

    // Route based on role
    switch (roleName) {
      case 'child':
      case 'elderly':
        // Dependents see their guardians
        return const DependentFamilyListScreen();
      
      case 'guardian':
      case 'global_user':
      default:
        // Guardians and personal users see their dependents
        return const FamilyListScreen();
    }
  }
}