import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/widgets/record_list_tile.dart';
import 'package:physi_log/models/measurement_record.dart';

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
              const _RecentRecordsSection(),
              const SizedBox(height: AppSpacing.xl),
              const _StatsSection(),
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
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('準備中')));
            },
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

class _RecentRecordsSection extends ConsumerWidget {
  const _RecentRecordsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordListNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('最新の記録', style: AppTextStyles.sectionTitle),
            const Spacer(),
            TextButton(
              onPressed: () => context.goNamed('recordList'),
              child: const Text('すべて見る'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        state.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(),
            ),
          ),
          loaded: (records, _, __) {
            if (records.isEmpty) {
              return _EmptyRecordsCard();
            }
            final recent = records.take(3).toList();
            return Column(
              children: recent
                  .map((record) => RecordListTile(record: record))
                  .toList(),
            );
          },
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
        ),
      ],
    );
  }
}

class _EmptyRecordsCard extends StatelessWidget {
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
            'まだ記録がありません',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordListNotifierProvider);

    final records = state.maybeWhen(
      loaded: (records, _, __) => records,
      orElse: () => <MeasurementRecord>[],
    );

    final totalCount = records.length;
    final athleteCount = records
        .map((r) => r.athleteName)
        .where((n) => n.isNotEmpty)
        .toSet()
        .length;
    final eventCount = records
        .map((r) => r.eventType)
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(value: '$totalCount', label: '総記録'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(value: '$athleteCount', label: '選手数'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(value: '$eventCount', label: '種目数'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
