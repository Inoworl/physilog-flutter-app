import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/measurement/presentation/widgets/session_keypad.dart';

void main() {
  testWidgets('キーパッドは渡された単位（kg など独自単位）を表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionKeypad(
              input: '60',
              unit: 'kg',
              allowDecimal: true,
              onKey: (_) {},
              onSave: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('kg'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
  });
}
