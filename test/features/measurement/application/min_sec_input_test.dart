import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/measurement/application/min_sec_input.dart';

void main() {
  group('MinSecInput.format', () {
    test('右詰めで m:ss にする', () {
      expect(MinSecInput.format(''), '');
      expect(MinSecInput.format('7'), '0:07');
      expect(MinSecInput.format('18'), '0:18');
      expect(MinSecInput.format('518'), '5:18');
      expect(MinSecInput.format('1230'), '12:30');
    });
  });

  group('MinSecInput.toSeconds', () {
    test('mmss を総秒数にする', () {
      expect(MinSecInput.toSeconds('518'), 318); // 5分18秒
      expect(MinSecInput.toSeconds('7'), 7); // 0分7秒
      expect(MinSecInput.toSeconds('1230'), 750); // 12分30秒
    });

    test('空は null', () {
      expect(MinSecInput.toSeconds(''), isNull);
    });

    test('秒が60以上は不正（null）', () {
      expect(MinSecInput.toSeconds('160'), isNull); // 1分60秒は不正
      expect(MinSecInput.toSeconds('99'), isNull); // 0分99秒は不正
    });
  });
}
