import 'user_model.dart';

/// Result of authentication operations
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final UserModel? user;

  const AuthResult({required this.isSuccess, this.errorMessage, this.user});

  /// Create successful auth result
  factory AuthResult.success(UserModel user) {
    return AuthResult(isSuccess: true, user: user);
  }

  /// Create failed auth result
  factory AuthResult.failure(String errorMessage) {
    return AuthResult(isSuccess: false, errorMessage: errorMessage);
  }

  @override
  String toString() {
    return 'AuthResult(isSuccess: $isSuccess, errorMessage: $errorMessage, user: $user)';
  }
}

/// Authentication state for the app
enum AuthState { initial, loading, authenticated, unauthenticated, error }

/// Authentication status with user data
class AuthStatus {
  final AuthState state;
  final UserModel? user;
  final String? errorMessage;

  const AuthStatus({required this.state, this.user, this.errorMessage});

  /// Create initial auth status
  factory AuthStatus.initial() {
    return const AuthStatus(state: AuthState.initial);
  }

  /// Create loading auth status
  factory AuthStatus.loading() {
    return const AuthStatus(state: AuthState.loading);
  }

  /// Create authenticated status
  factory AuthStatus.authenticated(UserModel user) {
    return AuthStatus(state: AuthState.authenticated, user: user);
  }

  /// Create unauthenticated status
  factory AuthStatus.unauthenticated() {
    return const AuthStatus(state: AuthState.unauthenticated);
  }

  /// Create error status
  factory AuthStatus.error(String errorMessage) {
    return AuthStatus(state: AuthState.error, errorMessage: errorMessage);
  }

  @override
  String toString() {
    return 'AuthStatus(state: $state, user: $user, errorMessage: $errorMessage)';
  }
}
