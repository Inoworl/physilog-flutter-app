import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:physi_log/features/force_update/data/firestore_app_update_settings_repository.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings_repository.dart';
import 'package:physi_log/features/force_update/domain/app_version.dart';

final forceUpdateFeatureEnabledProvider = Provider<bool>((ref) {
  const enabled = bool.fromEnvironment(
    'FORCE_UPDATE_ENABLED',
    defaultValue: true,
  );
  return enabled && Firebase.apps.isNotEmpty;
});

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final appUpdateSettingsRepositoryProvider =
    Provider<AppUpdateSettingsRepository>(
      (ref) => FirestoreAppUpdateSettingsRepository(),
    );

final appUpdateSettingsStreamProvider = StreamProvider<AppUpdateSettings?>(
  (ref) => ref.watch(appUpdateSettingsRepositoryProvider).watchSettings(),
);

final isForceUpdateRequiredProvider = Provider<bool>((ref) {
  if (!ref.watch(forceUpdateFeatureEnabledProvider)) {
    return false;
  }

  final settings = ref.watch(appUpdateSettingsStreamProvider).asData?.value;
  if (settings == null || !settings.forceUpdate) {
    return false;
  }

  final packageInfo = ref.watch(packageInfoProvider).asData?.value;
  if (packageInfo == null) {
    return false;
  }

  final minRequiredVersion = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => settings.iOSMinRequiredVersion,
    TargetPlatform.android => settings.androidMinRequiredVersion,
    _ => '',
  };

  return AppVersion.isCurrentVersionLessThanMinRequired(
    currentVersion: packageInfo.version,
    minRequiredVersion: minRequiredVersion,
  );
});
