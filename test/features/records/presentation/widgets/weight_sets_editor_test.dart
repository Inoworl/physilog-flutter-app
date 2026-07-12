import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/records/presentation/widgets/weight_sets_editor.dart';
import 'package:physi_log/models/record_set.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<List<RecordSet>> onChanged,
    required ValueChanged<bool> onValidityChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeightSetsEditor(
            onChanged: onChanged,
            onValidityChanged: onValidityChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('重さ・回数とも入力した行は有効なセットとして返す', (tester) async {
    List<RecordSet>? lastSets;
    var lastInvalid = false;
    await pump(
      tester,
      onChanged: (sets) => lastSets = sets,
      onValidityChanged: (invalid) => lastInvalid = invalid,
    );

    await tester.enterText(find.widgetWithText(TextField, '重さ'), '60');
    await tester.enterText(find.widgetWithText(TextField, '回数'), '10');
    await tester.pump();

    expect(lastSets, [const RecordSet(weight: 60, reps: 10)]);
    expect(lastInvalid, isFalse);
  });

  testWidgets('片方だけ入力した行はセットに含めず、不正行ありと通知する', (tester) async {
    List<RecordSet>? lastSets;
    var lastInvalid = false;
    await pump(
      tester,
      onChanged: (sets) => lastSets = sets,
      onValidityChanged: (invalid) => lastInvalid = invalid,
    );

    // 重さだけ入力し、回数は空のまま。
    await tester.enterText(find.widgetWithText(TextField, '重さ'), '60');
    await tester.pump();

    expect(lastSets, isEmpty);
    expect(lastInvalid, isTrue);
  });

  testWidgets('セットを追加すると行が増え、削除ボタンは1行のみのとき無効', (tester) async {
    await pump(tester, onChanged: (_) {}, onValidityChanged: (_) {});

    expect(find.widgetWithText(TextField, '重さ'), findsOneWidget);
    final removeButton = find.widgetWithIcon(
      IconButton,
      Icons.remove_circle_outline,
    );
    expect(tester.widget<IconButton>(removeButton).onPressed, isNull);

    await tester.tap(find.text('セットを追加'));
    await tester.pump();

    expect(find.widgetWithText(TextField, '重さ'), findsNWidgets(2));
    expect(tester.widget<IconButton>(removeButton.first).onPressed, isNotNull);
  });
}
