import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/auth_result.dart';

/// Scalable authentication service using Firebase Auth
/// Supports email/password authentication with extensibility for social logins
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StreamController<AuthStatus> _authStatusController =
      StreamController<AuthStatus>.broadcast();

  /// Stream of authentication status changes
  Stream<AuthStatus> get authStatusStream => _authStatusController.stream;

  /// Current authentication status
  AuthStatus _currentStatus = AuthStatus.initial();
  AuthStatus get currentStatus => _currentStatus;

  /// Current user if authenticated
  UserModel? get currentUser => _currentStatus.user;

  /// Check if user is currently authenticated
  bool get isAuthenticated => _currentStatus.state == AuthState.authenticated;

  /// Initialize the auth service and listen to auth state changes
  void initialize() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Handle authentication state changes from Firebase
  void _onAuthStateChanged(User? firebaseUser) {
    if (firebaseUser != null) {
      final user = UserModel.fromFirebaseUser(firebaseUser);
      _updateAuthStatus(AuthStatus.authenticated(user));
    } else {
      _updateAuthStatus(AuthStatus.unauthenticated());
    }
  }

  /// Update authentication status and notify listeners
  void _updateAuthStatus(AuthStatus status) {
    _currentStatus = status;
    _authStatusController.add(status);
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _updateAuthStatus(AuthStatus.loading());

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        final user = UserModel.fromFirebaseUser(credential.user!);
        _updateAuthStatus(AuthStatus.authenticated(user));
        return AuthResult.success(user);
      } else {
        final error = AuthResult.failure('ログインに失敗しました');
        _updateAuthStatus(AuthStatus.error(error.errorMessage!));
        return error;
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      final error = AuthResult.failure(errorMessage);
      _updateAuthStatus(AuthStatus.error(errorMessage));
      return error;
    } catch (e) {
      final errorMessage = '予期しないエラーが発生しました: ${e.toString()}';
      final error = AuthResult.failure(errorMessage);
      _updateAuthStatus(AuthStatus.error(errorMessage));
      return error;
    }
  }

  /// Create account with email and password
  Future<AuthResult> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _updateAuthStatus(AuthStatus.loading());

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // Update display name if provided
        if (displayName != null && displayName.isNotEmpty) {
          await credential.user!.updateDisplayName(displayName);
          await credential.user!.reload();
        }

        // Send email verification
        await credential.user!.sendEmailVerification();

        final user = UserModel.fromFirebaseUser(credential.user!);
        _updateAuthStatus(AuthStatus.authenticated(user));
        return AuthResult.success(user);
      } else {
        final error = AuthResult.failure('アカウント作成に失敗しました');
        _updateAuthStatus(AuthStatus.error(error.errorMessage!));
        return error;
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      final error = AuthResult.failure(errorMessage);
      _updateAuthStatus(AuthStatus.error(errorMessage));
      return error;
    } catch (e) {
      final errorMessage = '予期しないエラーが発生しました: ${e.toString()}';
      final error = AuthResult.failure(errorMessage);
      _updateAuthStatus(AuthStatus.error(errorMessage));
      return error;
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult(isSuccess: true);
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      return AuthResult.failure(errorMessage);
    } catch (e) {
      final errorMessage = '予期しないエラーが発生しました: ${e.toString()}';
      return AuthResult.failure(errorMessage);
    }
  }

  /// Send email verification
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return const AuthResult(isSuccess: true);
      } else {
        return AuthResult.failure('メール認証を送信できませんでした');
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      return AuthResult.failure(errorMessage);
    } catch (e) {
      final errorMessage = '予期しないエラーが発生しました: ${e.toString()}';
      return AuthResult.failure(errorMessage);
    }
  }

  /// Sign out current user
  Future<AuthResult> signOut() async {
    try {
      await _auth.signOut();
      _updateAuthStatus(AuthStatus.unauthenticated());
      return const AuthResult(isSuccess: true);
    } catch (e) {
      final errorMessage = 'ログアウトに失敗しました: ${e.toString()}';
      return AuthResult.failure(errorMessage);
    }
  }

  /// Delete current user account
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        _updateAuthStatus(AuthStatus.unauthenticated());
        return const AuthResult(isSuccess: true);
      } else {
        return AuthResult.failure('削除するアカウントが見つかりません');
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      return AuthResult.failure(errorMessage);
    } catch (e) {
      final errorMessage = '予期しないエラーが発生しました: ${e.toString()}';
      return AuthResult.failure(errorMessage);
    }
  }

  /// Update user profile
  Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        await user.reload();

        final updatedUser = UserModel.fromFirebaseUser(user);
        _updateAuthStatus(AuthStatus.authenticated(updatedUser));
        return AuthResult.success(updatedUser);
      } else {
        return AuthResult.failure('ユーザーが見つかりません');
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      return AuthResult.failure(errorMessage);
    } catch (e) {
      final errorMessage = '予期しないエラーが発生しました: ${e.toString()}';
      return AuthResult.failure(errorMessage);
    }
  }

  /// Change user password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);

        // Update password
        await user.updatePassword(newPassword);
        return const AuthResult(isSuccess: true);
      } else {
        return AuthResult.failure('ユーザーが見つかりません');
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      return AuthResult.failure(errorMessage);
    } catch (e) {
      final errorMessage = '予期しないエラーが発生しました: ${e.toString()}';
      return AuthResult.failure(errorMessage);
    }
  }

  /// Get user-friendly error message from Firebase Auth exception
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'このメールアドレスに登録されたアカウントが見つかりません';
      case 'wrong-password':
        return 'パスワードが正しくありません';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'weak-password':
        return 'パスワードが弱すぎます。より強力なパスワードを設定してください';
      case 'invalid-email':
        return '無効なメールアドレスです';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらく時間をおいてから再試行してください';
      case 'operation-not-allowed':
        return 'この操作は許可されていません';
      case 'invalid-credential':
        return '認証情報が無効です';
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは別の認証方法で既に登録されています';
      case 'requires-recent-login':
        return 'セキュリティのため、再度ログインしてください';
      default:
        return e.message ?? '認証エラーが発生しました';
    }
  }

  /// Dispose resources
  void dispose() {
    _authStatusController.close();
  }

  // Future social login methods (to be implemented)

  /// Sign in with Google (to be implemented)
  Future<AuthResult> signInWithGoogle() async {
    // TODO: Implement Google Sign-In
    return AuthResult.failure('Google ログインはまだ実装されていません');
  }

  /// Sign in with Apple (to be implemented)
  Future<AuthResult> signInWithApple() async {
    // TODO: Implement Apple Sign-In
    return AuthResult.failure('Apple ログインはまだ実装されていません');
  }
}
