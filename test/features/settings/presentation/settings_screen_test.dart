import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('設定画面はアカウント・規約・ヘルプ・危険な操作を表示する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text('メールアドレス登録'), findsOneWidget);
    expect(find.text('規約・ポリシー'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('端末引き継ぎ'), findsOneWidget);
    expect(find.text('引き継ぎ方法を見る'), findsOneWidget);
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

  for (final destination in _helpDestinations) {
    testWidgets('${destination.label}は公開ページをWebViewルートで開く', (tester) async {
      await tester.pumpWidget(_settingsAppWithHelpRoute());

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
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

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

  return MaterialApp.router(routerConfig: router);
}

const _docsBaseUrl = 'https://keishimizu26629.github.io/PhysiLog';

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
