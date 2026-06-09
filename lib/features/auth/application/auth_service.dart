import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth;

  factory AuthService.create() {
    try {
      return AuthService(auth: FirebaseAuth.instance);
    } catch (_) {
      return AuthService(auth: null);
    }
  }

  final FirebaseAuth? _auth;

  Stream<User?> authStateChanges() {
    final auth = _auth;
    if (auth == null) {
      return Stream<User?>.value(null);
    }
    return auth.authStateChanges();
  }

  Future<String?> ensureAnonymousSignIn() async {
    final auth = _auth;
    if (auth == null) {
      return null;
    }

    final currentUser = auth.currentUser;
    if (currentUser != null) {
      return currentUser.uid;
    }

    try {
      final credential = await auth.signInAnonymously();
      return credential.user?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<User?> linkEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    var user = auth.currentUser;
    user ??= (await auth.signInAnonymously()).user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Current user is unavailable.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final linked = await user.linkWithCredential(credential);
    return linked.user;
  }

  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _requireAuth().signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  String messageForAuthError(Object error) {
    if (error is! FirebaseAuthException) {
      return '認証処理に失敗しました。時間をおいて再度お試しください。';
    }

    switch (error.code) {
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'このメールアドレスは登録済みです。ログインをお試しください。';
      case 'provider-already-linked':
        return 'このアカウントにはメールアドレスが登録済みです。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'weak-password':
        return 'パスワードは6文字以上で入力してください。';
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが違います。';
      case 'user-not-found':
        return 'このメールアドレスのアカウントが見つかりません。';
      case 'network-request-failed':
        return '通信に失敗しました。ネットワーク接続を確認してください。';
      case 'unavailable':
        return 'Firebase認証が利用できません。設定を確認してください。';
      default:
        return '認証処理に失敗しました。時間をおいて再度お試しください。';
    }
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseAuthException(
        code: 'unavailable',
        message: 'FirebaseAuth is unavailable.',
      );
    }
    return auth;
  }
}
