import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';
import 'package:physi_log/features/records/application/record_csv_export_service.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/models/measurement_record.dart';

import '../../billing/support/plan_fixture.dart';

void main() {
  late PlanAccessState plan;
  late String? owner;
  late RecordCsvExportService service;
  late _ExportRecords repository;

  setUp(() {
    plan = fixturePlan(PlanTier.team);
    owner = 'fixture-owner';
    repository = _ExportRecords([
      fixtureRecord(
        id: 'first',
      ).copyWith(measuredAt: DateTime(2026, 1, 1, 0, 1)),
      fixtureRecord(
        id: 'second',
        athleteId: 'athlete-1',
        eventId: 'event-1',
      ).copyWith(athleteName: '選手 2', measuredAt: DateTime(2026, 1, 1, 23, 59)),
      fixtureRecord(id: 'tomorrow').copyWith(measuredAt: DateTime(2026, 1, 2)),
      fixtureRecord(
        id: 'foreign',
        owner: 'other-owner',
      ).copyWith(athleteName: '他人の名前'),
    ]);
    service = RecordCsvExportService(
      repository: repository,
      currentUserId: () => owner,
      currentPlan: () => plan,
    );
  });

  test('Free and personal/family cannot even fetch CSV data', () async {
    for (final tier in [PlanTier.free, PlanTier.personalFamily]) {
      plan = fixturePlan(tier);
      await expectLater(
        service.prepare(const CsvExportQuery()),
        throwsA(isA<PlanAccessException>()),
      );
    }
    expect(repository.reads, 0);
  });

  test(
    'Export includes both ends of a local calendar day and excludes other users',
    () async {
      final preview = await service.prepare(
        CsvExportQuery(
          dateFrom: DateTime(2026, 1, 1),
          dateTo: DateTime(2026, 1, 1),
        ),
      );
      expect(preview.document.count, 2);
      expect(utf8.decode(preview.document.bytes), isNot(contains('他人の名前')));
    },
  );

  test('Athlete/event filters use stable IDs, not display names', () async {
    final preview = await service.prepare(
      const CsvExportQuery(athleteId: 'athlete-1', eventId: 'event-1'),
    );
    expect(preview.document.count, 1);
    expect(utf8.decode(preview.document.bytes), contains('選手 2'));
  });

  test(
    'Repository bounds cover whole calendar days even when filters include a time',
    () async {
      await service.prepare(
        CsvExportQuery(
          dateFrom: DateTime(2026, 11, 1, 12),
          dateTo: DateTime(2026, 11, 1, 18),
        ),
      );
      final filter = repository.lastFilter!;
      expect(filter.dateFrom, DateTime(2026, 11, 1).toUtc());
      expect(
        filter.dateTo!.add(const Duration(days: 1)),
        DateTime(2026, 11, 2).toUtc(),
      );
    },
  );

  test(
    'Repository upper bound follows calendar midnight across daylight-saving changes',
    () async {
      await service.prepare(CsvExportQuery(dateTo: DateTime(2026, 11, 1)));
      expect(
        repository.lastFilter!.dateTo!.add(const Duration(days: 1)),
        DateTime(2026, 11, 2).toUtc(),
      );
    },
  );

  test('A reversed date range never starts a read', () async {
    await expectLater(
      service.prepare(
        CsvExportQuery(
          dateFrom: DateTime(2026, 2, 1),
          dateTo: DateTime(2026, 1, 1),
        ),
      ),
      throwsA(isA<PlanAccessException>()),
    );
    expect(repository.reads, 0);
  });

  test(
    'Expiry while loading and while the confirmation is open blocks export',
    () async {
      repository.onRead = () => plan = fixturePlan(PlanTier.free);
      await expectLater(
        service.prepare(const CsvExportQuery()),
        throwsA(isA<PlanAccessException>()),
      );
      repository.onRead = null;
      plan = fixturePlan(PlanTier.team);
      final preview = await service.prepare(const CsvExportQuery());
      plan = fixturePlan(PlanTier.free);
      var sent = false;
      await expectLater(
        service.share(preview, (document, authorize) async {
          sent = true;
        }),
        throwsA(isA<PlanAccessException>()),
      );
      expect(sent, isFalse);
    },
  );

  test('Identity switching cannot share a previous user preview', () async {
    final preview = await service.prepare(const CsvExportQuery());
    owner = 'other-owner';
    await expectLater(
      service.share(preview, (document, authorize) async {}),
      throwsA(isA<PlanAccessException>()),
    );
  });

  test('Native sharing reauthorizes after file preparation', () async {
    final preview = await service.prepare(const CsvExportQuery());
    await expectLater(
      service.share(preview, (document, authorize) async {
        owner = null;
        authorize();
      }),
      throwsA(isA<PlanAccessException>()),
    );
  });

  test('Paginated export reads every page without truncation', () async {
    repository.records = List.generate(
      251,
      (index) => fixtureRecord(id: 'record-$index'),
    );
    final preview = await service.prepare(const CsvExportQuery());
    expect(preview.document.count, 251);
    expect(repository.reads, 2);
  });

  test(
    'Oversized exports fail explicitly instead of silently truncating',
    () async {
      repository.records = List.generate(
        10001,
        (index) => fixtureRecord(id: 'record-$index'),
      );
      await expectLater(
        service.prepare(const CsvExportQuery()),
        throwsA(isA<PlanAccessException>()),
      );
    },
  );
}

class _ExportRecords extends InMemoryRecordRepository {
  _ExportRecords(this.records);
  List<MeasurementRecord> records;
  int reads = 0;
  RecordFilter? lastFilter;
  void Function()? onRead;

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    reads++;
    lastFilter = filter;
    onRead?.call();
    final offset = lastRecord == null
        ? 0
        : records.indexWhere((record) => record.id == lastRecord.id) + 1;
    return records.skip(offset).take(limit).toList();
  }
}
