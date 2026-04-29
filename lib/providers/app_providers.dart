import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/manage/data/firestore_athlete_repository.dart';
import 'package:physi_log/features/manage/data/firestore_event_repository.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/features/records/data/firestore_record_repository.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.create();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

final dataStoreModeProvider = Provider<String>((ref) => 'firestore');

final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(data: (user) => user?.uid, orElse: () => null);
});

final useFirestoreProvider = Provider<bool>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return userId != null;
});

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  return FirestoreRecordRepository();
});

final athleteRepositoryProvider = Provider<AthleteRepository>((ref) {
  return FirestoreAthleteRepository();
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return FirestoreEventRepository();
});
