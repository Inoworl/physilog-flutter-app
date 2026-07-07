import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/billing/application/revenuecat_service.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
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

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return const RevenueCatService();
});

final hasRevenueCatPersonalFamilyProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(useFirestoreProvider)) {
    return false;
  }
  return ref.watch(revenueCatServiceProvider).hasPersonalFamilyEntitlement();
});

final hasRevenueCatTeamProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(useFirestoreProvider)) {
    return false;
  }
  return ref.watch(revenueCatServiceProvider).hasTeamEntitlement();
});

final planAccessStatusProvider = Provider<PlanAccessStatus>((ref) {
  final now = DateTime.now();
  final entitlement = ref.watch(currentEntitlementProvider);
  final revenueCatPersonalFamily = ref.watch(
    hasRevenueCatPersonalFamilyProvider,
  );
  final revenueCatTeam = ref.watch(hasRevenueCatTeamProvider);
  final currentEntitlement = entitlement.valueOrNull;

  return const PlanAccessPolicy().evaluate(
    hasRevenueCatPersonalFamily: revenueCatPersonalFamily.valueOrNull ?? false,
    hasRevenueCatTeam: revenueCatTeam.valueOrNull ?? false,
    hasLegacyPersonalFamily:
        currentEntitlement?.hasLegacyPersonalFamilyAccessAt(now) ?? false,
    hasLegacyTeam: currentEntitlement?.hasLegacyTeamAccessAt(now) ?? false,
    hasManualTeam: currentEntitlement?.hasManualTeamAccessAt(now) ?? false,
  );
});

final currentPlanTierProvider = Provider<PlanTier>((ref) {
  return ref.watch(planAccessStatusProvider).tier;
});

final planCapabilitiesProvider = Provider<PlanCapabilities>((ref) {
  return ref.watch(planAccessStatusProvider).capabilities;
});
