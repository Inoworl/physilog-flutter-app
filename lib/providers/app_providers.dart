import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/auth/application/auth_service.dart';
import 'package:physi_log/features/billing/application/billing_controller.dart';
import 'package:physi_log/features/billing/application/billing_identity_sync.dart';
import 'package:physi_log/features/billing/application/plan_access_controller.dart';
import 'package:physi_log/features/billing/data/hive_pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/data/no_billing_repository.dart';
import 'package:physi_log/features/billing/data/revenuecat_billing_repository.dart';
import 'package:physi_log/features/billing/domain/billing_repository.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/presentation/subscription_management_launcher.dart';
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

final currentEntitlementProvider = StreamProvider<Entitlement?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(null);
  }
  return ref
      .watch(entitlementRepositoryProvider)
      .watchCurrentEntitlement(userId: userId);
});

final billingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  if (!ref.watch(useFirestoreProvider)) {
    return const NoBillingRepository();
  }
  return RevenueCatBillingRepository();
});

final pendingSubscriptionChangeRepositoryProvider =
    Provider<PendingSubscriptionChangeRepository>((ref) {
      return HivePendingSubscriptionChangeRepository();
    });

final subscriptionManagementLauncherProvider =
    Provider<SubscriptionManagementLauncher>((ref) {
      return const UrlSubscriptionManagementLauncher();
    });

final billingIdentitySyncServiceProvider = Provider<BillingIdentitySync>((ref) {
  return BillingIdentitySync(repository: ref.watch(billingRepositoryProvider));
});

final billingIdentitySyncProvider = FutureProvider<void>((ref) async {
  final useFirestore = ref.watch(useFirestoreProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (!useFirestore || userId == null) {
    return;
  }

  await ref.watch(billingIdentitySyncServiceProvider).synchronize(userId);
});

final planAccessStateStreamProvider = StreamProvider<PlanAccessState>((ref) {
  final useFirestore = ref.watch(useFirestoreProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (!useFirestore || userId == null) {
    return Stream.value(
      PlanAccessReady(
        const PlanAccessPolicy().evaluate(
          hasRevenueCatPersonalFamily: false,
          hasRevenueCatTeam: false,
          hasLegacyPersonalFamily: false,
          hasLegacyTeam: false,
          hasManualTeam: false,
        ),
      ),
    );
  }

  final identitySync = ref.watch(billingIdentitySyncProvider.future);
  final entitlementFuture = ref.watch(currentEntitlementProvider.future);
  final repository = ref.watch(billingRepositoryProvider);
  final clock = ref.watch(billingClockProvider);
  Timer? expiryTimer;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    expiryTimer?.cancel();
  });
  Stream<PlanAccessState> watchAccess() async* {
    if (disposed) return;
    try {
      await identitySync;
      final entitlement = await entitlementFuture;
      if (disposed) return;
      final now = clock();
      final expiresAt = entitlement?.expiresAt;
      if (entitlement?.isActiveAt(now) == true && expiresAt != null) {
        expiryTimer = Timer(expiresAt.difference(now), ref.invalidateSelf);
      }
      final controller = PlanAccessController(repository: repository);

      yield* controller.watchAccess(
        hasLegacyPersonalFamily:
            entitlement?.hasLegacyPersonalFamilyAccessAt(now) ?? false,
        hasLegacyTeam: entitlement?.hasLegacyTeamAccessAt(now) ?? false,
        hasManualTeam: entitlement?.hasManualTeamAccessAt(now) ?? false,
      );
    } on Object {
      yield const PlanAccessError();
    }
  }

  return watchAccess();
});

final planAccessStateProvider = Provider<PlanAccessState>((ref) {
  final asyncState = ref.watch(planAccessStateStreamProvider);
  return switch (asyncState) {
    AsyncData(:final value) => value,
    AsyncError() => const PlanAccessError(),
    _ => const PlanAccessLoading(),
  };
});

final billingControllerProvider =
    StateNotifierProvider.autoDispose<BillingController, BillingState>((ref) {
      final controller = BillingController(
        repository: ref.watch(billingRepositoryProvider),
        pendingChangeRepository: ref.watch(
          pendingSubscriptionChangeRepositoryProvider,
        ),
        userId: ref.watch(currentUserIdProvider),
        now: ref.watch(billingClockProvider),
        onCustomerAccessChanged: (_) {
          ref.invalidate(planAccessStateStreamProvider);
        },
      );
      unawaited(
        controller.initialize(
          identitySync: ref.watch(billingIdentitySyncProvider.future),
        ),
      );
      return controller;
    });
