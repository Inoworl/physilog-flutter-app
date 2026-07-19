import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/features/manage/presentation/athlete_form_sheet.dart';
import 'package:physi_log/features/manage/presentation/event_form_sheet.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/providers/app_providers.dart';

class ManageScreen extends ConsumerWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athleteState = ref.watch(athleteListNotifierProvider);
    final eventState = ref.watch(eventListNotifierProvider);
    final planState = ref.watch(planAccessStateProvider);
    final capabilities = switch (planState) {
      PlanAccessReady(:final capabilities) => capabilities,
      _ => null,
    };
    final loadedAthletes = athleteState.maybeWhen<List<Athlete>?>(
      loaded: (athletes) => athletes,
      orElse: () => null,
    );
    final loadedEvents = eventState.maybeWhen<List<Event>?>(
      loaded: (events) => events,
      orElse: () => null,
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanAccessNotice(
                state: planState,
                onRetry: () => ref.invalidate(planAccessStateStreamProvider),
              ),
              if (planState is! PlanAccessReady)
                const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: '選手',
                onAdd: loadedAthletes == null || capabilities == null
                    ? null
                    : () {
                        final maxAthleteCount = capabilities.maxAthleteCount;
                        if (!capabilities.canAddAthlete(
                          loadedAthletes.length,
                        )) {
                          _showPlanLimitDialog(
                            context,
                            targetName: '選手',
                            unit: '人',
                            limit: maxAthleteCount!,
                          );
                          return;
                        }
                        AthleteFormSheet.show(context);
                      },
              ),
              const SizedBox(height: 8),
              athleteState.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (message) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('選手データの読み込みに失敗しました'),
                    subtitle: Text(message),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref
                          .read(athleteListNotifierProvider.notifier)
                          .refresh(),
                    ),
                  ),
                ),
                loaded: (athletes) => _AthleteList(athletes: athletes),
              ),
              const SizedBox(height: 32),
              _SectionHeader(
                title: '種目',
                onAdd: loadedEvents == null || capabilities == null
                    ? null
                    : () {
                        final maxEventCount = capabilities.maxEventCount;
                        if (!capabilities.canAddEvent(loadedEvents.length)) {
                          _showPlanLimitDialog(
                            context,
                            targetName: '種目',
                            unit: 'つ',
                            limit: maxEventCount!,
                          );
                          return;
                        }
                        EventFormSheet.show(context);
                      },
              ),
              const SizedBox(height: 8),
              eventState.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (message) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('種目データの読み込みに失敗しました'),
                    subtitle: Text(message),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref
                          .read(eventListNotifierProvider.notifier)
                          .refresh(),
                    ),
                  ),
                ),
                loaded: (events) => _EventList(events: events),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanAccessNotice extends StatelessWidget {
  const _PlanAccessNotice({required this.state, required this.onRetry});

  final PlanAccessState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      PlanAccessLoading() => Card(
        child: ListTile(
          leading: Semantics(
            label: 'プラン情報を読み込み中',
            liveRegion: true,
            child: const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          title: const Text('プラン情報を確認中...'),
        ),
      ),
      PlanAccessError() => Card(
        child: ListTile(
          leading: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('プラン情報の取得に失敗しました'),
          trailing: IconButton(
            tooltip: 'プラン情報を再読み込み',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ),
      ),
      PlanAccessReady() => const SizedBox.shrink(),
    };
  }
}

Future<void> _showPlanLimitDialog(
  BuildContext context, {
  required String targetName,
  required String unit,
  required int limit,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('現在のプラン上限に達しています'),
      content: Text('現在のプランでは$targetNameは$limit$unitまで登録できます。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('追加'),
        ),
      ],
    );
  }
}

class _AthleteList extends StatelessWidget {
  const _AthleteList({required this.athletes});

  final List<Athlete> athletes;

  @override
  Widget build(BuildContext context) {
    if (athletes.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('選手データはまだありません'),
          subtitle: Text('右上の「追加」から選手を登録できます'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < athletes.length; i++) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                child: Text(athletes[i].name.characters.first),
              ),
              title: Text(athletes[i].name, style: AppTextStyles.cardTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AthleteFormSheet.show(context, athlete: athletes[i]),
            ),
            if (i < athletes.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('種目データはまだありません'),
          subtitle: Text('右上の「追加」から種目を登録できます'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: Text(events[i].name, style: AppTextStyles.cardTitle),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    EventFormSheet.show(context, event: events[i]);
                  } else if (value == 'delete') {
                    EventFormSheet.show(context, event: events[i]);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('編集')),
                  PopupMenuItem(value: 'delete', child: Text('削除')),
                ],
              ),
            ),
            if (i < events.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
