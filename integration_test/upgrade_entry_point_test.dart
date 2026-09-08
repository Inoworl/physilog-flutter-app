import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/measurement/presentation/session_setup_screen.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Team限定画面から共通プラン画面へ遷移できる', (tester) async {
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
            const PlanAccessReady(
              PlanAccessStatus(
                hasRevenueCatPersonalFamily: false,
                hasRevenueCatTeam: false,
                hasLegacyPersonalFamily: false,
                hasLegacyTeam: false,
                hasManualTeam: false,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('計測会はTeamプランで利用できます'), findsOneWidget);
    await tester.tap(find.text('プランを見る'));
    await tester.pumpAndSettle();

    expect(find.text('プラン画面'), findsOneWidget);
  });
}
