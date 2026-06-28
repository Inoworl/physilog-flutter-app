import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/features/manage/data/local_event_repository.dart';
import 'package:physi_log/models/event.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('physilog_events_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    if (Hive.isBoxOpen('events')) {
      final box = Hive.box<Map>('events');
      await box.clear();
      await box.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('種目を追加すると一覧に反映され名前順で取得される', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    await notifier.addEvent('100m走');
    await notifier.addEvent('50m走');

    final loaded = notifier.state.maybeWhen(
      loaded: (events) => events,
      orElse: () => null,
    );

    expect(loaded, isNotNull);
    expect(loaded!, hasLength(2));
    expect(loaded.map((event) => event.name).toList(), ['100m走', '50m走']);
    expect(loaded.every((event) => event.userId == 'local-user'), isTrue);
  });

  test('種目を更新すると一覧に反映される', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent('50m');
    expect(created, isA<Event>());

    await notifier.updateEvent(eventId: created!.id, name: '50m走');

    final loaded = notifier.state.maybeWhen(
      loaded: (events) => events,
      orElse: () => const <Event>[],
    );

    expect(loaded, hasLength(1));
    expect(loaded.single.name, '50m走');
  });

  test('記録の型を指定せず追加するとタイム/動画計測/秒になる', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent('50m走');

    expect(created, isNotNull);
    expect(created!.recordType, EventRecordType.time);
    expect(created.measurementMethod, EventMeasurementMethod.video);
    expect(created.unit, '秒');
  });

  test('距離種目を追加すると既定の単位と計測方法（cm/手入力）が入る', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent(
      '立ち幅跳び',
      recordType: EventRecordType.distance,
    );

    expect(created!.recordType, EventRecordType.distance);
    expect(created.measurementMethod, EventMeasurementMethod.manual);
    expect(created.unit, 'cm');
  });

  test('計測方法を明示指定して追加できる', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent(
      'ストップウォッチ50m',
      recordType: EventRecordType.time,
      measurementMethod: EventMeasurementMethod.manual,
    );

    expect(created!.recordType, EventRecordType.time);
    expect(created.measurementMethod, EventMeasurementMethod.manual);
  });

  test('更新では計測方法は変えられるが記録の型は固定される', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent(
      '立ち幅跳び',
      recordType: EventRecordType.distance,
    );

    final updated = await notifier.updateEvent(
      eventId: created!.id,
      name: '立ち幅跳び（両足）',
      measurementMethod: EventMeasurementMethod.video,
    );

    expect(updated!.name, '立ち幅跳び（両足）');
    // 計測方法は更新される
    expect(updated.measurementMethod, EventMeasurementMethod.video);
    // 記録の型は作成時のまま固定（既存記録の単位を壊さないため）
    expect(updated.recordType, EventRecordType.distance);
  });

  test('単位とベスト方向を指定して追加できる（体重kg・順位なし）', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent(
      '体重',
      recordType: EventRecordType.distance,
      unit: 'kg',
      scoreDirection: EventScoreDirection.none,
    );

    expect(created!.unit, 'kg');
    expect(created.scoreDirection, EventScoreDirection.none);
    expect(created.scoreLowerIsBetter, isNull);
  });

  test('更新でベスト方向を変更できる（記録があっても可）', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent('体脂肪率', unit: '%');
    // 既定（タイム由来）は小さいほど良い。
    expect(created!.effectiveScoreDirection, EventScoreDirection.lower);

    final updated = await notifier.updateEvent(
      eventId: created.id,
      name: '体脂肪率',
      scoreDirection: EventScoreDirection.none,
    );

    expect(updated!.effectiveScoreDirection, EventScoreDirection.none);
  });

  test('種目を削除すると一覧から消える', () async {
    final repository = LocalEventRepository();
    final notifier = EventListNotifier(
      repository: repository,
      userId: 'local-user',
    );

    final created = await notifier.addEvent('50m走');
    expect(created, isA<Event>());

    await notifier.deleteEvent(created!.id);

    final loaded = notifier.state.maybeWhen(
      loaded: (events) => events,
      orElse: () => const <Event>[],
    );

    expect(loaded, isEmpty);
    expect(await repository.getEvents(userId: 'local-user'), isEmpty);
  });
}
