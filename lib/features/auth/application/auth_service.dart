import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._(this._auth);

  final FirebaseAuth? _auth;

  factory AuthService.create() {
    try {
      return AuthService._(FirebaseAuth.instance);
    } catch (_) {
      return AuthService._(null);
    }
  }

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
}
