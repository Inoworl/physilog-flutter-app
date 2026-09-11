import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/features/measurement/presentation/widgets/session_player_pick_sheet.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

Athlete _athlete(String id, String name) => Athlete(
  id: id,
  userId: 'user-1',
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Event _event() => Event(
  id: 'event-1',
  userId: 'user-1',
  name: '30m走',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

MeasurementRecord _record(String athleteId, String name, double value) =>
    MeasurementRecord(
      id: 'rec-$athleteId',
      userId: 'user-1',
      athleteId: athleteId,
      eventId: 'event-1',
      athleteName: name,
      eventType: '30m走',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      recordValue: value,
      recordUnit: '秒',
      measuredAt: DateTime(2026, 6, 12, 10),
      memo: '',
      createdAt: DateTime(2026, 6, 12, 10),
      updatedAt: DateTime(2026, 6, 12, 10),
    );

Widget _host({
  required List<Athlete> roster,
  required MeasurementSessionState session,
  required void Function(SessionPlayerPickResult?) onResult,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            onResult(
              await showSessionPlayerPickSheet(
                context: context,
                roster: roster,
                session: session,
                measuredValue: 7.05,
                unit: '秒',
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('残り人数を表示し、選手タップで選手IDを返す', (tester) async {
    final roster = [
      _athlete('a1', 'たろう'),
      _athlete('a2', 'じろう'),
      _athlete('a3', 'さぶろう'),
    ];
    final session = MeasurementSessionState(
      event: _event(),
      date: DateTime(2026, 6, 12),
      entries: {
        'a1': SessionEntry(record: _record('a1', 'たろう', 7.21), attemptCount: 1),
      },
      isRestoring: false,
    );

    SessionPlayerPickResult? result;
    await tester.pumpWidget(
      _host(roster: roster, session: session, onResult: (r) => result = r),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 1人計測済み → 残り2人
    expect(find.textContaining('残り 2人'), findsOneWidget);
    expect(find.text('じろう'), findsOneWidget);

    await tester.tap(find.text('じろう'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.discard, isFalse);
    expect(result!.athleteId, 'a2');
  });

  testWidgets('「破棄して次へ」は discard を返す', (tester) async {
    final roster = [_athlete('a1', 'たろう')];
    final session = MeasurementSessionState(
      event: _event(),
      date: DateTime(2026, 6, 12),
      isRestoring: false,
    );

    SessionPlayerPickResult? result;
    await tester.pumpWidget(
      _host(roster: roster, session: session, onResult: (r) => result = r),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('この計測を破棄して次へ'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.discard, isTrue);
    expect(result!.athleteId, isNull);
  });
}
