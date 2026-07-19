import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/features/manage/presentation/manage_screen.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

class _FakeAthleteRepository implements AthleteRepository {
  _FakeAthleteRepository([List<Athlete>? athletes])
    : _athletes = [...?athletes];

  final List<Athlete> _athletes;

  @override
  Future<void> deleteAthlete({
    required String userId,
    required String id,
  }) async {
    _athletes.removeWhere((athlete) => athlete.id == id);
  }

  @override
  Future<List<Athlete>> getAthletes({required String userId}) async {
    return _athletes.where((athlete) => athlete.userId == userId).toList();
  }

  @override
  Future<void> saveAthlete(Athlete athlete) async {
    _athletes.add(athlete);
  }

  @override
  Future<void> updateAthlete(Athlete athlete) async {
    final index = _athletes.indexWhere((item) => item.id == athlete.id);
    if (index >= 0) {
      _athletes[index] = athlete;
    }
  }
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository([List<Event>? events]) : _events = [...?events];

  final List<Event> _events;

  @override
  Future<void> deleteEvent({required String userId, required String id}) async {
    _events.removeWhere((event) => event.id == id);
  }

  @override
  Future<List<Event>> getEvents({
    required String userId,
    bool includeDeleted = false,
  }) async {
    return _events.where((event) => event.userId == userId).toList();
  }

  @override
  Future<void> saveEvent(Event event) async {
    _events.add(event);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final index = _events.indexWhere((item) => item.id == event.id);
    if (index >= 0) {
      _events[index] = event;
    }
  }
}

class _FakeRecordRepository implements RecordRepository {
  @override
  Future<void> deleteRecord({
    required String userId,
    required String id,
  }) async {}

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) async {
    return null;
  }

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    return [];
  }

  @override
  Future<List<MeasurementRecord>> getAllRecords({
    required String userId,
  }) async {
    return [];
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {}

  @override
  Future<void> updateRecord(MeasurementRecord record) async {}
}

void main() {
  testWidgets('Freeプランで選手上限に達している場合は選手追加フォームを開かない', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.free,
        athletes: [_athlete('athlete-1', '太郎')],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '追加').first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('現在のプラン上限に達しています'), findsOneWidget);
    expect(find.text('現在のプランでは選手は1人まで登録できます。'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
    expect(find.text('選手を追加'), findsNothing);
  });

  testWidgets('個人・家族プランで選手上限に達している場合は選手追加フォームを開かない', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.personalFamily,
        athletes: [for (var i = 1; i <= 5; i++) _athlete('athlete-$i', '選手$i')],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '追加').first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('現在のプラン上限に達しています'), findsOneWidget);
    expect(find.text('現在のプランでは選手は5人まで登録できます。'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
    expect(find.text('選手を追加'), findsNothing);
  });

  testWidgets('Freeプランで種目上限に達している場合は種目追加フォームを開かない', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.free,
        events: [
          _event('event-1', '50m走'),
          _event('event-2', '100m走'),
          _event('event-3', '立ち幅跳び'),
        ],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '追加').last);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('現在のプラン上限に達しています'), findsOneWidget);
    expect(find.text('現在のプランでは種目は3つまで登録できます。'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
    expect(find.text('種目を追加'), findsNothing);
  });

  testWidgets('個人・家族プランでは種目数が3つ以上でも種目追加フォームを開ける', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.personalFamily,
        events: [
          _event('event-1', '50m走'),
          _event('event-2', '100m走'),
          _event('event-3', '立ち幅跳び'),
        ],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '追加').last);
    await tester.pumpAndSettle();

    expect(find.text('種目を追加'), findsOneWidget);
    expect(find.text('現在のプランでは種目は3つまで登録できます。'), findsNothing);
  });

  testWidgets('Teamプランでは選手が多くても選手追加フォームを開ける', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.team,
        athletes: [for (var i = 1; i <= 6; i++) _athlete('athlete-$i', '選手$i')],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '追加').first);
    await tester.pumpAndSettle();

    expect(find.text('選手を追加'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Teamプランでは種目が多くても種目追加フォームを開ける', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.team,
        events: [for (var i = 1; i <= 4; i++) _event('event-$i', '種目$i')],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '追加').last);
    await tester.pumpAndSettle();

    expect(find.text('種目を追加'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Freeプランで上限到達済みでも既存選手は編集と削除を開ける', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.free,
        athletes: [_athlete('athlete-1', '太郎')],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('太郎'));
    await tester.pumpAndSettle();

    expect(find.text('選手を編集'), findsOneWidget);
    expect(find.text('この選手を削除'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Freeプランで上限到達済みでも既存種目は編集と削除を開ける', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.free,
        events: [
          _event('event-1', '50m走'),
          _event('event-2', '100m走'),
          _event('event-3', '立ち幅跳び'),
        ],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    expect(find.text('種目を編集'), findsOneWidget);
    expect(find.text('この種目を削除'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('プラン取得中は追加操作を無効化してFree上限を表示しない', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.free,
        planState: const PlanAccessLoading(),
      ),
    );

    await tester.pump();

    expect(find.text('プラン情報を確認中...'), findsOneWidget);
    final addButtons = tester.widgetList<TextButton>(
      find.widgetWithText(TextButton, '追加'),
    );
    expect(addButtons.every((button) => button.onPressed == null), isTrue);
    expect(find.text('現在のプラン上限に達しています'), findsNothing);
  });

  testWidgets('プラン取得失敗時は再読み込みを表示してFree上限を表示しない', (tester) async {
    await tester.pumpWidget(
      _buildManageScreen(
        capabilities: PlanCapabilities.free,
        planState: const PlanAccessError(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('プラン情報の取得に失敗しました'), findsOneWidget);
    expect(find.byTooltip('プラン情報を再読み込み'), findsOneWidget);
    final addButtons = tester.widgetList<TextButton>(
      find.widgetWithText(TextButton, '追加'),
    );
    expect(addButtons.every((button) => button.onPressed == null), isTrue);
    expect(find.text('現在のプラン上限に達しています'), findsNothing);
  });
}

Widget _buildManageScreen({
  required PlanCapabilities capabilities,
  PlanAccessState? planState,
  List<Athlete> athletes = const [],
  List<Event> events = const [],
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('test-user'),
      planAccessStateProvider.overrideWithValue(
        planState ?? _readyPlanState(capabilities),
      ),
      athleteRepositoryProvider.overrideWithValue(
        _FakeAthleteRepository(athletes),
      ),
      eventRepositoryProvider.overrideWithValue(_FakeEventRepository(events)),
      recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
    ],
    child: const MaterialApp(home: ManageScreen()),
  );
}

PlanAccessReady _readyPlanState(PlanCapabilities capabilities) {
  return PlanAccessReady(
    PlanAccessStatus(
      hasRevenueCatPersonalFamily:
          capabilities.maxAthleteCount ==
          PlanCapabilities.personalFamily.maxAthleteCount,
      hasRevenueCatTeam: capabilities.canUseMeasurementSessions,
      hasLegacyPersonalFamily: false,
      hasLegacyTeam: false,
      hasManualTeam: false,
    ),
  );
}

Athlete _athlete(String id, String name) {
  final now = DateTime(2026, 1, 1);
  return Athlete(
    id: id,
    userId: 'test-user',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Event _event(String id, String name) {
  final now = DateTime(2026, 1, 1);
  return Event(
    id: id,
    userId: 'test-user',
    name: name,
    unit: '秒',
    createdAt: now,
    updatedAt: now,
  );
}
