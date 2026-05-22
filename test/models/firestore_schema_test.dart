import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

void main() {
  test('Firestore repositoryは英語collection名を使う', () {
    final athleteRepository = File(
      'lib/features/manage/data/firestore_athlete_repository.dart',
    ).readAsStringSync();
    final eventRepository = File(
      'lib/features/manage/data/firestore_event_repository.dart',
    ).readAsStringSync();
    final recordRepository = File(
      'lib/features/records/data/firestore_record_repository.dart',
    ).readAsStringSync();

    expect(athleteRepository, contains("collection('athletes')"));
    expect(eventRepository, contains("collection('events')"));
    expect(recordRepository, contains("collection('records')"));
    expect(athleteRepository, isNot(contains("collection('選手')")));
    expect(eventRepository, isNot(contains("collection('種目')")));
    expect(recordRepository, isNot(contains("collection('記録')")));
  });

  test('選手はusers/{uid}/選手配下のRulesに合う形でFirestoreへ保存する', () {
    final now = DateTime(2026, 5, 22, 10);
    final athlete = Athlete(
      id: 'athlete-1',
      userId: 'user-1',
      name: '山田太郎',
      createdAt: now,
      updatedAt: now,
    );

    final data = athlete.toFirestore();

    expect(data.keys, unorderedEquals(['name', 'createdAt', 'updatedAt']));
    expect(data['name'], '山田太郎');
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
  });

  test('種目はusers/{uid}/種目配下のRulesに合う形でFirestoreへ保存する', () {
    final now = DateTime(2026, 5, 22, 10);
    final event = Event(
      id: 'event-1',
      userId: 'user-1',
      name: '100m',
      createdAt: now,
      updatedAt: now,
    );

    final data = event.toFirestore();

    expect(
      data.keys,
      unorderedEquals(['name', 'unit', 'sortOrder', 'createdAt', 'updatedAt']),
    );
    expect(data['name'], '100m');
    expect(data['unit'], '秒');
    expect(data['sortOrder'], 0);
  });

  test('記録は日付・選手・種目を参照しsnapshotを持つ形でFirestoreへ保存する', () {
    final now = DateTime(2026, 5, 22, 10);
    final record = MeasurementRecord(
      id: 'record-1',
      userId: 'user-1',
      athleteId: 'athlete-1',
      eventId: 'event-1',
      athleteName: '山田太郎',
      eventType: '100m',
      startMs: 1000,
      endMs: 2234,
      durationMs: 1234,
      recordValue: 1.23,
      recordUnit: '秒',
      measuredAt: now,
      memo: '追い風',
      videoRef: '/tmp/video.mp4',
      fps: 60,
      createdAt: now,
      updatedAt: now,
    );

    final data = record.toFirestore();

    expect(data['athleteId'], 'athlete-1');
    expect(data['eventId'], 'event-1');
    expect(data['recordedAt'], isA<Timestamp>());
    expect(data['value'], 1.23);
    expect(data['unit'], '秒');
    expect(data['athleteNameSnapshot'], '山田太郎');
    expect(data['eventNameSnapshot'], '100m');
    expect(data['eventUnitSnapshot'], '秒');
    expect(data['note'], '追い風');
    expect(data['startMs'], 1000);
    expect(data['endMs'], 2234);
    expect(data['durationMs'], 1234);
    expect(data['videoRef'], '/tmp/video.mp4');
    expect(data['fps'], 60);
    expect(data, isNot(contains('id')));
    expect(data, isNot(contains('userId')));
    expect(data, isNot(contains('measuredAt')));
    expect(data, isNot(contains('athleteName')));
    expect(data, isNot(contains('eventType')));
    expect(data, isNot(contains('memo')));
  });
}
