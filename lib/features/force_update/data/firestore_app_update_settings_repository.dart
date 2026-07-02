import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings_repository.dart';

class FirestoreAppUpdateSettingsRepository
    implements AppUpdateSettingsRepository {
  FirestoreAppUpdateSettingsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const settingsCollection = 'settings';
  static const appVersionDocumentId = 'appVersion';

  final FirebaseFirestore _firestore;

  @override
  Stream<AppUpdateSettings?> watchSettings() {
    return _firestore
        .collection(settingsCollection)
        .doc(appVersionDocumentId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            return null;
          }
          return AppUpdateSettings.fromJson(data);
        });
  }
}
