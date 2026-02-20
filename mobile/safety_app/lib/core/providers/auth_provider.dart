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

  /// Restores the user session on cold start — the Instagram-style persistent login.
  ///
  /// Strategy:
  ///   1. No token in storage → logged out immediately (fast path).
  ///   2. Token found → restore user from cached JSON → state = logged in.
  ///      The router sees a non-null user and does NOT redirect to login.
  ///   3. Background API refresh → updates state with fresh data silently.
  ///      If the access token expired, DioClient's interceptor auto-refreshes
  ///      using the refresh token (this is already wired up in dio_client.dart).
  ///   4. If the background refresh fails for any reason → we keep the cached
  ///      user in state. The user stays logged in and can retry naturally.
  ///      Storage is only wiped when the server explicitly rejects the refresh
  ///      token (handled inside refreshAccessToken()).
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

  /// Refresh user data from API
  /// ✅ MERGED: Keeps your friend's error handling, adds your logging
  Future<void> refreshUser() async {
    print('🔄 AuthProvider: Starting user refresh...');

    try {
      final user = await _authApiService.fetchCurrentUser();

      print('✅ AuthProvider: User refreshed - ${user.fullName}');
      print('   Role: ${user.currentRole?.roleName ?? "No role"}');

      state = AsyncValue.data(user);
      print('✅ AuthProvider: State updated successfully');
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

  /// Logout user (your friend's implementation - handles Firebase + storage)
  Future<void> logout() async {
    print('🔄 AuthStateNotifier: Starting logout...');

    try {
      // Call service logout (handles backend + storage + Firebase)
      await _authApiService.logout();
      // Reset state to null (no user)
      state = const AsyncValue.data(null);
      print('✅ AuthStateNotifier: Logout successful - User state cleared');
    } catch (e) {
      // Log error but ALWAYS reset state
      print('⚠️ AuthStateNotifier: Logout error: $e');
      // CRITICAL: Reset state to null even on error
      state = const AsyncValue.data(null);
      print('✅ AuthStateNotifier: State reset despite error');
      // Don't rethrow - we want logout to always succeed in the UI
    }
  }

  /// ✅ Get access token from SecureStorageService (your feature)
  /// This matches how your login code saves the token
  Future<String?> getAccessToken() async {
    try {
      debugPrint(
        '🔍 [AuthProvider] Getting access token from secure storage...',
      );

      final token = await _storage.getAccessToken();

      if (token != null && token.isNotEmpty) {
        debugPrint('✅ [AuthProvider] Found access token');
        debugPrint('   Token preview: ${token.substring(0, 20)}...');
        return token;
      } else {
        debugPrint('⚠️ [AuthProvider] No access token found in secure storage');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [AuthProvider] Error getting access token: $e');
      return null;
    }
  }

  /// ✅ Update user profile picture (your feature)
  void updateProfilePicture(String? newProfilePicture) {
    final currentUser = state.value;
    if (currentUser == null) {
      print('⚠️ Cannot update profile picture: No user in state');
      return;
    }

    final updatedUser = currentUser.copyWith(profilePicture: newProfilePicture);
    state = AsyncValue.data(updatedUser);
    print('✅ Auth Provider: Profile picture updated in state');
  }

  /// ✅ Update entire user object (your feature)
  void updateUser(UserModel updatedUser) {
    state = AsyncValue.data(updatedUser);
    print('✅ Auth Provider: User data updated');
  }

  /// ✅ Remove profile picture (your feature)
  void removeProfilePicture() {
    updateProfilePicture(null);
    print('✅ Auth Provider: Profile picture removed');
  }

  /// ✅ Update user roles (your feature)
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

  /// Get current user synchronously (both versions had this)
  UserModel? get currentUser {
    return state.value;
  }

  /// Check if user is logged in (both versions had this)
  bool get isLoggedIn {
    return state.value != null;
  }
}

/// Provider for auth state
/// ✅ MERGED: Uses AuthApiService (your friend's) with extended functionality (yours)
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
      final authApiService = ref.watch(authApiServiceProvider);
      return AuthStateNotifier(authApiService);
    });
