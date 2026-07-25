import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_subscription.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/presentation/plan_screen.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../test/features/billing/support/fake_billing_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('個人・家族からTeamへの即時アップグレード要求を作成する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly, _teamMonthly],
      currentAccess: _personalMonthlyAccess,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_RegisteredUser()),
          ),
          currentUserIdProvider.overrideWithValue('integration-user'),
          useFirestoreProvider.overrideWithValue(true),
          billingRepositoryProvider.overrideWithValue(repository),
          pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
            const NoPendingSubscriptionChangeRepository(),
          ),
          planAccessStateProvider.overrideWithValue(
            const PlanAccessReady(
              PlanAccessStatus(
                hasRevenueCatPersonalFamily: true,
                hasRevenueCatTeam: false,
                hasLegacyPersonalFamily: false,
                hasLegacyTeam: false,
                hasManualTeam: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Teamへアップグレード'));
    await tester.pumpAndSettle();

    expect(
      find.text('変更はすぐに反映されます。ストアの確認画面で差額と請求タイミングを確認してください。'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, '変更する'));
    await tester.pumpAndSettle();

    expect(repository.purchaseRequests, [
      const BillingPurchaseRequest(
        packageId: 'team_monthly',
        productId: RevenueCatCatalog.teamMonthlyProductId,
        previousProductId: RevenueCatCatalog.personalFamilyMonthlyProductId,
        changeType: SubscriptionChangeType.upgrade,
        timing: SubscriptionChangeTiming.immediate,
        replacementMode: BillingReplacementMode.withTimeProration,
      ),
    ]);
  });
}

class _RegisteredUser extends Fake implements User {
  @override
  String get uid => 'integration-user';

  @override
  String? get email => 'integration@example.com';

  @override
  bool get isAnonymous => false;
}

const _personalMonthly = BillingProduct(
  packageId: r'$rc_monthly',
  productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
  tier: PlanTier.personalFamily,
  period: BillingPeriod.monthly,
  title: '個人・家族 月額',
  priceText: '¥500',
);

const _teamMonthly = BillingProduct(
  packageId: 'team_monthly',
  productId: RevenueCatCatalog.teamMonthlyProductId,
  tier: PlanTier.team,
  period: BillingPeriod.monthly,
  title: 'Team 月額',
  priceText: '¥980',
);

final _personalMonthlyAccess = BillingCustomerAccess(
  activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
  activeSubscriptions: const [
    BillingSubscription(
      entitlementId: RevenueCatCatalog.personalFamilyEntitlementId,
      productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
      tier: PlanTier.personalFamily,
      period: BillingPeriod.monthly,
      store: BillingStore.testStore,
      isActive: true,
      willRenew: true,
    ),
  ],
);
