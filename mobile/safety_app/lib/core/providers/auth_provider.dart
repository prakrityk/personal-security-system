import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import 'package:safety_app/models/role_info.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_api_service.dart'; // Your service (if still needed)


/// Provider for AuthApiService instance (your friend's - for Firebase)
final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService();
});

/// Provider for AuthService instance (yours - if needed for other features)
final authServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService();
});

/// Provider for current user (your friend's)
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authApiService = ref.watch(authApiServiceProvider);
  return await authApiService.getCurrentUser();
});

/// Provider to check if user is logged in (your friend's)
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final authApiService = ref.watch(authApiServiceProvider);
  return await authApiService.isLoggedIn();
});

/// State notifier for user authentication state
/// ✅ MERGED: Uses AuthApiService for auth, adds profile/role management
class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthApiService _authApiService; // Your friend's service for auth
  final SecureStorageService _storage = SecureStorageService();

  AuthStateNotifier(this._authApiService) : super(const AsyncValue.loading()) {
    _loadUser();
  }

  /// Load current user (your friend's implementation) from local storage
  Future<void> _loadUser() async {
    state = const AsyncValue.loading();
    try {
      // Step 1: Check for token
      final token = await _storage.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [AuthProvider] No token — user is logged out');
        state = const AsyncValue.data(null);
        return;
      }

      debugPrint('✅ [AuthProvider] Token found — restoring session');

      // Step 2: Attach token to Dio so all subsequent requests are authenticated
      _authApiService.attachTokenToDio(token);

      // Step 3: Restore user from cached JSON immediately.
      // This makes the router see a logged-in user without waiting for the API.
      final cachedUser = await _authApiService.getCurrentUser();
      if (cachedUser != null) {
        debugPrint(
          '✅ [AuthProvider] User restored from cache: ${cachedUser.fullName}',
        );
        state = AsyncValue.data(cachedUser);
      } else {
        // Token exists but no cached user JSON — unusual, but handle it.
        // We'll try the API below; if that also fails, log out.
        debugPrint(
          '⚠️ [AuthProvider] Token found but no cached user — will try API',
        );
      }

      // Step 4: Silent background refresh from API.
      // Wrapped in its own try/catch so a failure NEVER clears the cached state.
      try {
        final freshUser = await _authApiService.fetchCurrentUser();
        debugPrint(
          '✅ [AuthProvider] Session verified with API — user: ${freshUser.fullName}',
        );
        state = AsyncValue.data(freshUser);
      } catch (apiError) {
        debugPrint(
          '⚠️ [AuthProvider] Background API refresh failed: $apiError',
        );
        if (cachedUser != null) {
          // We already set state to cachedUser above — do nothing.
          // The user stays logged in with their cached data.
          debugPrint('ℹ️ [AuthProvider] Keeping cached user in state');
        } else {
          // No cached user AND API failed — cannot confirm session, log out.
          debugPrint(
            '❌ [AuthProvider] No cached user and API failed — logging out',
          );
          state = const AsyncValue.data(null);
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [AuthProvider] Fatal error in _loadUser: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Login user and refresh state from backend
  
  /// Refresh user data from backend
  /// ✅ MERGED: Keeps your friend's error handling, adds your logging
  Future<void> refreshUser() async {
    print('🔄 AuthProvider: Starting user refresh...');

    try {
      final user = await _authApiService.fetchCurrentUser();

      print('✅ AuthProvider: User refreshed - ${user.fullName}');
      print('   Role: ${user.currentRole?.roleName ?? "No role"}');
      print('✅ User refreshed. isVoiceRegistered: ${user.isVoiceRegistered}');

      state = AsyncValue.data(user);
      print('✅ AuthProvider: State updated successfully');
      print('✅ User refreshed. isVoiceRegistered: ${user.isVoiceRegistered}');
    } catch (e, stack) {
      print('❌ AuthProvider: Error refreshing user - $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update user data directly (your feature)
  /// ✅ Useful for immediate UI updates after profile edits
  void updateUserData(UserModel user) {
    print('✅ AuthProvider: Direct state update - ${user.fullName}');
    state = AsyncValue.data(user);
  }

  /// Logout user - clears all data and resets state
  Future<void> logout() async {
    print('🔄 AuthStateNotifier: Starting logout...');
    try {
      // Call service logout (handles backend + storage)
      await _authApiService.logout();

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

  /// Get current user synchronously (both versions had this)
  UserModel? get currentUser => state.value;

  /// Check if user is logged in
  bool get isLoggedIn {
    return state.value != null;
  }


  Future<void> updateVoiceRegistrationStatus(bool status) async {
    final currentUser = state.value;
    if (currentUser != null) {
      // Update user object
      final updatedUser = currentUser.copyWith(isVoiceRegistered: status);

      // Replace state to trigger UI rebuild
      state = AsyncValue.data(updatedUser);
      print("✅ Local State Updated: isVoiceRegistered = $status");

      // Optional: sync with backend
      // try {
      //   await _authApiService.fetchCurrentUser();
      // } catch (e) {
      //   print("⚠️ Background sync failed, but local UI is updated.");
      // }
    }
  }
}



/// Provider for auth state
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
      final authService = ref.watch(authServiceProvider);
      return AuthStateNotifier(authService);
    });
