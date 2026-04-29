import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/firebase_options.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dev Firestoreへeventsとrecordsを作成して読取できる', (
    tester,
  ) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: AppFirebaseOptions.currentPlatform,
      );
    }

    final authService = AuthService.create();
    final userId = await authService.ensureAnonymousSignIn();

    expect(userId, isNotNull);
    expect(userId, isNotEmpty);
    expect(Firebase.app().options.projectId, 'physilog-dev');

    final firestore = FirebaseFirestore.instance;
    final testRunId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final eventId = 'it_event_$testRunId';
    final eventName = 'it_event_$testRunId';
    final legacyRecordId = 'it_record_legacy_$testRunId';
    final genericRecordId = 'it_record_generic_$testRunId';

    final eventRef = firestore
        .collection('users')
        .doc(userId)
        .collection('events')
        .doc(eventId);
    final legacyRecordRef = firestore
        .collection('users')
        .doc(userId)
        .collection('records')
        .doc(legacyRecordId);
    final genericRecordRef = firestore
        .collection('users')
        .doc(userId)
        .collection('records')
        .doc(genericRecordId);

    try {
      final event = Event(
        id: eventId,
        userId: userId!,
        name: eventName,
        createdAt: now,
        updatedAt: now,
      );

      await eventRef.set(event.toFirestore());

      final savedEvent = await eventRef.get();
      expect(savedEvent.exists, isTrue);
      expect(savedEvent.data()?['userId'], userId);
      expect(savedEvent.data()?['name'], eventName);

      final legacyRecord = MeasurementRecord(
        id: legacyRecordId,
        userId: userId,
        athleteName: 'integration-athlete',
        eventType: eventName,
        startMs: 0,
        endMs: 0,
        durationMs: 0,
        measuredAt: now,
        memo: 'integration-test',
        createdAt: now,
        updatedAt: now,
      );

      await legacyRecordRef.set(legacyRecord.toFirestore());

      final savedLegacyRecord = await legacyRecordRef.get();
      expect(savedLegacyRecord.exists, isTrue);
      expect(savedLegacyRecord.data()?['userId'], userId);
      expect(savedLegacyRecord.data()?['eventType'], eventName);
      expect(savedLegacyRecord.data()?['memo'], 'integration-test');

      final genericRecord = MeasurementRecord(
        id: genericRecordId,
        userId: userId,
        athleteName: 'integration-athlete',
        eventType: eventName,
        startMs: 0,
        endMs: 0,
        durationMs: 0,
        recordValue: 20,
        recordUnit: '回',
        measuredAt: now,
        memo: 'integration-test',
        createdAt: now,
        updatedAt: now,
      );

      await genericRecordRef.set(genericRecord.toFirestore());

      final savedGenericRecord = await genericRecordRef.get();
      expect(savedGenericRecord.exists, isTrue);
      expect(savedGenericRecord.data()?['userId'], userId);
      expect(savedGenericRecord.data()?['eventType'], eventName);
      expect(savedGenericRecord.data()?['recordValue'], 20);
      expect(savedGenericRecord.data()?['recordUnit'], '回');
      expect(savedGenericRecord.data()?['memo'], 'integration-test');
    } finally {
      await legacyRecordRef.delete().catchError((_) {});
      await genericRecordRef.delete().catchError((_) {});
      await eventRef.delete().catchError((_) {});
    }
  });
}
