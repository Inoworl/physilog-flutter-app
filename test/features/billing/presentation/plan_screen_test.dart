import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/router.dart';
import 'package:physi_log/features/billing/domain/billing_catalog_failure.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/presentation/plan_screen.dart';
import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../support/fake_billing_repository.dart';

void main() {
  test('settingsPlan routeは/settings/planへ解決される', () {
    expect(router.namedLocation('settingsPlan'), '/settings/plan');
  });

  testWidgets('商品読み込み中を表示する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly, _teamYearly],
    )..fetchProductsCompleter = Completer<List<BillingProduct>>();

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pump();

    expect(find.text('商品情報を読み込み中...'), findsOneWidget);
    expect(find.text('購入する'), findsNothing);
  });

  testWidgets('有料プランを個人・家族とTeamに分けて支払い周期を切り替える', (tester) async {
    final repository = FakeBillingRepository(
      products: const [
        _personalMonthly,
        _personalYearly,
        _teamMonthly,
        _teamYearly,
      ],
    );

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('現在のプラン'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('支払い周期'), findsOneWidget);
    expect(find.text('月額'), findsOneWidget);
    expect(find.text('年額'), findsOneWidget);
    expect(find.text('個人・家族'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('¥500 / 月'), findsOneWidget);
    expect(find.text('¥980 / 月'), findsOneWidget);
    expect(find.text('¥5,000 / 年'), findsNothing);
    expect(find.text('¥9,800 / 年'), findsNothing);
    expect(find.text('個人・家族を購入'), findsOneWidget);
    expect(find.text('Teamを購入'), findsOneWidget);

    await tester.tap(find.text('年額'));
    await tester.pumpAndSettle();

    expect(find.text('¥500 / 月'), findsNothing);
    expect(find.text('¥980 / 月'), findsNothing);
    expect(find.text('¥5,000 / 年'), findsOneWidget);
    expect(find.text('¥9,800 / 年'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('購入を復元'), 200);
    expect(find.text('購入を復元'), findsOneWidget);
  });

  testWidgets('選択した支払い周期に対応する商品を購入する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [
        _personalMonthly,
        _personalYearly,
        _teamMonthly,
        _teamYearly,
      ],
    );

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('年額'));
    await tester.pumpAndSettle();
    final teamPurchaseButton = find.widgetWithText(FilledButton, 'Teamを購入');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(teamPurchaseButton);
    await tester.pumpAndSettle();

    expect(repository.purchasePackageIds, [
      _personalMonthly.packageId,
      _teamYearly.packageId,
    ]);
  });

  testWidgets('選択した支払い周期の商品がないプランは購入できない', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly, _teamYearly],
    );

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('個人・家族を購入'), findsOneWidget);
    expect(find.text('月額商品は現在購入できません'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '購入できません'), findsOneWidget);

    await tester.tap(find.text('年額'));
    await tester.pumpAndSettle();

    expect(find.text('年額商品は現在購入できません'), findsOneWidget);
    expect(find.text('Teamを購入'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '購入できません'), findsOneWidget);
  });

  testWidgets('現在プランの取得中と取得失敗をFree表示にしない', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(
      _planApp(repository: repository, planState: const PlanAccessLoading()),
    );
    await tester.pumpAndSettle();
    expect(find.text('現在のプランを確認中...'), findsOneWidget);
    expect(find.text('Free'), findsNothing);

    await tester.pumpWidget(
      _planApp(repository: repository, planState: const PlanAccessError()),
    );
    await tester.pumpAndSettle();
    expect(find.text('現在のプランを取得できませんでした'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
  });

  testWidgets('商品がない場合も購入情報を復元できる', (tester) async {
    final repository = FakeBillingRepository();

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('購入可能なプランがありません'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '再読み込み'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '購入を復元'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '購入を復元'));
    await tester.pumpAndSettle();

    expect(repository.restorePurchasesCalls, 1);
    expect(find.text('購入情報を復元しました'), findsOneWidget);
  });

  testWidgets('商品取得失敗後に再試行できる', (tester) async {
    final repository = FakeBillingRepository()
      ..fetchError = StateError('network error');

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('商品情報の取得に失敗しました'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '購入を復元'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '購入を復元'));
    await tester.pumpAndSettle();
    expect(repository.restorePurchasesCalls, 1);
    expect(find.text('購入情報を復元しました'), findsOneWidget);

    repository
      ..fetchError = null
      ..products = const [_personalMonthly];
    await tester.tap(find.widgetWithText(FilledButton, '再試行'));
    await tester.pumpAndSettle();

    expect(find.text('個人・家族'), findsOneWidget);
  });

  testWidgets('UID同期失敗後の再試行はUID同期からやり直す', (tester) async {
    var identitySyncAttempts = 0;
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useFirestoreProvider.overrideWithValue(true),
          billingRepositoryProvider.overrideWithValue(repository),
          planAccessStateProvider.overrideWithValue(
            _readyPlanState(PlanTier.free),
          ),
          billingIdentitySyncProvider.overrideWith((ref) async {
            identitySyncAttempts++;
            if (identitySyncAttempts == 1) {
              throw const BillingCatalogException(
                BillingCatalogFailure.invalidCredentials,
              );
            }
          }),
        ],
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('商品情報の取得に失敗しました'), findsOneWidget);
    expect(identitySyncAttempts, 1);

    await tester.tap(find.widgetWithText(FilledButton, '再試行'));
    await tester.pumpAndSettle();

    expect(identitySyncAttempts, 2);
    expect(find.text('個人・家族'), findsOneWidget);
  });

  testWidgets('localモードでは購入復元を表示しない', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(
      _planApp(repository: repository, billingEnabled: false),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('購入を復元'), findsNothing);
  });

  testWidgets('購入成功・キャンセル・失敗を明示する', (tester) async {
    final access = BillingCustomerAccess(
      activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
    );
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
      purchaseResult: BillingPurchaseResult.purchased(access),
    );

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();
    expect(find.text('購入が完了しました'), findsOneWidget);

    repository.purchaseResult = const BillingPurchaseResult.cancelled();
    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();
    expect(find.text('購入をキャンセルしました'), findsOneWidget);

    repository.purchaseResult = const BillingPurchaseResult.failed();
    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();
    expect(find.text('購入に失敗しました'), findsOneWidget);
  });

  testWidgets('購入処理中の二重タップを防ぐ', (tester) async {
    final completer = Completer<BillingPurchaseResult>();
    final repository = FakeBillingRepository(products: const [_personalMonthly])
      ..purchaseCompleter = completer;

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();

    final purchaseButton = find.widgetWithText(FilledButton, '個人・家族を購入');
    await tester.tap(purchaseButton);
    await tester.tap(purchaseButton);
    await tester.pump();

    expect(repository.purchasePackageIds, [r'$rc_monthly']);
    expect(find.text('購入処理中...'), findsOneWidget);

    completer.complete(const BillingPurchaseResult.cancelled());
    await tester.pumpAndSettle();
  });

  testWidgets('購入復元の成功と失敗を明示する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(_planApp(repository: repository));
    await tester.pumpAndSettle();

    final restoreButton = find.widgetWithText(OutlinedButton, '購入を復元');
    await tester.scrollUntilVisible(restoreButton, 200);
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('購入情報を復元しました'), -200);
    expect(find.text('購入情報を復元しました'), findsOneWidget);

    repository.restoreError = StateError('restore error');
    await tester.scrollUntilVisible(restoreButton, 200);
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('購入情報の復元に失敗しました'), -200);
    expect(find.text('購入情報の復元に失敗しました'), findsOneWidget);
  });

  testWidgets('購入後に現在プランがFreeから個人・家族へ変わる', (tester) async {
    final access = BillingCustomerAccess(
      activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
    );
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
      purchaseResult: BillingPurchaseResult.purchased(access),
    );

    await tester.pumpWidget(_planAppWithLivePlan(repository));
    await tester.pumpAndSettle();
    expect(find.text('Free'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();

    expect(find.text('個人・家族'), findsNWidgets(2));
    expect(find.text('Free'), findsNothing);
  });
}

Widget _planApp({
  required FakeBillingRepository repository,
  PlanAccessState? planState,
  bool billingEnabled = true,
}) {
  return ProviderScope(
    overrides: [
      useFirestoreProvider.overrideWithValue(billingEnabled),
      billingRepositoryProvider.overrideWithValue(repository),
      planAccessStateProvider.overrideWithValue(
        planState ?? _readyPlanState(PlanTier.free),
      ),
    ],
    child: const MaterialApp(home: PlanScreen()),
  );
}

Widget _planAppWithLivePlan(FakeBillingRepository repository) {
  return ProviderScope(
    overrides: [
      dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
      currentUserIdProvider.overrideWithValue('test-user'),
      billingRepositoryProvider.overrideWithValue(repository),
      entitlementRepositoryProvider.overrideWithValue(
        const _NoEntitlementRepository(),
      ),
    ],
    child: const MaterialApp(home: PlanScreen()),
  );
}

PlanAccessReady _readyPlanState(PlanTier tier) {
  return PlanAccessReady(
    PlanAccessStatus(
      hasRevenueCatPersonalFamily: tier == PlanTier.personalFamily,
      hasRevenueCatTeam: tier == PlanTier.team,
      hasLegacyPersonalFamily: false,
      hasLegacyTeam: false,
      hasManualTeam: false,
    ),
  );
}

class _NoEntitlementRepository implements EntitlementRepository {
  const _NoEntitlementRepository();

  @override
  Future<Entitlement?> getCurrentEntitlement({required String userId}) async {
    return null;
  }
}

const _personalMonthly = BillingProduct(
  packageId: r'$rc_monthly',
  productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
  tier: PlanTier.personalFamily,
  period: BillingPeriod.monthly,
  title: '個人・家族 月額',
  priceText: '¥500',
);

const _personalYearly = BillingProduct(
  packageId: 'personal_family_yearly',
  productId: RevenueCatCatalog.personalFamilyYearlyProductId,
  tier: PlanTier.personalFamily,
  period: BillingPeriod.yearly,
  title: '個人・家族 年額',
  priceText: '¥5,000',
);

const _teamMonthly = BillingProduct(
  packageId: 'team_monthly',
  productId: RevenueCatCatalog.teamMonthlyProductId,
  tier: PlanTier.team,
  period: BillingPeriod.monthly,
  title: 'Team 月額',
  priceText: '¥980',
);

const _teamYearly = BillingProduct(
  packageId: r'$rc_annual',
  productId: RevenueCatCatalog.teamYearlyProductId,
  tier: PlanTier.team,
  period: BillingPeriod.yearly,
  title: 'Team 年額',
  priceText: '¥9,800',
);
