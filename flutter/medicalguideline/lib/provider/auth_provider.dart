import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_result.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provider for AuthService singleton
final authServiceProvider = Provider<AuthService>((ref) {
  final authService = AuthService();
  authService.initialize();
  return authService;
});

/// Provider for authentication status stream
final authStatusProvider = StreamProvider<AuthStatus>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStatusStream;
});

/// Provider for current user
final currentUserProvider = Provider<UserModel?>((ref) {
  final authStatus = ref.watch(authStatusProvider);
  return authStatus.when(
    data: (status) => status.user,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for authentication state
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authStatus = ref.watch(authStatusProvider);
  return authStatus.when(
    data: (status) => status.state == AuthState.authenticated,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider for authentication loading state
final isAuthLoadingProvider = Provider<bool>((ref) {
  final authStatus = ref.watch(authStatusProvider);
  return authStatus.when(
    data: (status) => status.state == AuthState.loading,
    loading: () => true,
    error: (_, __) => false,
  );
});

/// Notifier for authentication operations
class AuthNotifier extends StateNotifier<AsyncValue<AuthResult?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  /// Sign in with email and password
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Create account with email and password
  Future<AuthResult?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AsyncValue.data(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.sendPasswordResetEmail(email);
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.sendEmailVerification();
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.signOut();
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    debugPrint('🔍 AuthNotifier.deleteAccount: 開始');
    state = const AsyncValue.loading();
    debugPrint('🔍 AuthNotifier.deleteAccount: 状態をloadingに設定');

    try {
      debugPrint(
        '🔍 AuthNotifier.deleteAccount: AuthService.deleteAccount呼び出し開始',
      );
      final result = await _authService.deleteAccount();
      debugPrint(
        '🔍 AuthNotifier.deleteAccount: AuthService.deleteAccount完了 = ${result.isSuccess}',
      );

      state = AsyncValue.data(result);
      debugPrint('🔍 AuthNotifier.deleteAccount: 状態をdataに設定');
    } catch (error, stackTrace) {
      debugPrint('🔍 AuthNotifier.deleteAccount: エラー発生 = $error');
      state = AsyncValue.error(error, stackTrace);
      debugPrint('🔍 AuthNotifier.deleteAccount: 状態をerrorに設定');
    }
    debugPrint('🔍 AuthNotifier.deleteAccount: 完了');
  }

  /// Update profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Sign in with Google (placeholder)
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.signInWithGoogle();
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Sign in with Apple (placeholder)
  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.signInWithApple();
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Clear the current operation result
  void clearResult() {
    state = const AsyncValue.data(null);
  }
}

/// Provider for AuthNotifier
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthResult?>>((ref) {
      final authService = ref.watch(authServiceProvider);
      return AuthNotifier(authService);
    });
