import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/manage/data/firestore_athlete_repository.dart';
import 'package:physi_log/features/manage/data/local_athlete_repository.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/records/data/firestore_record_repository.dart';
import 'package:physi_log/features/records/data/local_record_repository.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';

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
