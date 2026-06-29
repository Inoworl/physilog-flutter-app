import 'package:physi_log/features/force_update/domain/app_update_settings.dart';

abstract class AppUpdateSettingsRepository {
  Stream<AppUpdateSettings?> watchSettings();
}
