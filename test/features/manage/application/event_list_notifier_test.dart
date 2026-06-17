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
