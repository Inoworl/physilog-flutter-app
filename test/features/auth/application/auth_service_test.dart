import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      EmailAuthProvider.credential(
        email: 'fallback@example.com',
        password: 'password123',
      ),
    );
  });

  test('linkEmailAndPasswordは現在の匿名ユーザーにメール認証情報をリンクする', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final credential = _MockUserCredential();
    when(() => auth.currentUser).thenReturn(user);
    when(() => credential.user).thenReturn(user);
    when(
      () => user.linkWithCredential(any()),
    ).thenAnswer((_) async => credential);

    final result = await AuthService(auth: auth).linkEmailAndPassword(
      email: ' coach@example.com ',
      password: 'password123',
    );

    expect(result, user);
    verify(() => user.linkWithCredential(any())).called(1);
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
