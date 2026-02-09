// lib/core/providers/auth_provider.dart
// ✅ FINAL FIX: Uses SecureStorageService to match your login implementation

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

  AuthStateNotifier(this._authApiService) : super(const AsyncValue.loading()) {
    _loadUser();
  }

  /// Load current user
  Future<void> _loadUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authApiService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh user data from API WITHOUT setting loading state
  Future<void> refreshUser() async {
    print('🔄 AuthProvider: Starting user refresh...');

    try {
      final user = await _authApiService.fetchCurrentUser();
      state = AsyncValue.data(user);
      print('✅ AuthProvider: State updated successfully');
    } catch (e) {
      print('❌ AuthProvider: Error refreshing user - $e');
    }
  }

  /// Update user data directly
  void updateUserData(UserModel user) {
    print('✅ AuthProvider: Direct state update - ${user.fullName}');
    state = AsyncValue.data(user);
  }

  /// Logout user
  Future<void> logout() async {
    print('🔄 AuthStateNotifier: Starting logout...');

    try {
      // Call service logout (handles backend + storage)
      await _authApiService.logout();

      // Reset state to null (no user)
      state = const AsyncValue.data(null);
      print('✅ AuthStateNotifier: Logout successful - User state cleared');
    } catch (e) {
      print('⚠️ AuthStateNotifier: Logout error: $e');
      state = const AsyncValue.data(null);
      print('✅ AuthStateNotifier: State reset despite error');
    }
  }

  /// ✅ FINAL FIX: Get access token from SecureStorageService
  /// This matches EXACTLY how your login code saves the token
  Future<String?> getAccessToken() async {
    try {
      debugPrint(
        '🔍 [AuthProvider] Getting access token from secure storage...',
      );

      // Use the same SecureStorageService that login uses!
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

  /// Update user profile picture
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

  /// Update entire user object
  void updateUser(UserModel updatedUser) {
    state = AsyncValue.data(updatedUser);
    print('✅ Auth Provider: User data updated');
  }

  /// Remove profile picture
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
      final authApiService = ref.watch(authApiServiceProvider);
      return AuthStateNotifier(authApiService);
    });
