import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/records/presentation/manual_record_form.dart';
import 'package:physi_log/models/athlete.dart';

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
              const _GreetingSection(),
              const SizedBox(height: AppSpacing.xxl),
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

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.videocam,
            label: '動画計測',
            onTap: () => context.goNamed('videoImport'),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.edit_note,
            label: '手動記録',
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
        Text('選手一覧', style: AppTextStyles.sectionTitle),
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
