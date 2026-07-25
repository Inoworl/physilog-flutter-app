import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:physi_log/features/billing/data/hive_pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDirectory = await Directory.systemTemp.createTemp(
      'physilog_pending_subscription_change_test_',
    );
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    if (Hive.isBoxOpen(HivePendingSubscriptionChangeRepository.boxName)) {
      final box = Hive.box<Map>(HivePendingSubscriptionChangeRepository.boxName);
      await box.clear();
      await box.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('UIDごとに変更予約を保存・復元・削除できる', () async {
    final repository = HivePendingSubscriptionChangeRepository();
    final change = PendingSubscriptionChange(
      previousProductId: 'personal_monthly',
      targetProductId: 'team_yearly',
      createdAt: DateTime.utc(2026, 7, 22, 12),
    );

    await repository.save(userId: 'user-1', change: change);

    expect(await repository.get(userId: 'user-1'), change);
    expect(await repository.get(userId: 'user-2'), isNull);

    await repository.delete(userId: 'user-1');

    expect(await repository.get(userId: 'user-1'), isNull);
  });
}
