import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/presentation/upgrade_prompt.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/records/presentation/manual_record_form.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/providers/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: _GreetingSection()),
                  IconButton(
                    tooltip: '設定',
                    onPressed: () => context.pushNamed('settings'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _StartSessionButton(),
              const SizedBox(height: AppSpacing.lg),
              _QuickActionsSection(),
              const SizedBox(height: AppSpacing.xxl),
              const _AthleteSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'おはようございます';
    if (hour >= 12 && hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(), style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '今日の計測を始めましょう',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StartSessionButton extends ConsumerWidget {
  const _StartSessionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(planAccessStateProvider);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: switch (planState) {
        PlanAccessLoading() => FilledButton.icon(
          onPressed: null,
          icon: Semantics(
            label: 'プラン情報を読み込み中',
            liveRegion: true,
            child: const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          label: const Text('プラン情報を確認中...'),
        ),
        PlanAccessError() => FilledButton.icon(
          onPressed: () => ref.invalidate(planAccessStateStreamProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('プラン情報を再読み込み'),
        ),
        PlanAccessReady(:final capabilities) => FilledButton.icon(
          onPressed: () async {
            if (capabilities.canUseMeasurementSessions) {
              context.pushNamed('measurementSessionSetup');
              return;
            }

            final shouldViewPlans = await showUpgradePromptDialog(
              context,
              title: 'Teamプラン限定機能です',
              message: '計測会はTeamプランで利用できます。',
            );
            if (!context.mounted || !shouldViewPlans) {
              return;
            }

            context.pushNamed('settingsPlan');
          },
          icon: const Icon(Icons.groups),
          label: const Text('計測会を開始（チームでまとめて計測）'),
        ),
      },
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.videocam,
            label: '動画から計測を開始',
            onTap: () => context.pushNamed('videoImport'),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.edit_note,
            label: '手入力で追加',
            onTap: () => ManualRecordForm.show(context),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 36, color: AppColors.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(label, style: AppTextStyles.cardTitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AthleteSection extends ConsumerWidget {
  const _AthleteSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athleteState = ref.watch(athleteListNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('選手一覧', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        athleteState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (message) => Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ),
          loaded: (athletes) {
            if (athletes.isEmpty) {
              return _EmptyAthleteCard();
            }
            return _AthleteListCard(athletes: athletes);
          },
        ),
      ],
    );
  }
}

class _AthleteListCard extends StatelessWidget {
  const _AthleteListCard({required this.athletes});

  final List<Athlete> athletes;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < athletes.length; i++) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                child: Text(athletes[i].name.characters.first),
              ),
              title: Text(athletes[i].name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.goNamed(
                'recordList',
                queryParameters: {'view': 'sheet', 'athleteId': athletes[i].id},
              ),
            ),
            if (i < athletes.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _EmptyAthleteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(
          child: Text(
            'まだ選手が登録されていません',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
