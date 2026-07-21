import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/settings/presentation/settings_screen.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  for (final (tier, label) in [
    (PlanTier.free, 'Free'),
    (PlanTier.personalFamily, '個人・家族'),
    (PlanTier.team, 'Team'),
  ]) {
    testWidgets('設定画面は$labelプランをアカウント欄に表示する', (tester) async {
      await tester.pumpWidget(_settingsApp(planState: _readyPlanState(tier)));
      await tester.pumpAndSettle();

      expect(find.text('現在のプラン'), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      expect(find.text('プランを確認・変更'), findsOneWidget);
    });
  }

  testWidgets('設定画面はプラン取得中と取得失敗をFree表示にしない', (tester) async {
    await tester.pumpWidget(_settingsApp(planState: const PlanAccessLoading()));
    await tester.pumpAndSettle();
    expect(find.text('確認中...'), findsOneWidget);
    expect(find.text('Free'), findsNothing);

    await tester.pumpWidget(_settingsApp(planState: const PlanAccessError()));
    await tester.pumpAndSettle();
    expect(find.text('取得できませんでした'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
  });

  testWidgets('プランを確認・変更からsettingsPlanへ遷移する', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('プランを確認・変更'));
    await tester.pumpAndSettle();

    expect(find.text('プラン画面'), findsOneWidget);
  });

  testWidgets('設定画面は未登録メールと引き継ぎ導線を表示する', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('未登録'), findsOneWidget);
    expect(find.text('メールとパスワードを設定'), findsOneWidget);
    expect(find.text('この端末で使うログイン情報を作成'), findsOneWidget);
    expect(find.text('別端末から引き継ぐ'), findsOneWidget);
    expect(find.text('別端末で設定済みの情報を使用'), findsOneWidget);
    expect(find.text('この端末のデータを別端末でも使えるようにします。'), findsNothing);
    expect(find.text('登録済みのメールアドレスで以前の端末のデータを読み込みます。'), findsNothing);
    expect(find.text('規約・ポリシー'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('端末引き継ぎ'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('ヘルプ'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('ヘルプ'), findsOneWidget);
    expect(find.text('アプリの使い方'), findsOneWidget);
    expect(find.text('引き継ぎ方法を見る'), findsOneWidget);
    expect(find.text('アカウント削除方法'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('アカウント削除'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除'), findsOneWidget);
    expect(find.text('データ管理'), findsOneWidget);
    expect(find.text('危険な操作'), findsNothing);
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
    expect(find.text('ログアウト'), findsOneWidget);
    expect(find.text('メールとパスワードを設定'), findsNothing);
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
    final authService = _FakeAuthService();

    await tester.pumpWidget(_settingsApp(authService: authService));
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
    expect(authService.deletedAccount, isFalse);
  });

  testWidgets('アカウント削除は確認後に現在のFirebase Authユーザーを削除する', (tester) async {
    final authService = _FakeAuthService();

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('アカウント削除'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('アカウント削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    expect(authService.deletedAccount, isTrue);
    expect(find.text('アカウントを削除しました'), findsOneWidget);
  });

  testWidgets('ログアウトは確認後に匿名状態へ戻す', (tester) async {
    final authService = _FakeAuthService(
      user: _FakeUser(
        uid: 'email-uid',
        email: 'coach@example.com',
        isAnonymous: false,
      ),
    );

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();

    expect(find.text('ログアウトしますか？'), findsOneWidget);
    expect(authService.signedOutToAnonymous, isFalse);

    await tester.tap(find.text('ログアウト').last);
    await tester.pumpAndSettle();

    expect(authService.signedOutToAnonymous, isTrue);
    expect(find.text('ログアウトしました'), findsOneWidget);
    expect(find.text('未登録'), findsOneWidget);
    expect(find.text('メールとパスワードを設定'), findsOneWidget);
  });

  testWidgets('引き継ぎ設定は再入力パスワードを検証して匿名アカウントに認証情報をリンクする', (tester) async {
    final authService = _FakeAuthService(
      user: _FakeUser(uid: 'anonymous-uid', email: null, isAnonymous: true),
    );

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('メールとパスワードを設定'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountEmailAuthScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('この端末のデータを別端末でも使えるようにします。'), findsOneWidget);
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
    await tester.ensureVisible(find.text('設定する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定する'));
    await tester.pumpAndSettle();

    expect(find.text('パスワードが一致しません'), findsOneWidget);
    expect(authService.linkedEmail, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード再入力'),
      'password123',
    );
    await tester.ensureVisible(find.text('設定する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定する'));
    await tester.pumpAndSettle();

    expect(authService.linkedEmail, 'coach@example.com');
    expect(authService.linkedPassword, 'password123');
    expect(authService.linkedUserIdBeforeLink, 'anonymous-uid');
    expect(authService.signedInEmail, isNull);
    expect(find.byType(AccountEmailAuthScreen), findsNothing);
    expect(find.text('coach@example.com'), findsOneWidget);
    expect(find.text('メールアドレス変更'), findsOneWidget);
    expect(find.text('メールとパスワードを設定'), findsNothing);
    expect(find.text('引き継ぎ設定を保存しました'), findsOneWidget);
  });

  testWidgets('メール登録画面は匿名アカウントへのリンク成功を呼び出し元へ返す', (tester) async {
    final authService = _FakeAuthService(
      user: _FakeUser(uid: 'anonymous-uid', email: null, isAnonymous: true),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(authService)],
        child: const MaterialApp(home: _AccountAuthResultHost()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('登録画面を開く'));
    await tester.pumpAndSettle();
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
      'password123',
    );
    await tester.ensureVisible(find.text('設定する'));
    await tester.tap(find.text('設定する'));
    await tester.pumpAndSettle();

    expect(find.text('result=true'), findsOneWidget);
    expect(authService.linkedUserIdBeforeLink, 'anonymous-uid');
  });

  testWidgets('パスワード表示トグルは登録フォームの入力表示を切り替える', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('メールとパスワードを設定'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountEmailAuthScreen), findsOneWidget);
    final passwordField = find.widgetWithText(TextField, 'パスワード');
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.tap(find.byTooltip('パスワードを表示').first);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
    expect(find.byTooltip('パスワードを隠す'), findsWidgets);
  });

  testWidgets('別端末から引き継ぐは別ページで登録済みメールのデータを読み込む', (tester) async {
    final authService = _FakeAuthService(
      user: _FakeUser(
        uid: 'anonymous-transfer-uid',
        email: null,
        isAnonymous: true,
      ),
    );

    await tester.pumpWidget(_settingsApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('別端末から引き継ぐ'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountEmailAuthScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('登録済みのメールアドレスで以前の端末のデータを読み込みます。'), findsOneWidget);
    expect(find.text('引き継ぎ時に、この端末の未登録状態で作成したデータは削除されます。'), findsOneWidget);
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
    expect(
      authService.deletedAnonymousUserIdBeforeTransfer,
      'anonymous-transfer-uid',
    );
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

    expect(find.byType(AccountEmailAuthScreen), findsOneWidget);
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

    expect(find.byType(AccountEmailAuthScreen), findsOneWidget);
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

Widget _settingsApp({AuthService? authService, PlanAccessState? planState}) {
  return _settingsAppWithRoutes(authService: authService, planState: planState);
}

Widget _settingsAppWithHelpRoute() {
  return _settingsAppWithRoutes();
}

Widget _settingsAppWithRoutes({
  AuthService? authService,
  PlanAccessState? planState,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account/:mode',
        name: 'settingsAccountAuth',
        builder: (context, state) {
          final mode = accountEmailAuthModeFromRoute(
            state.pathParameters['mode'],
          );
          return AccountEmailAuthScreen(
            mode: mode ?? AccountEmailAuthMode.register,
          );
        },
      ),
      GoRoute(
        path: '/settings/plan',
        name: 'settingsPlan',
        builder: (context, state) {
          return const Scaffold(body: Center(child: Text('プラン画面')));
        },
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

  return ProviderScope(
    overrides: [
      if (authService != null)
        authServiceProvider.overrideWithValue(authService),
      if (planState != null)
        planAccessStateProvider.overrideWithValue(planState),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

PlanAccessReady _readyPlanState(PlanTier tier) {
  return PlanAccessReady(
    PlanAccessStatus(
      hasRevenueCatPersonalFamily: tier == PlanTier.personalFamily,
      hasRevenueCatTeam: tier == PlanTier.team,
      hasLegacyPersonalFamily: false,
      hasLegacyTeam: false,
      hasManualTeam: false,
    ),
  );
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
  _FakeAuthService({User? user})
    : _user = user,
      _controller = StreamController<User?>.broadcast(),
      super(auth: null);

  User? _user;
  final StreamController<User?> _controller;
  String? linkedEmail;
  String? linkedPassword;
  String? linkedUserIdBeforeLink;
  String? signedInEmail;
  String? signedInPassword;
  String? changedEmail;
  String? currentPasswordForEmailChange;
  String? changedPassword;
  String? currentPasswordForPasswordChange;
  bool deletedAccount = false;
  bool signedOutToAnonymous = false;
  String? deletedAnonymousUserIdBeforeTransfer;

  @override
  Stream<User?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<User?> linkEmailAndPassword({
    required String email,
    required String password,
  }) async {
    linkedUserIdBeforeLink = _user?.uid;
    linkedEmail = email;
    linkedPassword = password;
    _user = _FakeUser(
      uid: _user?.uid ?? 'uid',
      email: email,
      isAnonymous: false,
    );
    _controller.add(_user);
    return _user;
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
  Future<User?> transferToEmailAndPassword({
    required String email,
    required String password,
  }) async {
    deletedAnonymousUserIdBeforeTransfer = _user?.isAnonymous == true
        ? _user?.uid
        : null;
    signedInEmail = email;
    signedInPassword = password;
    _user = _FakeUser(uid: 'signed-in-uid', email: email, isAnonymous: false);
    _controller.add(_user);
    return _user;
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

  @override
  Future<void> deleteAccount() async {
    deletedAccount = true;
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> signOutAndContinueAnonymously() async {
    signedOutToAnonymous = true;
    _user = _FakeUser(uid: 'new-anonymous-uid', email: null, isAnonymous: true);
    _controller.add(_user);
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser({required this.email, required this.isAnonymous, this.uid = 'uid'});

  @override
  final String uid;

  @override
  final String? email;

  @override
  final bool isAnonymous;
}

class _AccountAuthResultHost extends StatefulWidget {
  const _AccountAuthResultHost();

  @override
  State<_AccountAuthResultHost> createState() => _AccountAuthResultHostState();
}

class _AccountAuthResultHostState extends State<_AccountAuthResultHost> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => const AccountEmailAuthScreen(
                    mode: AccountEmailAuthMode.register,
                  ),
                ),
              );
              if (!mounted) return;
              setState(() => _result = result);
            },
            child: const Text('登録画面を開く'),
          ),
          Text('result=$_result'),
        ],
      ),
    );
  }
}
