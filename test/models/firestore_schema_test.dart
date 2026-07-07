import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/entitlement.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

void main() {
  test('Firebase deploy設定はFirestore Rulesをリポジトリ管理する', () {
    final firebase =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final firestore = firebase['firestore'] as Map<String, dynamic>;

    expect(firestore['rules'], 'firestore.rules');
    expect(File('firestore.rules').existsSync(), isTrue);
  });

  test('Firestore Rulesは本人のusers配下だけを許可しentitlement書き込みを拒否する', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /users/{userId}'));
    expect(rules, contains('request.auth.uid == userId'));
    expect(rules, contains('match /athletes/{athleteId}'));
    expect(rules, contains('match /events/{eventId}'));
    expect(rules, contains('match /records/{recordId}'));
    expect(rules, contains('match /entitlements/{entitlementId}'));
    expect(rules, contains('allow delete: if isOwner(userId);'));
    expect(rules, contains('allow create, update, delete: if false;'));
    expect(rules, contains('match /{document=**}'));
  });

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
    final entitlementRepository = File(
      'lib/features/entitlements/data/firestore_entitlement_repository.dart',
    ).readAsStringSync();

    expect(athleteRepository, contains("collection('athletes')"));
    expect(eventRepository, contains("collection('events')"));
    expect(recordRepository, contains("collection('records')"));
    expect(entitlementRepository, contains("collection('entitlements')"));
    expect(athleteRepository, isNot(contains("collection('選手')")));
    expect(eventRepository, isNot(contains("collection('種目')")));
    expect(recordRepository, isNot(contains("collection('記録')")));
    expect(entitlementRepository, isNot(contains("collection('権限')")));
  });

  test('選手はusers/{uid}/選手配下のRulesに合う形でFirestoreへ保存する', () {
    final now = DateTime(2026, 5, 22, 10);
    final athlete = Athlete(
      id: 'athlete-1',
      userId: 'user-1',
      name: '山田太郎',
      age: 12,
      createdAt: now,
      updatedAt: now,
    );

    final data = athlete.toFirestore();

    expect(
      data.keys,
      unorderedEquals(['name', 'age', 'deletedAt', 'createdAt', 'updatedAt']),
    );
    expect(data['name'], '山田太郎');
    expect(data['age'], 12);
    expect(data['deletedAt'], isNull);
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
      unorderedEquals([
        'name',
        'unit',
        'sortOrder',
        'deletedAt',
        'createdAt',
        'updatedAt',
      ]),
    );
    expect(data['name'], '100m');
    expect(data['unit'], '秒');
    expect(data['sortOrder'], 0);
    expect(data['deletedAt'], isNull);
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
    expect(data, isNot(contains('eventUnitSnapshot')));
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

  test('単位なしの手動記録はunitをnullとしてFirestoreへ保存する', () {
    final now = DateTime(2026, 5, 22, 10);
    final record = MeasurementRecord(
      id: 'record-1',
      userId: 'user-1',
      athleteName: '山田太郎',
      eventType: '腕立て伏せ',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      recordValue: 15,
      measuredAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final data = record.toFirestore();

    expect(data['value'], 15);
    expect(data['unit'], isNull);
    expect(data, isNot(contains('eventUnitSnapshot')));
  });

  test('entitlementはusers/{uid}/entitlements/currentへ保存する', () {
    final now = DateTime(2026, 5, 27, 10);
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.manualTeam,
      source: EntitlementSources.manual,
      status: EntitlementStatuses.active,
      grantedAt: now,
      updatedAt: now,
    );

    final data = entitlement.toFirestore();

    expect(
      data.keys,
      unorderedEquals(['plan', 'source', 'status', 'grantedAt', 'updatedAt']),
    );
    expect(data['plan'], EntitlementPlans.manualTeam);
    expect(data['source'], EntitlementSources.manual);
    expect(data['status'], EntitlementStatuses.active);
    expect(data['grantedAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
  });
}
