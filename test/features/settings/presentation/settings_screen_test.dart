import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/settings/presentation/settings_screen.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  testWidgets('設定画面は未登録メールと引き継ぎ導線を表示する', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('未登録'), findsOneWidget);
    expect(find.text('メールアドレス登録'), findsOneWidget);
    expect(find.text('別端末から引き継ぐ'), findsOneWidget);
    expect(find.text('規約・ポリシー'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('端末引き継ぎ'), findsOneWidget);
    expect(find.text('引き継ぎ方法を見る'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('ヘルプ'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('ヘルプ'), findsOneWidget);
    expect(find.text('アプリの使い方'), findsOneWidget);
    expect(find.text('アカウント削除方法'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('アカウント削除'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除'), findsOneWidget);
  });

  testWidgets('登録済みユーザーはメールアドレスと変更導線を表示する', (tester) async {
    final authService = _FakeAuthService(
      user: _FakeUser(email: 'coach@example.com', isAnonymous: false),
    );

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('coach@example.com'), findsOneWidget);
    expect(find.text('メールアドレス変更'), findsOneWidget);
    expect(find.text('パスワード変更'), findsOneWidget);
    expect(find.text('メールアドレス登録'), findsNothing);
    expect(find.text('別端末から引き継ぐ'), findsNothing);
  });

  for (final destination in _helpDestinations) {
    testWidgets('${destination.label}は公開ページをWebViewルートで開く', (tester) async {
      await tester.pumpWidget(_settingsAppWithHelpRoute());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(destination.label),
        240,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(destination.label));
      await tester.pumpAndSettle();

      expect(find.text('title=${destination.title}'), findsOneWidget);
      expect(find.text('url=${destination.url}'), findsOneWidget);
    });
  }

  testWidgets('アカウント削除は確認ダイアログなしでは実行できない', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('アカウント削除'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('アカウント削除'));
    await tester.pumpAndSettle();

    expect(find.text('アカウントを削除しますか？'), findsOneWidget);
    expect(find.text('削除する'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
  });

  testWidgets('メールアドレス登録は再入力パスワードを検証して匿名アカウントに認証情報をリンクする', (tester) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('メールアドレス登録'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('この端末のデータを別端末へ引き継げるようにします。'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'パスワード再入力'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'メールアドレス'),
      'coach@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード再入力'),
      'different123',
    );
    await tester.ensureVisible(find.text('登録する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(find.text('パスワードが一致しません'), findsOneWidget);
    expect(authService.linkedEmail, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード再入力'),
      'password123',
    );
    await tester.ensureVisible(find.text('登録する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(authService.linkedEmail, 'coach@example.com');
    expect(authService.linkedPassword, 'password123');
    expect(authService.signedInEmail, isNull);
    expect(find.text('メールアドレスを登録しました'), findsOneWidget);
  });

  testWidgets('パスワード表示トグルは登録フォームの入力表示を切り替える', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('メールアドレス登録'));
    await tester.pumpAndSettle();

    final passwordField = find.widgetWithText(TextField, 'パスワード');
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.tap(find.byTooltip('パスワードを表示').first);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
    expect(find.byTooltip('パスワードを隠す'), findsWidgets);
  });

  testWidgets('別端末から引き継ぐは設定画面内で登録済みメールのデータを読み込む', (tester) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('別端末から引き継ぐ'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('登録済みのメールアドレスで以前の端末のデータを読み込みます。'), findsOneWidget);
    expect(find.text('ログイン後は、この端末の未登録状態で作成したデータは表示されなくなります。'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'パスワード再入力'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'メールアドレス'),
      'coach@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード'),
      'password123',
    );
    await tester.tap(find.text('データを引き継ぐ'));
    await tester.pumpAndSettle();

    expect(authService.signedInEmail, 'coach@example.com');
    expect(authService.signedInPassword, 'password123');
    expect(authService.linkedEmail, isNull);
    expect(find.text('データを引き継ぎました'), findsOneWidget);
  });

  testWidgets('メールアドレス変更は現在パスワードで再認証して確認メールを送る', (tester) async {
    final authService = _FakeAuthService(
      user: _FakeUser(email: 'coach@example.com', isAnonymous: false),
    );

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('メールアドレス変更'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '新しいメールアドレス'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '現在のパスワード'),
      'password123',
    );
    await tester.tap(find.text('確認メールを送る'));
    await tester.pumpAndSettle();

    expect(authService.changedEmail, 'new@example.com');
    expect(authService.currentPasswordForEmailChange, 'password123');
    expect(find.text('新しいメールアドレスへ確認メールを送信しました'), findsOneWidget);
  });

  testWidgets('パスワード変更は現在パスワードで再認証して新しいパスワードへ更新する', (tester) async {
    final authService = _FakeAuthService(
      user: _FakeUser(email: 'coach@example.com', isAnonymous: false),
    );

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('パスワード変更'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '現在のパスワード'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '新しいパスワード'),
      'newPassword123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '新しいパスワード再入力'),
      'newPassword123',
    );
    await tester.ensureVisible(find.text('パスワードを変更する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('パスワードを変更する'));
    await tester.pumpAndSettle();

    expect(authService.currentPasswordForPasswordChange, 'password123');
    expect(authService.changedPassword, 'newPassword123');
    expect(find.text('パスワードを変更しました'), findsOneWidget);
  });
}

Widget _settingsApp({AuthService? authService}) {
  return ProviderScope(
    overrides: [
      if (authService != null)
        authServiceProvider.overrideWithValue(authService),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

Widget _settingsAppWithHelpRoute() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/help',
        name: 'settingsHelp',
        builder: (context, state) {
          return Material(
            child: Column(
              children: [
                Text('title=${state.uri.queryParameters['title']}'),
                Text('url=${state.uri.queryParameters['url']}'),
              ],
            ),
          );
        },
      ),
    ],
  );

  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

const _docsBaseUrl = 'https://physilog-dev.web.app';

const _helpDestinations = [
  _HelpDestination(
    label: 'プライバシーポリシー',
    title: 'プライバシーポリシー',
    url: '$_docsBaseUrl/privacy.html',
  ),
  _HelpDestination(
    label: '利用規約',
    title: '利用規約',
    url: '$_docsBaseUrl/terms.html',
  ),
  _HelpDestination(
    label: '引き継ぎ方法を見る',
    title: '端末引き継ぎ',
    url: '$_docsBaseUrl/transfer.html',
  ),
  _HelpDestination(
    label: 'アプリの使い方',
    title: 'アプリの使い方',
    url: '$_docsBaseUrl/usage.html',
  ),
  _HelpDestination(
    label: 'アカウント削除方法',
    title: 'アカウント削除方法',
    url: '$_docsBaseUrl/account-deletion.html',
  ),
];

class _HelpDestination {
  const _HelpDestination({
    required this.label,
    required this.title,
    required this.url,
  });

  final String label;
  final String title;
  final String url;
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({User? user}) : _user = user, super(auth: null);

  final User? _user;
  String? linkedEmail;
  String? linkedPassword;
  String? signedInEmail;
  String? signedInPassword;
  String? changedEmail;
  String? currentPasswordForEmailChange;
  String? changedPassword;
  String? currentPasswordForPasswordChange;

  @override
  Stream<User?> authStateChanges() {
    return Stream<User?>.value(_user);
  }

  @override
  Future<User?> linkEmailAndPassword({
    required String email,
    required String password,
  }) async {
    linkedEmail = email;
    linkedPassword = password;
    return null;
  }

  @override
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signedInEmail = email;
    signedInPassword = password;
    return null;
  }

  @override
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    currentPasswordForEmailChange = currentPassword;
    changedEmail = newEmail;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    currentPasswordForPasswordChange = currentPassword;
    changedPassword = newPassword;
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser({required this.email, required this.isAnonymous});

  @override
  final String? email;

  @override
  final bool isAnonymous;
}
