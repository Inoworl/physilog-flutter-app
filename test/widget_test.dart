import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:physi_log/app/app.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('physilog_widget_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('動画計測'), findsOneWidget);
    expect(find.text('手動記録'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);

    await tester.tap(find.text('記録'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('一覧'), findsOneWidget);
    expect(find.text('シート'), findsOneWidget);
  });
}
