// ===================================================================
// IMPROVED: auth_provider.dart - Better State Management
// ===================================================================
// lib/core/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/models/role_info.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_service.dart';

/// Provider for AuthService instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// State notifier for user authentication state
class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(const AsyncValue.loading()) {
    _loadUser();
  }

  /// Load current user
  Future<void> _loadUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// ✅ IMPROVED: Refresh user data from API WITHOUT setting loading state
  /// This prevents router from redirecting to login during refresh
  Future<void> refreshUser() async {
    print('🔄 AuthProvider: Starting user refresh...');

    try {
      // DON'T set to loading - keep current user in state
      // This prevents router redirect during refresh

      // Fetch fresh data from API
      final user = await _authService.fetchCurrentUser();

      print('✅ AuthProvider: User refreshed - ${user.fullName}');
      print('   Role: ${user.currentRole?.roleName ?? "No role"}');

      // Update state with new data
      state = AsyncValue.data(user);

      print('✅ AuthProvider: State updated successfully');
    } catch (e, stack) {
      print('❌ AuthProvider: Error refreshing user - $e');
      // Don't update state on error - keep current user
      // state = AsyncValue.error(e, stack);
    }
  }

  /// ✅ NEW: Update user data directly (bypass API call)
  /// Use this when you already have the updated user object from an API call
  void updateUserData(UserModel user) {
    print('✅ AuthProvider: Direct state update - ${user.fullName}');
    state = AsyncValue.data(user);
  }

  /// Logout user - clears all data and resets state
  Future<void> logout() async {
    print('🔄 AuthStateNotifier: Starting logout...');

    try {
      // Call service logout (handles backend + storage)
      await _authService.logout();

      // Reset state to null (no user)
      state = const AsyncValue.data(null);

      print('✅ AuthStateNotifier: Logout successful - User state cleared');
    } catch (e, stack) {
      // Log error but ALWAYS reset state
      print('⚠️ AuthStateNotifier: Logout error: $e');

      // CRITICAL: Reset state to null even on error
      // This ensures user is logged out in UI even if something failed
      state = const AsyncValue.data(null);

      print('✅ AuthStateNotifier: State reset despite error');

      // Don't rethrow - we want logout to always succeed in the UI
      // The service already handled the actual logout
    }
  }

  // ===================================================================
  // AUTH PROVIDER - Profile Picture Update Methods
  // ===================================================================
  // Add these methods to your existing lib/core/providers/auth_provider.dart

  // Inside your AuthNotifier class:

  /// Update user profile picture in real-time
  /// Call this after successfully uploading a profile picture
  void updateProfilePicture(String? newProfilePicture) {
    final currentUser = state.value;
    if (currentUser == null) {
      print('⚠️ Cannot update profile picture: No user in state');
      return;
    }

    // Create updated user model with new profile picture
    final updatedUser = currentUser.copyWith(profilePicture: newProfilePicture);

    state = AsyncValue.data(updatedUser);

    print('✅ Auth Provider: Profile picture updated in state');
  }

  /// Update entire user object
  /// Useful when backend returns a complete updated user
  void updateUser(UserModel updatedUser) {
    state = AsyncValue.data(updatedUser);
    print('✅ Auth Provider: User data updated');
  }

  /// Remove profile picture (set to null)
  void removeProfilePicture() {
    updateProfilePicture(null);
    print('✅ Auth Provider: Profile picture removed');
  }

  /// Update user roles
  void updateUserRoles(List<RoleInfo> newRoles) {
    final currentUser = state.value;
    if (currentUser == null) {
      print('⚠️ Cannot update roles: No user in state');
      return;
    }

    final updatedUser = currentUser.copyWith(
      roles: newRoles,
      updatedAt: DateTime.now(),
    );

    state = AsyncValue.data(updatedUser);
    print('✅ Auth Provider: User roles updated');
  }

  /// Get current user synchronously
  UserModel? get currentUser {
    return state.value;
  }

  /// Check if user is logged in
  bool get isLoggedIn {
    return state.value != null;
  }
}

/// Provider for auth state
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
      final authService = ref.watch(authServiceProvider);
      return AuthStateNotifier(authService);
    });
