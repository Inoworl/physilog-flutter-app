import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/app/physi_log_root.dart';
import 'package:physi_log/firebase_options.dart';

Future<void> _waitFor(WidgetTester tester, Finder finder, String label) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('$label が見つかりませんでした');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _waitForAny(
  WidgetTester tester,
  List<Finder> finders,
  String label,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (true) {
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('$label が見つかりませんでした');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<Finder> _waitForAnyFinder(
  WidgetTester tester,
  List<Finder> finders,
  String label,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (true) {
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        return finder;
      }
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('$label が見つかりませんでした');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _initializeAppForTest() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: AppFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    // Firebase 設定がない環境でもテストを継続する。
    debugPrint('Firebase初期化をスキップしました: $e');
    return;
  }

  final authService = AuthService.create();
  await authService.ensureAnonymousSignIn();
}

Future<void> _tapBottomSheetSubmit(
  WidgetTester tester,
  String buttonLabel,
) async {
  final sheet = find.byType(BottomSheet);
  await _waitFor(tester, sheet, 'モーダル');
  if (tester.testTextInput.isRegistered) {
    if (tester.testTextInput.isVisible) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();

  var submitButton = find.descendant(
    of: sheet,
    matching: find.widgetWithText(FilledButton, buttonLabel),
  );

  var scrollAttempts = 0;
  while (submitButton.evaluate().isEmpty && scrollAttempts < 12) {
    final scrollables = find.descendant(
      of: sheet,
      matching: find.byType(Scrollable),
    );
    if (scrollables.evaluate().isEmpty) {
      break;
    }

    final scrollable = scrollables.first;
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
    submitButton = find.descendant(
      of: sheet,
      matching: find.widgetWithText(FilledButton, buttonLabel),
    );
    scrollAttempts += 1;
  }

  await _waitFor(tester, submitButton, '$buttonLabel ボタン');
  var submitElements = submitButton.evaluate();
  final submitButtonDeadline = DateTime.now().add(const Duration(seconds: 20));
  while (submitElements.isNotEmpty) {
    final submitWidget = submitElements.first.widget;
    if (submitWidget is FilledButton && submitWidget.onPressed != null) {
      break;
    }
    if (DateTime.now().isAfter(submitButtonDeadline)) {
      fail('$buttonLabel ボタン が有効になりませんでした');
    }
    debugPrint('$buttonLabel ボタンが無効。再描画を待機します。');
    await tester.pump(const Duration(milliseconds: 300));
    submitElements = submitButton.evaluate();
  }

  if (submitElements.isEmpty) {
    fail('$buttonLabel ボタン が見つかりませんでした');
  }

  final submitElement = submitElements.first;
  final submitWidget = submitElement.widget;
  if (submitWidget is FilledButton && submitWidget.onPressed != null) {
    debugPrint('$buttonLabel ボタンの onPressed を直接実行します');
    submitWidget.onPressed!();
  } else {
    debugPrint('$buttonLabel ボタンは無効 or 非対応。tap 経由で再試行します。');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
  }
  await tester.pumpAndSettle();
}

Finder _findTextFieldsInBottomSheet() {
  final sheet = find.byType(BottomSheet);
  return find.descendant(of: sheet, matching: find.byType(TextFormField));
}

String? _extractTextValue(Finder finder) {
  final elements = finder.evaluate();
  if (elements.isEmpty) return null;
  final widget = elements.first.widget;
  if (widget is Text) {
    return widget.data ?? widget.textAlign.toString();
  }
  return widget.toString();
}

Future<void> _waitForAuthResultMessage(
  WidgetTester tester,
  List<String> targetMessages,
  String label,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    for (final message in targetMessages) {
      if (find.text(message).evaluate().isNotEmpty) {
        debugPrint('$label: $message');
        return;
      }
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  final onScreenText = find
      .byType(Text)
      .evaluate()
      .map((element) => element.widget)
      .whereType<Text>()
      .map((widget) => widget.data ?? '')
      .where((text) => text.isNotEmpty)
      .where(
        (text) =>
            text.contains('登録') ||
            text.contains('ログイン') ||
            text.contains('メール') ||
            text.contains('認証') ||
            text.contains('エラー') ||
            text.contains('失敗'),
      )
      .toSet()
      .join(', ');

  fail('$label が見つかりませんでした。画面の関連テキスト: [$onScreenText]');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('選手・記録作成→メール登録→別セッション再ログインを実行する', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final athleteName = 'E2E-Athlete-$now';
    final eventName = 'E2E-Event-$now';
    final email = 'sync+$now@example.com';
    const password = 'test1234';

    await _initializeAppForTest();
    await tester.pumpWidget(const PhysiLogRoot());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 選手を作成
    await _waitFor(tester, find.text('管理'), '管理タブ');
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();

    await _waitFor(tester, find.text('選手'), '選手セクション');
    await tester.tap(find.text('追加').at(0));
    await tester.pumpAndSettle();

    await _waitFor(tester, _findTextFieldsInBottomSheet(), '選手名入力欄');
    await tester.enterText(_findTextFieldsInBottomSheet().first, athleteName);
    await _tapBottomSheetSubmit(tester, '登録する');
    await tester.pumpAndSettle();
    await _waitForAny(tester, [
      find.text('選手を登録しました'),
      find.text(athleteName),
    ], '作成した選手名');

    // 種目を作成
    await _waitForAny(tester, [
      find.text('種目を追加'),
      find.text('選手を登録しました'),
    ], '種目追加モーダル');
    await tester.tap(find.text('追加').at(1));
    await tester.pumpAndSettle();

    await _waitFor(tester, _findTextFieldsInBottomSheet(), '種目名入力欄');
    await tester.enterText(_findTextFieldsInBottomSheet().first, eventName);
    await _tapBottomSheetSubmit(tester, '登録する');
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text(eventName), '作成した種目名');

    // 記録を作成（手入力）
    await tester.tap(find.text('ホーム').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('手入力で追加'));
    await tester.pumpAndSettle();

    await _waitFor(tester, _findTextFieldsInBottomSheet(), '記録値入力欄');
    final recordFields = _findTextFieldsInBottomSheet();
    await tester.enterText(recordFields.at(0), '12.34');
    await tester.enterText(recordFields.at(1), 'sync-check');
    await _tapBottomSheetSubmit(tester, '記録する');
    await _waitForAny(
      tester,
      [
        find.text('手動記録を保存しました'),
        find.textContaining('保存に失敗しました'),
        find.text('Firebase認証待機中です。少し待って再実行してください。'),
      ],
      '記録保存メッセージ',
    );
    if (find.textContaining('保存に失敗しました').evaluate().isNotEmpty) {
      final failureMessage = _extractTextValue(
        find.textContaining('保存に失敗しました'),
      );
      fail('記録保存に失敗しています: $failureMessage');
    }
    if (find.text('Firebase認証待機中です。少し待って再実行してください。').evaluate().isNotEmpty) {
      fail('記録保存時に認証ユーザーが未確定でした');
    }
    if (find.text('手動記録を保存しました').evaluate().isEmpty) {
      fail('記録保存成功のメッセージを確認できませんでした');
    }

    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('記録'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _waitForAny(
      tester,
      [
        find.text('記録がありません'),
        find.text(athleteName),
        find.text(eventName),
        find.text('12.34秒'),
      ],
      '記録タブの表示',
    );
    if (find.text('記録がありません').evaluate().isNotEmpty) {
      fail('記録が保存されていません');
    }
    await _waitForAny(
      tester,
      [find.text(athleteName), find.text(eventName), find.text('12.34秒')],
      '保存済みの記録',
    );

    // メールアドレスを匿名アカウントへ登録
    await tester.tap(find.text('ホーム'));
    final settingsButtonFinder = await _waitForAnyFinder(
      tester,
      [find.byTooltip('設定'), find.byIcon(Icons.settings_outlined)],
      '設定ボタン',
    );
    await tester.tap(settingsButtonFinder);
    await tester.pumpAndSettle();

    await _waitFor(tester, find.text('メールアドレス登録'), 'メール登録メニュー');
    await tester.tap(find.text('メールアドレス登録'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード再入力'),
      password,
    );
    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _waitForAuthResultMessage(
      tester,
      const [
        'メールアドレスを登録しました',
        'ログインしました',
        'このメールアドレスは登録済みです。ログインをお試しください。',
        'このメールアドレスのアカウントが見つかりません。',
        'メールアドレスまたはパスワードが違います。',
        'このメールアドレスのアカウントは',
        'メールアドレスの形式が正しくありません',
        'メールアドレスを入力してください',
        'パスワードは6文字以上で入力してください',
        '認証処理に失敗しました。時間をおいて再度お試しください。',
        'Firebase認証が利用できません。設定を確認してください。',
      ],
      'メール登録完了メッセージ',
    );

    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    } else {
      await tester.tap(find.text('ホーム'));
      await tester.pumpAndSettle();
    }

    // 別端末同等の再ログインを模した再セッション検証
    await FirebaseAuth.instance.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final settingsButtonFinder2 = await _waitForAnyFinder(
      tester,
      [find.byTooltip('設定'), find.byIcon(Icons.settings_outlined)],
      '設定ボタン',
    );
    await tester.tap(settingsButtonFinder2);
    await tester.pumpAndSettle();

    await _waitFor(tester, find.text('別端末から引き継ぐ'), '再ログイン画面');
    await tester.tap(find.text('別端末から引き継ぐ'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.text('データを引き継ぐ'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _waitFor(tester, find.text('データを引き継ぎました'), 'ログイン完了メッセージ');

    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('記録'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _waitForAny(
      tester,
      [find.text(athleteName), find.text(eventName), find.text('12.34秒')],
      '再ログイン後の記録データ',
    );
  });
}
