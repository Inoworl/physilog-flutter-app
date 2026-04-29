import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:physi_log/app/overrides/mock_app_overrides.dart';
import 'package:physi_log/app/physi_log_root.dart';

void main() {
  patrolTest('smoke flow covers home manage and manual record', ($) async {
    await $.pumpWidgetAndSettle(
      PhysiLogRoot(overrides: mockAppOverrides()),
    );

    expect(find.text('動画計測'), findsOneWidget);
    expect(find.text('手動記録'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
    expect(find.text('山田太郎'), findsOneWidget);
    expect(find.text('50m走'), findsOneWidget);

    await $.tester.tap(find.byIcon(Icons.people_outlined));
    await $.tester.pumpAndSettle();

    expect(find.text('選手'), findsOneWidget);
    expect(find.text('種目'), findsOneWidget);
    expect(find.text('山田太郎'), findsOneWidget);
    expect(find.text('50m走'), findsOneWidget);

    await $.tester.tap(find.byIcon(Icons.home_outlined));
    await $.tester.pumpAndSettle();

    await $.tester.tap(find.text('手動記録'));
    await $.tester.pumpAndSettle();

    await $.tester.enterText(find.byType(TextFormField).at(0), '20');
    await $.tester.enterText(find.byType(TextFormField).at(1), '回');
    await $.tester.tap(find.text('記録する'));
    await $.tester.pumpAndSettle();

    await $.tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await $.tester.pumpAndSettle();

    expect(find.textContaining('20回'), findsWidgets);
    expect(find.text('山田太郎'), findsWidgets);
    expect(find.text('50m走'), findsWidgets);
  });
}
