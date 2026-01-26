// lib/core/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_service.dart';

/// Provider for AuthService instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for current user
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUser();
});

/// Provider to check if user is logged in
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isLoggedIn();
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

  /// Refresh user data from API
  Future<void> refreshUser() async {
    try {
      final user = await _authService.fetchCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
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
