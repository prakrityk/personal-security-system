// lib/core/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_service.dart';

/// Provider for AuthService instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// StateNotifier for user authentication state
class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(const AsyncValue.loading()) {
    _loadUser();
  }

  /// Load current user from local storage
  Future<void> _loadUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Login user and refresh state from backend
  Future<void> login(String email, String password) async {
    try {
      // Step 1: Login via service
      final authResponse = await _authService.login(email: email, password: password);

      // Step 2: Update state immediately
      state = AsyncValue.data(authResponse.user);

      // Step 3: Refresh user from backend to get latest fields
      await refreshUser();

      print('✅ Login complete. isVoiceRegistered: ${state.value?.isVoiceRegistered}');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Refresh user data from backend
  Future<void> refreshUser() async {
    try {
      final user = await _authService.fetchCurrentUser();
      state = AsyncValue.data(user);
      print('✅ User refreshed. isVoiceRegistered: ${user.isVoiceRegistered}');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update local state for voice registration
  Future<void> updateVoiceRegistrationStatus(bool status) async {
    final currentUser = state.value;
    if (currentUser != null) {
      // Update user object
      final updatedUser = currentUser.copyWith(isVoiceRegistered: status);

      // Replace state to trigger UI rebuild
      state = AsyncValue.data(updatedUser);
      print("✅ Local State Updated: isVoiceRegistered = $status");

      // Optional: sync with backend
      try {
        await _authService.fetchCurrentUser();
      } catch (e) {
        print("⚠️ Background sync failed, but local UI is updated.");
      }
    }
  }

  /// Logout user - clears storage and state
  Future<void> logout() async {
    print('🔄 AuthStateNotifier: Starting logout...');
    try {
      await _authService.logout();
      state = const AsyncValue.data(null);
      print('✅ AuthStateNotifier: Logout successful - User state cleared');
    } catch (e, stack) {
      print('⚠️ AuthStateNotifier: Logout error: $e');
      state = const AsyncValue.data(null);
      print('✅ AuthStateNotifier: State reset despite error');
    }
  }

  /// Get current user synchronously
  UserModel? get currentUser => state.value;

  /// Check if user is logged in
  bool get isLoggedIn => state.value != null;
}

/// Provider for AuthStateNotifier
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService);
});
