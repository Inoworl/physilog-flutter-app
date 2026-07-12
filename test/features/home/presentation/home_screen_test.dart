import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/home/presentation/home_screen.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/features/records/presentation/records_tab_screen.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

class _FakeAthleteRepository implements AthleteRepository {
  _FakeAthleteRepository(this._athletes);

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
  _FakeRecordRepository([List<MeasurementRecord>? records])
    : _records = [...?records];

  final List<MeasurementRecord> _records;

  @override
  Future<void> deleteRecord({
    required String userId,
    required String id,
  }) async {
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) async {
    try {
      return _records.firstWhere((record) => record.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    return _records.where((record) => record.userId == userId).toList();
  }

  @override
  Future<List<MeasurementRecord>> getAllRecords({
    required String userId,
  }) async {
    return _records.where((record) => record.userId == userId).toList();
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    _records.add(record);
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      _records[index] = record;
    }
  }
}

void main() {
  testWidgets('Homeは選手一覧を表示し手入力で記録追加を開ける', (tester) async {
    final athletes = [
      Athlete(
        id: 'athlete-1',
        userId: 'test-user',
        name: '田中太郎',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Athlete(
        id: 'athlete-2',
        userId: 'test-user',
        name: '佐藤花子',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('test-user'),
          athleteRepositoryProvider.overrideWithValue(
            _FakeAthleteRepository(athletes),
          ),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('選手一覧'), findsOneWidget);
    expect(find.text('田中太郎'), findsOneWidget);
    expect(find.text('佐藤花子'), findsOneWidget);
    expect(find.text('最新の記録'), findsNothing);
    expect(find.text('総記録'), findsNothing);

    expect(find.text('動画から計測を開始'), findsOneWidget);
    expect(find.text('手入力で追加'), findsOneWidget);
    expect(find.byTooltip('設定'), findsOneWidget);

    await tester.tap(find.text('手入力で追加'));
    await tester.pumpAndSettle();

    expect(find.text('手動記録'), findsOneWidget);
  });

  testWidgets('Homeの設定ボタンから設定画面へ遷移できる', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'settings',
              name: 'settings',
              builder: (context, state) => const Scaffold(body: Text('設定画面')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('test-user'),
          athleteRepositoryProvider.overrideWithValue(
            _FakeAthleteRepository(const []),
          ),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();

    expect(find.text('設定画面'), findsOneWidget);
  });

  testWidgets('Homeの動画開始ボタンから動画取り込み画面へ遷移できる', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/import',
          name: 'videoImport',
          builder: (context, state) => const Scaffold(body: Text('動画取り込み画面')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('test-user'),
          athleteRepositoryProvider.overrideWithValue(
            _FakeAthleteRepository(const []),
          ),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('動画から計測を開始'));
    await tester.pumpAndSettle();

    expect(find.text('動画取り込み画面'), findsOneWidget);
  });

  testWidgets('Homeの計測会開始ボタンはFreeプランではTeam限定メッセージを表示する', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/session',
          name: 'measurementSessionSetup',
          builder: (context, state) => const Scaffold(body: Text('計測会設定画面')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('test-user'),
          planCapabilitiesProvider.overrideWithValue(PlanCapabilities.free),
          athleteRepositoryProvider.overrideWithValue(
            _FakeAthleteRepository(const []),
          ),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('計測会を開始（チームでまとめて計測）'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Teamプラン限定機能です'), findsOneWidget);
    expect(find.text('計測会はTeamプランで利用できます。'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);
    expect(find.text('計測会設定画面'), findsNothing);
  });

  testWidgets('Homeの計測会開始ボタンはTeamプランなら計測会設定へ遷移する', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/session',
          name: 'measurementSessionSetup',
          builder: (context, state) => const Scaffold(body: Text('計測会設定画面')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('test-user'),
          planCapabilitiesProvider.overrideWithValue(PlanCapabilities.team),
          athleteRepositoryProvider.overrideWithValue(
            _FakeAthleteRepository(const []),
          ),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('計測会を開始（チームでまとめて計測）'));
    await tester.pumpAndSettle();

    expect(find.text('計測会設定画面'), findsOneWidget);
  });

  testWidgets('Homeの選手名をタップすると対象選手の記録シートへ遷移する', (tester) async {
    final athletes = [
      Athlete(
        id: 'athlete-1',
        userId: 'test-user',
        name: '田中太郎',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Athlete(
        id: 'athlete-2',
        userId: 'test-user',
        name: '佐藤花子',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'records',
              name: 'recordList',
              builder: (context, state) {
                final view = state.uri.queryParameters['view'];
                final initialViewMode = view == 'sheet'
                    ? RecordsViewMode.sheet
                    : RecordsViewMode.daily;

                return RecordsTabScreen(
                  initialViewMode: initialViewMode,
                  initialAthleteId: state.uri.queryParameters['athleteId'],
                );
              },
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('test-user'),
          athleteRepositoryProvider.overrideWithValue(
            _FakeAthleteRepository(athletes),
          ),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('佐藤花子'));
    await tester.pumpAndSettle();

    expect(find.text('記録'), findsOneWidget);
    expect(find.text('シート'), findsOneWidget);
    expect(find.text('佐藤花子の記録はまだありません'), findsOneWidget);
  });
}
