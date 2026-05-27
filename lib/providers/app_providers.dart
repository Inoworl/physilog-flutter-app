import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/entitlements/data/firestore_entitlement_repository.dart';
import 'package:physi_log/features/entitlements/data/no_entitlement_repository.dart';
import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/features/manage/data/firestore_athlete_repository.dart';
import 'package:physi_log/features/manage/data/firestore_event_repository.dart';
import 'package:physi_log/features/manage/data/local_athlete_repository.dart';
import 'package:physi_log/features/manage/data/local_event_repository.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/features/records/data/firestore_record_repository.dart';
import 'package:physi_log/features/records/data/local_record_repository.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/entitlement.dart';

enum DataStoreMode { local, firestore }

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.create();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

final dataStoreModeProvider = Provider<DataStoreMode>((ref) {
  const mode = String.fromEnvironment('DATA_STORE_MODE', defaultValue: 'local');
  if (mode == 'firestore') {
    return DataStoreMode.firestore;
  }
  return DataStoreMode.local;
});

final currentUserIdProvider = Provider<String?>((ref) {
  final mode = ref.watch(dataStoreModeProvider);
  final authState = ref.watch(authStateProvider);

  if (mode == DataStoreMode.firestore) {
    return authState.maybeWhen(data: (user) => user?.uid, orElse: () => null);
  }

  return authState.maybeWhen(
    data: (user) => user?.uid ?? 'local-user',
    orElse: () => 'local-user',
  );
});

final useFirestoreProvider = Provider<bool>((ref) {
  final mode = ref.watch(dataStoreModeProvider);
  final userId = ref.watch(currentUserIdProvider);
  return mode == DataStoreMode.firestore &&
      userId != null &&
      userId != 'local-user';
});

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  if (ref.watch(useFirestoreProvider)) {
    return FirestoreRecordRepository();
  }
  return LocalRecordRepository();
});

final athleteRepositoryProvider = Provider<AthleteRepository>((ref) {
  if (ref.watch(useFirestoreProvider)) {
    return FirestoreAthleteRepository();
  }
  return LocalAthleteRepository();
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  if (ref.watch(useFirestoreProvider)) {
    return FirestoreEventRepository();
  }
  return LocalEventRepository();
});

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  if (ref.watch(useFirestoreProvider)) {
    return FirestoreEntitlementRepository();
  }
  return const NoEntitlementRepository();
});

final currentEntitlementProvider = FutureProvider<Entitlement?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return null;
  }
  return ref
      .watch(entitlementRepositoryProvider)
      .getCurrentEntitlement(userId: userId);
});

final isPremiumEnabledProvider = Provider<bool>((ref) {
  final entitlement = ref.watch(currentEntitlementProvider);
  return entitlement.maybeWhen(
    data: (value) => value?.isActiveAt(DateTime.now()) ?? false,
    orElse: () => false,
  );
});
