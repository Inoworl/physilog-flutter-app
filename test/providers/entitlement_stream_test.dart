import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../features/billing/support/fake_billing_repository.dart';

void main() {
  testWidgets('Firestoreの利用権変更と削除を再読み込みなしで反映する', (tester) async {
    final updates = StreamController<Entitlement?>();
    final repository = _WatchingEntitlementRepository(updates.stream);
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('test-user'),
        entitlementRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() {
      container.dispose();
      unawaited(updates.close());
    });
    container.listen(currentEntitlementProvider, (_, _) {});
    await tester.pump();

    updates.add(_teamEntitlement);
    await tester.pump();
    expect(
      container.read(currentEntitlementProvider).valueOrNull,
      _teamEntitlement,
    );

    updates.add(null);
    await tester.pump();
    expect(container.read(currentEntitlementProvider).valueOrNull, isNull);
  });

  testWidgets('特別利用権の付与・期限切れ・削除をプランに自動反映する', (tester) async {
    final updates = StreamController<Entitlement?>();
    final container = ProviderContainer(
      overrides: [
        useFirestoreProvider.overrideWithValue(true),
        currentUserIdProvider.overrideWithValue('test-user'),
        entitlementRepositoryProvider.overrideWithValue(
          _WatchingEntitlementRepository(updates.stream),
        ),
        billingIdentitySyncProvider.overrideWith((ref) async {}),
        billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
        billingClockProvider.overrideWithValue(tester.binding.clock.now),
      ],
    );
    await _watchPlan(tester, container);
    updates.add(null);
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );

    updates.add(
      _teamEntitlement.copyWith(
        expiresAt: tester.binding.clock.now().add(const Duration(seconds: 10)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.team,
    );
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );

    updates.add(_teamEntitlement);
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.team,
    );
    updates.add(null);
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    unawaited(updates.close());
  });

  testWidgets('UID変更で旧購読を解除して旧ユーザーの権利を混ぜない', (tester) async {
    final firstUpdates = StreamController<Entitlement?>();
    final secondUpdates = StreamController<Entitlement?>();
    final userProvider = StateProvider<String?>((ref) => 'first-user');
    final container = ProviderContainer(
      overrides: [
        useFirestoreProvider.overrideWithValue(true),
        currentUserIdProvider.overrideWith((ref) => ref.watch(userProvider)),
        entitlementRepositoryProvider.overrideWith(
          (ref) => _WatchingEntitlementRepository(
            ref.watch(currentUserIdProvider) == 'first-user'
                ? firstUpdates.stream
                : secondUpdates.stream,
          ),
        ),
        billingIdentitySyncProvider.overrideWith((ref) async {}),
        billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
      ],
    );
    await _watchPlan(tester, container);
    firstUpdates.add(_teamEntitlement.copyWith(userId: 'first-user'));
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.team,
    );

    container.read(userProvider.notifier).state = 'second-user';
    await tester.pumpAndSettle();
    expect(firstUpdates.hasListener, isFalse);
    expect(container.read(planAccessStateProvider), isA<PlanAccessLoading>());
    firstUpdates.add(_teamEntitlement);
    secondUpdates.add(null);
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );

    container.read(userProvider.notifier).state = null;
    await tester.pumpAndSettle();
    expect(secondUpdates.hasListener, isFalse);
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.free,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    unawaited(firstUpdates.close());
    unawaited(secondUpdates.close());
  });

  testWidgets('Firestore購読エラーをFreeと誤判定せず次の通知で回復する', (tester) async {
    final updates = StreamController<Entitlement?>();
    final container = ProviderContainer(
      overrides: [
        useFirestoreProvider.overrideWithValue(true),
        currentUserIdProvider.overrideWithValue('test-user'),
        entitlementRepositoryProvider.overrideWithValue(
          _WatchingEntitlementRepository(updates.stream),
        ),
        billingIdentitySyncProvider.overrideWith((ref) async {}),
        billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
      ],
    );
    await _watchPlan(tester, container);
    updates.addError(StateError('permission-denied'));
    await tester.pumpAndSettle();
    expect(container.read(planAccessStateProvider), isA<PlanAccessError>());
    updates.add(_teamEntitlement);
    await tester.pumpAndSettle();
    expect(
      (container.read(planAccessStateProvider) as PlanAccessReady).tier,
      PlanTier.team,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    unawaited(updates.close());
  });

  testWidgets('ID同期待ち中のFirestoreエラーも未処理例外にしない', (tester) async {
    final identity = Completer<void>();
    final updates = StreamController<Entitlement?>();
    final container = ProviderContainer(
      overrides: [
        useFirestoreProvider.overrideWithValue(true),
        currentUserIdProvider.overrideWithValue('test-user'),
        entitlementRepositoryProvider.overrideWithValue(
          _WatchingEntitlementRepository(updates.stream),
        ),
        billingIdentitySyncProvider.overrideWith((ref) => identity.future),
        billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
      ],
    );
    await _watchPlan(tester, container);
    updates.addError(StateError('permission-denied'));
    await tester.pumpAndSettle();
    identity.complete();
    await tester.pumpAndSettle();
    expect(container.read(planAccessStateProvider), isA<PlanAccessError>());
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    unawaited(updates.close());
  });
}

Future<void> _watchPlan(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) {
          ref.watch(planAccessStateProvider);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _teamEntitlement = Entitlement(
  id: 'current',
  userId: 'test-user',
  plan: EntitlementPlans.manualTeam,
  source: EntitlementSources.manual,
  status: EntitlementStatuses.active,
  grantedAt: DateTime.utc(2026, 9, 11),
  updatedAt: DateTime.utc(2026, 9, 11),
);

class _WatchingEntitlementRepository implements EntitlementRepository {
  _WatchingEntitlementRepository(this.updates);

  final Stream<Entitlement?> updates;

  @override
  Future<Entitlement?> getCurrentEntitlement({required String userId}) async =>
      null;

  @override
  Stream<Entitlement?> watchCurrentEntitlement({required String userId}) =>
      updates;
}
