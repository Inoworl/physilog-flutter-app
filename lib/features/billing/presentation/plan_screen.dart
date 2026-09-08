import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/billing/application/billing_controller.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_subscription.dart';
import 'package:physi_log/features/billing/domain/pending_subscription_change_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/subscription_change_policy.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState = ref.watch(billingControllerProvider);
    final authState = ref.watch(authStateProvider);
    final planState = ref.watch(planAccessStateProvider);
    final billingEnabled = ref.watch(useFirestoreProvider);
    final controller = ref.read(billingControllerProvider.notifier);
    final managementLauncher = ref.read(subscriptionManagementLauncherProvider);
    final actionMessage = billingState.actionStatus.message;

    void retryCatalog() {
      ref.invalidate(billingIdentitySyncProvider);
    }

    Future<void> executePurchase(BillingProduct product) async {
      final request = const SubscriptionChangePolicy().createRequest(
        current: billingState.customerAccess?.currentSubscription,
        target: product,
      );
      if (request == null) {
        return;
      }

      if (request.changeType != SubscriptionChangeType.newPurchase) {
        final confirmed = await _confirmSubscriptionChange(
          context: context,
          request: request,
          target: product,
        );
        if (confirmed != true || !context.mounted) {
          return;
        }
      }

      await controller.purchase(request);
    }

    Future<void> purchase(BillingProduct product) async {
      final user = authState.valueOrNull;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウント情報を確認できませんでした。再度お試しください。')),
        );
        return;
      }

      final email = user.email?.trim();
      final needsEmailRegistration =
          user.isAnonymous || email == null || email.isEmpty;
      if (!needsEmailRegistration) {
        await executePurchase(product);
        return;
      }

      final registered = await context.pushNamed<bool>(
        'settingsAccountAuth',
        pathParameters: {'mode': 'register'},
      );
      if (registered != true || !context.mounted) {
        return;
      }

      await executePurchase(product);
    }

    Future<void> manageSubscription() async {
      final managementUri = billingState.customerAccess?.managementUri;
      if (managementUri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('契約管理画面を開けません。購入したストアのアカウント設定から確認してください。'),
          ),
        );
        return;
      }

      var opened = false;
      try {
        opened = await managementLauncher.open(managementUri);
      } on Object {
        opened = false;
      }
      if (!context.mounted || opened) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('契約管理画面を開けませんでした。時間をおいて再度お試しください。')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('プラン')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: _CurrentPlanCard(
                state: planState,
                subscription: billingState.customerAccess?.currentSubscription,
                onManage: manageSubscription,
              ),
            ),
            if (billingState.pendingChange case final pendingChange?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: _PendingChangeCard(change: pendingChange),
              ),
            if (billingEnabled && actionMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: _ActionNotice(
                  status: billingState.actionStatus,
                  message: actionMessage,
                ),
              ),
            Expanded(
              child: switch (billingState.catalogStatus) {
                BillingCatalogStatus.initial ||
                BillingCatalogStatus.loading => Semantics(
                  label: '商品情報を読み込み中',
                  liveRegion: true,
                  child: const LoadingState(message: '商品情報を読み込み中...'),
                ),
                BillingCatalogStatus.failed => ErrorState(
                  message: '商品情報の取得に失敗しました',
                  onRetry: retryCatalog,
                ),
                BillingCatalogStatus.loaded
                    when billingState.products.isEmpty =>
                  EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: '購入可能なプランがありません',
                    subtitle: 'しばらくしてから商品情報を再読み込みしてください。',
                    action: FilledButton.icon(
                      onPressed: retryCatalog,
                      icon: const Icon(Icons.refresh),
                      label: const Text('再読み込み'),
                    ),
                  ),
                BillingCatalogStatus.loaded => _ProductList(
                  state: billingState,
                  onPurchase: purchase,
                ),
              },
            ),
            if (billingEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        billingState.isIdentitySynchronized &&
                            !billingState.isActionInProgress
                        ? controller.restorePurchases
                        : null,
                    icon: const Icon(Icons.restore),
                    label: Text(
                      billingState.actionStatus == BillingActionStatus.restoring
                          ? '復元中...'
                          : '購入を復元',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmSubscriptionChange({
  required BuildContext context,
  required BillingPurchaseRequest request,
  required BillingProduct target,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(request.actionLabel(target: target)),
        content: Text(
          request.replacementMode == BillingReplacementMode.withoutProration
              ? 'プラン内容はすぐに切り替わり、新しい料金は次回更新時に請求されます。'
              : request.timing == SubscriptionChangeTiming.immediate
              ? '変更はすぐに反映されます。ストアの確認画面で差額と請求タイミングを確認してください。'
              : '変更は次回更新時に反映されます。それまでは現在のプランを利用できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('変更する'),
          ),
        ],
      );
    },
  );
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.state,
    required this.subscription,
    required this.onManage,
  });

  final PlanAccessState state;
  final BillingSubscription? subscription;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state) {
      PlanAccessLoading() => (Icons.hourglass_top, '現在のプランを確認中...'),
      PlanAccessError() => (Icons.error_outline, '現在のプランを取得できませんでした'),
      PlanAccessReady(:final tier) => (Icons.verified_outlined, tier.label),
    };

    final subscription = this.subscription;
    if (subscription == null) {
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: const Text('現在のプラン'),
          subtitle: Text(label),
        ),
      );
    }

    return Semantics(
      container: true,
      label: '現在の契約内容',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_outlined),
                  SizedBox(width: AppSpacing.sm),
                  Text('現在のプラン', style: AppTextStyles.cardTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${subscription.tier.label}・${subscription.period.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('商品ID: ${subscription.productId}'),
              Text(subscription.store.label),
              if (subscription.expiresAt case final expiresAt?)
                Text('有効期限: ${_formatDate(expiresAt)}'),
              Text(subscription.renewalLabel),
              if (subscription.hasBillingIssue)
                Text(
                  '支払い情報を確認してください',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.open_in_new),
                label: const Text('契約を管理'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingChangeCard extends StatelessWidget {
  const _PendingChangeCard({required this.change});

  final PendingSubscriptionChange change;

  @override
  Widget build(BuildContext context) {
    final target = billingConfigurationForProduct(change.targetProductId);
    final targetLabel = target == null
        ? change.targetProductId
        : '${target.tier.label}・${target.period.label}';

    return Semantics(
      container: true,
      label: '契約変更予約',
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('変更予約中'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('次回: $targetLabel'),
              const Text('反映状況は契約管理画面で確認してください。'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductList extends StatefulWidget {
  const _ProductList({required this.state, required this.onPurchase});

  final BillingState state;
  final ValueChanged<BillingProduct> onPurchase;

  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  BillingPeriod _selectedPeriod = BillingPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        const Text('購入できるプラン', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.lg),
        const Text('支払い周期', style: AppTextStyles.cardTitle),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<BillingPeriod>(
            segments: const [
              ButtonSegment(value: BillingPeriod.monthly, label: Text('月額')),
              ButtonSegment(value: BillingPeriod.yearly, label: Text('年額')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: state.isActionInProgress
                ? null
                : (selection) {
                    setState(() {
                      _selectedPeriod = selection.single;
                    });
                  },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final tier in const [PlanTier.personalFamily, PlanTier.team]) ...[
          _planCard(tier: tier, state: state),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _planCard({required PlanTier tier, required BillingState state}) {
    final product = _productFor(
      products: state.products,
      tier: tier,
      period: _selectedPeriod,
    );
    final request = product == null
        ? null
        : const SubscriptionChangePolicy().createRequest(
            current: state.customerAccess?.currentSubscription,
            target: product,
          );
    final isCurrent = product != null && request == null;

    return _PlanCard(
      tier: tier,
      period: _selectedPeriod,
      product: product,
      isBusy: state.isActionInProgress,
      isPurchasing:
          state.actionStatus == BillingActionStatus.purchasing &&
          state.activePackageId == product?.packageId,
      request: request,
      isCurrent: isCurrent,
      onPurchase: widget.onPurchase,
    );
  }

  BillingProduct? _productFor({
    required List<BillingProduct> products,
    required PlanTier tier,
    required BillingPeriod period,
  }) {
    for (final product in products) {
      if (product.tier == tier && product.period == period) {
        return product;
      }
    }
    return null;
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.period,
    required this.product,
    required this.isBusy,
    required this.isPurchasing,
    required this.request,
    required this.isCurrent,
    required this.onPurchase,
  });

  final PlanTier tier;
  final BillingPeriod period;
  final BillingProduct? product;
  final bool isBusy;
  final bool isPurchasing;
  final BillingPurchaseRequest? request;
  final bool isCurrent;
  final ValueChanged<BillingProduct> onPurchase;

  @override
  Widget build(BuildContext context) {
    final product = this.product;

    return Semantics(
      container: true,
      label: '${tier.label}プラン',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tier.label, style: AppTextStyles.cardTitle),
              const SizedBox(height: AppSpacing.sm),
              if (product case final product?)
                Text(
                  '${product.priceText} / ${period.unitLabel}',
                  style: Theme.of(context).textTheme.titleLarge,
                )
              else
                Text('${period.label}商品は現在購入できません'),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: isBusy || product == null || isCurrent
                    ? null
                    : () => onPurchase(product),
                child: Text(
                  isPurchasing
                      ? '購入処理中...'
                      : product == null
                      ? '購入できません'
                      : isCurrent
                      ? '利用中'
                      : request!.actionLabel(target: product),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionNotice extends StatelessWidget {
  const _ActionNotice({required this.status, required this.message});

  final BillingActionStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isFailure =
        status == BillingActionStatus.purchaseFailed ||
        status == BillingActionStatus.restoreFailed;
    final icon = isFailure ? Icons.error_outline : Icons.info_outline;
    final color = isFailure
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      liveRegion: true,
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(message),
        ),
      ),
    );
  }
}

extension on PlanTier {
  String get label => switch (this) {
    PlanTier.free => 'Free',
    PlanTier.personalFamily => '個人・家族',
    PlanTier.team => 'Team',
  };
}

extension on BillingPeriod {
  String get label => switch (this) {
    BillingPeriod.monthly => '月額',
    BillingPeriod.yearly => '年額',
  };

  String get unitLabel => switch (this) {
    BillingPeriod.monthly => '月',
    BillingPeriod.yearly => '年',
  };
}

extension on BillingPurchaseRequest {
  String actionLabel({required BillingProduct target}) {
    return switch (changeType) {
      SubscriptionChangeType.newPurchase => '${target.tier.label}を購入',
      SubscriptionChangeType.upgrade => '${target.tier.label}へアップグレード',
      SubscriptionChangeType.downgrade => '${target.tier.label}へ変更',
      SubscriptionChangeType.periodChange => '${target.period.label}へ変更',
    };
  }
}

extension on BillingStore {
  String get label => switch (this) {
    BillingStore.appStore => 'App Store',
    BillingStore.playStore => 'Google Play',
    BillingStore.testStore => 'Test Store',
    BillingStore.other => 'その他のストア',
  };
}

extension on BillingSubscription {
  String get renewalLabel {
    if (isCancellationScheduled) {
      return '更新: 有効期限で終了予定';
    }
    return willRenew ? '更新: 自動更新予定' : '更新: 自動更新なし';
  }
}

String _formatDate(DateTime date) {
  final localDate = date.toLocal();
  return '${localDate.year}年${localDate.month}月${localDate.day}日';
}

extension on BillingActionStatus {
  String? get message => switch (this) {
    BillingActionStatus.purchaseSucceeded => '購入が完了しました',
    BillingActionStatus.purchaseCancelled => '購入をキャンセルしました',
    BillingActionStatus.purchaseFailed => '購入に失敗しました',
    BillingActionStatus.restoreSucceeded => '購入情報を復元しました',
    BillingActionStatus.restoreFailed => '購入情報の復元に失敗しました',
    BillingActionStatus.idle ||
    BillingActionStatus.purchasing ||
    BillingActionStatus.restoring => null,
  };
}
