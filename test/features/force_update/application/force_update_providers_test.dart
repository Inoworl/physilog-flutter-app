import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:physi_log/features/force_update/application/force_update_providers.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings_repository.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('isForceUpdateRequiredProvider', () {
    test('機能が無効な場合は更新設定を読まずfalseを返す', () {
      final container = ProviderContainer(
        overrides: [
          forceUpdateFeatureEnabledProvider.overrideWithValue(false),
          appUpdateSettingsRepositoryProvider.overrideWithValue(
            _ThrowingAppUpdateSettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(isForceUpdateRequiredProvider), isFalse);
    });

    test('Androidの現在バージョンが最低必須バージョン未満の場合はtrueを返す', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final container = _createContainer(
        currentVersion: '1.2.9',
        settings: _settings(
          forceUpdate: true,
          androidMinRequiredVersion: '1.3.0',
        ),
      );
      addTearDown(container.dispose);

      await container.read(appUpdateSettingsStreamProvider.future);
      await container.read(packageInfoProvider.future);

      expect(container.read(isForceUpdateRequiredProvider), isTrue);
    });

    test('appVersion設定が存在しない場合はfalseを返す', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final container = _createContainer(
        currentVersion: '1.0.0',
        settings: null,
      );
      addTearDown(container.dispose);

      await container.read(appUpdateSettingsStreamProvider.future);
      await container.read(packageInfoProvider.future);

      expect(container.read(isForceUpdateRequiredProvider), isFalse);
    });

    test('forceUpdateがfalseの場合は最低必須バージョン未満でもfalseを返す', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final container = _createContainer(
        currentVersion: '1.0.0',
        settings: _settings(forceUpdate: false, iOSMinRequiredVersion: '2.0.0'),
      );
      addTearDown(container.dispose);

      await container.read(appUpdateSettingsStreamProvider.future);
      await container.read(packageInfoProvider.future);

      expect(container.read(isForceUpdateRequiredProvider), isFalse);
    });
  });
}

ProviderContainer _createContainer({
  required String currentVersion,
  required AppUpdateSettings? settings,
}) {
  return ProviderContainer(
    overrides: [
      forceUpdateFeatureEnabledProvider.overrideWithValue(true),
      appUpdateSettingsRepositoryProvider.overrideWithValue(
        _FakeAppUpdateSettingsRepository(settings),
      ),
      packageInfoProvider.overrideWith(
        (ref) async => PackageInfo(
          appName: 'PhysiLog',
          packageName: 'com.inoworl.physilog',
          version: currentVersion,
          buildNumber: '1',
        ),
      ),
    ],
  );
}

AppUpdateSettings _settings({
  required bool forceUpdate,
  String iOSMinRequiredVersion = '',
  String androidMinRequiredVersion = '',
}) {
  return AppUpdateSettings(
    title: 'アプリの更新',
    content: '最新バージョンへ更新してください。',
    forceUpdate: forceUpdate,
    iOSLatestVersion: '',
    androidLatestVersion: '',
    iOSMinRequiredVersion: iOSMinRequiredVersion,
    androidMinRequiredVersion: androidMinRequiredVersion,
    appStoreUrl: 'https://apps.apple.com/app/example',
    googlePlayUrl: 'https://play.google.com/store/apps/details?id=example',
  );
}

class _FakeAppUpdateSettingsRepository implements AppUpdateSettingsRepository {
  const _FakeAppUpdateSettingsRepository(this.settings);

  final AppUpdateSettings? settings;

  @override
  Stream<AppUpdateSettings?> watchSettings() => Stream.value(settings);
}

class _ThrowingAppUpdateSettingsRepository
    implements AppUpdateSettingsRepository {
  @override
  Stream<AppUpdateSettings?> watchSettings() {
    throw StateError('settings should not be read');
  }
}
