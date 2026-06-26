import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/event.dart';

Event _event({
  EventRecordType recordType = EventRecordType.time,
  EventScoreDirection? scoreDirection,
}) {
  return Event(
    id: 'e',
    userId: 'u',
    name: 'n',
    recordType: recordType,
    scoreDirection: scoreDirection,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('scoreDirection未設定はrecordTypeから導出（旧種目の移行）', () {
    expect(
      _event(recordType: EventRecordType.time).effectiveScoreDirection,
      EventScoreDirection.lower,
    );
    expect(
      _event(recordType: EventRecordType.distance).effectiveScoreDirection,
      EventScoreDirection.higher,
    );
    expect(
      _event(recordType: EventRecordType.count).effectiveScoreDirection,
      EventScoreDirection.higher,
    );
  });

  test('明示設定があればrecordTypeに依らず優先する', () {
    final e = _event(
      recordType: EventRecordType.distance,
      scoreDirection: EventScoreDirection.none,
    );
    expect(e.effectiveScoreDirection, EventScoreDirection.none);
    expect(e.scoreLowerIsBetter, isNull);
  });

  test('scoreLowerIsBetter: lower=true / higher=false / none=null', () {
    expect(
      _event(scoreDirection: EventScoreDirection.lower).scoreLowerIsBetter,
      isTrue,
    );
    expect(
      _event(scoreDirection: EventScoreDirection.higher).scoreLowerIsBetter,
      isFalse,
    );
    expect(
      _event(scoreDirection: EventScoreDirection.none).scoreLowerIsBetter,
      isNull,
    );
  });

  test('toFirestoreは実効ベスト方向を書き出す（旧種目も次回保存で明示化）', () {
    expect(
      _event(recordType: EventRecordType.time).toFirestore()['scoreDirection'],
      'lower',
    );
    expect(
      _event(
        recordType: EventRecordType.distance,
      ).toFirestore()['scoreDirection'],
      'higher',
    );
  });
}
