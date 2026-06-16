import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/auth/domain/user_metadata_repository.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      EmailAuthProvider.credential(
        email: 'fallback@example.com',
        password: 'password123',
      ),
    );
  });

  test('authStateChangesは同一UIDのメール紐付け更新も拾う', () {
    final auth = _MockFirebaseAuth();
    final stream = Stream<User?>.value(null);
    when(() => auth.userChanges()).thenAnswer((_) => stream);

    expect(AuthService(auth: auth).authStateChanges(), stream);
    verify(() => auth.userChanges()).called(1);
    verifyNever(() => auth.authStateChanges());
  });

  test('ensureAnonymousSignInは既存匿名ユーザーの作成日時メタデータを保証する', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final userMetadataRepository = _MockUserMetadataRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('anonymous-uid');
    when(
      () => userMetadataRepository.ensureAnonymousUserCreated(
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    final result = await AuthService(
      auth: auth,
      userMetadataRepository: userMetadataRepository,
    ).ensureAnonymousSignIn();

    expect(result, 'anonymous-uid');
    verify(
      () => userMetadataRepository.ensureAnonymousUserCreated(
        userId: 'anonymous-uid',
      ),
    ).called(1);
    verifyNever(() => auth.signInAnonymously());
  });

  test('ensureAnonymousSignInは匿名サインイン後に作成日時メタデータを作る', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final credential = _MockUserCredential();
    final userMetadataRepository = _MockUserMetadataRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => credential.user).thenReturn(user);
    when(() => user.uid).thenReturn('anonymous-uid');
    when(() => auth.signInAnonymously()).thenAnswer((_) async => credential);
    when(
      () => userMetadataRepository.ensureAnonymousUserCreated(
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    final result = await AuthService(
      auth: auth,
      userMetadataRepository: userMetadataRepository,
    ).ensureAnonymousSignIn();

    expect(result, 'anonymous-uid');
    verify(() => auth.signInAnonymously()).called(1);
    verify(
      () => userMetadataRepository.ensureAnonymousUserCreated(
        userId: 'anonymous-uid',
      ),
    ).called(1);
  });

  test('ensureAnonymousSignInはメタデータ保存に失敗してもUIDを返す', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final userMetadataRepository = _MockUserMetadataRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('anonymous-uid');
    when(
      () => userMetadataRepository.ensureAnonymousUserCreated(
        userId: any(named: 'userId'),
      ),
    ).thenThrow(Exception('Firestore is unavailable.'));

    final result = await AuthService(
      auth: auth,
      userMetadataRepository: userMetadataRepository,
    ).ensureAnonymousSignIn();

    expect(result, 'anonymous-uid');
  });

  test('linkEmailAndPasswordは現在の匿名ユーザーにメール認証情報をリンクする', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final credential = _MockUserCredential();
    final userMetadataRepository = _MockUserMetadataRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('anonymous-uid');
    when(() => credential.user).thenReturn(user);
    when(() => user.reload()).thenAnswer((_) async {});
    when(
      () => user.linkWithCredential(any()),
    ).thenAnswer((_) async => credential);
    when(
      () =>
          userMetadataRepository.markEmailLinked(userId: any(named: 'userId')),
    ).thenAnswer((_) async {});

    final result =
        await AuthService(
          auth: auth,
          userMetadataRepository: userMetadataRepository,
        ).linkEmailAndPassword(
          email: ' coach@example.com ',
          password: 'password123',
        );

    expect(result, user);
    expect(result?.uid, 'anonymous-uid');
    verify(() => user.linkWithCredential(any())).called(1);
    verify(() => user.reload()).called(1);
    verify(
      () => userMetadataRepository.markEmailLinked(userId: 'anonymous-uid'),
    ).called(1);
    verify(() => auth.currentUser).called(greaterThanOrEqualTo(2));
    verifyNever(
      () => auth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('signInWithEmailAndPasswordはメールログインを実行する', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final credential = _MockUserCredential();
    when(() => credential.user).thenReturn(user);
    when(
      () => auth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => credential);

    final result = await AuthService(auth: auth).signInWithEmailAndPassword(
      email: ' coach@example.com ',
      password: 'password123',
    );

    expect(result, user);
    verify(
      () => auth.signInWithEmailAndPassword(
        email: 'coach@example.com',
        password: 'password123',
      ),
    ).called(1);
  });

  test('changeEmailは現在パスワードで再認証して確認メール付きメール変更を実行する', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final credential = _MockUserCredential();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.email).thenReturn('old@example.com');
    when(
      () => user.reauthenticateWithCredential(any()),
    ).thenAnswer((_) async => credential);
    when(() => user.verifyBeforeUpdateEmail(any())).thenAnswer((_) async {});

    await AuthService(auth: auth).changeEmail(
      currentPassword: 'password123',
      newEmail: ' new@example.com ',
    );

    verify(() => user.reauthenticateWithCredential(any())).called(1);
    verify(() => user.verifyBeforeUpdateEmail('new@example.com')).called(1);
  });

  test('changePasswordは現在パスワードで再認証してパスワードを更新する', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final credential = _MockUserCredential();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.email).thenReturn('old@example.com');
    when(
      () => user.reauthenticateWithCredential(any()),
    ).thenAnswer((_) async => credential);
    when(() => user.updatePassword(any())).thenAnswer((_) async {});

    await AuthService(auth: auth).changePassword(
      currentPassword: 'password123',
      newPassword: 'newPassword123',
    );

    verify(() => user.reauthenticateWithCredential(any())).called(1);
    verify(() => user.updatePassword('newPassword123')).called(1);
  });

  test('messageForAuthErrorは登録済みメールをログイン誘導に変換する', () {
    final message = AuthService().messageForAuthError(
      FirebaseAuthException(code: 'email-already-in-use'),
    );

    expect(message, 'このメールアドレスは登録済みです。ログインをお試しください。');
  });
}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUserMetadataRepository extends Mock
    implements UserMetadataRepository {}
