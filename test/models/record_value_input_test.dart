import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/record_value_input.dart';

void main() {
  group('RecordValueInput.parse', () {
    test('空文字は値と単位なしとして扱う', () {
      final input = RecordValueInput.parse('  ');

      expect(input, isA<EmptyRecordValueInput>());
      expect(input.recordValue, isNull);
      expect(input.recordUnit, isNull);
      expect(input.displayText, '');
    });

    test('全角数字と単位を半角化して値と単位に分解する', () {
      final input = RecordValueInput.parse('１２．３４ 秒');

      expect(input, isA<ValidRecordValueInput>());
      expect(input.recordValue, 12.34);
      expect(input.recordUnit, '秒');
      expect(input.displayText, '12.34秒');
    });

    test('単位なしの数値も有効として扱う', () {
      final input = RecordValueInput.parse('15');

      expect(input, isA<ValidRecordValueInput>());
      expect(input.recordValue, 15);
      expect(input.recordUnit, isNull);
      expect(input.displayText, '15');
    });

    test('数値を含まない非空文字列は無効として扱う', () {
      final input = RecordValueInput.parse('棄権');

      expect(input, isA<InvalidRecordValueInput>());
      expect(input.recordValue, isNull);
      expect(input.recordUnit, isNull);
      expect(input.validationMessage, '記録値には数値を含めてください');
    });

    test('0以下の値は無効として扱う', () {
      final input = RecordValueInput.parse('0秒');

      expect(input, isA<InvalidRecordValueInput>());
      expect(input.validationMessage, '記録値は0より大きい値を入力してください');
    });
  });
}
