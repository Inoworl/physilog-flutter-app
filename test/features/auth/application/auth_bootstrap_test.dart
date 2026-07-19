import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/auth/application/auth_bootstrap.dart';

void main() {
  group('bootstrapFirebaseAuth', () {
    test('duplicate-appでも匿名認証を続行する', () async {
      var initializeCalls = 0;
      var anonymousSignInCalls = 0;

      await bootstrapFirebaseAuth(
        isFirebaseInitialized: () => false,
        initializeFirebase: () async {
          initializeCalls++;
          throw FirebaseException(plugin: 'core', code: 'duplicate-app');
        },
        ensureAnonymousSignIn: () async {
          anonymousSignInCalls++;
        },
      );

      expect(initializeCalls, 1);
      expect(anonymousSignInCalls, 1);
    });

    test('Firebaseが初期化済みなら再初期化せず匿名認証する', () async {
      var initializeCalls = 0;
      var anonymousSignInCalls = 0;

      await bootstrapFirebaseAuth(
        isFirebaseInitialized: () => true,
        initializeFirebase: () async {
          initializeCalls++;
        },
        ensureAnonymousSignIn: () async {
          anonymousSignInCalls++;
        },
      );

      expect(initializeCalls, 0);
      expect(anonymousSignInCalls, 1);
    });

    test('Firebase初期化失敗では匿名認証を実行せずエラーを通知する', () async {
      var anonymousSignInCalls = 0;
      Object? skippedError;
      final initializationError = StateError('configuration is missing');

      await bootstrapFirebaseAuth(
        isFirebaseInitialized: () => false,
        initializeFirebase: () async {
          throw initializationError;
        },
        ensureAnonymousSignIn: () async {
          anonymousSignInCalls++;
        },
        onInitializationSkipped: (error) => skippedError = error,
      );

      expect(anonymousSignInCalls, 0);
      expect(skippedError, same(initializationError));
    });
  });
}
