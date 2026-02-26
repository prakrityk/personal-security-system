import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import 'package:safety_app/models/role_info.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_api_service.dart';


/// Provider for AuthApiService instance
final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService();
});

/// Provider for AuthService instance
final authServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService();
});

/// Provider for current user
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authApiService = ref.watch(authApiServiceProvider);
  return await authApiService.getCurrentUser();
});

/// Provider to check if user is logged in
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final authApiService = ref.watch(authApiServiceProvider);
  return await authApiService.isLoggedIn();
});

/// State notifier for user authentication state
class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthApiService _authApiService;
  final SecureStorageService _storage = SecureStorageService();

  AuthStateNotifier(this._authApiService) : super(const AsyncValue.loading()) {
    _loadUser();
  }

  /// Load current user from local storage on app start
  Future<void> _loadUser() async {
    state = const AsyncValue.loading();
    try {
      final token = await _storage.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [AuthProvider] No token — user is logged out');
        state = const AsyncValue.data(null);
        return;
      }

      debugPrint('✅ [AuthProvider] Token found — restoring session');
      _authApiService.attachTokenToDio(token);

      final cachedUser = await _authApiService.getCurrentUser();
      if (cachedUser != null) {
        debugPrint(
          '✅ [AuthProvider] User restored from cache: ${cachedUser.fullName}',
        );
        state = AsyncValue.data(cachedUser);
      } else {
        debugPrint(
          '⚠️ [AuthProvider] Token found but no cached user — will try API',
        );
      }

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
          debugPrint('ℹ️ [AuthProvider] Keeping cached user in state');
        } else {
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

  /// Refresh user data from backend
  Future<void> refreshUser() async {
    print('🔄 AuthProvider: Starting user refresh...');
    try {
      final user = await _authApiService.fetchCurrentUser();
      print('✅ AuthProvider: User refreshed - ${user.fullName}');
      print('   Role: ${user.currentRole?.roleName ?? "No role"}');
      print('✅ User refreshed. isVoiceRegistered: ${user.isVoiceRegistered}');
      state = AsyncValue.data(user);
    } catch (e, stack) {
      print('❌ AuthProvider: Error refreshing user - $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update user data directly — for immediate UI updates after profile edits
  void updateUserData(UserModel user) {
    print('✅ AuthProvider: Direct state update - ${user.fullName}');
    state = AsyncValue.data(user);
  }

  /// Logout user - clears all data and resets state
  Future<void> logout() async {
    print('🔄 AuthStateNotifier: Starting logout...');
    try {
      await _authApiService.logout();
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

  /// ✅ FIXED: Now persists to secure storage so the gate doesn't re-appear
  /// after an app restart once registration is complete.
  Future<void> updateVoiceRegistrationStatus(bool status) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    final updatedUser = currentUser.copyWith(isVoiceRegistered: status);

    // ✅ Persist to storage — survives app restarts
    await _storage.saveUserData(updatedUser.toJson());

    // Update in-memory state — triggers router redirect to Home
    state = AsyncValue.data(updatedUser);

    print('🎤 isVoiceRegistered persisted → $status');
  }
}

/// Provider for auth state
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
      final authService = ref.watch(authServiceProvider);
      return AuthStateNotifier(authService);
    });