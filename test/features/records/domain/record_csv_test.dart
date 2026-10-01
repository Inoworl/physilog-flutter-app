import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/records/domain/record_csv.dart';
import 'package:physi_log/models/record_set.dart';

import '../../billing/support/plan_fixture.dart';

void main() {
  test(
    'CSV exports BOM, Japanese column names, precise values and timezone',
    () {
      final document = RecordCsv.encode([fixtureRecord()]);
      final text = utf8.decode(document.bytes);
      expect(document.count, 1);
      expect(document.bytes.take(3), [0xef, 0xbb, 0xbf]);
      expect(text, contains('測定日時,選手,種目,記録値,単位,セット'));
      expect(text, contains('2026-01-01T00:00:00.000Z'));
      expect(text, contains('選手 1,種目 1,1.234,秒,'));
      expect(text, isNot(contains('fixture-owner')));
    },
  );

  test('CSV escapes delimiters and defuses formula-like names', () {
    final document = RecordCsv.encode([
      fixtureRecord().copyWith(
        athleteName: '  =SUM(1,2)',
        eventType: '種目,"名前"\n次の行',
        memo: 'private note',
        videoRef: 'private video',
      ),
    ]);
    final text = utf8.decode(document.bytes);
    expect(text, contains('"\'  =SUM(1,2)"'));
    expect(text, contains('"種目,""名前""\n次の行"'));
    expect(text, isNot(contains('private note')));
    expect(text, isNot(contains('private video')));
  });

  test(
    'Dangerous text prefixes and control characters are not executable cells',
    () {
      for (final name in [
        '=1+1',
        '+cmd',
        '-cmd',
        '@cmd',
        '\tcmd',
        '\rcmd',
        '\ncmd',
        '　=1+1',
      ]) {
        final text = utf8.decode(
          RecordCsv.encode([fixtureRecord().copyWith(athleteName: name)]).bytes,
        );
        expect(text, contains("'$name"), reason: name);
      }
    },
  );

  test('Weight sets retain weight and repetitions without exposing memos', () {
    final text = utf8.decode(
      RecordCsv.encode([
        fixtureRecord().copyWith(
          recordValue: 30,
          recordUnit: 'kg',
          sets: const [
            RecordSet(weight: 20, reps: 10),
            RecordSet(weight: 30, reps: 5),
          ],
        ),
      ]).bytes,
    );
    expect(text, contains('30.0,kg,20.0×10; 30.0×5'));
  });

  test('Empty CSV still has a header and zero rows', () {
    final document = RecordCsv.encode([]);
    expect(document.count, 0);
    expect(utf8.decode(document.bytes).split('\r\n'), hasLength(2));
  });
}
