// lib/core/navigation/role_navigation_guard.dart

import 'package:flutter/material.dart';
import 'package:safety_app/core/navigation/role_based_navigation_config.dart';
import 'package:safety_app/models/user_model.dart';

/// Navigation guard that validates if a user has access to specific routes
class RoleNavigationGuard {
  /// Check if user can access a specific tab
  static bool canAccessTab(UserModel? user, String tabRoute) {
    if (user == null) return false;
    
    final roleName = user.currentRole?.roleName;
    return RoleBasedNavigationConfig.hasAccessToTab(roleName, tabRoute);
  }

  /// Get appropriate redirect route if user doesn't have access
  static String? getRedirectRoute(UserModel? user, String requestedRoute) {
    if (user == null) return '/login';
    
    // If user doesn't have a role assigned, send to role selection
    if (user.currentRole == null || !user.hasRole) {
      return '/role-intent';
    }
    
    // Check if user has access to the requested route
    if (!canAccessTab(user, requestedRoute)) {
      // Redirect to home (SOS) which is accessible to all roles
      return '/home';
    }
    
    return null; // No redirect needed
  }

  /// Determine the appropriate home route after login based on user role
  static String getHomeRouteForUser(UserModel? user) {
    if (user == null) return '/login';
    
    // If no role assigned, go to role selection
    if (user.currentRole == null || !user.hasRole) {
      return '/role-intent';
    }
    
    // All roles go to the general home screen
    // The home screen itself will show role-appropriate tabs
    return '/home';
  }

  /// Check if a dependent user should have limited access
  static bool isDependentRole(String? roleName) {
    if (roleName == null) return false;
    
    final normalizedRole = roleName.toLowerCase();
    return normalizedRole == 'child' || normalizedRole == 'elderly';
  }

  /// Check if a user is a guardian or personal user
  static bool isGuardianOrPersonal(String? roleName) {
    if (roleName == null) return false;
    
    final normalizedRole = roleName.toLowerCase();
    return normalizedRole == 'guardian' || normalizedRole == 'global_user';
  }

  /// Show access denied dialog
  static void showAccessDeniedDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Restricted'),
        content: Text(
          'Your current role does not have access to $feature. '
          'Please contact your guardian for assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}