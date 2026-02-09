// // lib/core/providers/auth_provider.dart
// // ✅ MERGED VERSION: Combines Firebase auth with profile/role management features

// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart';
// import 'package:safety_app/core/storage/secure_storage_service.dart';
// import 'package:safety_app/models/role_info.dart';
// import 'package:safety_app/models/user_model.dart';
// import 'package:safety_app/services/auth_api_service.dart'; // Your service (if still needed)

// /// Provider for AuthApiService instance (your friend's - for Firebase)
// final authApiServiceProvider = Provider<AuthApiService>((ref) {
//   return AuthApiService();
// });

// /// Provider for AuthService instance (yours - if needed for other features)
// final authServiceProvider = Provider<AuthApiService>((ref) {
//   return AuthApiService();
// });

// /// Provider for current user (your friend's)
// final currentUserProvider = FutureProvider<UserModel?>((ref) async {
//   final authApiService = ref.watch(authApiServiceProvider);
//   return await authApiService.getCurrentUser();
// });

// /// Provider to check if user is logged in (your friend's)
// final isLoggedInProvider = FutureProvider<bool>((ref) async {
//   final authApiService = ref.watch(authApiServiceProvider);
//   return await authApiService.isLoggedIn();
// });

// /// State notifier for user authentication state
// /// ✅ MERGED: Uses AuthApiService for auth, adds profile/role management
// class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
//   final AuthApiService _authApiService; // Your friend's service for auth
//   final SecureStorageService _storage = SecureStorageService();

//   AuthStateNotifier(this._authApiService) : super(const AsyncValue.loading()) {
//     _loadUser();
//   }

//   /// Load current user (your friend's implementation)
//   Future<void> _loadUser() async {
//     state = const AsyncValue.loading();
//     try {
//       final user = await _authApiService.getCurrentUser();
//       state = AsyncValue.data(user);
//     } catch (e, stack) {
//       state = AsyncValue.error(e, stack);
//     }
//   }

//   /// Refresh user data from API
//   /// ✅ MERGED: Keeps your friend's error handling, adds your logging
//   Future<void> refreshUser() async {
//     print('🔄 AuthProvider: Starting user refresh...');

//     try {
//       final user = await _authApiService.fetchCurrentUser();

//       print('✅ AuthProvider: User refreshed - ${user.fullName}');
//       print('   Role: ${user.currentRole?.roleName ?? "No role"}');

//       state = AsyncValue.data(user);
//       print('✅ AuthProvider: State updated successfully');
//     } catch (e, stack) {
//       print('❌ AuthProvider: Error refreshing user - $e');
//       state = AsyncValue.error(e, stack);
//     }
//   }

//   /// Update user data directly (your feature)
//   /// ✅ Useful for immediate UI updates after profile edits
//   void updateUserData(UserModel user) {
//     print('✅ AuthProvider: Direct state update - ${user.fullName}');
//     state = AsyncValue.data(user);
//   }

//   /// Logout user (your friend's implementation - handles Firebase + storage)
//   Future<void> logout() async {
//     print('🔄 AuthStateNotifier: Starting logout...');

//     try {
//       // Call service logout (handles backend + storage + Firebase)
//       await _authApiService.logout();
//       // Reset state to null (no user)
//       state = const AsyncValue.data(null);
//       print('✅ AuthStateNotifier: Logout successful - User state cleared');
//     } catch (e, stack) {
//       // Log error but ALWAYS reset state
//       print('⚠️ AuthStateNotifier: Logout error: $e');
//       // CRITICAL: Reset state to null even on error
//       state = const AsyncValue.data(null);
//       print('✅ AuthStateNotifier: State reset despite error');
//       // Don't rethrow - we want logout to always succeed in the UI
//     }
//   }

//   /// ✅ Get access token from SecureStorageService (your feature)
//   /// This matches how your login code saves the token
//   Future<String?> getAccessToken() async {
//     try {
//       debugPrint(
//         '🔍 [AuthProvider] Getting access token from secure storage...',
//       );

//       final token = await _storage.getAccessToken();

//       if (token != null && token.isNotEmpty) {
//         debugPrint('✅ [AuthProvider] Found access token');
//         debugPrint('   Token preview: ${token.substring(0, 20)}...');
//         return token;
//       } else {
//         debugPrint('⚠️ [AuthProvider] No access token found in secure storage');
//         return null;
//       }
//     } catch (e) {
//       debugPrint('❌ [AuthProvider] Error getting access token: $e');
//       return null;
//     }
//   }

//   /// ✅ Update user profile picture (your feature)
//   void updateProfilePicture(String? newProfilePicture) {
//     final currentUser = state.value;
//     if (currentUser == null) {
//       print('⚠️ Cannot update profile picture: No user in state');
//       return;
//     }

//     final updatedUser = currentUser.copyWith(profilePicture: newProfilePicture);
//     state = AsyncValue.data(updatedUser);
//     print('✅ Auth Provider: Profile picture updated in state');
//   }

//   /// ✅ Update entire user object (your feature)
//   void updateUser(UserModel updatedUser) {
//     state = AsyncValue.data(updatedUser);
//     print('✅ Auth Provider: User data updated');
//   }

//   /// ✅ Remove profile picture (your feature)
//   void removeProfilePicture() {
//     updateProfilePicture(null);
//     print('✅ Auth Provider: Profile picture removed');
//   }

//   /// ✅ Update user roles (your feature)
//   void updateUserRoles(List<RoleInfo> newRoles) {
//     final currentUser = state.value;
//     if (currentUser == null) {
//       print('⚠️ Cannot update roles: No user in state');
//       return;
//     }

//     final updatedUser = currentUser.copyWith(
//       roles: newRoles,
//       updatedAt: DateTime.now(),
//     );

//     state = AsyncValue.data(updatedUser);
//     print('✅ Auth Provider: User roles updated');
//   }

//   /// Get current user synchronously (both versions had this)
//   UserModel? get currentUser {
//     return state.value;
//   }

//   /// Check if user is logged in (both versions had this)
//   bool get isLoggedIn {
//     return state.value != null;
//   }
// }

// /// Provider for auth state
// /// ✅ MERGED: Uses AuthApiService (your friend's) with extended functionality (yours)
// final authStateProvider =
//     StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
//       final authApiService = ref.watch(authApiServiceProvider);
//       return AuthStateNotifier(authApiService);
//     });
// lib/core/providers/auth_provider.dart
// ✅ MERGED VERSION: Combines Firebase auth with profile/role management features

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

  /// Load current user (your friend's implementation)
  Future<void> _loadUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authApiService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, stack) {
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
    } catch (e, stack) {
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