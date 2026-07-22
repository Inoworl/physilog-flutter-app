import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/measurement/presentation/session_setup_screen.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  testWidgets('Team以外で計測会設定画面へ直接入った場合はロック表示になる', (tester) async {
    final router = GoRouter(
      initialLocation: '/session',
      routes: [
        GoRoute(
          path: '/session',
          builder: (context, state) => const SessionSetupScreen(),
        ),
        GoRoute(
          path: '/settings/plan',
          name: 'settingsPlan',
          builder: (context, state) => const Scaffold(body: Text('プラン画面')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessStateProvider.overrideWithValue(
            _readyPlanState(PlanTier.free),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('計測会を始める'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('計測会はTeamプランで利用できます'), findsOneWidget);
    expect(find.text('個人・家族プランでは、動画計測と手入力の記録追加を利用できます'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'プランを見る'), findsOneWidget);

    await tester.tap(find.text('プランを見る'));
    await tester.pumpAndSettle();

    expect(find.text('プラン画面'), findsOneWidget);
  });

  testWidgets('プラン取得中はTeam限定ロックではなく読み込み表示になる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessStateProvider.overrideWithValue(const PlanAccessLoading()),
        ],
        child: const MaterialApp(home: SessionSetupScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('プラン情報を確認中...'), findsOneWidget);
    expect(find.text('計測会はTeamプランで利用できます'), findsNothing);
  });

  testWidgets('プラン取得失敗時はTeam限定ロックではなく再試行を表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessStateProvider.overrideWithValue(const PlanAccessError()),
        ],
        child: const MaterialApp(home: SessionSetupScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('プラン情報の取得に失敗しました'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '再試行'), findsOneWidget);
    expect(find.text('計測会はTeamプランで利用できます'), findsNothing);
  });
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
