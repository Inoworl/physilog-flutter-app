import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/records/presentation/widgets/value_keypad_field.dart';
import 'package:physi_log/models/event.dart';

Future<void> _pump(
  WidgetTester tester, {
  required EventRecordType recordType,
  required String unit,
  required ValueChanged<double?> onChanged,
  double? initialValue,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueKeypadField(
          recordType: recordType,
          unit: unit,
          initialValue: initialValue,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

Future<void> _tapDigit(WidgetTester tester, String digit) async {
  await tester.tap(find.widgetWithText(OutlinedButton, digit));
  await tester.pump();
}

void main() {
  testWidgets('数値入力で値を返す', (tester) async {
    double? value;
    await _pump(
      tester,
      recordType: EventRecordType.distance,
      unit: 'cm',
      onChanged: (v) => value = v,
    );

    await _tapDigit(tester, '2');
    await _tapDigit(tester, '3');
    await _tapDigit(tester, '0');

    expect(value, 230);
  });

  testWidgets('回数は小数キーを出さない', (tester) async {
    double? value;
    await _pump(
      tester,
      recordType: EventRecordType.count,
      unit: '回',
      onChanged: (v) => value = v,
    );

    expect(find.widgetWithText(OutlinedButton, '.'), findsNothing);

    await _tapDigit(tester, '1');
    await _tapDigit(tester, '5');

    expect(value, 15);
  });

  testWidgets('タイムは分:秒トグルで総秒数を返す', (tester) async {
    double? value;
    await _pump(
      tester,
      recordType: EventRecordType.time,
      unit: '秒',
      onChanged: (v) => value = v,
    );

    await tester.tap(find.text('分:秒'));
    await tester.pumpAndSettle();

    await _tapDigit(tester, '1');
    await _tapDigit(tester, '0');
    await _tapDigit(tester, '2');

    // 1:02 = 62秒
    expect(value, 62);
  });
}
