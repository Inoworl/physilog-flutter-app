import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('設定画面はアカウント・引き継ぎ・ヘルプ・危険な操作を表示する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text('メールアドレス登録'), findsOneWidget);
    expect(find.text('端末引き継ぎ'), findsOneWidget);
    expect(find.text('引き継ぎ方法を見る'), findsOneWidget);
    expect(find.text('ヘルプ'), findsOneWidget);
    expect(find.text('アプリの使い方'), findsOneWidget);
    expect(find.text('アカウント削除'), findsOneWidget);
  });

  testWidgets('アカウント削除は確認ダイアログなしでは実行できない', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アカウント削除'));
    await tester.pumpAndSettle();

    expect(find.text('アカウントを削除しますか？'), findsOneWidget);
    expect(find.text('削除する'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
  });
}
