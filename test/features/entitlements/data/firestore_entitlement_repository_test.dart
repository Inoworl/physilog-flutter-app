// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:physi_log/features/entitlements/data/firestore_entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';

class _Firestore extends Mock implements FirebaseFirestore {}

class _Collection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _Document extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _Snapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late FirestoreEntitlementRepository repository;
  late _Document current;
  late _Snapshot existing;
  late _Snapshot missing;
  late StreamController<DocumentSnapshot<Map<String, dynamic>>> updates;

  setUp(() {
    final firestore = _Firestore();
    final users = _Collection();
    final user = _Document();
    final entitlements = _Collection();
    current = _Document();
    existing = _Snapshot();
    missing = _Snapshot();
    updates = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('test-user')).thenReturn(user);
    when(() => user.collection('entitlements')).thenReturn(entitlements);
    when(() => entitlements.doc('current')).thenReturn(current);
    when(() => current.snapshots()).thenAnswer((_) => updates.stream);
    when(() => existing.exists).thenReturn(true);
    when(() => existing.id).thenReturn('current');
    when(() => existing.reference).thenReturn(current);
    when(() => current.parent).thenReturn(entitlements);
    when(() => entitlements.parent).thenReturn(user);
    when(() => user.id).thenReturn('test-user');
    when(() => existing.data()).thenReturn({
      'plan': EntitlementPlans.manualTeam,
      'source': EntitlementSources.manual,
      'status': EntitlementStatuses.active,
      'grantedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 11)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 11)),
    });
    when(() => missing.exists).thenReturn(false);
    repository = FirestoreEntitlementRepository(firestore: firestore);
  });

  tearDown(() => unawaited(updates.close()));

  test('既存パスの作成・変更・削除を同じ購読へ通知する', () async {
    final revoked = _Snapshot();
    when(() => revoked.exists).thenReturn(true);
    when(() => revoked.id).thenReturn('current');
    when(() => revoked.reference).thenReturn(current);
    when(
      () => revoked.data(),
    ).thenReturn({...existing.data()!, 'status': EntitlementStatuses.revoked});
    final results = expectLater(
      repository.watchCurrentEntitlement(userId: 'test-user'),
      emitsInOrder([
        isNull,
        isA<Entitlement>().having(
          (value) => value.hasManualTeamAccessAt(DateTime.utc(2026, 9, 11)),
          'active',
          isTrue,
        ),
        isA<Entitlement>().having(
          (value) => value.status,
          'status',
          EntitlementStatuses.revoked,
        ),
        isNull,
        emitsDone,
      ]),
    );
    updates
      ..add(missing)
      ..add(existing)
      ..add(revoked)
      ..add(missing);
    await updates.close();
    await results;
    verify(() => current.snapshots()).called(1);
    verifyNever(() => current.get());
  });

  test('購読失敗をnullへ変換せず通知する', () async {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final result = expectLater(
      repository.watchCurrentEntitlement(userId: 'test-user'),
      emitsError(same(error)),
    );
    updates.addError(error);
    await result;
  });

  test('購読解除でFirestoreの監視を停止する', () async {
    final subscription = repository
        .watchCurrentEntitlement(userId: 'test-user')
        .listen((_) {});
    expect(updates.hasListener, isTrue);
    await subscription.cancel();
    expect(updates.hasListener, isFalse);
  });
}
