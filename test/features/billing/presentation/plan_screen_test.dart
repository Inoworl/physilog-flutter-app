import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/router.dart';
import 'package:physi_log/features/billing/domain/billing_catalog_failure.dart';
import 'package:physi_log/features/billing/domain/billing_customer_access.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_result.dart';
import 'package:physi_log/features/billing/domain/billing_subscription.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/presentation/plan_screen.dart';
import 'package:physi_log/features/billing/presentation/subscription_management_launcher.dart';
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

  testWidgets('匿名ユーザーはメール登録完了前に購入できずキャンセルすると元画面へ戻る', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(
      _planRouterApp(
        repository: repository,
        user: _FakeUser(uid: 'anonymous-uid', email: null, isAnonymous: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();

    expect(find.text('購入前メール登録'), findsOneWidget);
    expect(repository.purchasePackageIds, isEmpty);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('購入前メール登録'), findsNothing);
    expect(find.text('プラン'), findsOneWidget);
    expect(repository.purchasePackageIds, isEmpty);
  });

  testWidgets('匿名ユーザーはメール登録成功後に選択した商品の購入を再開する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(
      _planRouterApp(
        repository: repository,
        user: _FakeUser(uid: 'anonymous-uid', email: null, isAnonymous: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();
    expect(repository.purchasePackageIds, isEmpty);

    await tester.tap(find.text('登録完了'));
    await tester.pumpAndSettle();

    expect(repository.purchasePackageIds, [_personalMonthly.packageId]);
  });

  testWidgets('メール登録済みユーザーは追加登録なしで直接購入できる', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(
      _planRouterApp(
        repository: repository,
        user: _FakeUser(
          uid: 'registered-uid',
          email: 'coach@example.com',
          isAnonymous: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();

    expect(find.text('購入前メール登録'), findsNothing);
    expect(repository.purchasePackageIds, [_personalMonthly.packageId]);
  });

  testWidgets('認証ユーザーを確認できない場合は購入せず再試行を案内する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
    );

    await tester.pumpWidget(
      _planApp(repository: repository, authStream: Stream.value(null)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '個人・家族を購入'));
    await tester.pumpAndSettle();

    expect(repository.purchasePackageIds, isEmpty);
    expect(find.text('アカウント情報を確認できませんでした。再度お試しください。'), findsOneWidget);
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
          pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
            FakePendingSubscriptionChangeRepository(),
          ),
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

  testWidgets('現在の商品詳細を表示して再購入を無効にする', (tester) async {
    final repository = FakeBillingRepository(
      products: const [
        _personalMonthly,
        _personalYearly,
        _teamMonthly,
        _teamYearly,
      ],
      currentAccess: _personalMonthlyAccess,
    );

    await tester.pumpWidget(
      _planApp(
        repository: repository,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('個人・家族・月額'), findsOneWidget);
    expect(
      find.text('商品ID: ${RevenueCatCatalog.personalFamilyMonthlyProductId}'),
      findsOneWidget,
    );
    expect(find.text('Test Store'), findsOneWidget);
    expect(find.text('有効期限: 2026年8月1日'), findsOneWidget);

    final currentButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '利用中'),
    );
    expect(currentButton.onPressed, isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Teamへアップグレード'), findsOneWidget);
  });

  testWidgets('解約検知後も期限内は利用中として終了予定と請求問題を表示する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
      currentAccess: _cancelledPersonalMonthlyAccess,
    );

    await tester.pumpWidget(
      _planApp(
        repository: repository,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '利用中'), findsOneWidget);
    expect(find.text('更新: 有効期限で終了予定'), findsOneWidget);
    expect(find.text('支払い情報を確認してください'), findsOneWidget);
    expect(find.text('有効期限: 2026年8月1日'), findsOneWidget);
  });

  testWidgets('個人・家族からTeamへの即時アップグレードを確認して実行する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly, _teamMonthly],
      currentAccess: _personalMonthlyAccess,
    );

    await tester.pumpWidget(
      _planApp(
        repository: repository,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Teamへアップグレード'));
    await tester.pumpAndSettle();

    expect(find.text('Teamへアップグレード'), findsNWidgets(2));
    expect(
      find.text('変更はすぐに反映されます。ストアの確認画面で差額と請求タイミングを確認してください。'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, '変更する'));
    await tester.pumpAndSettle();

    final request = repository.purchaseRequests.single;
    expect(request.changeType, SubscriptionChangeType.upgrade);
    expect(
      request.previousProductId,
      RevenueCatCatalog.personalFamilyMonthlyProductId,
    );
    expect(request.replacementMode, BillingReplacementMode.withTimeProration);
  });

  testWidgets('Teamから個人・家族への変更を次回更新として案内する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly, _teamMonthly],
      currentAccess: _teamMonthlyAccess,
    );

    await tester.pumpWidget(
      _planApp(
        repository: repository,
        planState: _readyPlanState(PlanTier.team),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '個人・家族へ変更'));
    await tester.pumpAndSettle();

    expect(find.text('個人・家族へ変更'), findsNWidgets(2));
    expect(find.text('変更は次回更新時に反映されます。それまでは現在のプランを利用できます。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '変更する'));
    await tester.pumpAndSettle();

    final request = repository.purchaseRequests.single;
    expect(request.changeType, SubscriptionChangeType.downgrade);
    expect(request.replacementMode, BillingReplacementMode.deferred);
  });

  testWidgets('同一Tierの月額から年額への変更を次回更新として案内する', (tester) async {
    final repository = FakeBillingRepository(
      products: const [_personalMonthly, _personalYearly],
      currentAccess: _personalMonthlyAccess,
    );

    await tester.pumpWidget(
      _planApp(
        repository: repository,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('年額'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '年額へ変更'));
    await tester.pumpAndSettle();
    expect(find.text('変更は次回更新時に反映されます。それまでは現在のプランを利用できます。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '変更する'));
    await tester.pumpAndSettle();

    final request = repository.purchaseRequests.single;
    expect(request.changeType, SubscriptionChangeType.periodChange);
    expect(request.replacementMode, BillingReplacementMode.deferred);
  });

  testWidgets('保存済みの変更予約を再起動後も表示する', (tester) async {
    final pendingRepository = FakePendingSubscriptionChangeRepository()
      ..changes['registered-uid'] = PendingSubscriptionChange(
        previousProductId: RevenueCatCatalog.personalFamilyMonthlyProductId,
        targetProductId: RevenueCatCatalog.teamYearlyProductId,
        createdAt: DateTime.utc(2026, 7, 22),
      );
    final repository = FakeBillingRepository(
      products: const [_personalMonthly, _teamYearly],
      currentAccess: _personalMonthlyAccess,
    );

    await tester.pumpWidget(
      _planApp(
        repository: repository,
        pendingChangeRepository: pendingRepository,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('変更予約中'), findsOneWidget);
    expect(find.text('次回: Team・年額'), findsOneWidget);
    expect(find.text('反映状況は契約管理画面で確認してください。'), findsOneWidget);
  });

  testWidgets('契約管理ボタンからStoreの管理URLを外部で開く', (tester) async {
    final launcher = _FakeSubscriptionManagementLauncher();
    final repository = FakeBillingRepository(
      products: const [_personalMonthly],
      currentAccess: _personalMonthlyAccess,
    );

    await tester.pumpWidget(
      _planApp(
        repository: repository,
        managementLauncher: launcher,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '契約を管理'));
    await tester.pumpAndSettle();

    expect(launcher.openedUris, [Uri.parse('https://store.example/manage')]);
  });

  testWidgets('契約管理URLがない場合はStoreのアカウント設定を案内する', (tester) async {
    final missingUrlRepository = FakeBillingRepository(
      products: const [_personalMonthly],
      currentAccess: _personalMonthlyAccessWithoutManagementUrl,
    );

    await tester.pumpWidget(
      _planApp(
        repository: missingUrlRepository,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '契約を管理'));
    await tester.pumpAndSettle();
    expect(
      find.text('契約管理画面を開けません。購入したストアのアカウント設定から確認してください。'),
      findsOneWidget,
    );
  });

  testWidgets('契約管理画面の起動に失敗した場合は再試行を案内する', (tester) async {
    final launcher = _FakeSubscriptionManagementLauncher()..shouldOpen = false;
    await tester.pumpWidget(
      _planApp(
        repository: FakeBillingRepository(
          products: const [_personalMonthly],
          currentAccess: _personalMonthlyAccess,
        ),
        managementLauncher: launcher,
        planState: _readyPlanState(PlanTier.personalFamily),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '契約を管理'));
    await tester.pumpAndSettle();
    expect(find.text('契約管理画面を開けませんでした。時間をおいて再度お試しください。'), findsOneWidget);
  });
}

Widget _planApp({
  required FakeBillingRepository repository,
  PlanAccessState? planState,
  bool billingEnabled = true,
  User? user,
  Stream<User?>? authStream,
  PendingSubscriptionChangeRepository? pendingChangeRepository,
  SubscriptionManagementLauncher? managementLauncher,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) =>
            authStream ??
            Stream.value(
              user ??
                  _FakeUser(
                    uid: 'registered-uid',
                    email: 'coach@example.com',
                    isAnonymous: false,
                  ),
            ),
      ),
      useFirestoreProvider.overrideWithValue(billingEnabled),
      billingRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue('registered-uid'),
      pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
        pendingChangeRepository ?? FakePendingSubscriptionChangeRepository(),
      ),
      subscriptionManagementLauncherProvider.overrideWithValue(
        managementLauncher ?? _FakeSubscriptionManagementLauncher(),
      ),
      planAccessStateProvider.overrideWithValue(
        planState ?? _readyPlanState(PlanTier.free),
      ),
    ],
    child: const MaterialApp(home: PlanScreen()),
  );
}

Widget _planRouterApp({
  required FakeBillingRepository repository,
  required User user,
}) {
  final router = GoRouter(
    initialLocation: '/settings/plan',
    routes: [
      GoRoute(
        path: '/settings/plan',
        name: 'settingsPlan',
        builder: (context, state) => const PlanScreen(),
      ),
      GoRoute(
        path: '/settings/account/:mode',
        name: 'settingsAccountAuth',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('購入前メール登録')),
          body: Column(
            children: [
              FilledButton(
                onPressed: () => context.pop(true),
                child: const Text('登録完了'),
              ),
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(user)),
      useFirestoreProvider.overrideWithValue(true),
      billingRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue(user.uid),
      pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
        FakePendingSubscriptionChangeRepository(),
      ),
      subscriptionManagementLauncherProvider.overrideWithValue(
        _FakeSubscriptionManagementLauncher(),
      ),
      planAccessStateProvider.overrideWithValue(_readyPlanState(PlanTier.free)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _planAppWithLivePlan(FakeBillingRepository repository) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          _FakeUser(
            uid: 'test-user',
            email: 'coach@example.com',
            isAnonymous: false,
          ),
        ),
      ),
      dataStoreModeProvider.overrideWithValue(DataStoreMode.firestore),
      currentUserIdProvider.overrideWithValue('test-user'),
      billingRepositoryProvider.overrideWithValue(repository),
      pendingSubscriptionChangeRepositoryProvider.overrideWithValue(
        FakePendingSubscriptionChangeRepository(),
      ),
      subscriptionManagementLauncherProvider.overrideWithValue(
        _FakeSubscriptionManagementLauncher(),
      ),
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

class _FakeUser extends Fake implements User {
  _FakeUser({
    required this.uid,
    required this.email,
    required this.isAnonymous,
  });

  @override
  final String uid;

  @override
  final String? email;

  @override
  final bool isAnonymous;
}

class _FakeSubscriptionManagementLauncher
    implements SubscriptionManagementLauncher {
  bool shouldOpen = true;
  final openedUris = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    openedUris.add(uri);
    return shouldOpen;
  }
}

final _personalMonthlyAccess = BillingCustomerAccess(
  activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
  activeSubscriptions: [
    BillingSubscription(
      entitlementId: RevenueCatCatalog.personalFamilyEntitlementId,
      productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
      tier: PlanTier.personalFamily,
      period: BillingPeriod.monthly,
      store: BillingStore.testStore,
      isActive: true,
      willRenew: true,
      expiresAt: DateTime.utc(2026, 8, 1),
    ),
  ],
  managementUrl: 'https://store.example/manage',
);

final _personalMonthlyAccessWithoutManagementUrl = BillingCustomerAccess(
  activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
  activeSubscriptions: _personalMonthlyAccess.activeSubscriptions,
);

final _cancelledPersonalMonthlyAccess = BillingCustomerAccess(
  activeEntitlementIds: {RevenueCatCatalog.personalFamilyEntitlementId},
  activeSubscriptions: [
    BillingSubscription(
      entitlementId: RevenueCatCatalog.personalFamilyEntitlementId,
      productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
      tier: PlanTier.personalFamily,
      period: BillingPeriod.monthly,
      store: BillingStore.testStore,
      isActive: true,
      willRenew: false,
      expiresAt: DateTime.utc(2026, 8, 1),
      unsubscribeDetectedAt: DateTime.utc(2026, 7, 24),
      billingIssueDetectedAt: DateTime.utc(2026, 7, 24),
    ),
  ],
  managementUrl: 'https://store.example/manage',
);

final _teamMonthlyAccess = BillingCustomerAccess(
  activeEntitlementIds: {RevenueCatCatalog.teamEntitlementId},
  activeSubscriptions: const [
    BillingSubscription(
      entitlementId: RevenueCatCatalog.teamEntitlementId,
      productId: RevenueCatCatalog.teamMonthlyProductId,
      tier: PlanTier.team,
      period: BillingPeriod.monthly,
      store: BillingStore.testStore,
      isActive: true,
      willRenew: true,
    ),
  ],
  managementUrl: 'https://store.example/manage',
);
